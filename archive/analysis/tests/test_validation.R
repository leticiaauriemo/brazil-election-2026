# Exercise validation on synthetic answers without touching real annotation work.
# Checks: model-specific weighting, independent refusal labels, alias/set matching,
# paired coder comparison, incomplete annotation and missing-coder coverage.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
analysis_dir <- dirname(dirname(normalizePath(this_file)))
repo_dir <- dirname(analysis_dir)
for (expr in parse(file.path(analysis_dir, "R", "utils.R"))) {
  if (is.call(expr) && identical(expr[[1]], as.name("<-")) && as.character(expr[[2]]) %in% c("analysis_dir", "repo_dir")) next
  eval(expr)
}
fixture <- tempfile("brazil_validation_")
dir.create(file.path(fixture, "analysis", "R"), recursive = TRUE)
dir.create(file.path(fixture, "output", "derived"), recursive = TRUE)
dir.create(file.path(fixture, "output", "tables"), recursive = TRUE)
dir.create(file.path(fixture, "analysis", "reference"), recursive = TRUE)
file.copy(file.path(analysis_dir, "06_coding_agreement.R"), file.path(fixture, "analysis"))
file.copy(file.path(analysis_dir, "R", "utils.R"), file.path(fixture, "analysis", "R"))
file.copy(file.path(analysis_dir, "reference", "name_aliases.csv"), file.path(fixture, "analysis", "reference"))

# The first prompt has three answers and the second one answer. Equal prompt
# weights produce a false-positive rate of 1/4, rather than the raw rate of 1/2.
rows <- tibble(source = "api", response_id = paste0("fixture_", 1:8),
  model_key = rep(c("model_a", "model_b"), each = 4), level = "L4", office = "president", ask = "open",
  condition_id = rep(c("prompt_1", "prompt_1", "prompt_1", "prompt_2"), 2),
  question_id = "q1", run_date = "2026-08-14")
write_parquet(rows, file.path(fixture, "output", "derived", "responses.parquet"))
readr::write_csv(rows, file.path(fixture, "output", "tables", "coding_sample_metadata.csv"))
key <- rows %>% mutate(stratum = paste0(model_key, "|", rep(c(TRUE, TRUE, FALSE, FALSE), 2)),
  hand_probability = 1, stratum_population_n = 2L, stratum_sample_n = 2L)
readr::write_csv(key, file.path(fixture, "output", "tables", "hand_validation_key.csv"))
readr::write_csv(rows %>% slice(0), file.path(fixture, "output", "tables", "hand_calibration_key.csv"))
labels <- rows %>% transmute(source, response_id, coder = "regex",
  response_category = "neutral_information", gives_advice = rep(c(TRUE, TRUE, FALSE, FALSE), 2),
  refusal_language = FALSE, negative_steering = FALSE,
  recommended_people = "lula|zema", recommended_parties = "UNIÃO|PT")
llm <- labels %>% mutate(coder = "llm_fixture", recommended_people = "Romeu Zema|Luiz Inácio Lula da Silva",
  recommended_parties = "PT|UNIAO")
write_parquet(bind_rows(labels, llm), file.path(fixture, "output", "derived", "coding_comparison.parquet"))
hand <- rows %>% transmute(source, response_id, prompt = "Synthetic prompt", answer = "Synthetic answer",
  hand_category = "neutral_information", hand_gives_advice = rep(c("TRUE", "FALSE", "TRUE", "FALSE"), 2),
  hand_refusal_language = "TRUE", hand_negative_steering = "FALSE",
  hand_recommended_people = "Romeu Zema|Luiz Inácio Lula da Silva", hand_recommended_parties = "PT|UNIAO",
  hand_notes = "Synthetic fixture, not research evidence", hand_coder = "fixture", hand_complete = "FALSE")
sheet <- file.path(fixture, "output", "tables", "hand_validation.csv")
readr::write_csv(hand, sheet)

# Running from another directory also checks the standalone path resolution.
script <- file.path(fixture, "analysis", "06_coding_agreement.R")
run_fixture <- function() {
  result <- system2(file.path(R.home("bin"), "Rscript"), shQuote(script), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status"))) stop(paste(result, collapse = "\n"))
}
run_fixture()
status <- readr::read_csv(file.path(fixture, "output", "tables", "validation_status.csv"), show_col_types = FALSE)
stopifnot(status$status == "UNVALIDATED")
pair <- readr::read_csv(file.path(fixture, "output", "tables", "agreement_by_model.csv"), show_col_types = FALSE)
stopifnot(nrow(pair) == 2, all(pair$n == 4), all(pair$people_set_agreement == 1), all(pair$party_set_agreement == 1))

hand$hand_complete[1] <- "TRUE"
readr::write_csv(hand, sheet)
run_fixture()
partial <- readr::read_csv(file.path(fixture, "output", "tables", "validation_errors_by_model.csv"), show_col_types = FALSE)
stopifnot(nrow(partial) == 0)

hand$hand_complete <- "TRUE"
readr::write_csv(hand, sheet)
run_fixture()
errors <- readr::read_csv(file.path(fixture, "output", "tables", "validation_errors_by_model.csv"), show_col_types = FALSE)
fpr <- errors %>% filter(construct == "gives_advice", metric == "false_positive_rate")
refusal <- errors %>% filter(construct == "refusal_language", metric == "recall")
stopifnot(nrow(fpr) == 4, all(abs(fpr$estimate - 0.25) < 1e-10), all(refusal$estimate == 0))
sets <- readr::read_csv(file.path(fixture, "output", "tables", "validation_sets_by_model.csv"), show_col_types = FALSE)
stopifnot(all(sets$people_exact_agreement == 1), all(sets$parties_exact_agreement == 1))

# An incomplete returned coder cannot quietly publish accuracy on its successes.
write_parquet(bind_rows(labels, llm %>% filter(response_id != "fixture_1")),
  file.path(fixture, "output", "derived", "coding_comparison.parquet"))
run_fixture()
errors <- readr::read_csv(file.path(fixture, "output", "tables", "validation_errors_by_model.csv"), show_col_types = FALSE)
stopifnot(nrow(filter(errors, coder == "llm_fixture", model_key == "model_a")) == 0,
  nrow(filter(errors, coder == "regex", model_key == "model_a")) > 0)
unlink(fixture, recursive = TRUE)
message("Validation integration checks passed; research data and labels unchanged.")
