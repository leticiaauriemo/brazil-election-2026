# Cleans the RANQIA ChatGPT-web export into the standard response table.
#
# Input:  data/ranqia/raw/raw_executions.parquet        one row per execution
#         data/ranqia/raw/citations.parquet             one row per citation record
#         data/ranqia/raw/query_fan_outs.parquet        one row per search query
#         round_2026-08-14/brazil_eval_archetype_prompts_2026-08-14.json
# Output: output/derived/responses_ranqia.parquet           standard columns
#         output/tables/qc_ranqia_*.csv
#
# RANQIA ran the 256 prompts of the 2026-08-19 handoff through the ChatGPT web
# interface with browser automation, about 3,700 times each, on four dates. The
# export carries no model identifier: `provider` is "openai" throughout, and the
# product surface is what is being measured. Every execution is therefore given
# model_key "chatgpt_web", and the design labels come from matching the prompt
# text back to the handoff.
#
# Two things distinguish this source from the API round. The text is a rendering
# of the web page, so it carries markdown bullet indents, favicon images and
# source chips that are not part of the answer. And some captures are not answers
# at all but interface states - a login wall, "Searching the web", "Worked for
# 7s" - which are flagged incomplete here rather than left for the coder to read
# as refusals.

# Shared definitions (paths, taxonomies, helpers), located relative to this file.
this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))

# --- Design crosswalk ------------------------------------------------------
# The handoff joined body and question with a blank line; RANQIA's platform
# joined them with a space. Whitespace is collapsed on both sides before matching
# and every one of the 256 prompts must resolve.
handoff <- jsonlite::fromJSON(handoff_path, simplifyVector = FALSE)$prompts %>%
  map_dfr(~ tibble(
    condition_id = str_remove(.x$id, "__(president|deputy)_(open|candidate)$"),
    question_id = str_extract(.x$id, "(president|deputy)_(open|candidate)$"),
    archetype = scalar_chr(.x$archetype),
    level = scalar_chr(.x$level),
    gender = scalar_chr(.x$gender),
    prompt_handoff = .x$prompt
  )) %>%
  mutate(
    archetype = na_if(archetype, "None"),
    gender = na_if(gender, "None"),
    prompt_key = str_squish(prompt_handoff),
    body = str_squish(str_remove(prompt_handoff, "\\n\\n[^\\n]+$"))
  ) %>%
  left_join(questions, by = "question_id")
stopifnot(nrow(handoff) == 256, n_distinct(handoff$prompt_key) == 256)

prompts <- read_parquet(file.path(ranqia_raw_dir, "raw_executions.parquet"), col_select = c("prompt_id", "prompt_text")) %>%
  distinct() %>%
  mutate(prompt_key = str_squish(prompt_text)) %>%
  inner_join(handoff, by = "prompt_key")
stopifnot(nrow(prompts) == 256, n_distinct(prompts$prompt_id) == 256)

# --- Executions -------------------------------------------------------------
executions <- read_parquet(
  file.path(ranqia_raw_dir, "raw_executions.parquet"),
  col_select = c("execution_id", "prompt_id", "provider", "search_date", "response_text")
)
stopifnot(all(executions$provider == "openai"), n_distinct(executions$execution_id) == nrow(executions))

# Interface states captured instead of an answer. Each pattern was read off the
# corpus of short captures; anything under 200 characters that is not one of
# them is listed in qc_ranqia_short_texts.csv for inspection.
artefact_pattern <- paste0(
  "^\\s*(?:\\*\\s+)?(?:",
  "Log in for advice|Searching the web|Searching \\d+ websites|This may take a while|",
  "Unable to connect|Worked for \\d+s|Claro\\s+Escuro",
  ")"
)

# Rendering residue. Favicon images precede the source chips ChatGPT shows after
# a searched claim ("Justiça Eleitoral+1"); the chip text itself is left in place
# because it cannot be separated from the answer without a parser of the page.
strip_web_markup <- function(x) {
  x %>%
    str_remove_all("!\\[\\]\\(https?://[^)]*\\)") %>%
    str_replace_all("(?m)^\\*\\s{3}", "- ") %>%
    str_replace_all("(?m)^ {4}", "") %>%
    str_replace_all("\\\\\\[(\\d+)\\\\\\]", "[\\1]") %>%
    str_trim()
}

