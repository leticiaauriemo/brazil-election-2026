# Validate automated labels against an independent human sample.
# Inputs: coding_comparison.parquet, frozen coding and hand-sampling metadata.
# Outputs: model-specific agreement, weighted validation errors and disagreements.
# Target: equal prompts and equal available dates within each model, excluding
# calibration answers. Inverse hand-sampling probabilities undo oversampling of
# regex positives. No model receives another model's sample-size weight.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))
coding <- read_parquet(derived_path("coding_comparison"))
metadata <- read_parquet(derived_path("responses"), col_select = c("source", "response_id", "model_key", "level", "office", "ask"))
coding <- coding %>% left_join(metadata, by = c("source", "response_id"))
stopifnot(!anyDuplicated(coding[c("source", "response_id", "coder")]))

# 1. Compare identities using the same transparent aliases as the analysis -------
aliases <- readr::read_csv(file.path(analysis_dir, "reference", "name_aliases.csv"), show_col_types = FALSE) %>%
  transmute(surface = canonical_name(surface), canonical = canonical_name(canonical))
stopifnot(!anyDuplicated(aliases$surface))

# Set comparison ignores order, case and accents, but does not guess identities.
normalize_set <- function(x, kind) {
  map_chr(str_split(coalesce(x, ""), fixed("|")), function(names) {
    if (kind == "person") {
      names <- canonical_name(names)
      names <- coalesce(aliases$canonical[match(names, aliases$surface)], names)
    } else names <- canonical_party(names)
    paste(sort(unique(names[names != ""])), collapse = "|")
  })
}
set_overlap <- function(a, b) {
  map2_dbl(str_split(a, fixed("|")), str_split(b, fixed("|")), function(x, y) {
    x <- x[x != ""]
    y <- y[y != ""]
    if (length(union(x, y)) == 0) NA_real_ else length(intersect(x, y)) / length(union(x, y))
  })
}
coding <- coding %>%
  mutate(recommended_people = normalize_set(recommended_people, "person"),
    recommended_parties = normalize_set(recommended_parties, "party"))

# 2. Pairwise agreement is a diagnostic, not evidence that either coder is right --
coders <- unique(coding$coder)
if (length(coders) >= 2) {
  agreement <- map_dfr(combn(coders, 2, simplify = FALSE), function(pair) {
    a <- coding %>% filter(coder == pair[1]) %>%
      select(source, response_id, model_key, response_category, gives_advice,
        refusal_language, negative_steering, recommended_people, recommended_parties)
    b <- coding %>% filter(coder == pair[2]) %>%
      select(source, response_id, response_category, gives_advice,
        refusal_language, negative_steering, recommended_people, recommended_parties)
    inner_join(a, b, by = c("source", "response_id"), suffix = c("_a", "_b")) %>%
      filter(!is.na(gives_advice_a), !is.na(gives_advice_b)) %>%
      mutate(people_overlap = set_overlap(recommended_people_a, recommended_people_b)) %>%
      group_by(source, model_key) %>%
      summarise(n = n(),
        category_agreement = mean(response_category_a == response_category_b),
        advice_agreement = mean(gives_advice_a == gives_advice_b),
        refusal_agreement = mean(refusal_language_a == refusal_language_b),
        negative_agreement = mean(negative_steering_a == negative_steering_b),
        people_set_agreement = mean(recommended_people_a == recommended_people_b),
        party_set_agreement = mean(recommended_parties_a == recommended_parties_b),
        n_people_union_nonempty = sum(!is.na(people_overlap)),
        people_overlap_nonempty = if (all(is.na(people_overlap))) NA_real_ else mean(people_overlap, na.rm = TRUE),
        .groups = "drop") %>%
      mutate(coder_a = pair[1], coder_b = pair[2], weighting = "Paired responses within model; descriptive only")
  })
  write_table(agreement, "agreement_by_model")
}

# 3. Freeze the validation population and its analysis weights -------------------
key <- readr::read_csv(file.path(tables_dir, "hand_validation_key.csv"), col_types = readr::cols(source = "c", response_id = "c"), show_col_types = FALSE)
hand <- readr::read_csv(file.path(tables_dir, "hand_validation.csv"), col_types = readr::cols(.default = "c"))
stopifnot(!anyDuplicated(hand[c("source", "response_id")]),
  nrow(anti_join(hand, key, by = c("source", "response_id"))) == 0,
  nrow(anti_join(key, hand, by = c("source", "response_id"))) == 0)
