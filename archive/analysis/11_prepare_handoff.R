# Export the complete processed corpus and a portable semantic-coding package.
# Inputs: responses.parquet, frozen coding_sample_ids.csv + metadata, analysis codebook.
# Outputs: output/ranqia_handoff/{responses.parquet,code_responses.py,codebook.json,
#          requirements.txt,README.md,handoff_manifest.json}.
# The full corpus is stacked already. llm_selected defines the paid coding sample;
# inclusion probabilities for selected rows travel with it; unselected rows have
# missing weights, not zero probabilities. Ranqia returns the same rows with
# LLM columns and nested entity lists; it performs no statistical work.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))
package_dir <- file.path(output_dir, "ranqia_handoff")
dir.create(package_dir, recursive = TRUE, showWarnings = FALSE)
input_path <- file.path(package_dir, "responses.parquet")
# A sent input must never change underneath a coding run. Rebuild deliberately
# into a new directory after moving the previous handoff, not on routine reruns.
if (!file.exists(input_path)) {
  selected <- readr::read_csv(file.path(tables_dir, "coding_sample_metadata.csv"),
    col_types = readr::cols(.default = "c")) %>% transmute(source, response_id,
      llm_selected = TRUE, llm_selection_probability = as.numeric(selection_probability))
  responses <- read_parquet(derived_path("responses")) %>% left_join(selected, by = c("source", "response_id")) %>%
    mutate(llm_selected = replace_na(llm_selected, FALSE),
      llm_selection_probability = llm_selection_probability)
  stopifnot(sum(responses$llm_selected) == nrow(selected), all(responses$complete_response[responses$llm_selected]))
  write_parquet(responses, paste0(input_path, ".tmp"))
  stopifnot(file.rename(paste0(input_path, ".tmp"), input_path))
  manifest <- list(created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    rows = nrow(responses), selected = sum(responses$llm_selected),
    sampling = "Frozen API complete responses plus up to100 web responses per prompt/date; short captures outside original sampling frame",
    row_key = c("source", "response_id"), model_known_for_web = FALSE,
    return_files = c("responses_coded.parquet", "manifest.json"),
    return_contract = "Original rows and columns preserved; llm_* columns appended; llm_entities is a nested list",
    counts = responses %>% group_by(source, model_key) %>% summarise(rows = n(), selected = sum(llm_selected), .groups = "drop"))
  write_json(manifest, file.path(package_dir, "handoff_manifest.json"), pretty = TRUE, auto_unbox = TRUE)
}
for (name in c("05_classify_llm.py", "codebook.json", "requirements.txt", "RANQIA_README.md")) {
  target <- dplyr::recode(name, "05_classify_llm.py" = "code_responses.py", "RANQIA_README.md" = "README.md")
  if (!file.exists(file.path(package_dir, target))) stopifnot(file.copy(file.path(analysis_dir, name), file.path(package_dir, target)))
}
message("Portable handoff at ", package_dir, ". No paid calls submitted.")
