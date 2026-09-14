# Who the deputy answers talk about. The presidential field is a handful of names; the
# deputy field is 70 seats and hundreds of candidates, so the interesting question is
# concentration: how many names, how often the same ones, and whether describing a
# candidate (without recommending) already tilts by the voter's side.
# Output: tables/concentration_by_office.csv, tables/deputy_names_by_side.csv,
#         figures/05_concentration_by_office, figures/05_deputy_names_by_side
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup_deputy.R"
))
full <- labelled_sample() %>%
  filter(level == "L5")
# Every person mentioned, with the coder's stance, for the full-profile answers.
mentions <- open_dataset(labels_path) %>%
  filter(llm_status == "succeeded") %>%
  select(source, response_id, llm_entities) %>%
  collect() %>%
  semi_join(full, by = c("source", "response_id")) %>%
  unnest(llm_entities) %>%
  filter(kind == "person") %>%
  transmute(
    source, response_id, stance, name = canonical_name(name), party = canonical_party(party)
  )
aliases <- read_csv(reference("name_aliases.csv"), show_col_types = FALSE) %>%
  mutate(across(everything(), canonical_name))
mentions <- mentions %>%
  left_join(aliases, by = c("name" = "surface")) %>%
  mutate(name = coalesce(canonical, name)) %>%
  select(-canonical) %>%
  distinct() %>%
  inner_join(
    full %>% select(source, response_id, model_key, office, archetype),
    by = c("source", "response_id")
  )
write_table(mentions %>% count(office, stance), "stances_by_office")

# 1. Concentration: distinct names and the share of mentions taken by the top three,
#    per model and office, for recommended names and for any mention.
concentration <- bind_rows(
  mentions %>%
    filter(stance == "recommended") %>%
    mutate(set = "Recommended (alone or in a shortlist)"),
  mentions %>% mutate(set = "Mentioned in any way")
) %>%
  count(set, model_key, office, name) %>%
  group_by(set, model_key, office) %>%
  arrange(desc(n), .by_group = TRUE) %>%
  summarise(
    mentions = sum(n),
    distinct_names = n(),
    top3_share = sum(head(n, 3)) / sum(n),
    top_name = first(name),
    .groups = "drop"
  )
write_table(concentration, "concentration_by_office")
p <- concentration %>%
  filter(mentions >= 20) %>%
  mutate(
    model = model_name(model_key),
    office = factor(unname(office_labels[office]), unname(office_labels))
  ) %>%
  ggplot(aes(distinct_names, top3_share, color = office, shape = set)) +
  geom_point(size = 2.4) +
  ggrepel::geom_text_repel(aes(label = model), size = 2.5, show.legend = FALSE, max.overlaps = 20) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  scale_x_log10() +
  scale_color_manual(values = unname(palette[c("navy", "coral")])) +
  labs(
    x = "Distinct names (log scale)", y = "Share of mentions going to the top three names",
    caption = paste0(
      "Full profiles, specific-candidate wording; one point per model, office and set, sets ",
      "with at least 20 mentions. The presidential race is a few names; the deputy race ",
      "spreads over many, but a few recur."
    )
  ) +
  guides(color = guide_legend(nrow = 1), shape = guide_legend(nrow = 1))
save_figure("05_concentration_by_office", p, 10, 6)

# 2. Which deputies get named, by side and stance: the most-mentioned names and the share
#    of each side's answers that mention them.
deputy <- mentions %>%
  filter(office == "federal_deputy") %>%
  mutate(
    side = side_name(archetype),
    stance = if_else(stance == "recommended", "Recommended", "Described only")
  )
answers_by_side <- full %>%
  filter(office == "federal_deputy") %>%
  mutate(side = side_name(archetype)) %>%
  count(side, name = "answers")
# The coder copies the party tag as written, so one person carries several; keep the
# modal clean acronym for the label and count on the name alone.
party_label <- deputy %>%
  filter(!is.na(party), str_detect(party, "^[A-Z]{2,13}$")) %>%
  count(name, party) %>%
  group_by(name) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(name, party)
names_by_side <- deputy %>%
  distinct(source, response_id, side, stance, name) %>%
  count(side, stance, name) %>%
  inner_join(answers_by_side, by = "side") %>%
  left_join(party_label, by = "name") %>%
  mutate(share = n / answers)
write_table(names_by_side, "deputy_names_by_side")
top_names <- names_by_side %>%
  group_by(name) %>%
  summarise(n = sum(n), .groups = "drop") %>%
  slice_max(n, n = 20) %>%
  pull(name)
p <- names_by_side %>%
  filter(name %in% top_names) %>%
  mutate(
    label = paste0(str_to_title(name), " (", coalesce(party, "no party given"), ")"),
    label = fct_reorder(label, share, .fun = sum)
  ) %>%
  ggplot(aes(share, label, fill = side)) +
  geom_col(position = position_dodge(width = .8)) +
  facet_wrap(~stance) +
  scale_x_continuous(labels = pct) +
  scale_fill_manual(values = unname(palette[c("coral", "gold", "navy")])) +
  labs(
    x = "Share of the side's deputy answers mentioning the name", y = NULL,
    caption = paste0(
      "Federal deputy, SP; full profiles, specific-candidate wording; all models pooled, ",
      "answers unweighted. The twenty most-mentioned names, split by whether the answer ",
      "recommends them or only describes them."
    )
  )
save_figure("05_deputy_names_by_side", p, 12, 7)
message("Mentions: ", nrow(mentions), "; deputy names ", n_distinct(deputy$name))
