# ChatGPT web captures collected by Ranqia: one row per execution, matched back
# to the 256 handoff prompts; plus the links shown in each answer.
# Input:  data/web/{raw_executions,citations,query_fan_outs}.parquet
#         reference/prompts_2026-08-14.json
# Output: output/derived/{responses_web,web_captures,web_citations,web_queries,
#         web_rule_links}.parquet
# responses_web carries the answer text and stays local; web_captures is the same table
# without text, plus a flag for answers that mention the ban on AI recommendations.
# Captures that are interface states rather than answers ("Log in for advice",
# "Searching the web", "Worked for 7s") are flagged incomplete.
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup.R"
))

handoff <- fromJSON(handoff_path, simplifyVector = FALSE)$prompts %>%
  map_dfr(~ tibble(
    condition_id = str_remove(.x$id, "__(president|deputy)_(open|candidate)$"),
    question_id = str_extract(.x$id, "(president|deputy)_(open|candidate)$"),
    archetype = .x$archetype,
    level = .x$level,
    gender = .x$gender,
    prompt = .x$prompt
  )) %>%
  mutate(
    across(c(archetype, gender), ~ na_if(.x, "None")),
    prompt_key = str_squish(prompt),
    body = str_squish(str_remove(prompt, "\\n\\n[^\\n]+$")),
    question = str_extract(prompt, "[^\\n]+$"),
    office = if_else(str_starts(question_id, "president"), "president", "federal_deputy"),
    ask = if_else(str_ends(question_id, "open"), "open", "candidate")
  )
stopifnot(nrow(handoff) == 256)

executions <- read_parquet(
  file.path(web_raw_dir, "raw_executions.parquet"),
  col_select = c("execution_id", "prompt_id", "prompt_text", "search_date", "response_text")
)
prompts <- executions %>%
  distinct(prompt_id, prompt_text) %>%
  mutate(prompt_key = str_squish(prompt_text)) %>%
  inner_join(handoff, by = "prompt_key")
stopifnot(nrow(prompts) == 256)

artefact <- paste0(
  "^\\s*(?:\\*\\s+)?(?:Log in for advice|Searching the web|Searching \\d+ websites|",
  "This may take a while|Unable to connect|Worked for \\d+s|Claro\\s+Escuro)"
)
queries <- read_parquet(
  file.path(web_raw_dir, "query_fan_outs.parquet"), col_select = c("execution_id", "query")
)
responses <- executions %>%
  select(-prompt_text) %>%
  inner_join(
    prompts %>% select(
      prompt_id, condition_id, question_id, archetype, level, gender, office, ask, body, question
    ),
    by = "prompt_id"
  ) %>%
  left_join(count(queries, execution_id, name = "n_queries"), by = "execution_id") %>%
  mutate(
    response_id = as.character(execution_id),
    source = "chatgpt_web",
    model_key = "chatgpt_web",
    run_date = as.Date(search_date),
    # Rendering residue: favicon images and bullet indents from the page.
    answer = response_text %>%
      str_remove_all("!\\[\\]\\(https?://[^)]*\\)") %>%
      str_replace_all("(?m)^\\*\\s{3}", "- ") %>%
      str_trim(),
    complete = !is.na(response_text) & str_trim(response_text) != "" &
      !str_detect(response_text, artefact) & str_length(response_text) >= 200,
    search_used = replace_na(n_queries, 0L) > 0
  ) %>%
  group_by(prompt_id, run_date) %>%
  mutate(repetition = row_number()) %>%
  ungroup() %>%
  select(
    source, response_id, condition_id, archetype, level, gender, question_id,
    office, ask, body, question, model_key, repetition, run_date, answer, complete, search_used
  )
stopifnot(!anyDuplicated(responses$response_id))
write_parquet(responses, derived("responses_web"))
ban <- paste0(
  "23\\.?755|(veda|proib)[^.]{0,120}(inteligencia artificial|\\bia\\b|chatbot)|",
  "(inteligencia artificial|\\bia\\b|chatbot)[^.]{0,120}(veda|proib)"
)
responses %>%
  mutate(
    mentions_ban = str_detect(
      str_to_lower(stringi::stri_trans_general(answer, "Latin-ASCII")), ban
    )
  ) %>%
  select(-answer, -body, -question) %>%
  write_parquet(derived("web_captures"))

# The queries the interface sent to its search engine, one row each.
queries %>%
  transmute(response_id = as.character(execution_id), query) %>%
  write_parquet(derived("web_queries"))

# Links, with a flag for the ones that touch the electoral court's rule on AI (Resolucao
# 23.755/2026): the text of the resolution itself, or news and explainers about the rules
# for AI in the election.
citations <- read_parquet(
  file.path(web_raw_dir, "citations.parquet"),
  col_select = c("execution_id", "url", "domain", "cited_in_answer")
) %>%
  mutate(
    url = str_to_lower(url),
    rule_page = case_when(
      str_detect(url, "23-755|23\\.755|23755") ~ "resolution text",
      str_detect(url, "inteligencia-artificial|ia-generativa|uso-de-ia|regras-para-uso-de-ia") ~
        "news about the rule",
      TRUE ~ NA_character_
    )
  )
# Links rendered in the visible answer, by domain.
citations %>%
  filter(cited_in_answer) %>%
  transmute(
    response_id = as.character(execution_id),
    domain = str_remove(str_to_lower(domain), "^www\\."),
    rule_page = !is.na(rule_page)
  ) %>%
  write_parquet(derived("web_citations"))
# Retrieved rule pages are kept whether or not the answer showed them.
citations %>%
  filter(!is.na(rule_page)) %>%
  transmute(response_id = as.character(execution_id), rule_page, shown = cited_in_answer) %>%
  distinct() %>%
  write_parquet(derived("web_rule_links"))
message(
  "Web: ", nrow(responses), " captures, ", sum(responses$complete), " complete, ",
  n_distinct(responses$run_date), " dates."
)
