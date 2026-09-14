# Verify returned semantic labels and held-out validation through production R.
# Inputs are four synthetic answers, one of which the semantic coder failed to
# label; all outputs go to a disposable temp folder.
suppressPackageStartupMessages({library(arrow);library(dplyr);library(tidyr);library(purrr);library(stringr);library(jsonlite)})
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
analysis <- dirname(dirname(normalizePath(script)))
folder <- tempfile("brazil-coder-"); dir.create(folder)
e <- new.env(parent = globalenv())
e$analysis_dir <- analysis; e$repo_dir <- folder; e$derived_dir <- folder; e$tables_dir <- folder
e$reference_dir <- file.path(folder, "reference"); dir.create(e$reference_dir)
e$main_coder <- "llm_fixture"
e$party_scales_path <- file.path(dirname(analysis), "round_2026-08-14", "party_scales.json")
e$derived_path <- function(name) file.path(folder, paste0(name, ".parquet"))
e$write_table <- function(x, name) readr::write_csv(x, file.path(folder, paste0(name, ".csv")))
for (expr in parse(file.path(analysis, "R", "utils.R"))) {
  if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
      as.character(expr[[2]]) %in% c("canonical_name", "canonical_party", "load_party_scales", "%||%", "response_categories")) eval(expr, e)
}
metadata <- tibble(source = "api", response_id = as.character(1:4), model_key = "gpt4o", cell_id = "cell",
  condition_id = "profile", question_id = "president_open", level = "L5", archetype = "a", gender = "homem",
  office = "president", ask = "open", run_date = as.Date("2026-08-22"), complete_response = TRUE,
  citation_count = 0L, search_used = FALSE, answer_chars = 200L)
write_parquet(metadata, e$derived_path("responses"))
regex <- metadata %>% transmute(source, response_id, coder = "regex", refusal_language = FALSE,
  refusal_grounds = "none", procedure_guidance = FALSE, stale_timing = FALSE)
write_parquet(regex, e$derived_path("coding"))
entities <- tibble(source = "api", response_id = c("1", "2"), coder = "regex", entity_kind = "person",
  entity = "Lula", entity_party = c("PT", "PT"), party_source = "tag", stance = "recommended",
  stance_tier = "strong", evidence = "Vote em Lula.")
write_parquet(entities, e$derived_path("entity_mentions"))
run <- file.path(folder, "data", "ranqia", "llm", "run"); dir.create(run, recursive = TRUE)
# One unselected answer remains in the delivered file, without semantic labels.
original <- bind_rows(metadata, metadata %>% slice(1) %>% mutate(response_id = "5")) %>%
  mutate(llm_selected = response_id != "5", answer = "Original text preserved")
entity_rows <- tibble(kind = "person", name = "Lula", party = "PT", stance = "recommended",
  recommendation_basis = "explicit_endorsement", evidence = "Vote em Lula.")
# Answer 4 is selected but the coder failed on it: no labels, no coder, no entities.
labelled <- original$llm_selected & original$response_id != "4"
returned <- original %>% mutate(llm_status = case_when(!llm_selected ~ "not_selected", response_id == "4" ~ "failed", TRUE ~ "succeeded"),
  llm_coder = if_else(labelled, "llm_fixture", NA_character_),
  llm_refusal_language = if_else(labelled, FALSE, NA),
  llm_refusal_grounds = if_else(labelled, "none", NA_character_),
  llm_procedure_guidance = if_else(labelled, FALSE, NA), llm_stale_timing = if_else(labelled, FALSE, NA),
  llm_explicit_endorsement = if_else(labelled, response_id %in% c("1", "2"), NA),
  llm_personalized_matching = if_else(labelled, response_id == "1", NA),
  llm_negative_steering = if_else(labelled, FALSE, NA),
  llm_entities = list(entity_rows, entity_rows, entity_rows[0,], NULL, NULL))
write_parquet(returned, file.path(run, "responses_coded_final.parquet"))
readr::write_csv(tibble(source = "api", response_id = "4", custom_id = "x", result_type = "invalid_output", detail = "fixture"), file.path(run, "failed_requests_final.csv"))
hash_folder <- file.path(folder, "output", "ranqia_handoff"); dir.create(hash_folder, recursive = TRUE)
write_parquet(original, file.path(hash_folder, "responses.parquet"))
writeLines(c("inputhash  responses.parquet"), file.path(hash_folder, "SHA256SUMS"))
codebook_version <- fromJSON(file.path(analysis, "codebook.json"), simplifyVector = FALSE)$version
write_json(list(input_sha256 = "inputhash", codebook_version = codebook_version, model = "fixture",
  final_valid_selected = 3L, residual_failures = 1L), file.path(run, "final_manifest.json"), auto_unbox = TRUE)
