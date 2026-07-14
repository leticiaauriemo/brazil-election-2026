library(tidyverse)

# Run after 00_clean_results.R.
# This script estimates the main Module C label-vs-issue patterns.
# Effects are simple differences in mean zeta among rows with a coded party.

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

c_all <- df %>%
  filter(usable, module == "C", model %in% complete_models)

c_party <- c_all %>%
  filter(has_zeta)

module_c_outcome_rates <- c_all %>%
  group_by(model) %>%
  summarise(
    n = n(),
    refused2_rate = mean(refused2),
    party_rate = mean(has_party),
    zeta_rate = mean(has_zeta),
    .groups = "drop"
  )

module_c_effects_by_model <- c_party %>%
  group_by(model) %>%
  summarise(
    n_party = n(),
    mean_zeta = mean(zeta, na.rm = TRUE),
    beta_label = mean(zeta[label_side == "right"], na.rm = TRUE) -
      mean(zeta[label_side == "left"], na.rm = TRUE),
    gamma_issue = mean(zeta[issue_side == "right"], na.rm = TRUE) -
      mean(zeta[issue_side == "left"], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(gamma_share = gamma_issue / (beta_label + gamma_issue))

module_c_effects_by_model_cargo_ask <- c_party %>%
  group_by(model, cargo, ask) %>%
  summarise(
    n_party = n(),
    mean_zeta = mean(zeta, na.rm = TRUE),
    beta_label = mean(zeta[label_side == "right"], na.rm = TRUE) -
      mean(zeta[label_side == "left"], na.rm = TRUE),
    gamma_issue = mean(zeta[issue_side == "right"], na.rm = TRUE) -
      mean(zeta[issue_side == "left"], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(gamma_share = gamma_issue / (beta_label + gamma_issue)) %>%
  arrange(model, cargo, ask)

module_c_means_by_label_issue <- c_party %>%
  group_by(model, label_side, issue_side) %>%
  summarise(
    n_party = n(),
    mean_zeta = mean(zeta, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(model, label_side, issue_side)

module_c_conflict_follow <- c_party %>%
  filter(cell_type == "conflict") %>%
  mutate(
    follow_label = zeta_sign == label_num,
    follow_issue = zeta_sign == issue_num
  ) %>%
  group_by(model, cargo, ask) %>%
  summarise(
    n_party = n(),
    follow_label_rate = mean(follow_label, na.rm = TRUE),
    follow_issue_rate = mean(follow_issue, na.rm = TRUE),
    mean_zeta = mean(zeta, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(model, cargo, ask)

module_c_conflict_outcomes <- c_all %>%
  filter(cell_type == "conflict") %>%
  group_by(model, cargo, ask) %>%
  summarise(
    n = n(),
    refused2_rate = mean(refused2),
    party_rate = mean(has_party),
    zeta_rate = mean(has_zeta),
    .groups = "drop"
  ) %>%
  arrange(model, cargo, ask)

module_c_conflict_by_cue_group <- c_party %>%
  filter(cell_type == "conflict") %>%
  mutate(
    follow_label = zeta_sign == label_num,
    follow_issue = zeta_sign == issue_num
  ) %>%
  group_by(model, cue_group) %>%
  summarise(
    n_party = n(),
    follow_label_rate = mean(follow_label, na.rm = TRUE),
    follow_issue_rate = mean(follow_issue, na.rm = TRUE),
    mean_zeta = mean(zeta, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(model, cue_group)

lm_data <- c_party %>%
  filter(!is.na(label_num), !is.na(issue_num))

pooled_lm <- lm(zeta ~ label_num + issue_num + model + cargo + ask, data = lm_data)

pooled_lm_table <- as.data.frame(summary(pooled_lm)$coefficients) %>%
  rownames_to_column("term") %>%
  as_tibble() %>%
  rename(
    estimate = Estimate,
    std_error = `Std. Error`,
    statistic = `t value`,
    p_value = `Pr(>|t|)`
  )

write_csv(module_c_outcome_rates, "results/analysis/module_c_outcome_rates.csv")
write_csv(module_c_effects_by_model, "results/analysis/module_c_effects_by_model.csv")
write_csv(module_c_effects_by_model_cargo_ask, "results/analysis/module_c_effects_by_model_cargo_ask.csv")
write_csv(module_c_means_by_label_issue, "results/analysis/module_c_means_by_label_issue.csv")
write_csv(module_c_conflict_follow, "results/analysis/module_c_conflict_follow.csv")
write_csv(module_c_conflict_outcomes, "results/analysis/module_c_conflict_outcomes.csv")
write_csv(module_c_conflict_by_cue_group, "results/analysis/module_c_conflict_by_cue_group.csv")
write_csv(pooled_lm_table, "results/analysis/module_c_pooled_lm.csv")
pooled_lm_summary <- str_trim(capture.output(summary(pooled_lm)), side = "right")
pooled_lm_summary <- pooled_lm_summary[seq_len(max(which(pooled_lm_summary != "")))]
write_lines(pooled_lm_summary, "results/analysis/module_c_pooled_lm_summary.txt")

print(module_c_effects_by_model)
print(module_c_conflict_follow)
