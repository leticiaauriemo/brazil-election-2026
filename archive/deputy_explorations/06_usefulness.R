# Is the assistant any use to a voter who does not know the deputy field? The refusal to
# name one candidate covers very different answers: a shortlist, a party, a description of
# candidates, or bare procedure. This orders them from most to least actionable, by office.
# Output: tables/usefulness_by_office.csv, tables/usefulness_by_model_office.csv,
#         tables/usefulness_by_level_office.csv, figures/06_usefulness_by_office
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup_deputy.R"
))
sample <- labelled_sample() %>%
  mutate(
    tier = case_when(
      advice ~ "Names one candidate",
      shortlist ~ "Names a personalized shortlist",
      party_only ~ "Names a party, no candidate",
      names_any ~ "Describes candidates, picks none",
      procedure ~ "Explains how to choose, names nobody",
      TRUE ~ "Declines, nothing else"
    ),
    tier = factor(tier, c(
      "Names one candidate", "Names a personalized shortlist", "Names a party, no candidate",
      "Describes candidates, picks none", "Explains how to choose, names nobody",
      "Declines, nothing else"
    )),
    office = factor(unname(office_labels[office]), unname(office_labels))
  )
# Shares weighted as elsewhere: days within prompt, prompts within model, models equal.
tier_shares <- function(d, by) {
  cells <- d %>%
    distinct(across(all_of(c(by, "model_key", "prompt_cell", "run_date")))) %>%
    cross_join(distinct(d, tier))
  d %>%
    count(across(all_of(c(by, "model_key", "prompt_cell", "run_date"))), tier, name = "k") %>%
    group_by(across(all_of(c(by, "model_key", "prompt_cell", "run_date")))) %>%
    mutate(p = k / sum(k)) %>%
    ungroup() %>%
    right_join(cells, by = c(by, "model_key", "prompt_cell", "run_date", "tier")) %>%
    mutate(p = replace_na(p, 0)) %>%
    group_by(across(all_of(c(by, "model_key", "prompt_cell"))), tier) %>%
    summarise(p = mean(p), .groups = "drop") %>%
    group_by(across(all_of(c(by, "model_key"))), tier) %>%
    summarise(p = mean(p), .groups = "drop")
}
full <- sample %>%
  filter(level == "L5")
by_model <- tier_shares(full, "office")
write_table(by_model, "usefulness_by_model_office")
pooled <- by_model %>%
  group_by(office, tier) %>%
  summarise(share = mean(p), .groups = "drop")
write_table(pooled, "usefulness_by_office")
by_level <- tier_shares(sample, c("office", "level")) %>%
  group_by(office, level, tier) %>%
  summarise(share = mean(p), .groups = "drop")
write_table(by_level, "usefulness_by_level_office")
# Refusal language itself, by office and model, full profiles.
write_table(
  rate_by(full, model_key, office, outcomes = c(refusal, names_any, procedure)),
  "refusal_by_model_office"
)

p <- by_model %>%
  bind_rows(pooled %>% mutate(model_key = "all", p = share)) %>%
  mutate(model = factor(
    coalesce(unname(model_labels[model_key]), "All models, equal weight"),
    rev(c(unname(model_labels[model_levels]), "All models, equal weight"))
  )) %>%
  ggplot(aes(p, model, fill = tier)) +
  geom_col() +
  facet_wrap(~office) +
  scale_x_continuous(labels = pct) +
  scale_fill_manual(values = c(
    palette[["navy"]], palette[["teal"]], palette[["gold"]], "#A8C5D6", "#C9CED3",
    palette[["coral"]]
  )) +
  labs(
    x = "Share of labelled answers", y = NULL,
    caption = paste0(
      "Full profiles, specific-candidate wording. Answers ordered from most to least ",
      "actionable for a voter; each answer falls in exactly one tier."
    )
  ) +
  guides(fill = guide_legend(nrow = 2))
save_figure("06_usefulness_by_office", p, 12, 6)
message("Tiers: ", nrow(by_model), " model x office x tier rows.")
