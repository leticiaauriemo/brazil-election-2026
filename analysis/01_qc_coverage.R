library(tidyverse)

# Run after 00_clean_results.R.
# This script checks coverage, API errors, empty responses, and parser edge cases.

dir.create("results/analysis", showWarnings = FALSE, recursive = TRUE)

df <- read_csv(
  "results/analysis/clean_results.csv",
  show_col_types = FALSE,
  locale = locale(encoding = "UTF-8")
)

model_coverage <- df %>%
  group_by(model) %>%
  summarise(
    rows = n(),
    api_errors = sum(!api_ok),
    empty_or_error_responses = sum(empty_or_error_response),
    usable_rows = sum(usable),
    usable_rate = mean(usable),
    refused_parse_rate = mean(refused_parse[usable], na.rm = TRUE),
    refused2_rate = mean(refused2[usable], na.rm = TRUE),
    party_rate = mean(has_party[usable], na.rm = TRUE),
    zeta_rate = mean(has_zeta[usable], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(usable_rate), model)

module_coverage <- df %>%
  group_by(model, module) %>%
  summarise(
    rows = n(),
    usable_rows = sum(usable),
    usable_rate = mean(usable),
    refused2_rate = mean(refused2[usable], na.rm = TRUE),
    party_rate = mean(has_party[usable], na.rm = TRUE),
    zeta_rate = mean(has_zeta[usable], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(model, module)

error_messages <- df %>%
  filter(!api_ok) %>%
  mutate(error_short = str_sub(str_squish(error), 1, 160)) %>%
  count(model, error_short, sort = TRUE)

parser_edges <- df %>%
  filter(usable, parser_edge) %>%
  count(model, party_rec, sort = TRUE)

complete_models <- model_coverage %>%
  filter(usable_rows == rows) %>%
  select(model)

write_csv(model_coverage, "results/analysis/qc_model_coverage.csv")
write_csv(module_coverage, "results/analysis/qc_module_coverage.csv")
write_csv(error_messages, "results/analysis/qc_error_messages.csv")
write_csv(parser_edges, "results/analysis/qc_parser_edges.csv")
write_csv(complete_models, "results/analysis/qc_complete_models.csv")

print(model_coverage)
print(complete_models)
