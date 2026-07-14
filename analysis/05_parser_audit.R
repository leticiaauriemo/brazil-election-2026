library(tidyverse)

# Run after 00_clean_results.R.
# This script writes small audit samples for parser and refusal issues.
# The goal is manual inspection, not final estimation.

dir.create("results/analysis", showWarnings = FALSE, recursive = TRUE)

df <- read_csv(
  "results/analysis/clean_results.csv",
  show_col_types = FALSE,
  locale = locale(encoding = "UTF-8")
)

set.seed(20260630)

audit <- df %>%
  mutate(
    prompt_short = str_sub(str_squish(prompt), 1, 400),
    response_short = str_sub(str_squish(response), 1, 900)
  )

complete_models <- audit %>%
  group_by(model) %>%
  summarise(rows = n(), usable_rows = sum(usable), .groups = "drop") %>%
  filter(rows == usable_rows) %>%
  pull(model)

audit_cols <- c(
  "model", "module", "cond_id", "cargo", "ask", "rep",
  "ideology_cue", "issue_cue", "issue_side", "cell_type",
  "party_rec", "zeta", "refused_parse", "refused2", "names_person",
  "prompt_short", "response_short"
)

empty_or_error_sample <- audit %>%
  filter(empty_or_error_response | !api_ok) %>%
  select(any_of(c(audit_cols, "error"))) %>%
  arrange(runif(n())) %>%
  slice_head(n = 80)

new_refusal_sample <- audit %>%
  filter(usable, refused2, !refused_parse) %>%
  select(any_of(audit_cols)) %>%
  arrange(runif(n())) %>%
  slice_head(n = 80)

no_party_not_refused_sample <- audit %>%
  filter(usable, model %in% complete_models, !has_party, !refused2) %>%
  select(any_of(audit_cols)) %>%
  arrange(runif(n())) %>%
  slice_head(n = 100)

candidate_named_no_party_sample <- audit %>%
  filter(usable, model %in% complete_models, ask == "candidate", names_person, !has_party, !refused2) %>%
  select(any_of(audit_cols)) %>%
  arrange(runif(n())) %>%
  slice_head(n = 100)

parser_edge_sample <- audit %>%
  filter(usable, parser_edge) %>%
  select(any_of(audit_cols)) %>%
  arrange(runif(n())) %>%
  slice_head(n = 100)

write_csv(empty_or_error_sample, "results/analysis/audit_empty_or_error_responses.csv")
write_csv(new_refusal_sample, "results/analysis/audit_new_refusal_matches.csv")
write_csv(no_party_not_refused_sample, "results/analysis/audit_no_party_not_refused.csv")
write_csv(candidate_named_no_party_sample, "results/analysis/audit_candidate_named_no_party.csv")
write_csv(parser_edge_sample, "results/analysis/audit_parser_edges.csv")

print(count(audit, model, usable, sort = TRUE))
print(count(audit, party_rec, has_zeta, sort = TRUE))
