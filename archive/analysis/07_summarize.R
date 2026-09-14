# Describe electoral guidance, first within models and only then across models.
# Inputs: responses.parquet, coding_analysis.parquet, entity_mentions_analysis.parquet.
# Outputs: output/reviewed/<coder>/tables and derived/cell_means.parquet.
# Estimand: equal observed days within prompt, equal prompts within model, equal
# models in the named pooled panel. This is a designed prompt average, not voter
# prevalence or market exposure. Undefined conditional outcomes remain missing.
# Responses the semantic coder failed to label are excluded from each rate and
# counted in not_coded; *_lower/_upper set them to 0/1 for worst-case bounds.
# Main analysis: the "specific candidate" wording, the closer analogue of the
# Japan forced-choice prompt. The open wording enters only through the wording
# contrast (08) and the L5 option shares (section 4), which pool both wordings
# because advice-giving answers are scarce for the cautious configurations.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))

# 1. Join the selected instrument to the collection record -----------------------
coding <- read_parquet(derived_path("coding_analysis")) %>% select(-coder)
metadata <- read_parquet(derived_path("responses"), col_select = c("source", "response_id", "cell_id",
  "condition_id", "question_id", "model_key", "archetype", "level", "gender", "office", "ask",
  "run_date", "complete_response", "search_used", "answer_chars"))
responses <- metadata %>% filter(complete_response) %>% inner_join(coding, by = c("source", "response_id")) %>%
  mutate(single_named = recommendation_strength == "single_named", shortlist = recommendation_strength == "shortlist",
    party_only = recommendation_strength == "party_only", names_any_person = n_people > 0,
    disclaimer_with_advice = refusal_language & gives_advice,
    scaled_recommendation = if_else(is.na(gives_advice), NA, !is.na(zeta_recommended)),
    zeta_mass = if_else(is.na(gives_advice), NA_real_, replace_na(zeta_recommended, 0)),
    unclassified = response_category == "unclear", not_coded = response_category == "not_coded",
    gives_advice_lower = replace_na(gives_advice, FALSE), gives_advice_upper = replace_na(gives_advice, TRUE),
    refusal_language_lower = replace_na(refusal_language, FALSE), refusal_language_upper = replace_na(refusal_language, TRUE),
    personalized_matching_lower = replace_na(personalized_matching, FALSE), personalized_matching_upper = replace_na(personalized_matching, TRUE))
stopifnot(!anyDuplicated(responses[c("source", "response_id")]))
outcomes <- c("gives_advice", "gives_direction", "explicit_endorsement", "personalized_matching", "negative_steering",
  "single_named", "shortlist", "party_only", "names_any_person", "refusal_language", "disclaimer_with_advice",
  "procedure_guidance", "slate_enumeration", "stale_timing", "citation_any", "unclassified", "scaled_recommendation", "zeta_mass",
  "not_coded", "gives_advice_lower", "gives_advice_upper", "refusal_language_lower", "refusal_language_upper",
  "personalized_matching_lower", "personalized_matching_upper")
drop_nan <- function(x) if_else(is.nan(x), NA_real_, x)
cell_keys <- c("source", "model_key", "cell_id", "condition_id", "question_id", "archetype", "level", "gender", "office", "ask")

# 2. Date means prevent high-volume collection days from choosing the answer -----
daily_all <- responses %>% group_by(across(all_of(c(cell_keys, "run_date")))) %>%
  summarise(n = n(), n_labelled = sum(!is.na(gives_advice)), across(all_of(outcomes), ~drop_nan(mean(as.numeric(.x), na.rm = TRUE))), .groups = "drop")
cells_all <- daily_all %>% group_by(across(all_of(cell_keys))) %>%
  summarise(n = sum(n), n_labelled = sum(n_labelled), dates = n(), across(all_of(outcomes), ~drop_nan(mean(.x, na.rm = TRUE))), .groups = "drop") %>%
  mutate(zeta_recommended = if_else(scaled_recommendation > 0, zeta_mass / scaled_recommendation, NA_real_))
write_parquet(cells_all, derived_path("cell_means"))
daily <- daily_all %>% filter(ask == "candidate")
cells <- cells_all %>% filter(ask == "candidate")
main <- responses %>% filter(ask == "candidate")
write_result(metadata %>% group_by(model_key) %>% summarise(collected = n(), complete = sum(complete_response), .groups = "drop") %>%
  left_join(main %>% group_by(model_key) %>% summarise(coded = n(), labelled = sum(!is.na(gives_advice)),
    missing_share = mean(is.na(gives_advice)), .groups = "drop"), by = "model_key") %>% mutate(coder = main_coder, wording = "candidate"), "coverage")

