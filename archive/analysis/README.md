# Analysis of AI voting advice

The pipeline compares the same constructed Portuguese prompts across ten API configurations and the ChatGPT web surface. Project framing and current decisions live in the vault, linked from the workspace `notes/` folder. Raw collection records remain read-only.

## Run

```bash
Rscript analysis/run_all.R
```

This runs only local processing. It never submits paid LLM requests. R packages: arrow, dplyr, ggplot2, jsonlite, purrr, readr, stringi, stringr, tidyr, scales. The standalone judge has its own `requirements.txt`.

The frozen coding IDs and human annotation sheets are preserved on reruns. The portable handoff is also immutable once created: move an old handoff aside before deliberately preparing a new version. The scripts stop on missing or inconsistent inputs; they do not replace a requested LLM coder with regex.

| Script | Purpose |
|---|---|
| `01_clean_api.R` | Archives to response table; compares coverage/prompts against the independent design inventory |
| `01_clean_ranqia.R` | Prompt crosswalk, browser cleanup, explicit capture-failure flags, citations/search metadata |
| `02_stack_responses.R` | Append API and web responses with unique source/response keys and prompt-cell identifiers |
| `04_select_coding_sample.R` | Preserve/freeze LLM IDs, sampling metadata, disjoint calibration and validation sheets |
| `03_classify_regex.R` | Provisional cue coding on that same frozen sample; never a validated semantic outcome |
| `03b_normalize_coding.R` | Import completed judge returns; common identity/party normalization and response outcomes |
| `06_coding_agreement.R` | Model-specific agreement and held-out, sampling-weighted human error estimates |
| `07_summarize.R` | Model-first rates, profile/office/wording breakdowns, candidate distributions, web repetition diagnostics |
| `07b_convergence_benchmarks.R` | Concentration of recommended options within and across models; party shares against the Zucco–Power scale by profile side; recommendation shares next to `reference/benchmarks_2026.csv` (Genial/Quaest August 2026; 2022 São Paulo seats) |
| `reference/archetype_population_shares.csv` | Neto (2024) segment sizes used to weight the nine profiles in the benchmark comparison; equal weights are the comparison series |
| `07c_web.R` | Consumer-surface exhibits: web vs OpenAI API ladder, within-prompt stability of web advice, web top party by profile vs API, cited domains by advice status (from `data/ranqia/raw/citations.parquet`) |
| `08_regressions.R` | Explicit matched mean differences; equal-model pooled effects |
| `09_figures.R` | Candidate exhibits with neutral, denominator-specific captions; final blog selection remains open |
| `10_deck_materials.R` | Exact archived prompt/excerpt provenance; excerpts illustrate responses, not their frequency |
| `10b_examples.R` | Ten traced exchanges (prompt, question, answer, codes) chosen deterministically per behaviour; `examples.csv` and `examples.tex` |
| `11_prepare_handoff.R` | Full combined processed Parquet with selected rows marked; standalone coder and codebook |
| `12_package_handoff.py` | Standard-library checksums and verified ZIP of the handoff |

04 runs before 03 to establish IDs and again afterward to establish hand samples. Only missing sheets are created. Existing calibration and validation annotations remain untouched.

## Sampling and weighting

The existing frozen sample contains 103,934 rows: 12,783 API and 91,151 web. API responses were eligible when nonempty and provider-finished; web rows were sampled up to 100 per prompt/date from the original capture eligibility frame. Short captures admitted by revised cleaning remain outside this frozen frame and are separately listed for inspection. They are not silently assigned a sampling probability they never had.

Within a prompt, average observed collection dates equally; within a model, average the specified prompt grid equally. A pooled statistic is then the simple average of model-specific quantities. Each model/configuration receives one weight, independent of repetitions or willingness to advise. Named model lists accompany pooled results. Conditional quantities remain undefined for models without relevant recommendations; tables list which models have defined quantities rather than silently changing the pool.

These are averages over designed prompts, not population rates for Brazilian voters, market-share-weighted exposure, or estimates for a random population of models. L3/L4/L5 have more bodies than L1/L2, so an all-prompt rate weights those levels according to the explicit 64-body inventory. Level-specific tables and matched comparisons avoid confusing that weighting with an equal-level average.

The main differences are within model: issue added to biography (L4−L3), demographics added to issue (L4−L2, averaging gender variants first), attitudes/identities added (L5−L4), office, ask wording, and gender. L2 and L3 are different branches, not successive additions. L1 is one shared baseline, not nine independent controls. Difference tables report descriptive effects, with archetype heterogeneity separately; no p-values assume independent web executions or a random sample of voters.

