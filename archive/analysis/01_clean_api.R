# Cleans the API round's release archives into the standard response table.
#
# Input:  round_2026-08-14/results/release_zips/*.zip  one ZIP per model slot,
#         one JSON per response inside
# Output: output/derived/responses_api.parquet             standard columns plus
#         the request and usage metadata specific to API calls
#         output/tables/qc_api_*.csv
#
# The archives are the raw record of the 2026-08-14 round and are never
# modified. Each JSON carries the exact prompt, the condition and question
# labels, the frozen request configuration and the provider's usage report. The
# design is fully crossed, so the expected number of responses is read off the
# archives themselves - conditions x questions x models x repetitions - rather
# than written here as a constant.

# Shared definitions (paths, taxonomies, helpers), located relative to this file.
this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))

zip_files <- sort(list.files(api_zip_dir, pattern = "\\.zip$", full.names = TRUE))
if (length(zip_files) == 0) stop("No release ZIPs under ", api_zip_dir, ".")

read_response <- function(json_path, source_zip_name) {
  raw <- fromJSON(json_path, simplifyVector = FALSE)
  usage <- raw$usage %||% list()
  search <- raw$search_usage %||% list()
  config <- raw$model_config %||% list()
  reasoning <- config$reasoning %||% list()
  search_config <- config$search %||% list()

  tibble(
    schema_version = scalar_num(raw$schema_version),
    created_at_utc = scalar_chr(raw$created_at_utc),
    config_sha256 = scalar_chr(raw$config_sha256),
    condition_id = scalar_chr(raw$condition_id),
    archetype = scalar_chr(raw$archetype),
    level = scalar_chr(raw$level),
    gender = scalar_chr(raw$gender),
    body = scalar_chr(raw$body),
    question_id = scalar_chr(raw$question_id),
    office = scalar_chr(raw$office),
    ask = scalar_chr(raw$ask),
    question = scalar_chr(raw$question),
    prompt = scalar_chr(raw$prompt),
    model_key = scalar_chr(raw$model_key),
    repetition = scalar_num(raw$repetition),
    job_id = scalar_chr(raw$job_id),
    requested_model = scalar_chr(config$model),
    requested_provider = scalar_chr(config$provider),
    reasoning_status = scalar_chr(reasoning$status),
    reasoning_effort = scalar_chr(reasoning$effort),
    search_mechanism = scalar_chr(search_config$mechanism),
    temperature_parameter = scalar_chr(config$temperature_parameter),
    temperature = scalar_num(raw$temperature),
    max_tokens = scalar_num(raw$max_tokens),
    answer = scalar_chr(raw$answer),
    returned_model = scalar_chr(raw$returned_model),
    returned_provider = scalar_chr(raw$returned_provider),
    finish_reason = scalar_chr(raw$finish_reason),
    prompt_tokens = scalar_num(usage$prompt_tokens),
    completion_tokens = scalar_num(usage$completion_tokens),
    total_tokens = scalar_num(usage$total_tokens),
    cost_usd = scalar_num(usage$cost),
    search_reported = scalar_lgl(search$reported),
    search_used = scalar_lgl(search$used),
    web_search_calls = scalar_num(search$web_search_calls %||% search$web_search_requests),
    page_reads = scalar_num(search$page_reads),
    citation_count = length(raw$citations %||% list()),
    latency_seconds = scalar_num(raw$latency_seconds),
    source_zip = source_zip_name,
    source_member = basename(json_path)
  )
}

message("Reading release archives through an ephemeral local extraction...")
extract_root <- file.path(tempdir(), "brazil_eval_api_round")
if (dir.exists(extract_root)) unlink(extract_root, recursive = TRUE, force = TRUE)
dir.create(extract_root, recursive = TRUE)
on.exit(unlink(extract_root, recursive = TRUE, force = TRUE), add = TRUE)

responses <- map_dfr(zip_files, function(zip_path) {
  model_dir <- file.path(extract_root, tools::file_path_sans_ext(basename(zip_path)))
  dir.create(model_dir, recursive = TRUE)
  utils::unzip(zip_path, exdir = model_dir)
  json_files <- sort(list.files(model_dir, pattern = "\\.json$", full.names = TRUE, recursive = TRUE))
  message("  ", basename(zip_path), ": ", length(json_files), " files")
  out <- map_dfr(json_files, ~ read_response(.x, basename(zip_path)))
  unlink(model_dir, recursive = TRUE, force = TRUE)
  out
})

