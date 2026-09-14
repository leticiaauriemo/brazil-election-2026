# API round: one ZIP per model, one JSON per response, into one table.
# Input:  data/api/release_zips/*.zip
# Output: output/derived/responses_api.parquet
# A response is complete when the provider stopped on its own; the few that ended
# in a tool call carry a truncated answer and are dropped from every rate.
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup.R"
))

read_one <- function(path) {
  raw <- fromJSON(path, simplifyVector = FALSE)
  tibble(
    response_id = raw$job_id,
    condition_id = raw$condition_id,
    archetype = raw$archetype %||% NA_character_,
    level = raw$level,
    gender = raw$gender %||% NA_character_,
    question_id = str_replace(raw$question_id, "^federal_deputy_", "deputy_"),
    office = raw$office,
    ask = raw$ask,
    body = raw$body %||% "",
    question = raw$question,
    model_key = raw$model_key,
    repetition = as.integer(raw$repetition),
    run_date = as.Date(substr(raw$created_at_utc, 1, 10)),
    answer = raw$answer %||% "",
    finish_reason = raw$finish_reason %||% NA_character_
  )
}
responses <- list()
for (zip in list.files(api_zip_dir, pattern = "\\.zip$", full.names = TRUE)) {
  extract_dir <- tempfile("api_round")
  dir.create(extract_dir)
  unzip(zip, exdir = extract_dir)
  responses[[zip]] <- map_dfr(
    list.files(extract_dir, pattern = "\\.json$", full.names = TRUE), read_one
  )
  unlink(extract_dir, recursive = TRUE)
}
# Llama often writes the search it would run, "[openrouter_web_search(query=...)]", and
# stops there. Like Sabia's tool calls, these are preambles to an answer, not answers.
pseudo_call <- "\\[[a-z_]+\\(query=[^\\]]*\\)\\]\\s*$"
responses <- bind_rows(responses) %>%
  mutate(
    source = "api",
    complete = !is.na(finish_reason) & finish_reason == "stop" & str_trim(answer) != "" &
      !str_detect(answer, pseudo_call)
  )

# The design is fully crossed: 64 bodies x 4 questions x 10 models x 5 repetitions.
stopifnot(
  nrow(responses) == 64 * 4 * 10 * 5,
  !anyDuplicated(responses$response_id),
  n_distinct(responses$condition_id) == 64,
  n_distinct(responses$question_id) == 4
)
write_parquet(responses, derived("responses_api"))
message("API: ", nrow(responses), " responses, ", sum(responses$complete), " complete.")