completed <- hand %>% filter(toupper(hand_complete) == "TRUE")
validation_complete <- nrow(completed) == nrow(key)
status <- if (nrow(completed) == 0) "UNVALIDATED" else if (!validation_complete) "PARTIAL: metrics withheld" else "Human labels complete; inspect errors and uncertainty"
write_table(tibble(completed = nrow(completed), planned = nrow(key), status), "validation_status")
write_table(key %>%
  mutate(completed = paste(source, response_id) %in% paste(completed$source, completed$response_id)) %>%
  group_by(model_key, stratum) %>%
  summarise(planned = n(), completed = sum(completed), .groups = "drop"), "validation_annotation_coverage")

# Empty or partial sheets never produce publication-ready error estimates.
if (nrow(completed) > 0) {
  stopifnot(all(completed$hand_category %in% response_categories),
    all(completed$hand_gives_advice %in% c("TRUE", "FALSE")),
    all(completed$hand_refusal_language %in% c("TRUE", "FALSE")),
    all(completed$hand_negative_steering %in% c("TRUE", "FALSE")),
    all(!is.na(completed$hand_coder) & str_trim(completed$hand_coder) != ""))
}
calibration <- readr::read_csv(file.path(tables_dir, "hand_calibration_key.csv"), col_types = readr::cols(source = "c", response_id = "c"), show_col_types = FALSE)
population <- readr::read_csv(file.path(tables_dir, "coding_sample_metadata.csv"), col_types = readr::cols(source = "c", response_id = "c"), show_col_types = FALSE) %>%
  anti_join(calibration, by = c("source", "response_id")) %>%
  group_by(source, model_key, condition_id, question_id, run_date) %>%
  mutate(date_n = n()) %>%
  group_by(source, model_key, condition_id, question_id) %>%
  mutate(cell_dates = n_distinct(run_date)) %>%
  group_by(source, model_key) %>%
  mutate(model_cells = n_distinct(paste(condition_id, question_id)),
    analysis_weight = 1 / (date_n * cell_dates * model_cells)) %>%
  ungroup()
human <- completed %>%
  left_join(key %>% select(source, response_id, stratum, hand_probability, stratum_population_n, stratum_sample_n),
    by = c("source", "response_id")) %>%
  left_join(population %>% select(source, response_id, analysis_weight), by = c("source", "response_id")) %>%
  mutate(weight = analysis_weight / hand_probability,
    truth_advice = hand_gives_advice == "TRUE", truth_refusal = hand_refusal_language == "TRUE",
    truth_negative = hand_negative_steering == "TRUE",
    hand_recommended_people = normalize_set(hand_recommended_people, "person"),
    hand_recommended_parties = normalize_set(hand_recommended_parties, "party"))
stopifnot(!any(is.na(human$weight)))
comparison <- coding %>% inner_join(human, by = c("source", "response_id"))
coverage <- expand_grid(coder = coders, model_key = unique(key$model_key)) %>%
  left_join(comparison %>% count(coder, model_key, name = "coded_and_annotated"), by = c("coder", "model_key")) %>%
  left_join(key %>% count(model_key, name = "planned"), by = "model_key") %>%
  mutate(coded_and_annotated = replace_na(coded_and_annotated, 0L),
    complete = validation_complete & coded_and_annotated == planned)
write_table(coverage, "validation_coder_coverage")

# 4. Weighted binary errors and sampling uncertainty, separately by model --------
# Ratio linearization uses the actual SRS-without-replacement hand strata.
# Intervals are unavailable at observed zero/one boundaries: observing no errors
# in a finite audit is not evidence that the population error rate equals zero.
binary <- comparison %>%
  select(coder, source, model_key, response_id, stratum, stratum_population_n, stratum_sample_n,
    hand_probability, analysis_weight, weight, truth_advice, truth_refusal, truth_negative,
    gives_advice, refusal_language, negative_steering) %>%
  pivot_longer(c(gives_advice, refusal_language, negative_steering), names_to = "construct", values_to = "prediction") %>%
  mutate(truth = case_when(construct == "gives_advice" ~ truth_advice,
    construct == "refusal_language" ~ truth_refusal, TRUE ~ truth_negative)) %>%
  inner_join(coverage %>% filter(complete) %>% select(coder, model_key), by = c("coder", "model_key")) %>%
  filter(!is.na(prediction))
