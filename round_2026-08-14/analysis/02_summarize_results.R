source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]), winslash = "/")), "R", "utils.R"))

classified_path <- file.path(derived_dir, "responses_classified.rds")
if (!file.exists(classified_path)) stop("Run 01_classify_responses.R first.")
responses <- readRDS(classified_path) %>% filter(complete_response)
party_mentions <- readRDS(file.path(derived_dir, "party_mentions.rds"))
person_mentions <- readRDS(file.path(derived_dir, "person_mentions.rds"))

outcome_vars <- c(
  "explicit_refusal", "person_mention", "party_mention", "single_best_match",
  "named_despite_refusal", "citation_any", "stale_timing"
)

outcome_labels <- c(
  explicit_refusal = "Explicit refusal",
  person_mention = "Named political figure",
  party_mention = "Named party",
  single_best_match = "Single-best-match language",
  named_despite_refusal = "Named figure despite refusal",
  citation_any = "At least one citation",
  stale_timing = "Stale election-timing claim"
)

rate_long <- function(data, groups) {
  data %>%
    select(all_of(groups), all_of(outcome_vars)) %>%
    pivot_longer(all_of(outcome_vars), names_to = "outcome", values_to = "value") %>%
    group_by(across(all_of(c(groups, "outcome")))) %>%
    summarise(n = n(), rate = mean(value), .groups = "drop") %>%
    mutate(outcome_label = unname(outcome_labels[outcome]))
}

model_outcomes <- rate_long(responses, "model_key")
level_outcomes <- rate_long(responses, "level")
model_level_outcomes <- rate_long(responses, c("model_key", "level"))
ask_outcomes <- rate_long(responses, "ask")
model_ask_outcomes <- rate_long(responses, c("model_key", "ask"))
office_outcomes <- rate_long(responses, "office")
model_office_outcomes <- rate_long(responses, c("model_key", "office"))
style_by_model <- responses %>% count(model_key, response_style) %>% group_by(model_key) %>% mutate(rate = n / sum(n)) %>% ungroup()

archetype_level_outcomes <- responses %>%
  filter(level %in% c("L2", "L4", "L5")) %>%
  {rate_long(., c("archetype", "level"))}

model_archetype_l5_outcomes <- responses %>%
  filter(level == "L5") %>%
  {rate_long(., c("model_key", "archetype"))}

gender_outcomes <- responses %>%
  filter(level %in% c("L3", "L4", "L5"), !is.na(gender)) %>%
  {rate_long(., c("model_key", "gender"))}

gender_contrasts <- gender_outcomes %>%
  select(model_key, gender, outcome, rate) %>%
  pivot_wider(names_from = gender, values_from = rate) %>%
  mutate(diff_woman_minus_man = mulher - homem)

layer_cell_rates <- responses %>%
  filter(level %in% c("L3", "L4", "L5")) %>%
  select(model_key, archetype, gender, office, ask, level, all_of(outcome_vars)) %>%
  pivot_longer(all_of(outcome_vars), names_to = "outcome", values_to = "value") %>%
  group_by(model_key, archetype, gender, office, ask, level, outcome) %>%
  summarise(rate = mean(value), .groups = "drop") %>%
  pivot_wider(names_from = level, values_from = rate) %>%
  mutate(`L4-L3` = L4 - L3, `L5-L4` = L5 - L4)

layer_contrasts <- layer_cell_rates %>%
  select(model_key, archetype, gender, office, ask, outcome, `L4-L3`, `L5-L4`) %>%
  pivot_longer(c(`L4-L3`, `L5-L4`), names_to = "contrast", values_to = "difference") %>%
  group_by(model_key, outcome, contrast) %>%
  summarise(mean_difference = mean(difference), .groups = "drop")

archetype_layer_contrasts <- layer_cell_rates %>%
  select(model_key, archetype, gender, office, ask, outcome, `L4-L3`, `L5-L4`) %>%
  pivot_longer(c(`L4-L3`, `L5-L4`), names_to = "contrast", values_to = "difference") %>%
  group_by(archetype, outcome, contrast) %>%
  summarise(mean_difference = mean(difference), .groups = "drop")

ask_contrasts <- model_ask_outcomes %>%
  select(model_key, ask, outcome, rate) %>%
  pivot_wider(names_from = ask, values_from = rate) %>%
  mutate(candidate_minus_open = candidate - open)

office_contrasts <- model_office_outcomes %>%
  select(model_key, office, outcome, rate) %>%
  pivot_wider(names_from = office, values_from = rate) %>%
  mutate(president_minus_deputy = president - federal_deputy)

