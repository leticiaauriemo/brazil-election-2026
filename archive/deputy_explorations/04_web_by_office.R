# ChatGPT web on the two races: does it search more, read different sources, or answer
# differently when the question is about a deputy rather than the president?
# Output: tables/web_by_office.csv, tables/web_domains_by_office.csv,
#         tables/web_queries_by_office.csv, figures/04_web_domains_by_office,
#         figures/04_web_categories_by_office
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup_deputy.R"
))
web <- labelled_sample() %>%
  filter(model_key == "chatgpt_web", level == "L5")
answers <- read_parquet(derived("responses_web"), col_select = c("response_id", "answer")) %>%
  semi_join(web, by = "response_id") %>%
  mutate(answer_chars = str_length(answer)) %>%
  select(-answer)
web <- web %>%
  inner_join(answers, by = "response_id")

# 1. Headline differences.
write_table(web %>%
  group_by(office) %>%
  summarise(
    captures = n(),
    searched = mean(search_used),
    answer_chars = median(answer_chars),
    advice = mean(advice),
    any_steer = mean(any_steer),
    party_only = mean(party_only),
    names_anyone = mean(names_any),
    .groups = "drop"
  ), "web_by_office")

# 2. Category mix by office, web only.
cats <- web %>%
  count(office, category) %>%
  group_by(office) %>%
  mutate(share = n / sum(n)) %>%
  ungroup()
p <- cats %>%
  mutate(
    office = factor(unname(office_labels[office]), unname(office_labels)),
    category = fct_reorder(category, share, .fun = max)
  ) %>%
  ggplot(aes(share, category, fill = office)) +
  geom_col(position = position_dodge(width = .8)) +
  scale_x_continuous(labels = pct) +
  scale_fill_manual(values = unname(palette[c("navy", "coral")])) +
  labs(
    x = "Share of labelled captures", y = NULL,
    caption = paste0(
      "ChatGPT web, full profiles, specific-candidate wording. For the deputy race the ",
      "interface far more often explains how to choose without describing anyone."
    )
  )
save_figure("04_web_categories_by_office", p, 10, 5)

# 3. Domains by office: the deputy answer leans on the electoral court.
citations <- read_parquet(derived("web_citations")) %>%
  inner_join(web %>% select(response_id, office), by = "response_id") %>%
  mutate(source_type = case_when(
    str_detect(domain, "^gov\\.br$|tse\\.jus\\.br|\\.gov\\.br|\\.leg\\.br|\\.jus\\.br|planalto") ~
      "Official",
    str_detect(domain, "wikipedia") ~ "Wikipedia",
    str_detect(domain, "instagram|facebook|youtube|twitter|x\\.com|tiktok|linkedin|threads") ~
      "Social media",
    str_detect(domain, "\\.org\\.br|partido|psol|novo\\.org|mbl|missao") ~
      "Party and movement sites",
    TRUE ~ "Press and other"
  ))
domains <- citations %>%
  count(office, domain, source_type, name = "links") %>%
  group_by(office) %>%
  mutate(share = links / sum(links)) %>%
  ungroup()
frequent <- domains %>%
  group_by(domain) %>%
  summarise(links = sum(links)) %>%
  filter(links >= 100) %>%
  pull(domain)
write_table(domains %>% filter(domain %in% frequent), "web_domains_by_office")
p <- domains %>%
  filter(domain %in% frequent) %>%
  mutate(
    office = factor(unname(office_labels[office]), unname(office_labels)),
    domain = reorder(domain, share, FUN = max),
    source_type = factor(source_type, c(
      "Official", "Press and other", "Party and movement sites", "Wikipedia", "Social media"
    ))
  ) %>%
  ggplot(aes(share, domain, color = office)) +
  geom_point(size = 2.2, position = position_dodge(width = .6)) +
  facet_grid(source_type ~ ., scales = "free_y", space = "free_y") +
  scale_x_continuous(labels = pct) +
  scale_color_manual(values = unname(palette[c("navy", "coral")])) +
  labs(
    x = "Share of the race's links shown in the answer", y = NULL,
    caption = paste0(
      "ChatGPT web, full profiles, specific-candidate wording, labelled captures; links ",
      "rendered in the answer, domains with at least 100 links across both races."
    )
  ) +
  theme(strip.text.y = element_text(angle = 0, hjust = 0))
save_figure("04_web_domains_by_office", p, 10, 8)

# 4. What it searches for, by office: the deputy query is about the race, not a person.
queries <- read_parquet(derived("web_queries")) %>%
  inner_join(web %>% select(response_id, office, archetype), by = "response_id") %>%
  mutate(text = str_to_lower(stringi::stri_trans_general(query, "Latin-ASCII")))
write_table(queries %>%
  count(office, text, sort = TRUE) %>%
  group_by(office) %>%
  mutate(share = n / sum(n)) %>%
  slice_head(n = 15) %>%
  ungroup(), "web_queries_by_office")
message("Web captures: ", nrow(web), "; citations ", nrow(citations), "; queries ", nrow(queries))