# 3. All rate breakdowns use the same two-stage model aggregation ----------------
# Within a model, se is the standard error of the mean across prompt cells. No
# interval across these deliberately selected models is a confidence interval for
# the universe of AI systems. Ranges describe heterogeneity.
groups <- list(model = character(), level = "level", office = "office", ask = "ask", archetype = "archetype",
  level_office = c("level", "office"), full_profile = c("archetype", "office"))
for (name in names(groups)) {
  sample <- if (name == "full_profile") filter(cells, level == "L5") else if (name == "ask") cells_all else cells
  model_rates <- sample %>% group_by(across(all_of(c("model_key", groups[[name]])))) %>%
    summarise(n_cells = n(), n_coded = sum(n), n_labelled = sum(n_labelled),
      across(all_of(outcomes), list(rate = ~drop_nan(mean(.x, na.rm = TRUE)),
        se = ~sd(.x, na.rm = TRUE) / sqrt(sum(!is.na(.x)))), .names = "{.col}__{.fn}"), .groups = "drop") %>%
    pivot_longer(matches("__(rate|se)$"), names_to = c("outcome", ".value"), names_sep = "__")
  write_result(model_rates, paste0("rates_by_", name))
  pooled <- model_rates %>% group_by(across(all_of(c(groups[[name]], "outcome")))) %>%
    summarise(min_model = min(rate), max_model = max(rate), rate = mean(rate), n_models = n(),
      models = paste(sort(as.character(model_key)), collapse = "|"), .groups = "drop")
  write_result(pooled, paste0("pooled_by_", name))
}

# Category shares are mutually exclusive; the independent disclaimer flag is not.
category_daily <- main %>% count(model_key, cell_id, run_date, response_category, name = "count") %>%
  group_by(model_key, cell_id, run_date) %>% complete(response_category = response_categories, fill = list(count = 0)) %>%
  mutate(share = count / sum(count)) %>% ungroup()
category_cells <- category_daily %>% group_by(model_key, cell_id, response_category) %>% summarise(share = mean(share), .groups = "drop")
write_result(category_cells %>% group_by(model_key, response_category) %>% summarise(share = mean(share), .groups = "drop"), "categories_by_model")

# 4. Direction: show unconditional exposure as well as conditional recommendations
# First restrict to full profiles and analyze each office separately. Missing
# affiliation reduces scale coverage; it never turns a recommendation centrist.
# Both wordings are pooled here; the option shares condition on advice.
zeta_models <- cells_all %>% filter(level == "L5") %>% group_by(model_key, archetype, office) %>%
  summarise(n_cells = n(), advice_rate = mean(gives_advice, na.rm = TRUE), scale_coverage = drop_nan(mean(scaled_recommendation, na.rm = TRUE)),
    zeta_mass = drop_nan(mean(zeta_mass, na.rm = TRUE)), .groups = "drop") %>%
  mutate(mean_zeta = if_else(scale_coverage > 0, zeta_mass / scale_coverage, NA_real_))
write_result(zeta_models, "ideology_by_model_profile")
write_result(zeta_models %>% group_by(archetype, office) %>% summarise(n_models = n(),
  n_models_defined = sum(!is.na(mean_zeta)), models = paste(sort(as.character(model_key)), collapse = "|"),
  models_defined = paste(sort(as.character(model_key[!is.na(mean_zeta)])), collapse = "|"), models_missing = paste(model_key[is.na(mean_zeta)], collapse = "|"),
  mean_zeta = if (all(is.na(mean_zeta))) NA_real_ else mean(mean_zeta, na.rm = TRUE), .groups = "drop"), "ideology_pooled_coverage")

entities <- read_parquet(derived_path("entity_mentions_analysis")) %>%
  inner_join(responses %>% select(source, response_id, model_key, cell_id, run_date, level, archetype, office), by = c("source", "response_id"))
