# Which outlets feed the answer, by the voter's side. Citations rendered in the answer,
# classified by domain, for the labelled full-profile captures.
# Output: tables/sources_by_side.csv, tables/top_domains_by_side.csv, figures/03_*
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]))), "00_setup_explore.R"))
web <- web_sample() %>% filter(ask == "candidate", level == "L5") %>% mutate(side = unname(side[archetype]))
cites <- open_dataset(file.path(raw, "citations.parquet")) %>% filter(cited_in_answer) %>%
  select(execution_id, domain) %>% filter(execution_id %in% web$execution_id) %>% collect() %>%
  inner_join(web %>% select(execution_id, archetype, side, office, advice), by = "execution_id") %>%
  mutate(domain = str_remove(str_to_lower(domain), "^www\\."),
    source_type = case_when(
      str_detect(domain, "tse\\.jus\\.br|\\.gov\\.br|\\.leg\\.br|\\.jus\\.br|planalto") ~ "Official",
      str_detect(domain, "wikipedia") ~ "Wikipedia",
      str_detect(domain, "instagram|facebook|youtube|twitter|x\\.com|tiktok|linkedin|threads") ~ "Social media",
      str_detect(domain, "\\.org\\.br|partido|psol|novo\\.org|mbl|missao") ~ "Party and movement sites",
      str_detect(domain, "globo|folha|uol|estadao|cnnbrasil|poder360|metropoles|veja|cartacapital|r7\\.com|terra\\.com|correiobraziliense|gazetadopovo|jota|nexojornal|valor|infomoney|exame|istoe|bbc|reuters|elpais|dw\\.com|agenciabrasil|congressoemfoco|brasildefato|oantagonista|jovempan|piaui|sbt|band|revistaforum|theintercept") ~ "Press and news",
      TRUE ~ "Other"))
write_table(cites %>% count(side, source_type, name = "links") %>% group_by(side) %>% mutate(share = links / sum(links)) %>% ungroup(), "sources_by_side")
write_table(cites %>% count(side, domain, sort = TRUE) %>% group_by(side) %>% mutate(share = n / sum(n)) %>% slice_head(n = 12) %>% ungroup(), "top_domains_by_side")
# Every domain with enough links, any type, by the voter's side; share of the side's links.
domains <- cites %>% count(side, domain, source_type) %>% group_by(side) %>% mutate(share = n / sum(n)) %>% ungroup()
keep <- domains %>% group_by(domain) %>% summarise(n = sum(n)) %>% filter(n >= 80) %>% pull(domain)
p <- domains %>% filter(domain %in% keep) %>%
  mutate(side = factor(side, c("Left profiles", "Centre profiles", "Right profiles")), domain = reorder(domain, share, FUN = max),
    source_type = factor(source_type, c("Official", "Press and news", "Party and movement sites", "Wikipedia", "Social media", "Other"))) %>%
  ggplot(aes(share, domain, color = side)) + geom_point(size = 2.2, position = position_dodge(width = .6)) +
  facet_grid(source_type ~ ., scales = "free_y", space = "free_y") +
  scale_x_continuous(labels = pct) + scale_color_manual(values = unname(palette[c("coral", "gold", "navy")])) +
  labs(x = "Share of the side's links shown in the answer", y = NULL, color = NULL,
    caption = "ChatGPT web, full profiles, specific-candidate wording, labelled captures; links rendered in the answer, domains with at least 80 links across all profiles.") +
  theme(strip.text.y = element_text(angle = 0, hjust = 0))
save_figure("03_domains_by_side", p, 10, 9)
message("Citations classified: ", nrow(cites))
