# Stacks the two cleaned sources into the single response table the coder reads.
#
# Input:  output/derived/responses_api.parquet
#         output/derived/responses_ranqia.parquet
# Output: output/derived/responses.parquet   standard columns, one row per response
#         output/tables/qc_overview.csv
#
# A cell is one profile body x question x model slot within a source. It is the
# unit at which repetitions are drawn and therefore the unit of inference in
# every later script; the identifier is built here so that no script downstream
# reconstructs it differently.

# Shared definitions (paths, taxonomies, helpers), located relative to this file.
this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))

api <- read_parquet(derived_path("responses_api"), col_select = all_of(standard_columns)) %>% mutate(short_capture = FALSE)
ranqia <- read_parquet(derived_path("responses_ranqia"), col_select = all_of(c(standard_columns, "short_capture")))

responses <- bind_rows(api, ranqia) %>%
  mutate(
    source = factor(source, levels = source_levels),
    model_key = factor(model_key, levels = model_levels),
    level = factor(level, levels = level_levels),
    archetype = factor(archetype, levels = archetype_levels),
    office = factor(office, levels = office_levels),
    ask = factor(ask, levels = ask_levels),
    gender = factor(gender, levels = gender_levels),
    cell_id = paste(source, condition_id, question_id, model_key, sep = "|")
  )

stopifnot(
  n_distinct(paste(responses$source, responses$response_id)) == nrow(responses),
  !any(is.na(responses$condition_id)),
  !any(is.na(responses$question_id)),
  !any(is.na(responses$level)),
  n_distinct(responses$condition_id) == 64,
  all(is.na(responses$archetype) == (responses$level %in% c("L1"))),
  all(is.na(responses$gender) == (responses$level %in% c("L1", "L2")))
)

write_parquet(responses, derived_path("responses"))

write_table(
  responses %>%
    group_by(source, model_key) %>%
    summarise(
      responses = n(),
      complete = sum(complete_response),
      cells = n_distinct(cell_id),
      dates = n_distinct(run_date),
      median_words = median(answer_words[complete_response]),
      citation_rate = mean(citation_count[complete_response] > 0),
      search_rate = mean(search_used[complete_response], na.rm = TRUE),
      .groups = "drop"
    ),
  "qc_overview"
)

message("Stacked ", nrow(responses), " responses in ", n_distinct(responses$cell_id), " cells; complete N = ", sum(responses$complete_response), ".")
