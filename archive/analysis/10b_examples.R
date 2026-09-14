# Real exchanges for the outline: one prompt and one complete answer per response
# type, chosen deterministically from the labelled sample and printed with their
# source and response id so every quotation can be traced to the raw record.
# Inputs: responses.parquet, coding_analysis.parquet, entity_mentions_analysis.parquet.
# Outputs: reviewed/<coder>/tables/examples.csv and examples.tex.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))
coding <- read_parquet(derived_path("coding_analysis"))
responses <- read_parquet(derived_path("responses"), col_select = c("source", "response_id", "model_key", "archetype",
  "level", "gender", "office", "ask", "run_date", "body", "question", "answer", "answer_chars")) %>%
  inner_join(coding, by = c("source", "response_id")) %>% filter(label_status == "labelled")

# Each row names a behaviour and the filter that identifies it; the shortest
# qualifying answer within a length band is taken, so excerpts stay readable.
pick <- function(label, data, min_chars = 400, max_chars = 2200) {
  x <- data %>% filter(answer_chars >= min_chars, answer_chars <= max_chars) %>% arrange(answer_chars, response_id) %>% slice_head(n = 1)
  stopifnot(nrow(x) == 1)
  x %>% mutate(example = label)
}
cand <- responses %>% filter(ask == "candidate")
examples <- bind_rows(
  pick("Nothing revealed: refusal with procedure (GPT-5.6 Sol)", cand %>% filter(model_key == "gpt56_sol", level == "L1", response_category == "procedural_guidance")),
  pick("Biography only: no advice (GPT-4o)", cand %>% filter(model_key == "gpt4o", level == "L3", !gives_advice, office == "president")),
  pick("Issue only: explicit endorsement (GPT-4o)", cand %>% filter(model_key == "gpt4o", level == "L2", explicit_endorsement, office == "president")),
  pick("Full profile: disclaimer then personalized shortlist (Gemini)", cand %>% filter(model_key == "gemini_pro", level == "L5", refusal_language, personalized_matching, !explicit_endorsement)),
  pick("Full profile: explicit endorsement, single name (Grok, deputy)", cand %>% filter(model_key == "grok46", level == "L5", explicit_endorsement, recommendation_strength == "single_named", office == "federal_deputy")),
  pick("Full profile: party-only matching down-ballot (Sabiá, deputy)", cand %>% filter(model_key == "sabia4", level == "L5", personalized_matching, recommendation_strength == "party_only", str_detect(recommended_parties, "^[A-Z|]+$"))),
  pick("Full profile: refusal with research guidance (Claude Opus)", cand %>% filter(model_key == "claude_opus5", level == "L5", response_category %in% c("substantive_refusal", "procedural_guidance"), !gives_advice), min_chars = 300),
  pick("Full profile, ChatGPT web: refusal with offer to compare", cand %>% filter(model_key == "chatgpt_web", level == "L5", refusal_language, !gives_advice, response_category == "procedural_guidance")),
  pick("Full profile, ChatGPT web: personalized matching", cand %>% filter(model_key == "chatgpt_web", level == "L5", personalized_matching)),
  pick("Full profile: endorsement with alternatives steered against (DeepSeek)", cand %>% filter(model_key == "deepseek_v4_pro", level == "L5", negative_steering))
) %>% select(example, source, response_id, model_key, archetype, level, gender, office, ask, run_date, response_category,
  gives_advice, refusal_language, recommended_people, recommended_parties, body, question, answer)
write_result(examples, "examples")

# LaTeX: prompt body, question and answer verbatim (escaped), long answers cut with an ellipsis.
# Links are reduced to their domain in brackets so lines stay breakable; nothing else is edited.
esc <- function(x) x %>% str_replace_all("\u2014", "---") %>% str_replace_all("\u2013", "--") %>%
  str_replace_all("\\[\\[?[0-9]+\\]?\\]\\((https?://[^/\\s)]+)[^\\s)]*\\)", "[\\1]") %>%
  str_replace_all("https?://([^/\\s)]+)[^\\s)]*", "[\\1]") %>%
  str_replace_all(fixed("\\"), "\\textbackslash{}") %>% str_replace_all("([&%$#_{}])", "\\\\\\1") %>%
  str_replace_all("~", "\\\\textasciitilde{}") %>% str_replace_all("\\^", "\\\\textasciicircum{}") %>%
  str_replace_all("\\*\\*", "") %>% str_replace_all("\n{2,}", "\n\n") %>% str_replace_all("\n", "\\\\\\\\\n")
cut <- function(x, n = 1500) if_else(str_length(x) > n, paste0(esc(str_sub(x, 1, n)), " [\\ldots]"), esc(x))
blocks <- examples %>% mutate(tex = sprintf(
  "\\subsection*{%s}\n\\noindent\\textit{%s; %s; profile %s, %s, %s; %s.}\\\\[2pt]\n\\noindent\\textbf{Prompt.} %s\\\\[2pt]\n\\noindent\\textbf{Question.} %s\\\\[2pt]\n\\noindent\\textbf{Answer.} \\begingroup\\small %s\\endgroup\\\\[2pt]\n\\noindent\\textit{Coded: %s%s%s.}\n",
  esc(example), esc(paste(source, response_id, sep = " / ")), unname(model_labels[model_key]), esc(coalesce(unname(archetype_labels[archetype]), "none")), esc(unname(level_labels[level])), coalesce(gender, "unspecified"),
  esc(recode(office, president = "president", federal_deputy = "federal deputy, SP")),
  if_else(body == "", "(none)", esc(body)), esc(question), cut(answer),
  esc(recode(response_category, !!!setNames(unname(category_labels), names(category_labels)))),
  if_else(recommended_people != "", paste0("; recommended people: ", esc(str_to_title(str_replace_all(recommended_people, fixed("|"), ", ")))), ""),
  if_else(recommended_parties != "", paste0("; recommended parties: ", esc(str_replace_all(recommended_parties, fixed("|"), ", "))), "")))
writeLines(blocks$tex, file.path(result_dir, "tables", "examples.tex"))
message("Wrote ", nrow(examples), " traced examples.")
