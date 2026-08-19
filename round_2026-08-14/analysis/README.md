# Exploratory results analysis

This directory contains the reproducible analysis for the 12,800-response
round. The raw GitHub release assets should remain as ZIP archives under
`../results/release_zips/`; the scripts read them directly and never modify
the raw responses.

Run the full pipeline from the repository root:

```powershell
Rscript round_2026-08-14/analysis/run_all.R
```

Generated datasets, tables, and figures are written to
`round_2026-08-14/results/analysis/`, which is ignored by Git. The Beamer
source is `../deck/exploratory_results_expanded.tex`, and the compiled PDF is
`../deck/exploratory_results_expanded.pdf`.

The automated text coding is intentionally descriptive. It distinguishes
observable features such as an explicit refusal, a named political figure,
a party mention, and high-precision single-best-match language. It does not
claim to establish whether a recommendation is factually or normatively
correct.

The pipeline also produces four profile-specific figures for external reporting:
L5 refusal and person-mention rates by archetype, refusal by archetype and
information level, the model-by-archetype L5 refusal matrix, and the matched
L4-minus-L3 issue-priority contrast.

`04_prepare_deck_materials.R` makes the quoted material auditable. It writes
`deck_prompt_examples.csv` with one exact full L5 prompt for each archetype,
`deck_response_quote_audit.csv` with every selected response excerpt and an
exact-match flag, and `profile_prompt_frames.tex` for the Beamer appendix.

The repository retains only the expanded external-audience deck. Earlier
exploratory slide sources and duplicate PDFs are intentionally not kept.
