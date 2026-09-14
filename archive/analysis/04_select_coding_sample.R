# Freeze the coding sample and independent calibration/validation exercises.
# Inputs: responses.parquet; coding_sample_ids.csv if already frozen; regex labels.
# Outputs: frozen IDs, inclusion probabilities, separate hand sheets and keys.
# All API responses and up to 100 web responses per prompt/date define the coding
# population. Equal date/prompt/model weights are applied later, not through N.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))
metadata <- read_parquet(derived_path("responses"), col_select = c("source", "response_id",
  "model_key", "condition_id", "question_id", "run_date", "level", "archetype", "gender",
  "office", "ask", "complete_response", "short_capture")) %>% filter(complete_response, !short_capture)
sample_path <- file.path(tables_dir, "coding_sample_ids.csv")

# Short captures newly admitted by cleaning were outside the original sampling
# frame. They remain a separate QC population, not silently assigned positive
# inclusion probabilities in a sample that could never have selected them.

# 1. Preserve the original 103,934 IDs; a seed alone does not freeze a sample ------
if (file.exists(sample_path)) {
  selected <- readr::read_csv(sample_path, col_types = readr::cols(.default = "c")) %>% select(source, response_id)
  stopifnot(!anyDuplicated(selected), nrow(anti_join(selected, metadata, by = c("source", "response_id"))) == 0)
} else {
  set.seed(20260905)
  selected <- bind_rows(metadata %>% filter(source == "api"), metadata %>% filter(source == "chatgpt_web") %>%
    group_by(condition_id, question_id, run_date) %>% slice_sample(n = 100) %>% ungroup()) %>%
    select(source, response_id)
  write_table(selected, "coding_sample_ids")
}
population <- metadata %>% count(source, model_key, condition_id, question_id, run_date, name = "population_n")
sample_metadata <- metadata %>% semi_join(selected, by = c("source", "response_id")) %>%
  group_by(source, model_key, condition_id, question_id, run_date) %>% mutate(sample_n = n()) %>% ungroup() %>%
  left_join(population, by = c("source", "model_key", "condition_id", "question_id", "run_date")) %>%
  mutate(selection_probability = sample_n / population_n)
write_table(sample_metadata, "coding_sample_metadata")

# 2. Calibration teaches the codebook; validation estimates errors independently -
# Allocation deliberately gives the web surface 180 validation answers rather
# than 18. Within model, split equally on provisional regex advice. Inclusion
# probabilities restore the target population when computing precision/recall.
if (file.exists(derived_path("coding"))) {
  strata <- sample_metadata %>% left_join(read_parquet(derived_path("coding")) %>%
    select(source, response_id, gives_advice), by = c("source", "response_id"))
  if (any(is.na(strata$gives_advice))) stop("Run regex coding on every frozen ID before drawing hand samples")
  strata <- strata %>% mutate(stratum = paste(model_key, gives_advice, sep = "|"))
  if (!file.exists(file.path(tables_dir, "hand_calibration_key.csv"))) {
    set.seed(20260907)
    calibration <- strata %>% group_by(model_key, gives_advice) %>%
      group_modify(~slice_sample(.x, n = if (.y$model_key == "chatgpt_web") 30 else 3)) %>% ungroup()
    write_table(calibration, "hand_calibration_key")
  }
  calibration <- readr::read_csv(file.path(tables_dir, "hand_calibration_key.csv"),
    col_types = readr::cols(.default = "c")) %>% select(source, response_id)
  if (!file.exists(file.path(tables_dir, "hand_validation_key.csv"))) {
    validation_pool <- strata %>% anti_join(calibration, by = c("source", "response_id")) %>%
      group_by(stratum) %>% mutate(stratum_population_n = n()) %>% ungroup()
    set.seed(20260908)
    validation <- validation_pool %>% group_by(model_key, gives_advice) %>%
      group_modify(~slice_sample(.x, n = if (.y$model_key == "chatgpt_web") 90 else 24)) %>% ungroup() %>%
      group_by(stratum) %>% mutate(stratum_sample_n = n(), hand_probability = stratum_sample_n / stratum_population_n) %>% ungroup()
    write_table(validation, "hand_validation_key")
  }
  for (exercise in c("calibration", "validation")) {
    sheet_path <- file.path(tables_dir, paste0("hand_", exercise, ".csv"))
    if (file.exists(sheet_path)) next # Never overwrite annotation work.
    key <- readr::read_csv(file.path(tables_dir, paste0("hand_", exercise, "_key.csv")),
      col_types = readr::cols(.default = "c")) %>% select(source, response_id)
    answers <- open_dataset(derived_path("responses")) %>% filter(response_id %in% key$response_id) %>%
      select(source, response_id, prompt, answer) %>% collect() %>% semi_join(key, by = c("source", "response_id"))
    sheet <- answers %>% mutate(hand_category = "", hand_gives_advice = "", hand_refusal_language = "",
      hand_negative_steering = "", hand_recommended_people = "", hand_recommended_parties = "",
      hand_notes = "", hand_coder = "", hand_complete = FALSE)
    write_table(sheet, paste0("hand_", exercise))
  }
  message("Frozen hand samples available. Calibration and validation are disjoint; legacy sheet preserved.")
} else message("Coding IDs frozen. Run 03, then rerun 04 to draw hand samples.")
