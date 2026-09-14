# Check the actual summary and contrast scripts on an unbalanced synthetic panel.
# Inputs: analysis/07_summarize.R and analysis/08_regressions.R; no research data.
# Outputs: assertions and disposable tables under the operating-system temp folder.
# The fixture makes response weighting, date weighting and undefined conditional
# outcomes yield visibly different answers, so those mistakes cannot pass silently.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(readr)
})
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
analysis_dir <- dirname(dirname(normalizePath(script)))
fixture_dir <- tempfile("brazil-results-")
dir.create(fixture_dir)

# 1. Two configurations answer the same prompts at different repetition counts ---
profiles <- bind_rows(
  tibble(level = "L1", archetype = NA_character_, gender = NA_character_),
  crossing(level = "L2", archetype = c("a", "b")) %>% mutate(gender = NA_character_),
  crossing(level = c("L3", "L4", "L5"), archetype = c("a", "b"), gender = c("homem", "mulher"))
) %>% mutate(condition_id = paste(level, archetype, gender, sep = "_"))
prompts <- crossing(profiles, office = c("president", "federal_deputy"), ask = c("open", "candidate")) %>%
  mutate(question_id = paste(office, ask, sep = "_"))
metadata <- crossing(prompts, model_key = c("gpt4o", "chatgpt_web")) %>%
  mutate(source = if_else(model_key == "gpt4o", "api", "chatgpt_web"),
    cell_id = paste(model_key, condition_id, question_id, sep = "_"),
    days = if_else(source == "api", 1L, 2L)) %>%
  uncount(days, .id = "day") %>%
  mutate(run_date = paste0("2026-08-0", day), repetitions = case_when(source == "api" ~ 4L, day == 1 ~ 2L, TRUE ~ 10L)) %>%
  uncount(repetitions, .id = "repetition") %>%
  mutate(response_id = as.character(row_number()), complete_response = TRUE, search_used = FALSE, answer_chars = 1000L)
coding <- metadata %>% mutate(
  gives_advice = (is.na(archetype) | archetype == "a") &
    if_else(source == "api", level != "L4" | repetition <= 2, day == 2 & repetition <= 2),
  gives_direction = gives_advice, coder = "fixture", explicit_endorsement = gives_advice,
  personalized_matching = FALSE, negative_steering = FALSE,
  recommendation_strength = if_else(gives_advice, "single_named", "none"),
  n_people = as.integer(gives_advice), refusal_language = !gives_advice,
  procedure_guidance = FALSE, slate_enumeration = FALSE, stale_timing = FALSE, citation_any = FALSE,
  zeta_recommended = if_else(gives_advice, -.6, NA_real_),
  response_category = if_else(gives_advice, "explicit_endorsement", "substantive_refusal"),
  recommended_people = if_else(gives_advice, if_else(source == "chatgpt_web" & repetition == 2, "bob", "alice"), ""),
  recommended_parties = if_else(gives_advice, "PT", "")) %>%
  select(source, response_id, coder, gives_advice, gives_direction, explicit_endorsement, personalized_matching,
    negative_steering, recommendation_strength, n_people, refusal_language, procedure_guidance, slate_enumeration,
    stale_timing, citation_any, zeta_recommended, response_category, recommended_people, recommended_parties)
entities <- coding %>% filter(gives_advice) %>% transmute(source, response_id,
  entity_kind = "person", entity = recommended_people, entity_party = "PT", stance = "recommended", registry_matched = NA)
write_parquet(metadata, file.path(fixture_dir, "responses.parquet"))
write_parquet(coding, file.path(fixture_dir, "coding_analysis.parquet"))
write_parquet(entities, file.path(fixture_dir, "entity_mentions_analysis.parquet"))

# 2. Run the production statements with only file locations substituted -----------
execution <- new.env(parent = globalenv())
execution$main_coder <- "fixture"
execution$result_dir <- fixture_dir
execution$response_categories <- c("explicit_endorsement", "substantive_refusal")
execution$derived_path <- function(name) file.path(fixture_dir, paste0(name, ".parquet"))
execution$write_result <- function(data, name) write_csv(data, file.path(fixture_dir, paste0(name, ".csv")), na = "")
for (name in c("07_summarize.R", "08_regressions.R")) {
  lines <- readLines(file.path(analysis_dir, name))
  lines <- lines[!grepl("^this_file <-|^source\\(file.path", lines)]
  eval(parse(text = lines), envir = execution)
}

# 3. Check estimands against the deliberately constructed probabilities ----------
# Web: zero advice on a two-answer day, 20% on a ten-answer day => 10%,
# not the response-weighted 16.7%. API contributes exactly half the pooled mean.
pool <- read_csv(file.path(fixture_dir, "pooled_by_full_profile.csv"), show_col_types = FALSE) %>%
  filter(archetype == "a", outcome == "gives_advice")
stopifnot(all(abs(pool$rate - .55) < 1e-12), all(pool$n_models == 2))
people <- read_csv(file.path(fixture_dir, "person_recommendations_by_model.csv"), show_col_types = FALSE)
stopifnot(all(is.na(people$conditional[people$archetype == "b"])))
alice <- people %>% filter(model_key == "chatgpt_web", archetype == "a", entity == "alice")
stopifnot(all(abs(alice$unconditional - .05) < 1e-12), all(abs(alice$conditional - .5) < 1e-12))
ideology <- read_csv(file.path(fixture_dir, "ideology_by_model_profile.csv"), show_col_types = FALSE)
stopifnot(all(is.na(ideology$mean_zeta[ideology$archetype == "b"])),
  all(abs(ideology$mean_zeta[ideology$archetype == "a"] + .6) < 1e-12))

# Both gender variants of L4 share one L2 issue baseline. The a-profile change
# is -50 pp; the b-profile change is zero, giving the API a -25 pp average.
contrasts <- read_csv(file.path(fixture_dir, "contrasts_by_model.csv"), show_col_types = FALSE) %>%
  filter(model_key == "gpt4o", outcome == "gives_advice")
biography <- contrasts %>% filter(contrast == "biography_added_to_issue")
issue <- contrasts %>% filter(contrast == "issue_added_to_state")
stopifnot(abs(biography$difference + .25) < 1e-12, biography$n_pairs == 8,
  abs(issue$baseline - 1) < 1e-12, abs(issue$treatment - .5) < 1e-12,
  abs(issue$difference + .5) < 1e-12)
# The two web recommendations name different people but the same party.
# Two empty sets on the other date must never be scored as perfect agreement.
people_sets <- read_csv(file.path(fixture_dir, "web_people_consistency.csv"), show_col_types = FALSE)
party_sets <- read_csv(file.path(fixture_dir, "web_parties_consistency.csv"), show_col_types = FALSE)
stopifnot(all(people_sets$pair_agreement[!is.na(people_sets$pair_agreement)] == 0),
  all(party_sets$pair_agreement[!is.na(party_sets$pair_agreement)] == 1),
  all(is.na(people_sets$pair_agreement[is.na(people_sets$n_advice_with_set)])),
  nrow(people_sets) == nrow(prompts))
message("Passed: unequal counts, equal dates/models, undefined conditionals, shared baselines and pairwise sets.")
