# What a deputy steer looks like. When a model steers a voter on the deputy race, does it
# name one person, a shortlist, or only a party? And do the three readings point to the
# same parties for the same voters?
# Output: tables/steer_shape_by_model.csv, tables/deputy_parties_by_reading.csv,
#         figures/02_steer_shape_by_office, figures/02_deputy_parties_by_reading
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup_deputy.R"
))
full <- labelled_sample() %>%
  filter(level == "L5")
entities <- read_parquet(derived("entities"))

# 1. The shape of a steer, by model and office: share of all labelled answers.
shape <- rate_by(full, model_key, office, outcomes = c(advice, shortlist, party_only)) %>%
  select(model_key, office, advice, shortlist, party_only) %>%
  pivot_longer(c(advice, shortlist, party_only), names_to = "shape", values_to = "share")
write_table(shape, "steer_shape_by_model")
p <- shape %>%
  mutate(
    model = model_name(model_key),
    office = factor(unname(office_labels[office]), unname(office_labels)),
    shape = factor(
      recode(shape,
        advice = "Names one candidate", shortlist = "Personalized shortlist",
        party_only = "Names a party, no candidate"
      ),
      c("Names one candidate", "Personalized shortlist", "Names a party, no candidate")
    )
  ) %>%
  ggplot(aes(share, fct_rev(model), fill = shape)) +
  geom_col() +
  facet_wrap(~office) +
  scale_x_continuous(labels = pct) +
  scale_fill_manual(values = unname(palette[c("navy", "teal", "gold")])) +
  labs(
    x = "Share of labelled answers", y = NULL,
    caption = paste0(
      "Full profiles, specific-candidate wording. Answers that endorse or match the voter ",
      "to an option, split by what they point to. Deputy steers are far more often a party ",
      "without a person."
    )
  )
save_figure("02_steer_shape_by_office", p, 11, 5)

# 2. Which parties, under three readings, by the voter's side. Each reading is a share of
# the answers of that kind; a shortlist splits evenly over its people.
deputy <- full %>%
  filter(office == "federal_deputy")
party_of <- function(ids, kind_wanted) {
  entities %>%
    semi_join(ids, by = c("source", "response_id")) %>%
    filter(kind == kind_wanted, !is.na(party), str_detect(party, "^[A-Z]{2,13}$")) %>%
    distinct(source, response_id, party) %>%
    group_by(source, response_id) %>%
    mutate(w = 1 / n()) %>%
    ungroup() %>%
    inner_join(ids, by = c("source", "response_id"))
}
ids <- function(flag) {
  deputy %>%
    filter({{ flag }}) %>%
    select(source, response_id, model_key, archetype)
}
readings <- bind_rows(
  party_of(ids(party_only), "party") %>% mutate(reading = "Party named alone"),
  party_of(ids(advice), "person") %>% mutate(reading = "Party of the one named candidate"),
  party_of(ids(shortlist), "person") %>% mutate(reading = "Parties of the shortlisted candidates")
) %>%
  mutate(side = side_name(archetype)) %>%
  group_by(reading, side, party) %>%
  summarise(weight = sum(w), .groups = "drop") %>%
  group_by(reading, side) %>%
  mutate(answers = sum(weight), share = weight / answers) %>%
  ungroup()
write_table(readings, "deputy_parties_by_reading")
top_parties <- readings %>%
  group_by(party) %>%
  summarise(share = max(share), .groups = "drop") %>%
  filter(share >= .05) %>%
  pull(party)
p <- readings %>%
  filter(party %in% top_parties) %>%
  mutate(
    party = fct_reorder(party, share, .fun = max),
    reading = factor(reading, c(
      "Party named alone", "Party of the one named candidate",
      "Parties of the shortlisted candidates"
    ))
  ) %>%
  ggplot(aes(share, party, color = reading, shape = reading)) +
  geom_point(size = 2.4, position = position_dodge(width = .6)) +
  facet_wrap(~side) +
  scale_x_continuous(labels = pct) +
  scale_color_manual(values = unname(palette[c("gold", "navy", "teal")])) +
  labs(
    x = "Share of steering answers pointing to the party", y = NULL,
    caption = paste0(
      "Federal deputy, SP; full profiles, specific-candidate wording; all models pooled, ",
      "answers unweighted. Parties reaching 5% under any reading."
    )
  ) +
  guides(color = guide_legend(nrow = 1))
save_figure("02_deputy_parties_by_reading", p, 12, 5.5)
message("Readings: ", nrow(readings), " rows.")
