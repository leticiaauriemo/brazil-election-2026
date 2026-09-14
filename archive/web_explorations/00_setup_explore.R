# Shared settings for the web-only explorations. These read the current pipeline's
# derived files and Ranqia's raw exports; outputs stay in this folder until one of
# them is promoted to the official pipeline.
suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(stringr); library(purrr)
  library(readr); library(ggplot2)
})
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])))
current <- file.path(here, "..", "..")
raw <- file.path(here, "..", "data", "ranqia", "raw")
derived <- function(name) file.path(current, "output", "derived", paste0(name, ".parquet"))
write_table <- function(x, name) write_csv(x, file.path(here, "tables", paste0(name, ".csv")), na = "")
level_order <- c("L1", "L3", "L2", "L4", "L5")
level_labels <- c(L1 = "Nothing", L3 = "Biography", L2 = "Issue", L4 = "Bio +\nissue", L5 = "+ Attitudes")
archetype_levels <- c("militante_esquerda", "progressista", "classes_d_e", "liberal_social", "empreendedor_individual",
  "conservador_cristao", "agro", "empresario", "extrema_direita")
archetype_labels <- c(militante_esquerda = "Left activist", progressista = "Progressive", classes_d_e = "State-dependent",
  liberal_social = "Social liberal", empreendedor_individual = "Solo entrepreneur", conservador_cristao = "Christian conservative",
  agro = "Agribusiness", empresario = "Business owner", extrema_direita = "Far right")
side <- c(militante_esquerda = "Left profiles", progressista = "Left profiles", classes_d_e = "Left profiles",
  liberal_social = "Centre profiles", empreendedor_individual = "Centre profiles",
  conservador_cristao = "Right profiles", agro = "Right profiles", empresario = "Right profiles", extrema_direita = "Right profiles")
office_labels <- c(president = "President", federal_deputy = "Federal deputy, SP")
palette <- c(navy = "#17324D", teal = "#2A9D8F", gold = "#E9C46A", coral = "#E76F51", grey = "#7A8793", ink = "#202B33")
pct <- scales::label_percent(accuracy = 1)
theme_set(theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.y = element_blank(), legend.position = "bottom",
    legend.title = element_blank(), strip.text = element_text(face = "bold", color = palette[["navy"]]),
    plot.caption = element_text(color = palette[["grey"]], hjust = 0, size = rel(0.8))))
save_figure <- function(name, plot, width, height) {
  plot$labels$caption <- str_wrap(plot$labels$caption, width = round(width * 14))
  for (ext in c("png", "pdf")) ggsave(file.path(here, "figures", paste0(name, ".", ext)), plot, width = width, height = height, dpi = 180, bg = "white")
}
# The web captures in the coded sample, full profile, specific-candidate wording, labelled.
web_sample <- function() read_parquet(derived("sample")) %>%
  filter(model_key == "chatgpt_web", labelled) %>%
  select(-any_of("search_used")) %>%
  inner_join(read_parquet(derived("responses_web"), col_select = c("response_id", "search_used", "answer")) %>%
      mutate(answer_chars = str_length(answer)) %>% select(-answer), by = "response_id") %>%
  mutate(execution_id = as.integer(response_id))
