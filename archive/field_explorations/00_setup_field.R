# Shared settings for the field-coverage explorations: the deputy explorations' setup,
# with outputs redirected here.
this_file <- normalizePath(sub(
  "^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
))
source(file.path(dirname(this_file), "..", "deputy_explorations", "00_setup_deputy.R"))
here <- dirname(this_file)
