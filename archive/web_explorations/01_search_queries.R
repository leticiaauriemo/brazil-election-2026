# What ChatGPT searches for when a voter asks. Ranqia logged the queries the interface
# issued; the question is whether the voter's profile enters them, and which part of it.
# Output: tables/query_terms_by_level.csv, tables/top_queries_by_profile.csv, figures/01_*
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]))), "00_setup_explore.R"))
web <- read_parquet(derived("responses_web"), col_select = c("response_id", "level", "archetype", "gender", "office", "ask", "complete", "search_used")) %>%
  filter(complete, ask == "candidate") %>% mutate(execution_id = as.integer(response_id))
queries <- read_parquet(file.path(raw, "query_fan_outs.parquet"), col_select = c("execution_id", "query")) %>%
  inner_join(web, by = "execution_id") %>%
  mutate(q = str_to_lower(stringi::stri_trans_general(query, "Latin-ASCII")),
    # Does the query carry the voter's biography, the voter's issue, the voter's politics, or only the election itself?
    demographic = str_detect(q, "\\b(mulher|homem|anos|idade|renda|salari\\w*|ensino|escolaridade|superior|medio)\\b"),
    issue = str_detect(q, paste0("agroneg|rural|ambient|privatiz|imposto|tribut|autonom|\\bmei\\b|familia|crist|evangel|",
      "seguranca|minoria|lgbt|clima|democracia|polariza|bolsa familia|programa social|custo de vida|emprego|",
      "ordem|nacionalis|sindicat|trabalhista|direitos sociais|liberal|conservador|progressist")),
    politics = str_detect(q, "esquerda|direita|bolsonar|lula|\\bpt\\b|petista|centro"),
    official = str_detect(q, "\\btse\\b|calendario|registro|divulgacand"))
by_level <- queries %>% group_by(level) %>%
  summarise(queries = n(), across(c(demographic, issue, politics, official), mean), .groups = "drop") %>%
  left_join(web %>% group_by(level) %>% summarise(captures = n(), searched = mean(search_used), .groups = "drop"), by = "level")
write_table(by_level, "query_terms_by_level")
p <- by_level %>% select(level, demographic, issue, politics, official) %>%
  pivot_longer(-level, names_to = "term", values_to = "share") %>%
  mutate(level = factor(level, level_order, labels = unname(level_labels[level_order])),
    term = factor(recode(term, demographic = "Voter's age, gender, income or education", issue = "Voter's issue or values",
      politics = "Left/right, a party or a politician", official = "TSE, registration, calendar"),
      c("TSE, registration, calendar", "Voter's issue or values", "Left/right, a party or a politician", "Voter's age, gender, income or education"))) %>%
  ggplot(aes(level, share, fill = term)) + geom_col(position = position_dodge(width = .8)) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  scale_fill_manual(values = unname(palette[c("grey", "navy", "teal", "coral")])) +
  labs(x = "What the voter reveals", y = "Share of search queries containing the terms",
    caption = "ChatGPT web, specific-candidate wording, all captures that ran a search (about 43%); 2.3 queries per search on average. A query can fall in several classes.") +
  guides(fill = guide_legend(nrow = 2))
save_figure("01_search_query_terms", p, 10, 5.5)
write_table(queries %>% filter(level == "L5") %>% count(archetype, office, query, sort = TRUE) %>%
  group_by(archetype, office) %>% mutate(share = n / sum(n)) %>% slice_head(n = 5) %>% ungroup(), "top_queries_by_profile")
message("Queries: ", nrow(queries), " from ", n_distinct(queries$execution_id), " searched captures.")
