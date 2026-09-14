# Field-coverage explorations

Does an answer that lists presidential candidates list the whole field? Resolucao TSE 23.755/2026
forbids favouring or disfavouring any candidate; a listing that leaves some registered candidates
out is a soft form of it. Scripts source the deputy explorations' setup and write here.

| Script | Question | Figures |
|---|---|---|
| `01_field_coverage.R` | Among answers that name registered candidates without steering: how many of the 13 they cover, which ones, and whether the omitted set depends on the voter's side. | `01_field_coverage_by_model`, `01_candidate_coverage`, `01_candidate_coverage_by_side` |

The register is the thirteen presidential candidacies in `current/reference/benchmarks_2026.csv`.