# The question id in the raw JSON is written as "<office>_<ask>"; the deputy
# office is spelled out in full there and abbreviated in the handoff and in
# utils.R, so it is normalised here.
responses <- responses %>%
  mutate(
    question_id = str_replace(question_id, "^federal_deputy_", "deputy_"),
    source = "api",
    response_id = job_id,
    run_date = as.Date(substr(created_at_utc, 1, 10)),
    repetition = as.integer(repetition),
    answer_chars = str_length(answer),
    answer_words = str_count(answer, boundary("word")),
    # A response is complete when the provider stopped on its own. The handful
    # that ended in a tool call carry a truncated answer and stay out of the
    # main rates.
    complete_response = !is.na(answer) & str_trim(answer) != "" & finish_reason == "stop",
    # Only Maritaca reports whether its native search ran, and a response without
    # a report is one where it did not. OpenRouter's server tool leaves no such
    # record, so for those nine slots the flag is unobserved and stays missing;
    # citations are the only trace of search there.
    search_used = if_else(search_mechanism == "maritaca:web_search", search_used %in% TRUE, NA)
  )

# The expected grid comes from the archived handoff and the fixed five-repetition
# design, not the observed records (which cannot reveal a missing model or cell).
inventory <- fromJSON(handoff_path, simplifyVector = FALSE)$prompts %>%
  map_dfr(~ tibble(condition_id = str_remove(.x$id, "__(president|deputy)_(open|candidate)$"),
    question_id = str_extract(.x$id, "(president|deputy)_(open|candidate)$"), expected_prompt = .x$prompt))
expected <- tidyr::crossing(inventory %>% select(condition_id, question_id),
  model_key = setdiff(model_levels, "chatgpt_web"), repetition = 1:5)
stopifnot(nrow(anti_join(expected, responses, by = c("condition_id", "question_id", "model_key", "repetition"))) == 0,
  nrow(anti_join(responses, expected, by = c("condition_id", "question_id", "model_key", "repetition"))) == 0,
  nrow(responses) == nrow(expected), n_distinct(responses$job_id) == nrow(responses))
prompt_check <- responses %>% left_join(inventory, by = c("condition_id", "question_id"))
stopifnot(all(prompt_check$prompt == prompt_check$expected_prompt))
write_table(tibble(manifests_present = length(list.files(round_dir, pattern = "manifest.*json$", recursive = TRUE)),
  observed_hashes = n_distinct(responses$config_sha256),
  interpretation = "Hashes include runner code/subsets; use recorded request settings. Original retry histories are unavailable."), "qc_api_provenance")

write_parquet(responses, derived_path("responses_api"))

# --- QC ---------------------------------------------------------------------
write_table(
  tibble(
    metric = c(
      "Raw responses", "Unique job IDs", "Non-empty answers", "Finish reason = stop",
      "Finish reason = tool_calls", "Manifest hashes", "Model slots", "Conditions", "Questions", "Repetitions"
    ),
    value = c(
      nrow(responses), n_distinct(responses$job_id), sum(str_trim(responses$answer) != ""),
      sum(responses$finish_reason == "stop"), sum(responses$finish_reason == "tool_calls"),
      n_distinct(responses$config_sha256), n_distinct(responses$model_key),
      n_distinct(responses$condition_id), n_distinct(responses$question_id), max(responses$repetition)
    )
  ),
  "qc_api_overview"
)

write_table(
  responses %>%
    group_by(config_sha256) %>%
    summarise(n = n(), first_response = min(created_at_utc), last_response = max(created_at_utc), models = n_distinct(model_key), .groups = "drop") %>%
    arrange(first_response),
  "qc_api_manifest_hashes"
)

write_table(
  responses %>%
    distinct(model_key, requested_provider, requested_model, reasoning_status, reasoning_effort, search_mechanism, temperature_parameter, temperature, max_tokens) %>%
    arrange(model_key),
  "qc_api_request_settings"
)

write_table(responses %>% count(model_key, returned_provider, returned_model, sort = TRUE), "qc_api_returned_routes")

write_table(
  responses %>%
    filter(!complete_response) %>%
    select(job_id, model_key, finish_reason, answer_chars, citation_count, search_reported, search_used),
  "qc_api_incomplete_responses"
)

message("Saved ", nrow(responses), " API responses. Complete N = ", sum(responses$complete_response), ".")