responses <- executions %>%
  left_join(prompts %>% select(prompt_id, condition_id, question_id, archetype, level, gender, office, ask, body, question), by = "prompt_id") %>%
  mutate(
    raw_chars = str_length(response_text),
    is_artefact = is.na(response_text) | str_trim(coalesce(response_text, "")) == "" |
      str_detect(response_text, artefact_pattern),
    short_capture = raw_chars < 200,
    answer = strip_web_markup(response_text)
  ) %>%
  group_by(prompt_id, search_date) %>%
  mutate(repetition = row_number()) %>%
  ungroup()

# --- Citations and search queries -------------------------------------------
# `cited_in_answer` marks the citation records that surfaced in the visible
# answer, as opposed to pages retrieved and not shown. Query fan-outs are the
# searches the interface issued; any query means search was used.
citations <- read_parquet(file.path(ranqia_raw_dir, "citations.parquet"), col_select = c("execution_id", "cited_in_answer")) %>%
  group_by(execution_id) %>%
  summarise(citation_count = sum(cited_in_answer, na.rm = TRUE), citation_records = n(), .groups = "drop")

queries <- read_parquet(file.path(ranqia_raw_dir, "query_fan_outs.parquet"), col_select = c("execution_id")) %>%
  count(execution_id, name = "n_queries")

responses <- responses %>%
  left_join(citations, by = "execution_id") %>%
  left_join(queries, by = "execution_id") %>%
  mutate(
    citation_count = replace_na(citation_count, 0L),
    citation_records = replace_na(citation_records, 0L),
    n_queries = replace_na(n_queries, 0L),
    source = "chatgpt_web",
    response_id = as.character(execution_id),
    model_key = "chatgpt_web",
    run_date = as.Date(search_date),
    prompt = paste(body, question),
    complete_response = !is_artefact,
    answer_chars = str_length(answer),
    answer_words = str_count(answer, boundary("word")),
    search_used = n_queries > 0
  )

write_parquet(
  responses %>% select(all_of(standard_columns), prompt_id, execution_id, raw_chars, short_capture, citation_records, n_queries),
  derived_path("responses_ranqia")
)

# --- QC ---------------------------------------------------------------------
write_table(
  responses %>% count(run_date, complete_response, name = "n") %>% arrange(run_date),
  "qc_ranqia_by_date"
)

write_table(
  responses %>% count(prompt_id, run_date, name = "executions") %>% arrange(prompt_id, run_date),
  "qc_ranqia_prompt_date_counts"
)

write_table(
  responses %>%
    filter(is_artefact) %>%
    mutate(text = str_trunc(str_squish(response_text), 80)) %>%
    count(text, sort = TRUE),
  "qc_ranqia_artefacts"
)

write_table(
  responses %>%
    filter(raw_chars < 200, !str_detect(response_text, artefact_pattern)) %>%
    transmute(execution_id, prompt_id, run_date, raw_chars, text = str_squish(response_text)),
  "qc_ranqia_short_texts"
)

write_table(
  tibble(
    metric = c(
      "Executions", "Unique execution IDs", "Prompts matched", "Dates",
      "Interface artefacts", "Complete responses", "Duplicate answer texts",
      "Executions with citations in answer", "Executions with search queries"
    ),
    value = c(
      nrow(responses), n_distinct(responses$execution_id), n_distinct(responses$prompt_id), n_distinct(responses$run_date),
      sum(responses$is_artefact), sum(responses$complete_response), sum(duplicated(responses$response_text)),
      sum(responses$citation_count > 0), sum(responses$n_queries > 0)
    )
  ),
  "qc_ranqia_overview"
)

message(
  "Cleaned ", nrow(responses), " ChatGPT-web executions over ", n_distinct(responses$run_date), " dates; ",
  sum(responses$is_artefact), " interface artefacts flagged incomplete."
)