for (kind in c("person", "party")) {
  recs <- if (kind == "person") entities %>% filter(entity_kind == "person", stance == "recommended") %>% select(source, response_id, entity) else
    entities %>% filter(stance == "recommended", !is.na(entity_party)) %>% transmute(source, response_id, entity = entity_party)
  recs <- recs %>% distinct() %>% inner_join(responses %>% filter(level == "L5") %>%
    select(source, response_id, model_key, cell_id, run_date, archetype, office), by = c("source", "response_id"))
  # Restrict display to observed options, but give each option explicit zeros in
  # every model/prompt/day. Multi-option answers can contribute to several columns.
  options <- recs %>% distinct(office, entity)
  denominators <- daily_all %>% filter(level == "L5") %>% select(model_key, cell_id, run_date, archetype, office, n_labelled, gives_advice)
  counts <- recs %>% count(model_key, cell_id, run_date, entity, name = "recommended_n")
  prevalence <- denominators %>% inner_join(options, by = "office", relationship = "many-to-many") %>%
    left_join(counts, by = c("model_key", "cell_id", "run_date", "entity")) %>%
    mutate(p = if_else(n_labelled > 0, replace_na(recommended_n, 0L) / n_labelled, NA_real_)) %>% group_by(model_key, cell_id, archetype, office, entity) %>%
    summarise(p = drop_nan(mean(p, na.rm = TRUE)), advice_rate = drop_nan(mean(gives_advice, na.rm = TRUE)), .groups = "drop") %>%
    group_by(model_key, archetype, office, entity) %>% summarise(unconditional = drop_nan(mean(p, na.rm = TRUE)), advice_rate = drop_nan(mean(advice_rate, na.rm = TRUE)), .groups = "drop") %>%
    mutate(conditional = if_else(advice_rate > 0, unconditional / advice_rate, NA_real_))
  write_result(prevalence, paste0(kind, "_recommendations_by_model"))
  write_result(prevalence %>% group_by(archetype, office, entity) %>% summarise(unconditional = mean(unconditional),
    conditional = if (all(is.na(conditional))) NA_real_ else mean(conditional, na.rm = TRUE),
    n_models = n(), n_models_conditional = sum(!is.na(conditional)),
    models = paste(sort(as.character(model_key)), collapse = "|"),
    models_defined = paste(sort(as.character(model_key[!is.na(conditional)])), collapse = "|"),
    models_missing = paste(sort(as.character(model_key[is.na(conditional)])), collapse = "|"), .groups = "drop"), paste0(kind, "_recommendations_pooled"))
}
write_result(entities %>% filter(entity_kind == "person") %>% group_by(model_key, office) %>% summarise(
  distinct_names = n_distinct(entity), registry_available = any(!is.na(registry_matched)),
  registry_match_rate = if (all(is.na(registry_matched))) NA_real_ else mean(registry_matched), .groups = "drop"), "candidate_reference_coverage")

# 5. Repeated web answers: prompt probabilities and agreement --------------------
web <- main %>% filter(source == "chatgpt_web")
write_result(cells %>% filter(source == "chatgpt_web"), "web_prompt_rates")

# Pairwise agreement estimates Pr(two distinct draws produce the same set).
# Unlike a modal share it does not mechanically rise with five rather than 100 draws.
# Report candidate-set agreement only where advice names a person; party-only
# advice has its own party-set measure, not an empty candidate set.
for (kind in c("people", "parties")) {
  set_column <- paste0("recommended_", kind)
  sets <- web %>% filter(gives_advice, .data[[set_column]] != "") %>%
    count(cell_id, run_date, recommendation_set = .data[[set_column]], name = "set_n") %>%
    group_by(cell_id, run_date) %>% summarise(n_advice_with_set = sum(set_n),
      matching_pairs = sum(set_n * (set_n - 1)), .groups = "drop") %>%
    mutate(pair_agreement = if_else(n_advice_with_set >= 2, matching_pairs / (n_advice_with_set * (n_advice_with_set - 1)), NA_real_))
  # Average eligible within-day estimates so collection volume does not
  # determine a prompt's result; pairs never cross collection days.
  prompt_sets <- sets %>% group_by(cell_id) %>% summarise(
    n_advice_with_set = sum(n_advice_with_set),
    eligible_dates = sum(!is.na(pair_agreement)),
    pair_agreement = if (all(is.na(pair_agreement))) NA_real_ else mean(pair_agreement, na.rm = TRUE),
    .groups = "drop")
  write_result(cells %>% filter(source == "chatgpt_web") %>% select(cell_id, level, office, ask, n, gives_advice) %>%
    left_join(prompt_sets, by = "cell_id"), paste0("web_", kind, "_consistency"))
}
write_result(tibble(coder = main_coder, status = "Human validation required before publication",
  weighting = "Equal observed days per prompt; equal prompts per model; equal models in named pool; main tables use the specific-candidate wording",
  population = "Frozen coding sample of designed prompts; not a representative voter sample"), "interpretation")
message("Model-first tables written to ", result_dir)