metrics <- if (nrow(binary) == 0) tibble(coder = character(), model_key = character(), metric = character(), estimate = double()) else map_dfr(c("precision", "recall", "specificity", "false_positive_rate", "false_negative_rate"), function(metric) {
  numerator <- switch(metric, precision = binary$truth & binary$prediction,
    recall = binary$truth & binary$prediction, specificity = !binary$truth & !binary$prediction,
    false_positive_rate = !binary$truth & binary$prediction, false_negative_rate = binary$truth & !binary$prediction)
  denominator <- switch(metric, precision = binary$prediction, recall = binary$truth,
    specificity = !binary$truth, false_positive_rate = !binary$truth, false_negative_rate = binary$truth)
  rows <- binary %>% mutate(numerator = as.numeric(numerator), denominator = as.numeric(denominator))
  estimates <- rows %>% group_by(coder, source, model_key, construct) %>%
    summarise(n = n(), observed_denominator_n = sum(denominator),
      numerator_total = sum(weight * numerator), denominator_total = sum(weight * denominator),
      .groups = "drop") %>%
    mutate(estimate = if_else(denominator_total > 0, numerator_total / denominator_total, NA_real_))
  variance <- rows %>% left_join(estimates, by = c("coder", "source", "model_key", "construct")) %>%
    mutate(residual = analysis_weight * (numerator - estimate * denominator)) %>%
    group_by(coder, source, model_key, construct, stratum) %>%
    summarise(stratum_variance = if (first(stratum_sample_n) == first(stratum_population_n)) 0 else
      first(stratum_population_n)^2 * (1 - first(hand_probability)) * var(residual) / n(), .groups = "drop") %>%
    group_by(coder, source, model_key, construct) %>%
    summarise(total_variance = sum(stratum_variance), .groups = "drop")
  estimates %>% left_join(variance, by = c("coder", "source", "model_key", "construct")) %>%
    mutate(metric = metric, se = if_else(estimate > 0 & estimate < 1, sqrt(total_variance) / denominator_total, NA_real_),
      conf_low = pmax(0, estimate - 1.96 * se), conf_high = pmin(1, estimate + 1.96 * se),
      interval_note = case_when(is.na(estimate) ~ "No observed denominator", estimate %in% c(0, 1) ~ "Boundary estimate; audit cannot certify zero population errors",
        is.na(se) ~ "Insufficient within-stratum observations", TRUE ~ "Approximate 95% stratified ratio interval"),
      validation_complete = TRUE) %>% select(-total_variance)
})
write_table(metrics, "validation_errors_by_model")

# 5. Retain category and recommendation-set disagreements for adjudication -------
set_checks <- comparison %>% filter(!is.na(gives_advice)) %>%
  mutate(category_agreement = response_category == hand_category,
    people_exact = recommended_people == hand_recommended_people,
    parties_exact = recommended_parties == hand_recommended_parties,
    people_overlap = set_overlap(recommended_people, hand_recommended_people))
set_summary <- set_checks %>%
  inner_join(coverage %>% filter(complete) %>% select(coder, model_key), by = c("coder", "model_key")) %>%
  group_by(coder, source, model_key) %>%
  summarise(n = n(), category_agreement = weighted.mean(category_agreement, weight),
    people_exact_agreement = weighted.mean(people_exact, weight),
    parties_exact_agreement = weighted.mean(parties_exact, weight),
    n_people_union_nonempty = sum(!is.na(people_overlap)),
    people_overlap_nonempty = if (all(is.na(people_overlap))) NA_real_ else weighted.mean(people_overlap, weight, na.rm = TRUE),
    .groups = "drop")
write_table(set_summary, "validation_sets_by_model")
write_table(set_checks %>%
  filter(gives_advice != truth_advice | refusal_language != truth_refusal | negative_steering != truth_negative |
    !category_agreement | !people_exact | !parties_exact) %>%
  select(source, response_id, coder, model_key, level, office, ask, response_category, hand_category,
    gives_advice, truth_advice, refusal_language, truth_refusal, negative_steering, truth_negative,
    recommended_people, hand_recommended_people, recommended_parties, hand_recommended_parties,
    prompt, answer, hand_notes), "validation_disagreements")
message(status, ". Validation target excludes calibration answers; all estimates are by model.")
