# Estimate matched mean differences within each observed model configuration.
# Input: derived/cell_means.parquet. Output: reviewed/<coder>/tables/contrasts*.
# In a balanced design these differences are the corresponding saturated-model
# coefficients. Writing the pairs directly exposes what is held constant.
# The profiles and models are purposively chosen. We report effects and dispersion
# across archetypes, not population-voter p-values. Web execution dependence is
# unknown, so repetition count does not justify artificially narrow intervals.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))
cells <- read_parquet(derived_path("cell_means"))
outcomes <- c("gives_advice", "gives_direction", "explicit_endorsement", "personalized_matching", "negative_steering",
  "single_named", "shortlist", "party_only", "refusal_language", "disclaimer_with_advice", "names_any_person",
  "gives_advice_lower", "gives_advice_upper")
long_all <- cells %>% pivot_longer(all_of(outcomes), names_to = "outcome", values_to = "value")
# Main contrasts use the specific-candidate wording; the wording contrast itself needs both.
long <- long_all %>% filter(ask == "candidate")

# 1. Information additions; L2 and L3 are branches, not successive levels ---------
matched <- long %>% filter(level %in% c("L3", "L4", "L5")) %>%
  select(model_key, archetype, gender, office, ask, level, outcome, value) %>%
  pivot_wider(names_from = level, values_from = value)
pairs <- bind_rows(
  matched %>% transmute(model_key, archetype, gender, office, ask, outcome, contrast = "issue_added_to_biography", baseline = L3, treatment = L4),
  matched %>% transmute(model_key, archetype, gender, office, ask, outcome, contrast = "attitudes_added_to_biography_and_issue", baseline = L4, treatment = L5))

# Average the two gender variants before matching a single shared issue-only body.
issue <- long %>% filter(level %in% c("L2", "L4")) %>% group_by(model_key, archetype, office, ask, outcome, level) %>%
  summarise(value = mean(value), .groups = "drop") %>% pivot_wider(names_from = level, values_from = value)
pairs <- bind_rows(pairs, issue %>% transmute(model_key, archetype, gender = NA_character_, office, ask, outcome,
  contrast = "biography_added_to_issue", baseline = L2, treatment = L4))
baseline <- long %>% filter(level == "L1") %>% select(model_key, office, ask, outcome, baseline = value)
issue_only <- long %>% filter(level == "L2") %>% select(model_key, archetype, office, ask, outcome, treatment = value) %>%
  left_join(baseline, by = c("model_key", "office", "ask", "outcome")) %>%
  mutate(gender = NA_character_, contrast = "issue_added_to_state")
pairs <- bind_rows(pairs, issue_only)
# The L1 comparison shares a baseline across archetypes. It supplies one baseline
# estimate, not nine independent control observations; no replicated-control SE.

# 2. Office and wording contrasts hold the other prompt attributes constant ------
by_office <- long %>% select(model_key, archetype, level, gender, condition_id, ask, office, outcome, value) %>%
  pivot_wider(names_from = office, values_from = value)
pairs <- bind_rows(pairs, by_office %>% transmute(model_key, archetype, level, condition_id, gender, office = NA_character_, ask, outcome,
  contrast = "deputy_minus_president", baseline = president, treatment = federal_deputy))
by_ask <- long_all %>% select(model_key, archetype, level, gender, condition_id, office, ask, outcome, value) %>%
  pivot_wider(names_from = ask, values_from = value)
pairs <- bind_rows(pairs, by_ask %>% transmute(model_key, archetype, level, condition_id, gender, office, ask = NA_character_, outcome,
  contrast = "specific_candidate_minus_open", baseline = open, treatment = candidate))
by_gender <- long %>% filter(level %in% c("L3", "L4", "L5")) %>%
  select(model_key, archetype, level, office, ask, gender, outcome, value) %>% pivot_wider(names_from = gender, values_from = value)
pairs <- bind_rows(pairs, by_gender %>% transmute(model_key, archetype, level, gender = NA_character_, office, ask, outcome,
  contrast = "woman_minus_man", baseline = homem, treatment = mulher))
# A prompt cell with no labelled response has no cell mean; its pairs are dropped and counted.
write_result(pairs %>% filter(is.na(baseline) | is.na(treatment)) %>% count(model_key, contrast, outcome, name = "pairs_dropped"), "contrast_pairs_dropped")
pairs <- pairs %>% filter(!is.na(baseline), !is.na(treatment))
pairs <- pairs %>% mutate(pair_id = paste(model_key, contrast, archetype, level, gender, office, ask, sep = "|"), difference = treatment - baseline)
write_result(pairs, "contrast_pairs")

# 3. Each model contributes one effect to the pooled descriptive average ----------
# se is the standard error of the mean difference across matched prompt pairs within a
# model; in this balanced design the mean difference is the OLS coefficient on the
# treatment indicator with pair fixed effects, and the 95% interval is +-1.96 se.
by_model <- pairs %>% group_by(model_key, contrast, outcome) %>% summarise(n_pairs = n(),
  se = sd(difference) / sqrt(n()), baseline = mean(baseline), treatment = mean(treatment),
  difference = mean(difference), .groups = "drop") %>%
  mutate(conf_low = difference - 1.96 * se, conf_high = difference + 1.96 * se)
