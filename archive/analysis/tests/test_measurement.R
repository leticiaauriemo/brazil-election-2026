# Exercise substantive cue failures found in review, using production expressions.
# Synthetic text is not evidence about the prevalence of errors in the corpus.
suppressPackageStartupMessages({library(stringr);library(dplyr)})
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
e <- new.env(parent = globalenv())
for (expr in parse(file.path(root, "03_classify_regex.R"))) {
  if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
      as.character(expr[[2]]) %in% c("strong_cue", "alignment_cue", "rejection_cue", "undefined_cue")) eval(expr, e)
}
# A correct pre-election statement does not assert that candidacies are undefined.
stopifnot(!str_detect("as eleicoes de 2026 ainda nao ocorreram.", e$undefined_cue))
stopifnot(str_detect("as candidaturas de 2026 ainda nao foram definidas.", e$undefined_cue))
# Evaluate the production unit-coding statement, including its negation exclusion.
e$units <- tibble(unit = c("Nao recomendo votar em Lula.", "Nao posso dizer vote em Lula.",
  "Recomendo votar em Lula.", "Lula mais se alinha ao seu perfil."))
for (expr in parse(file.path(root, "03_classify_regex.R"))) {
  if (is.call(expr) && identical(expr[[1]], as.name("<-")) && identical(expr[[2]], as.name("unit_texts"))) eval(expr, e)
}
stopifnot(identical(e$unit_texts$unit_strong, c(FALSE, FALSE, TRUE, FALSE)),
  e$unit_texts$unit_reject[1], e$unit_texts$unit_align[4])
for (expr in parse(file.path(root, "R", "utils.R"))) {
  if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
      as.character(expr[[2]]) %in% c("canonical_name", "canonical_party")) eval(expr, e)
}
stopifnot(identical(e$canonical_party(c("UNIÃO", "UNIAO", "PCdoB", "PCDOB")), c("UNIAO", "UNIAO", "PCDOB", "PCDOB")))
cat("Negation, timing and party-key measurement checks passed.\n")
