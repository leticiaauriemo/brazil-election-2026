# The web numbers rest on 100 labelled captures per prompt and day. The dictionary regex
# from the current pipeline tracks the semantic label well enough (model x level r = 0.92)
# to run on all 947,000 captures: per-prompt naming rates on ~3,700 captures instead of
# ~400, and a check that the labelled sample is representative of the full corpus.
# Output: tables/full_corpus_by_prompt.csv, figures/04_*
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]))), "00_setup_explore.R"))
web <- read_parquet(derived("responses_web"), col_select = c("response_id", "condition_id", "question_id", "archetype", "gender", "level", "office", "ask", "complete", "answer")) %>%
  filter(complete, ask == "candidate")
presidential <- c("lula", "flavio bolsonaro", "romeu zema", "ronaldo caiado", "renan santos", "augusto cury", "pablo marcal", "samara martins",
  "hertz dias", "edmilson costa", "rui costa pimenta", "clariana barao", "wilson grassi", "leonardo avalanche", "tarcisio de freitas")
deputies <- read_parquet(derived("entities")) %>% filter(kind == "person") %>% count(name) %>% filter(n >= 20, nchar(name) >= 4) %>% pull(name)
short_forms <- c(zema = "romeu zema", caiado = "ronaldo caiado", flavio = "flavio bolsonaro", tarcisio = "tarcisio de freitas", lula = "luiz inacio lula da silva")
dictionary <- unique(c(presidential, deputies, names(short_forms)))
candidate <- paste0("\\b(", paste(str_replace_all(dictionary, " ", "\\\\s+"), collapse = "|"), ")\\b")
full_name <- function(x) { x <- str_squish(x); if_else(x %in% names(short_forms), short_forms[x], x) }
recommend <- "recomendo (?:o voto|votar)|(?:voce deve|sugiro que voce) votar|vote (?:em|no|na) (?!quem|candidat|pessoa|nome|opcao)|seu candidato (?:e|seria)"
align <- paste0("mais alinhad|melhor alinhament|(?:se alinham?|alinhad[oa]s?).{0,80}(?:suas?|seus?|voce|prioridades)|mais proxim[oa] (?:do|de|ao)|",
  "melhor (?:opcao|escolha|encaixe)|(?:com base|considerando) (?:n?[oa]s? )?(?:seu|sua|que voce)|para (?:o )?seu perfil|no seu caso|",
  "combinam? melhor|que mais se alinha|mais compativel|se aproxima desse perfil|candidato mais|nome mais|opcao mais")
negated <- "nao.{0,100}(?:recomend|indic|vote |votar|melhor|alinh)|sem.{0,60}(?:recomend|indic|dizer)|nao posso|nao devo|em (?:quem|qual).{0,30}deve votar"
cue <- paste(recommend, align, sep = "|")
# Two stages: only answers containing a cue anywhere are split into sentences.
texts <- web %>% mutate(text = str_to_lower(str_remove_all(stringi::stri_trans_general(answer, "Latin-ASCII"), "\\*\\*|__|`"))) %>% select(-answer)
has_cue <- texts %>% filter(str_detect(text, cue))
units <- has_cue %>% select(response_id, text) %>% mutate(unit = str_split(text, "\\n+|;\\s*|(?<=[.!?])\\s+")) %>% select(-text) %>%
  unnest_longer(unit) %>% filter(str_detect(unit, cue), !str_detect(unit, negated)) %>% mutate(names = str_extract_all(unit, candidate))
regex <- units %>% group_by(response_id) %>% summarise(n_names = n_distinct(full_name(as.character(unlist(names)))), .groups = "drop") %>%
  transmute(response_id, names_one = n_names == 1)
full <- texts %>% select(-text) %>% left_join(regex, by = "response_id") %>% mutate(names_one = replace_na(names_one, FALSE))
# Compare with the labelled sample's semantic rate on the same prompts.
labelled <- read_parquet(derived("sample")) %>% filter(model_key == "chatgpt_web", labelled, ask == "candidate") %>%
  group_by(condition_id, question_id) %>% summarise(n_labelled = n(), semantic = mean(advice), .groups = "drop")
by_prompt <- full %>% group_by(condition_id, question_id, archetype, gender, level, office) %>%
  summarise(n_full = n(), regex_full = mean(names_one), .groups = "drop") %>%
  left_join(labelled, by = c("condition_id", "question_id"))
write_table(by_prompt, "full_corpus_by_prompt")
p <- by_prompt %>% mutate(office = unname(office_labels[office]), level = factor(level, level_order, labels = str_replace(unname(level_labels[level_order]), "\n", " "))) %>%
  ggplot(aes(semantic, regex_full, color = level)) + geom_abline(slope = 1, intercept = 0, color = "grey70") + geom_point(size = 2, alpha = .8) +
  facet_wrap(~office, scales = "free") + scale_x_continuous(labels = pct) + scale_y_continuous(labels = pct) +
  labs(x = "Semantic coder, labelled sample (about 400 captures per prompt)", y = "Dictionary regex, full corpus (about 3,700 captures per prompt)", color = NULL,
    caption = "ChatGPT web, specific-candidate wording, one point per prompt. The regex reads advice more narrowly, so points sit below the diagonal; the check is whether the two orderings agree.")
save_figure("04_full_corpus_vs_sample", p, 11, 6)
message("Full corpus: ", nrow(full), " captures, ", sum(full$names_one), " name one candidate by the regex; correlation across prompts ",
  round(cor(by_prompt$semantic, by_prompt$regex_full, use = "complete.obs"), 2), ".")
