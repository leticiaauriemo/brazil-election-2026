# Shared settings for the blog pipeline: packages, paths, design labels, helpers.
# Sourced by every numbered script. Paths resolve from this file's location, so
# scripts run from any working directory with Rscript.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(readr)
  library(jsonlite)
  library(ggplot2)
})

here <- dirname(normalizePath(sub(
  "^--file=", "",
  grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
)))
# Inputs live under data/, copied unchanged from the deliveries: the API round (one ZIP
# per model and the 256 handoff prompts), Ranqia's ChatGPT-web export, and Ranqia's
# GPT-5 mini labels. data/ and output/ are gitignored; see README for provenance.
api_zip_dir <- file.path(here, "data", "api", "release_zips")
handoff_path <- file.path(here, "reference", "prompts_2026-08-14.json")
web_raw_dir <- file.path(here, "data", "web")
labels_path <- file.path(here, "data", "labels", "responses_coded_final.parquet")
reference <- function(name) file.path(here, "reference", name)
derived <- function(name) file.path(here, "output", "derived", paste0(name, ".parquet"))
write_table <- function(x, name) {
  write_csv(x, file.path(here, "output", "tables", paste0(name, ".csv")), na = "")
}
read_table <- function(name) {
  read_csv(file.path(here, "output", "tables", paste0(name, ".csv")), show_col_types = FALSE)
}

# Design labels. Levels are ordered for the reader: what the voter reveals,
# from nothing to attitudes.
model_levels <- c(
  "gpt4o", "gpt56_luna", "gpt56_sol", "claude_sonnet5", "claude_opus5", "gemini_pro",
  "deepseek_v4_pro", "grok46", "llama_maverick", "sabia4", "chatgpt_web"
)
model_labels <- c(
  gpt4o = "GPT-4o", gpt56_luna = "GPT-5.6 Luna", gpt56_sol = "GPT-5.6 Sol",
  claude_sonnet5 = "Claude Sonnet 5", claude_opus5 = "Claude Opus 5",
  gemini_pro = "Gemini 3.1 Pro", deepseek_v4_pro = "DeepSeek V4 Pro",
  grok46 = "Grok 4.6", llama_maverick = "Llama 4 Maverick",
  sabia4 = "Sabiá 4", chatgpt_web = "ChatGPT (web)"
)
level_order <- c("L1", "L3", "L2", "L4", "L5")
level_labels <- c(
  L1 = "Nothing", L3 = "Biography", L2 = "Issue",
  L4 = "Biography + issue", L5 = "+ Attitudes"
)
archetype_levels <- c(
  "militante_esquerda", "progressista", "classes_d_e", "liberal_social", "empreendedor_individual",
  "conservador_cristao", "agro", "empresario", "extrema_direita"
)
archetype_labels <- c(
  militante_esquerda = "Left activist", progressista = "Progressive",
  classes_d_e = "State-dependent", liberal_social = "Social liberal",
  empreendedor_individual = "Solo entrepreneur",
  conservador_cristao = "Christian conservative", agro = "Agribusiness",
  empresario = "Business owner", extrema_direita = "Far right"
)
office_labels <- c(president = "President", federal_deputy = "Federal deputy, SP")
side_labels <- c(
  militante_esquerda = "Left profiles", progressista = "Left profiles",
  classes_d_e = "Left profiles", liberal_social = "Centre profiles",
  empreendedor_individual = "Centre profiles", conservador_cristao = "Right profiles",
  agro = "Right profiles", empresario = "Right profiles", extrema_direita = "Right profiles"
)
side_order <- c("Left profiles", "Centre profiles", "Right profiles")

# Text keys. The semantic coder keeps the answer's surface form ("**Lula (PT)**", "PL-SP",
# "Partido Liberal (PL)"); markdown, a trailing party tag and a state suffix are formatting.
canonical_name <- function(x) {
  x <- x %>%
    str_remove_all("\\*\\*|__|`") %>%
    str_remove("\\s*\\([^()]*\\)\\s*$")
  str_squish(str_to_lower(stringi::stri_trans_general(x, "Latin-ASCII")))
}
canonical_party <- function(x) {
  key <- str_to_upper(str_squish(stringi::stri_trans_general(
    str_remove_all(x, "\\*\\*|__|`"), "Latin-ASCII"
  )))
  acronym <- str_match(key, "\\(([A-Z]{2,13})\\)")[, 2]
  key <- coalesce(acronym, str_remove(key, "\\s*\\([^()]*\\)\\s*$")) %>%
    str_remove("\\s*[-/]\\s*[A-Z]{2}$")
  recode(key,
    "PC DO B" = "PCDOB", "PARTIDO DOS TRABALHADORES" = "PT", "PARTIDO LIBERAL" = "PL",
    "PARTIDO SOCIALISMO E LIBERDADE" = "PSOL", "UNIAO BRASIL" = "UNIAO",
    "PARTIDO NOVO" = "NOVO", "REDE SUSTENTABILIDADE" = "REDE",
    "PARTIDO MISSAO" = "MISSAO", "MISSAO/MBL" = "MISSAO",
    "PROGRESSISTAS" = "PP", "PARTIDO PROGRESSISTAS" = "PP", "PODE" = "PODEMOS",
    "PARTIDO PODEMOS" = "PODEMOS", "PARTIDO SOCIAL DEMOCRATICO" = "PSD",
    "PARTIDO COMUNISTA DO BRASIL" = "PCDOB",
    "MOVIMENTO DEMOCRATICO BRASILEIRO" = "MDB",
    "PARTIDO SOCIALISTA BRASILEIRO" = "PSB",
    "PARTIDO DEMOCRATICO TRABALHISTA" = "PDT",
    "PARTIDO VERDE" = "PV",
    "PARTIDO DA SOCIAL DEMOCRACIA BRASILEIRA" = "PSDB",
    "UNIDADE POPULAR" = "UP", "UP - UNIDADE POPULAR" = "UP",
    "DEMOCRACIA CRISTA" = "DC",
    "PARTIDO REPUBLICANOS" = "REPUBLICANOS"
  )
}

# Figures: publication style, no titles and no captions; the post supplies the text. The
# base theme is set globally so a plot's own theme() calls (rotated labels) are kept.
palette <- c(
  navy = "#17324D", teal = "#2A9D8F", gold = "#E9C46A",
  coral = "#E76F51", grey = "#7A8793", ink = "#202B33"
)
theme_set(
  theme_minimal(base_size = 11) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_blank(),
      legend.position = "bottom",
      legend.title = element_blank(),
      strip.text = element_text(face = "bold", color = palette[["navy"]])
    )
)
save_figure <- function(name, plot, width, height) {
  for (ext in c("png", "pdf")) {
    ggsave(file.path(here, "output", "figures", paste0(name, ".", ext)), plot,
      width = width, height = height, dpi = 180, bg = "white"
    )
  }
}
