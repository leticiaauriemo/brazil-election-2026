options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(jsonlite)
  library(purrr)
  library(stringr)
  library(tidyr)
})

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

scalar_chr <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[[1]])) NA_character_ else as.character(x[[1]])
}

scalar_num <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[[1]])) NA_real_ else as.numeric(x[[1]])
}

scalar_lgl <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[[1]])) NA else isTRUE(x[[1]])
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) == 0) stop("Run an analysis script with Rscript.")
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]), winslash = "/", mustWork = TRUE)
analysis_dir <- dirname(script_path)
round_dir <- normalizePath(file.path(analysis_dir, ".."), winslash = "/", mustWork = TRUE)
repo_dir <- normalizePath(file.path(round_dir, ".."), winslash = "/", mustWork = TRUE)

analysis_results_dir <- file.path(round_dir, "results", "analysis")
derived_dir <- file.path(analysis_results_dir, "derived")
tables_dir <- file.path(analysis_results_dir, "tables")
figures_dir <- file.path(analysis_results_dir, "figures")
dir.create(derived_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

model_levels <- c(
  "gpt4o", "gpt56_luna", "gpt56_sol", "claude_sonnet5", "claude_opus5",
  "gemini_pro", "deepseek_v4_pro", "grok46", "llama_maverick", "sabia4"
)

model_labels <- c(
  gpt4o = "GPT-4o",
  gpt56_luna = "GPT-5.6 Luna",
  gpt56_sol = "GPT-5.6 Sol",
  claude_sonnet5 = "Claude Sonnet 5",
  claude_opus5 = "Claude Opus 5",
  gemini_pro = "Gemini 3.1 Pro",
  deepseek_v4_pro = "DeepSeek V4 Pro",
  grok46 = "Grok 4.6",
  llama_maverick = "Llama 4 Maverick",
  sabia4 = "Sabiá 4"
)

level_levels <- c("L1", "L2", "L3", "L4", "L5")

archetype_levels <- c(
  "militante_esquerda", "progressista", "classes_d_e", "liberal_social",
  "empreendedor_individual", "conservador_cristao", "agro", "empresario",
  "extrema_direita"
)

archetype_labels <- c(
  militante_esquerda = "Left activist",
  progressista = "Progressive",
  classes_d_e = "State-dependent",
  liberal_social = "Social liberal",
  empreendedor_individual = "Solo entrepreneur",
  conservador_cristao = "Christian conservative",
  agro = "Agribusiness",
  empresario = "Business owner",
  extrema_direita = "Far right"
)

palette <- c(
  navy = "#17324D", blue = "#3F72AF", teal = "#2A9D8F", gold = "#E9C46A",
  coral = "#E76F51", red = "#B23A48", ink = "#202B33", grey = "#7A8793",
  light = "#EEF2F5"
)

theme_round <- function(base_size = 12) {
  theme_minimal(base_size = base_size, base_family = "Arial") +
    theme(
      plot.title.position = "plot",
      plot.title = element_text(face = "bold", color = palette[["navy"]], size = rel(1.15)),
      plot.subtitle = element_text(color = palette[["grey"]], margin = margin(b = 8)),
      plot.caption = element_text(color = palette[["grey"]], hjust = 0, size = rel(0.72)),
      axis.title = element_text(color = palette[["ink"]]),
      axis.text = element_text(color = palette[["ink"]]),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      legend.position = "bottom",
      legend.title = element_blank(),
      strip.text = element_text(face = "bold", color = palette[["navy"]]),
      plot.margin = margin(10, 14, 8, 10)
    )
}

save_plot <- function(filename, plot, width = 10.5, height = 5.7) {
  ggsave(
    filename = file.path(figures_dir, filename), plot = plot,
    width = width, height = height, units = "in", dpi = 180, bg = "white"
  )
}

pct <- function(x, digits = 0) scales::percent(x, accuracy = 10^(-digits))