write_result(by_model, "contrasts_by_model")
# Worst-case bounds on the advice contrasts: unlabelled responses all 0 or all 1.
bounds <- pairs %>% filter(outcome %in% c("gives_advice_lower", "gives_advice_upper")) %>%
  select(pair_id, model_key, contrast, outcome, baseline, treatment) %>%
  pivot_wider(names_from = outcome, values_from = c(baseline, treatment)) %>%
  group_by(model_key, contrast) %>% summarise(
    difference_lower = mean(treatment_gives_advice_lower - baseline_gives_advice_upper),
    difference_upper = mean(treatment_gives_advice_upper - baseline_gives_advice_lower), .groups = "drop")
write_result(by_model %>% filter(outcome == "gives_advice") %>% left_join(bounds, by = c("model_key", "contrast")) %>%
  mutate(sign_robust = sign(difference_lower) == sign(difference_upper)), "contrasts_by_model_bounds")
write_result(pairs %>% filter(!is.na(archetype)) %>% group_by(model_key, contrast, outcome, archetype) %>%
  summarise(difference = mean(difference), .groups = "drop"), "contrast_heterogeneity_by_profile")
write_result(by_model %>% group_by(contrast, outcome) %>% summarise(n_models = n(),
  models = paste(sort(as.character(model_key)), collapse = "|"), min_model = min(difference), max_model = max(difference),
  # Models are fixed choices, so the pooled se treats the model effects as independent estimates.
  se = sqrt(sum(se^2)) / n(), baseline = mean(baseline), treatment = mean(treatment), difference = mean(difference), .groups = "drop") %>%
  mutate(conf_low = difference - 1.96 * se, conf_high = difference + 1.96 * se), "contrasts_pooled")

# 4. Consumer surface versus API: descriptive matched deployment differences ------
web <- long %>% filter(model_key == "chatgpt_web") %>% select(condition_id, question_id, outcome, web = value)
write_result(long %>% filter(model_key %in% c("gpt4o", "gpt56_sol", "gpt56_luna")) %>%
  inner_join(web, by = c("condition_id", "question_id", "outcome")) %>% group_by(model_key, outcome) %>%
  summarise(n_prompts = n(), api = mean(value), web = mean(web), api_minus_web = mean(value - web), .groups = "drop"), "web_api_comparison")
# 5. Response-level linear probability models, one per configuration ---------------
# Same estimands as the matched differences, written as regressions with the
# biography-only level (L3) as reference, and standard errors clustered by prompt
# cell, so the repetitions and collection days of one prompt count once. Gender is
# unspecified exactly at L1 and L2, so that dummy is collinear with the level dummies
# and fixest drops it; the woman-versus-man coefficient is identified within L3-L5.
coding <- read_parquet(derived_path("coding_analysis")) %>% filter(label_status == "labelled") %>%
  select(source, response_id, gives_advice, refusal_language, personalized_matching, explicit_endorsement)
rows <- read_parquet(derived_path("responses"), col_select = c("source", "response_id", "model_key", "cell_id", "level", "office", "ask", "gender")) %>%
  inner_join(coding, by = c("source", "response_id")) %>%
  mutate(level = factor(level, level_levels), office = factor(office, office_levels), ask = factor(ask, ask_levels),
    gender = factor(replace_na(as.character(gender), "unspecified"), c("homem", "mulher", "unspecified")))
term_labels <- c("level::L1" = "Bare question (vs biography only)", "level::L2" = "Issue only (vs biography only)",
  "level::L4" = "Biography and issue (vs biography only)", "level::L5" = "Attitudes added (vs biography only)",
  "office::federal_deputy" = "Federal deputy (vs president)", "ask::candidate" = "Specific-candidate wording (vs open)",
  "gender::mulher" = "Woman (vs man)")
regressions <- map_dfr(c("gives_advice", "refusal_language", "personalized_matching", "explicit_endorsement"), function(outcome) {
  map_dfr(split(rows, rows$model_key), function(d) {
    # A flag that never varies for a configuration (e.g. universal refusal language) has no model.
    if (n_distinct(d[[outcome]]) < 2) return(tibble())
    fit <- fixest::feols(as.formula(paste(outcome, "~ i(level, ref = 'L3') + i(office, ref = 'president') + i(ask, ref = 'open') + i(gender, ref = 'homem')")),
      data = d, cluster = ~cell_id)
    ct <- as.data.frame(fixest::coeftable(fit))
    tibble(model_key = d$model_key[1], outcome = outcome, term = rownames(ct), estimate = ct[, 1], se = ct[, 2],
      n = stats::nobs(fit), n_clusters = n_distinct(d$cell_id))
  })
}) %>% filter(term %in% names(term_labels)) %>%
  mutate(term_label = unname(term_labels[term]), conf_low = estimate - 1.96 * se, conf_high = estimate + 1.96 * se)
write_result(regressions, "regression_by_model")
message("Matched effects and per-model linear probability models saved; cell-clustered standard errors, no population-voter inference.")