ids <- metadata %>% select(source, response_id)
readr::write_csv(ids, file.path(folder, "coding_sample_ids.csv"))

run_production <- function(name) {
  for (expr in parse(file.path(analysis, name))) {
    if (is.call(expr) && identical(expr[[1]], as.name("source"))) next
    if (is.call(expr) && identical(expr[[1]], as.name("<-")) && identical(expr[[2]], as.name("this_file"))) next
    eval(expr, e)
  }
}
run_production("03b_normalize_coding.R")
active <- read_parquet(e$derived_path("coding_analysis"))
stopifnot(nrow(active) == 4, active$personalized_matching[active$response_id == "1"],
  active$explicit_endorsement[active$response_id == "1"], active$zeta_recommended[active$response_id == "1"] == -.691,
  active$recommended_people[active$response_id == "1"] == "luiz inacio lula da silva",
  is.na(active$zeta_recommended[active$response_id == "3"]),
  is.na(active$gives_advice[active$response_id == "4"]), active$response_category[active$response_id == "4"] == "not_coded",
  is.na(active$n_people[active$response_id == "4"]), active$label_status[active$response_id == "4"] == "missing")

# A ready manifest cannot conceal dropped original rows or changed selection.
write_parquet(returned %>% filter(response_id != "5"), file.path(run, "responses_coded_final.parquet"))
stopifnot(inherits(try(run_production("03b_normalize_coding.R"), silent = TRUE), "try-error"))
write_parquet(returned %>% mutate(llm_selected = TRUE), file.path(run, "responses_coded_final.parquet"))
stopifnot(inherits(try(run_production("03b_normalize_coding.R"), silent = TRUE), "try-error"))
# A failed row missing from the ledger, or a success count off the manifest, is refused.
write_parquet(returned %>% mutate(llm_status = if_else(response_id == "3", "failed", llm_status)), file.path(run, "responses_coded_final.parquet"))
stopifnot(inherits(try(run_production("03b_normalize_coding.R"), silent = TRUE), "try-error"))
# Empty entity lists are successful measurements, not missing responses.
empty_return <- returned
empty_return$llm_entities[1:3] <- rep(list(entity_rows[0,]), 3)
write_parquet(empty_return, file.path(run, "responses_coded_final.parquet"))
run_production("03b_normalize_coding.R")
stopifnot(all(na.omit(read_parquet(e$derived_path("coding_analysis"))$n_people) == 0))
write_parquet(returned, file.path(run, "responses_coded_final.parquet"))
run_production("03b_normalize_coding.R")

# Human truth yields TP=FP=FN=TN=1 for the regex instrument.
key <- metadata %>% transmute(source, response_id, model_key, stratum = if_else(response_id %in% c("1", "2"), "positive", "negative"),
  hand_probability = 1, stratum_population_n = 2L, stratum_sample_n = 2L)
readr::write_csv(key, file.path(folder, "hand_validation_key.csv"))
readr::write_csv(ids[0,], file.path(folder, "hand_calibration_key.csv"))
readr::write_csv(metadata, file.path(folder, "coding_sample_metadata.csv"))
hand <- ids %>% mutate(prompt = "Em quem votar?", answer = "Synthetic example",
  hand_category = if_else(response_id %in% c("1", "4"), "explicit_endorsement", "unclear"),
  hand_gives_advice = if_else(response_id %in% c("1", "4"), "TRUE", "FALSE"), hand_refusal_language = "FALSE",
  hand_negative_steering = "FALSE", hand_recommended_people = if_else(response_id %in% c("1", "4"), "Lula", ""),
  hand_recommended_parties = if_else(response_id %in% c("1", "4"), "PT", ""), hand_notes = "", hand_coder = "fixture", hand_complete = TRUE)
readr::write_csv(hand, file.path(folder, "hand_validation.csv"))
run_production("06_coding_agreement.R")
errors <- readr::read_csv(file.path(folder, "validation_errors_by_model.csv"), show_col_types = FALSE)
stopifnot(all(errors$estimate[errors$coder == "regex" & errors$construct == "gives_advice"] == .5))
# An incomplete audit must not publish error estimates from a selected subset.
hand$hand_complete[1] <- FALSE
readr::write_csv(hand, file.path(folder, "hand_validation.csv"))
run_production("06_coding_agreement.R")
stopifnot(nrow(readr::read_csv(file.path(folder, "validation_errors_by_model.csv"), show_col_types = FALSE)) == 0)
cat("Semantic return integration, exact aliases, independent flags and held-out validation checks passed.\n")