valid_jobs <- responses %>% select(job_id, archetype, level, office)
party_l5 <- valid_jobs %>%
  filter(level == "L5") %>%
  left_join(party_mentions, by = "job_id") %>%
  group_by(archetype, party) %>%
  summarise(n = n_distinct(job_id), .groups = "drop")
party_denoms <- valid_jobs %>% filter(level == "L5") %>% count(archetype, name = "denom")
top_parties <- party_l5 %>% filter(!is.na(party)) %>% group_by(party) %>% summarise(n = sum(n), .groups = "drop") %>% slice_max(n, n = 10) %>% pull(party)
party_archetype <- expand_grid(archetype = factor(archetype_levels, levels = archetype_levels), party = top_parties) %>%
  left_join(party_l5, by = c("archetype", "party")) %>%
  left_join(party_denoms, by = "archetype") %>%
  mutate(n = replace_na(n, 0L), rate = n / denom)

person_pres_l5 <- valid_jobs %>%
  filter(level == "L5", office == "president") %>%
  left_join(person_mentions, by = "job_id") %>%
  group_by(archetype, person) %>%
  summarise(n = n_distinct(job_id), .groups = "drop")
person_denoms <- valid_jobs %>% filter(level == "L5", office == "president") %>% count(archetype, name = "denom")
top_people <- person_pres_l5 %>% filter(!is.na(person)) %>% group_by(person) %>% summarise(n = sum(n), .groups = "drop") %>% slice_max(n, n = 10) %>% pull(person)
person_archetype <- expand_grid(archetype = factor(archetype_levels, levels = archetype_levels), person = top_people) %>%
  left_join(person_pres_l5, by = c("archetype", "person")) %>%
  left_join(person_denoms, by = "archetype") %>%
  mutate(n = replace_na(n, 0L), rate = n / denom)

top_people_overall <- person_mentions %>%
  semi_join(responses, by = "job_id") %>% count(person, sort = TRUE) %>% mutate(rate = n / nrow(responses))
top_parties_overall <- party_mentions %>%
  semi_join(responses, by = "job_id") %>% count(party, sort = TRUE) %>% mutate(rate = n / nrow(responses))

rep_groups <- responses %>%
  group_by(model_key, condition_id, question_id) %>%
  summarise(
    repetitions = n(), unique_party_sets = n_distinct(party_signature),
    unique_person_sets = n_distinct(person_signature),
    stable_party_set = unique_party_sets == 1,
    stable_person_set = unique_person_sets == 1,
    .groups = "drop"
  )
repetition_stability <- rep_groups %>%
  group_by(model_key) %>%
  summarise(
    cells = n(), party_exact_stability = mean(stable_party_set),
    person_exact_stability = mean(stable_person_set),
    mean_unique_party_sets = mean(unique_party_sets),
    mean_unique_person_sets = mean(unique_person_sets), .groups = "drop"
  )

operations <- responses %>%
  group_by(model_key) %>%
  summarise(
    n = n(), median_words = median(answer_words), median_latency = median(latency_seconds, na.rm = TRUE),
    citation_rate = mean(citation_any), search_reported_rate = mean(search_reported, na.rm = TRUE),
    search_used_rate = mean(search_used, na.rm = TRUE),
    cost_known_n = sum(!is.na(cost_usd)), total_cost_usd = sum(cost_usd, na.rm = TRUE),
    median_cost_usd = median(cost_usd, na.rm = TRUE), .groups = "drop"
  )

write_table <- function(x, name) readr::write_csv(x, file.path(tables_dir, paste0(name, ".csv")), na = "")
tables <- list(
  model_outcomes = model_outcomes, level_outcomes = level_outcomes,
  model_level_outcomes = model_level_outcomes, ask_outcomes = ask_outcomes,
  model_ask_outcomes = model_ask_outcomes, office_outcomes = office_outcomes,
  model_office_outcomes = model_office_outcomes, style_by_model = style_by_model,
  archetype_level_outcomes = archetype_level_outcomes,
  model_archetype_l5_outcomes = model_archetype_l5_outcomes,
  gender_outcomes = gender_outcomes, gender_contrasts = gender_contrasts,
  layer_contrasts = layer_contrasts, archetype_layer_contrasts = archetype_layer_contrasts,
  ask_contrasts = ask_contrasts,
  office_contrasts = office_contrasts, party_archetype = party_archetype,
  person_archetype = person_archetype, top_people_overall = top_people_overall,
  top_parties_overall = top_parties_overall, repetition_stability = repetition_stability,
  operations = operations
)
iwalk(tables, write_table)
saveRDS(tables, file.path(derived_dir, "summary_tables.rds"), compress = "xz")

message("Saved ", length(tables), " summary tables for ", nrow(responses), " complete responses.")
