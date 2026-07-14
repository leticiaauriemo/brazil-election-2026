library(tidyverse)

# Run after 00_clean_results.R.
# This script checks whether issue-only prompts collapse to flagship parties
# or vary across issues within the same ideological side.

dir.create("results/analysis", showWarnings = FALSE, recursive = TRUE)

df <- read_csv(
  "results/analysis/clean_results.csv",
  show_col_types = FALSE,
  locale = locale(encoding = "UTF-8")
)

complete_models <- df %>%
  group_by(model) %>%
  summarise(rows = n(), usable_rows = sum(usable), .groups = "drop") %>%
  filter(rows == usable_rows) %>%
  pull(model)

a_all <- df %>%
  filter(usable, module == "A", model %in% complete_models)

a_issue_summary <- a_all %>%
  group_by(model, issue_cue, issue_side) %>%
  summarise(
    n = n(),
    refused2_rate = mean(refused2),
    party_rate = mean(has_party),
    zeta_rate = mean(has_zeta),
    mean_zeta = mean(zeta, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(model, issue_side, issue_cue)

a_issue_summary_by_ask_cargo <- a_all %>%
  group_by(model, cargo, ask, issue_cue, issue_side) %>%
  summarise(
    n = n(),
    refused2_rate = mean(refused2),
    party_rate = mean(has_party),
    mean_zeta = mean(zeta, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(model, cargo, ask, issue_side, issue_cue)

a_party_counts <- a_all %>%
  filter(has_party) %>%
  count(model, issue_cue, issue_side, party_rec, sort = TRUE) %>%
  group_by(model, issue_cue, issue_side) %>%
  mutate(party_share = n / sum(n)) %>%
  ungroup() %>%
  arrange(model, issue_side, issue_cue, desc(n))

a_issue_means <- a_all %>%
  filter(has_zeta) %>%
  group_by(model, cargo, ask, issue_side, issue_cue) %>%
  summarise(mean_zeta = mean(zeta, na.rm = TRUE), .groups = "drop")

a_dispersion <- a_issue_means %>%
  group_by(model, cargo, ask, issue_side) %>%
  summarise(
    issues_with_zeta = n(),
    sd_issue_mean_zeta = sd(mean_zeta, na.rm = TRUE),
    min_issue_mean_zeta = min(mean_zeta, na.rm = TRUE),
    max_issue_mean_zeta = max(mean_zeta, na.rm = TRUE),
    range_issue_mean_zeta = max_issue_mean_zeta - min_issue_mean_zeta,
    .groups = "drop"
  ) %>%
  arrange(model, cargo, ask, issue_side)

write_csv(a_issue_summary, "results/analysis/module_a_issue_summary.csv")
write_csv(a_issue_summary_by_ask_cargo, "results/analysis/module_a_issue_summary_by_ask_cargo.csv")
write_csv(a_party_counts, "results/analysis/module_a_party_counts.csv")
write_csv(a_dispersion, "results/analysis/module_a_dispersion.csv")

print(a_issue_summary)
print(a_dispersion)
