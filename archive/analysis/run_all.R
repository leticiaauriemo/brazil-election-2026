# Runs the pipeline end to end. Each stage writes to output/ and reads only what
# the preceding stages wrote, so any single stage can be rerun on its own after
# an edit. Paid semantic coding is a separate explicit step using the portable
# package. Sample IDs and human labels are preserved on reruns.

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]), winslash = "/", mustWork = TRUE)
analysis_dir <- dirname(script_path)

scripts <- c(
  "01_clean_api.R", "01_clean_ranqia.R", "02_stack_responses.R",
  "04_select_coding_sample.R", "03_classify_regex.R", "04_select_coding_sample.R",
  "03b_normalize_coding.R", "06_coding_agreement.R",
  "07_summarize.R", "08_regressions.R", "09_figures.R", "10_deck_materials.R",
  "11_prepare_handoff.R"
)

rscript_bin <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")

for (script in scripts) {
  message("\n=== ", script, " ===")
  status <- system2(rscript_bin, shQuote(file.path(analysis_dir, script)))
  if (!identical(status, 0L)) stop(script, " failed with status ", status)
}

status <- system2("python3", shQuote(file.path(analysis_dir, "12_package_handoff.py")))
if (!identical(status, 0L)) stop("Handoff archive verification failed")
message("\nAnalysis complete; no paid coding submitted.")
