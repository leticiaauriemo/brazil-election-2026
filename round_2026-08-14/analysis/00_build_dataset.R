source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]), winslash = "/")), "R", "utils.R"))

zip_dir <- file.path(round_dir, "results", "release_zips")
zip_files <- sort(list.files(zip_dir, pattern = "\\.zip$", full.names = TRUE))
if (length(zip_files) != 10) {
  stop("Expected 10 release ZIPs under ", zip_dir, "; found ", length(zip_files), ".")
}

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
    archetype_name_pt = scalar_chr(raw$archetype_name_pt),
    gender = scalar_chr(raw$gender),
    level = scalar_chr(raw$level),
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

message("Reading verified release archives through an ephemeral local extraction...")
temp_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
extract_root <- normalizePath(file.path(temp_root, "brazil_eval_round_2026_08_14"), winslash = "/", mustWork = FALSE)
if (!startsWith(tolower(extract_root), paste0(tolower(temp_root), "/"))) {
  stop("Refusing to manage an extraction directory outside the R session temp directory.")
}
if (dir.exists(extract_root)) unlink(extract_root, recursive = TRUE, force = TRUE)
dir.create(extract_root, recursive = TRUE)
on.exit(unlink(extract_root, recursive = TRUE, force = TRUE), add = TRUE)

responses <- map_dfr(zip_files, function(zip_path) {
  model_dir <- file.path(extract_root, tools::file_path_sans_ext(basename(zip_path)))
  dir.create(model_dir, recursive = TRUE)
  zip::unzip(zip_path, exdir = model_dir)
  json_files <- sort(list.files(model_dir, pattern = "\\.json$", full.names = TRUE))
  message("  ", basename(zip_path), ": ", length(json_files), " files")
  out <- map_dfr(json_files, ~read_response(.x, basename(zip_path)))
  unlink(model_dir, recursive = TRUE, force = TRUE)
  out
}) %>%
  mutate(
    model_key = factor(model_key, levels = model_levels),
    level = factor(level, levels = level_levels),
    archetype = factor(archetype, levels = archetype_levels),
    repetition = as.integer(repetition),
    answer_words = str_count(answer, boundary("word")),
    answer_chars = str_length(answer),
    complete_response = !is.na(answer) & str_trim(answer) != "" & finish_reason == "stop"
  )

stopifnot(
  nrow(responses) == 12800,
  n_distinct(responses$job_id) == 12800,
  all(!is.na(responses$answer) & str_trim(responses$answer) != ""),
  all(table(responses$model_key) == 1280)
)

saveRDS(responses, file.path(derived_dir, "responses_raw_index.rds"), compress = "xz")

qc_overview <- tibble(
  metric = c(
    "Raw responses", "Unique job IDs", "Non-empty answers", "Finish reason = stop",
    "Finish reason = tool_calls", "Manifest hashes", "Model slots"
  ),
  value = c(
    nrow(responses), n_distinct(responses$job_id), sum(str_trim(responses$answer) != ""),
    sum(responses$finish_reason == "stop"), sum(responses$finish_reason == "tool_calls"),
    n_distinct(responses$config_sha256), n_distinct(responses$model_key)
  )
)
write.csv(qc_overview, file.path(tables_dir, "qc_overview.csv"), row.names = FALSE, fileEncoding = "UTF-8")

manifest_hashes <- responses %>%
  group_by(config_sha256) %>%
  summarise(
    n = n(), first_response = min(created_at_utc), last_response = max(created_at_utc),
    models = n_distinct(model_key), .groups = "drop"
  ) %>%
  arrange(first_response)
write.csv(manifest_hashes, file.path(tables_dir, "qc_manifest_hashes.csv"), row.names = FALSE, fileEncoding = "UTF-8")

request_settings <- responses %>%
  distinct(
    model_key, requested_provider, requested_model, reasoning_status, reasoning_effort,
    search_mechanism, temperature_parameter, temperature, max_tokens
  ) %>%
  arrange(model_key)
write.csv(request_settings, file.path(tables_dir, "qc_request_settings.csv"), row.names = FALSE, fileEncoding = "UTF-8")

returned_routes <- responses %>%
  count(model_key, returned_provider, returned_model, sort = TRUE)
write.csv(returned_routes, file.path(tables_dir, "qc_returned_routes.csv"), row.names = FALSE, fileEncoding = "UTF-8")

incomplete <- responses %>%
  filter(!complete_response) %>%
  select(job_id, model_key, finish_reason, answer_chars, citation_count, search_reported, search_used)
write.csv(incomplete, file.path(tables_dir, "qc_incomplete_responses.csv"), row.names = FALSE, fileEncoding = "UTF-8")

message("Saved ", nrow(responses), " indexed responses. Main-analysis complete N = ", sum(responses$complete_response), ".")
