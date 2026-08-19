script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]), winslash = "/", mustWork = TRUE)
analysis_dir <- dirname(script_path)

scripts <- c(
  "00_build_dataset.R",
  "01_classify_responses.R",
  "02_summarize_results.R",
  "03_make_figures.R",
  "04_prepare_deck_materials.R"
)

for (script in scripts) {
  message("\n=== ", script, " ===")
  rscript_bin <- shortPathName(file.path(R.home("bin"), "Rscript.exe"))
  status <- system2(
    rscript_bin,
    shQuote(file.path(analysis_dir, script))
  )
  if (!identical(status, 0L)) stop(script, " failed with status ", status)
}

message("\nAnalysis complete.")