Web exhibits summarize one estimate per prompt, with no date comparisons. Within-day candidate-set agreement estimates the probability that two distinct advice-giving draws produce the same set; empty sets and cells with fewer than two eligible draws do not count as agreement. Eligible within-day agreement estimates are averaged equally for each prompt. Histograms show estimated prompt probabilities, including finite coding-sample noise.

## Measurement and return contract

`codebook.json` defines independent refusal, endorsement, personal matching, negative steering, procedural-help, and timing-claim flags, with exact answer evidence. Timing claims are not automatically factual errors. Political mentions are not recommendations. Recommendation form (one person/several/party only) is distinct from endorsement strength.

Use `RANQIA_README.md` for the portable judge. Ranqia's final package delivers `results/responses_coded_final.parquet`, `final_manifest.json` and `failed_requests_final.csv`; place the three files under `data/ranqia/llm/<run>/` (current run: `final_2026-09-09`, GPT-5 mini through Ranqia's OpenAI adaptation of the runner). The Parquet preserves every original row and column, appends `llm_*` labels/status, and stores entities as a nested list within each row. The importer checks the frozen input hash and codebook version, full row/selection coverage, and that failed rows match the ledger and manifest counts; it then expands the entity lists internally. Failed rows (3,493 of 103,934) stay in the sample with `label_status = "missing"` and NA outcomes: rates in 07–08 are computed over labelled responses, `not_coded` reports the missing share, and `*_lower`/`*_upper` outcomes set missing labels to 0/1 for worst-case bounds. The regex coder is never used to fill missing labels; it is the secondary instrument in the agreement table only.

```bash
BRAZIL_CODER=llm_gpt-5-mini-2025-08-07 Rscript analysis/03b_normalize_coding.R
BRAZIL_CODER=llm_gpt-5-mini-2025-08-07 Rscript analysis/06_coding_agreement.R
BRAZIL_CODER=llm_gpt-5-mini-2025-08-07 Rscript analysis/07_summarize.R
BRAZIL_CODER=llm_gpt-5-mini-2025-08-07 Rscript analysis/07b_convergence_benchmarks.R
BRAZIL_CODER=llm_gpt-5-mini-2025-08-07 Rscript analysis/07c_web.R
BRAZIL_CODER=llm_gpt-5-mini-2025-08-07 Rscript analysis/08_regressions.R
BRAZIL_CODER=llm_gpt-5-mini-2025-08-07 Rscript analysis/09_figures.R
BRAZIL_CODER=llm_gpt-5-mini-2025-08-07 Rscript analysis/10_deck_materials.R
BRAZIL_CODER=llm_gpt-5-mini-2025-08-07 Rscript analysis/10b_examples.R
cd paper/outline && Rscript make_tables.R && tectonic outline.tex   # results outline (MacTeX absent; tectonic)
```

`reference/name_aliases.csv` is a versioned explicit text crosswalk. No corpus modal affiliation is used. `data/reference/candidate_registry.csv` is optional external ground truth, with columns `candidate_id,name,party,office,status`, unique normalized name/office, restricted to the relevant 2026 contests. Until supplied, candidate validity is unmeasured. Stated affiliations support exploratory party-scale summaries, not factual certification. Registry name/office matching is not candidate issue congruence or a claim about legal eligibility at all collection dates.

Zucco–Power and Bolognesi are separate scales with normalized party keys. Missing coverage stays missing. No historical vote-share slope is interpreted as recommendation quality or identification of a reasoning mechanism.

## Outputs and verification

Current exhibits and statistical tables are under `output/reviewed/<coder>/`. `output/tables/` contains current collection QC, coding diagnostics, frozen sampling IDs, annotation sheets and quote audits. `output/derived/` contains current intermediate data. Superseded pipelines, decks and results are removed. The complete sendable package is `output/ranqia_handoff/`; no credentials belong in it.

See `VALIDATION.md` for calibration and independent annotation. An empty or partial sheet cannot produce publication-ready error estimates. Regex exhibits remain provisional, and semantic outputs also require human validation.

```bash
Rscript analysis/tests/test_measurement.R
Rscript analysis/tests/test_results.R
Rscript analysis/tests/test_coder_integration.R
Rscript analysis/tests/test_validation.R
python -m unittest discover -s analysis/tests -p 'test_llm_handoff.py' -v
```

Tests cover substantive negation/timing failures, party keys, deliberately unequal cell/model counts, undefined conditional outcomes, shared baselines, and offline/mocked judge transport. They do not establish semantic accuracy or verify live provider compatibility. Human validation remains separate from structural checks.
