library(tidyverse)

# Run after 00_clean_results.R.
# This script creates first-pass descriptive tables.

dir.create("results/analysis", showWarnings = FALSE, recursive = TRUE)

df <- read_csv(
  "results/analysis/clean_results.csv",
  show_col_types = FALSE,
  locale = locale(encoding = "UTF-8")
)

usable <- df %>%
  filter(usable)

complete_models <- df %>%
  group_by(model) %>%
  summarise(rows = n(), usable_rows = sum(usable), .groups = "drop") %>%
  filter(rows == usable_rows) %>%
  pull(model)

complete <- usable %>%
  filter(model %in% complete_models)

summary_by_model <- usable %>%
  group_by(model) %>%
  summarise(
    n = n(),
    refused_parse_rate = mean(refused_parse),
    refused2_rate = mean(refused2),
    party_rate = mean(has_party),
    zeta_rate = mean(has_zeta),
    mean_zeta = mean(zeta, na.rm = TRUE),
    search_rate = mean(did_search),
    names_person_rate = mean(names_person),
    .groups = "drop"
  ) %>%
  arrange(desc(n))

summary_complete_by_model <- complete %>%
  group_by(model) %>%
  summarise(
    n = n(),
    refused_parse_rate = mean(refused_parse),
    refused2_rate = mean(refused2),
    party_rate = mean(has_party),
    zeta_rate = mean(has_zeta),
    mean_zeta = mean(zeta, na.rm = TRUE),
    search_rate = mean(did_search),
    names_person_rate = mean(names_person),
    .groups = "drop"
  )

summary_complete_by_ask_cargo <- complete %>%
  group_by(model, ask, cargo) %>%
  summarise(
    n = n(),
    refused2_rate = mean(refused2),
    party_rate = mean(has_party),
    zeta_rate = mean(has_zeta),
    mean_zeta = mean(zeta, na.rm = TRUE),
    names_person_rate = mean(names_person),
    no_party_not_refused2_rate = mean(!has_party & !refused2),
    .groups = "drop"
  ) %>%
  arrange(model, ask, cargo)

summary_complete_by_module <- complete %>%
  group_by(model, module) %>%
  summarise(
    n = n(),
    refused2_rate = mean(refused2),
    party_rate = mean(has_party),
    zeta_rate = mean(has_zeta),
    mean_zeta = mean(zeta, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(model, module)

party_counts_complete <- complete %>%
  count(model, party_rec, has_zeta, sort = TRUE)

write_csv(summary_by_model, "results/analysis/descriptives_by_model_all_usable.csv")
write_csv(summary_complete_by_model, "results/analysis/descriptives_by_model_complete.csv")
write_csv(summary_complete_by_ask_cargo, "results/analysis/descriptives_by_ask_cargo_complete.csv")
write_csv(summary_complete_by_module, "results/analysis/descriptives_by_module_complete.csv")
write_csv(party_counts_complete, "results/analysis/descriptives_party_counts_complete.csv")

print(summary_complete_by_model)
print(summary_complete_by_ask_cargo)
