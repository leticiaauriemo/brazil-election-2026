# Shared settings for the president-versus-deputy explorations. The current pipeline's
# setup supplies packages, labels and the theme; only the output paths are redirected
# to this folder. Inputs are output/derived and output/tables at the repository root.
this_file <- normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
))
here <- dirname(this_file)
current <- file.path(here, "..", "..")
source(file.path(current, "00_setup.R"))
here <- dirname(this_file)
library(forcats)
labels_path <- file.path(
  here, "..", "data", "ranqia", "llm", "final_2026-09-09", "responses_coded_final.parquet"
)
derived <- function(name) file.path(current, "output", "derived", paste0(name, ".parquet"))
reference <- function(name) file.path(current, "reference", name)
read_table <- function(name) {
  read_csv(file.path(current, "output", "tables", paste0(name, ".csv")), show_col_types = FALSE)
}
write_table <- function(x, name) {
  write_csv(x, file.path(here, "tables", paste0(name, ".csv")), na = "")
}
save_figure <- function(name, plot, width, height) {
  plot$labels$caption <- str_wrap(plot$labels$caption, width = round(width * 14))
  for (ext in c("png", "pdf")) {
    ggsave(file.path(here, "figures", paste0(name, ".", ext)), plot,
      width = width, height = height, dpi = 180, bg = "white"
    )
  }
}
pct <- scales::label_percent(accuracy = 1)
model_name <- function(x) {
  factor(unname(model_labels[as.character(x)]), unname(model_labels[model_levels]))
}
level_name <- function(x) {
  factor(
    x, level_order,
    labels = str_replace(unname(level_labels[level_order]), "Biography \\+ issue", "Bio +\nissue")
  )
}
profile_name <- function(x) {
  factor(unname(archetype_labels[as.character(x)]), rev(unname(archetype_labels[archetype_levels])))
}
side_name <- function(x) factor(unname(side_labels[as.character(x)]), side_order)
# Weighting as in current/: days within a prompt, prompts within a model.
rate_by <- function(d, ..., outcomes) {
  d %>%
    group_by(..., prompt_cell, run_date) %>%
    summarise(across({{ outcomes }}, mean), .groups = "drop") %>%
    group_by(..., prompt_cell) %>%
    summarise(across({{ outcomes }}, mean), .groups = "drop") %>%
    group_by(...) %>%
    summarise(
      prompts = n(),
      across({{ outcomes }}, list(se = ~ sd(.x) / sqrt(n()), mean = mean), .names = "{.col}_{.fn}"),
      .groups = "drop"
    ) %>%
    rename_with(~ str_remove(.x, "_mean$"))
}
# The labelled sample, specific wording, with the three readings of a steer.
labelled_sample <- function() {
  read_parquet(derived("sample")) %>%
    filter(ask == "candidate", labelled) %>%
    mutate(
      party_only = steers & n_people == 0,
      shortlist = steers & n_people >= 2,
      any_steer = steers
    )
}
