# Analysis workflow

Run every script from the repository root. The scripts are numbered in execution order.

~~~powershell
Rscript analysis/00_clean_results.R
Rscript analysis/01_qc_coverage.R
Rscript analysis/02_descriptives.R
Rscript analysis/03_module_c_effects.R
Rscript analysis/04_module_a_dispersion.R
Rscript analysis/05_parser_audit.R
Rscript analysis/06_paper_results.R
Rscript analysis/07_intermediation_audit.R
~~~

00_clean_results.R reads results/parsed.csv and creates the derived
results/analysis/clean_results.csv. This large intermediate file is ignored by Git and
can always be regenerated. Compact tables and figures are versioned under:

- results/analysis/: quality control, descriptive tables, and parser-audit samples;
- results/paper/: paper-oriented estimates and figures;
- results/intermediation/: final deck estimates and figures.

The principal R packages are tidyverse, sandwich, lmtest, broom, and scales.
