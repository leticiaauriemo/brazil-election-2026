# Fri Aug 14 — method/data audit

## Findings (before fixes)
1. **GPT-5 and DeepSeek severely undersampled in `results/parsed.csv`.** GPT-5 had only 136/2680 target rows (~5%), DeepSeek 1581/2680 (~59%). Reruns from Jul 14–16 (`results/rerun5_gpt5.txt`, `results/rerun5_deepseek.txt`) had written the missing raw JSON to `results/raw/`, but `parsed.csv` was never regenerated afterward. This meant the deck's headline "GPT-5 refuses 87.5%" was based on a small leftover sample.
2. **Refusal classifier can't see past its own boilerplate match.** `analysis/parse.py::extract_party()` returns immediately once it matches a refusal phrase, without checking for a party mentioned afterward. Checked against real data: 63% of all Python-flagged refusals still contain a party sigla somewhere in the text — 0% for GPT-5/Gemini Pro (genuine hard refusers) vs. 76–99% for Claude Sonnet, Sabiá 4, Grok, Gemini Flash. Spot-checked 3 Claude Sonnet cases: genuine refusals that neutrally survey multiple candidates, not disguised recommendations — but the pipeline has no way to systematically tell "true refusal with neutral mentions" apart from "soft refusal that still recommends" (the pattern the deck's own methodology, p.16, says should be coded as party+disclaimer). Luca already built audit infrastructure for this (`analysis/05_parser_audit.R` → `results/analysis/audit_*.csv`, ~443 sampled rows) but no review appears to have been done yet.
3. **Minor parser noise:** ~3 rows where the `Partido: <TOKEN>` fallback grabbed a non-party all-caps token — "MS"/"MG" (Brazilian state abbreviations following a candidate's name) and "LGBT" (from "direitos das mulheres e LGBT").
4. Uncommitted `max_tokens` fix in `runners/run_api.py` (1024→8000) — this is what actually fixed the reasoning-model empty-response problem, but was never committed on its own (only the resulting data was, in `15f04af`).

## Fixes applied today
- **Merged the reruns**: re-ran `python3 analysis/parse.py` against the now-complete `results/raw/` (32,160 JSON files, confirmed 2,680 per model × 12 models). This regenerated `results/parsed.csv` from 28,474 → 32,160 rows. GPT-5 and DeepSeek now both at full 2,680/2,680 coverage.
- **Parser noise**: added a `KNOWN_SIGLA` whitelist in `analysis/parse.py::extract_party()` so the `Partido: <token>` fallback only accepts a recognized party sigla instead of any bare all-caps token. Verified MS/MG/LGBT false positives are gone (0 rows) in the regenerated `parsed.csv`; real party extraction unaffected (falls through to the existing substring/whole-response fallbacks).
- Did **not** touch the `run_api.py` max_tokens fix or commit anything — still uncommitted, pending a decision.

## Manual review of the refusal/parser ambiguity (item "b")
R isn't installed on this machine, so I replicated `00_clean_results.R`'s `refused2` logic and the `05_parser_audit.R` sampling logic in Python against the freshly regenerated `parsed.csv`, and read through samples by hand.

**Pinpointed the actual bug — it's narrower than my first guess.** It's not that `refused2` steps on `has_party` (it doesn't: the downstream `case_when` in `06_paper_results.R`/`07_intermediation_audit.R` checks `has_party` before `refused2`, so a row with both set correctly counts as a party recommendation). The real bug is upstream, in `analysis/parse.py::extract_party()`: the moment one of the 17 narrow refusal phrases matches, the function **returns immediately** — `party_rec` is *never even attempted* for that row, regardless of what appears later in the response. Confirmed on the full merged data:
- 5,308 usable rows have `refused_parse=True` → `party_rec` guaranteed `None` (100%, by construction).
- Of those, **52.4% (2,781 rows) still mention a party sigla somewhere in the response** — text that was never scanned. Wildly uneven by model: Grok 98.7%, Claude Sonnet 80.0%, Sabiá 4 79.8%, Gemini Flash 76.4%, Mistral 75.0%, Llama 57.9%, GPT-4o 55.1%, DeepSeek 53.8%, Claude Opus 35.7%, GPT-5 21.9%, Gemini Pro 7.4%.

**But — read ~15 of these by hand, and most are genuine refusals, not disguised recommendations.** Typical pattern: the model declines with boilerplate ("não é meu papel indicar...", "não posso e não vou recomendar...") and then gives a *neutral survey* mentioning multiple parties/candidates for context — not a single clear pick. So the current refusal-rate numbers are probably in the right neighborhood, but the pipeline has **no way to tell "hard refusal with neutral survey" apart from "soft refusal that still leans/recommends"** — exactly the ambiguity the deck's own methodology (p.16) and its race-effect caveat (p.49) already flag as needing human review. A blind fix (just removing the early return and grabbing whatever sigla appears first) would likely trade this problem for a worse one — false-positive "recommendations" attributed from neutral multi-candidate surveys.

**Other categories checked out fine, not bugs:**
- `no_party_not_refused` sample: mostly the model naming a *person* (e.g., "Samara Martins", "Lula") without a party sigla — already a known, documented limitation (`parse.py`'s own docstring: candidate/person extraction is "intentionally minimal for the pilot").
- `parser_edge` (has party, no ζ score): all 20 rows are `PRTB` — a real minor party just missing from `profiles/party_scales.json`'s Zucco-Power mapping, not parser noise. Separate, low-priority, easy to fix if wanted.
- `empty_or_error`: fully explained by `claude_fable` being 404/unavailable (already excluded downstream via `usable`).

## Still open
- The refused_parse early-return issue (2,781 ambiguous rows) needs a real decision: either (a) leave current refusal-rate estimates as approximately valid pending Andy's methodological sign-off, or (b) do a scaled reclassification (e.g., LLM-judge pass) on the ambiguous subset to separate hard refusals from soft ones that still lean.
- `results/parsed_slim.csv` and `results/log_*.txt` (June 22) still look like dead artifacts from an earlier pipeline version — untouched, not blocking anything.
- Nothing has been committed to git yet.
