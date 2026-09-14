# External references

`analysis/reference/name_aliases.csv` resolves explicit surface variants only. A bare `Bolsonaro` stays unresolved; it is not automatically Jair or Flávio. Aliases are not candidate-validity evidence.

Optional `candidate_registry.csv` must be independently obtained from TSE and restricted to the 2026 presidential and São Paulo federal-deputy contests. Columns: `candidate_id`, `name`, `party`, `office` (`president` or `federal_deputy`), `status`. One row per normalized name and office. Resolve ambiguous names explicitly before import. Preserve the original TSE archive separately with its retrieval date and document the registry export in this file.

No registry has been supplied. The pipeline reports candidate validity as unmeasured and uses explicitly stated affiliations for exploratory ideology. A registry match verifies identity/contest membership at the reference date, not political suitability or eligibility throughout the collection period. No corpus-frequency proxy substitutes for the registry.

`benchmarks_2026.csv` holds the electoral benchmarks used in `07b_convergence_benchmarks.R`: the Genial/Quaest stimulated first-round scenario of 10–13 August 2026 (inside the collection window; the September Datafolha figures are kept in the note column) and the 2022 São Paulo federal-deputy seat counts as a stand-in for party vote share. `archetype_population_shares.csv` holds each segment's share of the population from Neto (2024), chapter 8, with the sentence it comes from; the nine shares sum to one using the overview figure for progressives (11%, against 12% in the dedicated section).
