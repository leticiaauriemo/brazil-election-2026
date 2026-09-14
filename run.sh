#!/bin/sh
# Rebuilds everything from the raw inputs under data/. About 15 minutes.
set -e
cd "$(dirname "$0")"
Rscript 01_clean_api.R
Rscript 02_clean_web.R
Rscript 03_labels.R
Rscript 04_regex.R
Rscript 05_results.R
Rscript 06_figures.R
