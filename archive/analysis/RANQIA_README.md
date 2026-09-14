# Add LLM coding to the responses

Run the script below and return **`coding_run/responses_coded.parquet` and `coding_run/manifest.json`**.

The Parquet is the main deliverable: exactly the same rows, in the same order, with every original column preserved and LLM columns appended. It includes all 959,990 original rows. The existing `llm_selected` flag identifies the 103,934 responses to code; do not change that flag or select a new sample.

## 1. Set up

Requires Python 3.10+ and an Anthropic API account. In this folder:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

Configure `ANTHROPIC_API_KEY` using your usual secret-management method. Replace `PROVIDER_MODEL_ID` below with the agreed Anthropic model ID.

## 2. Submit

```bash
python code_responses.py submit --model PROVIDER_MODEL_ID
```

This submits the selected responses in batches. It reads `responses.parquet` and `codebook.json` beside the script, and saves progress in `coding_run/`. Keep the input, script, codebook and model unchanged during the run. Running the same command again skips batches already submitted; it does not intentionally purchase them twice.

## 3. Collect and return

After the provider finishes processing:

```bash
python code_responses.py collect --model PROVIDER_MODEL_ID
```

If results are pending, repeat this command later. Collection retrieves existing work and does not purchase new coding.

Return:

- **`coding_run/responses_coded.parquet`** — the enriched responses.
- **`coding_run/manifest.json`** — identifies the input, judge and run, and reports completion.

Keep the other files in `coding_run/` as the run's checkpoints and audit trail. If any rows fail, return `failed_requests.csv` too so we can resolve them. Do not silently drop or recode failures.

## What is added to each row?

| Columns | Meaning |
|---|---|
| `llm_status` | `succeeded`, `failed`, `pending`, or `not_selected` |
| `llm_error` | Failure or pending explanation, otherwise null |
| `llm_coder`, `llm_codebook_version` | Judge and coding definitions used |
| `llm_refusal_language`, `llm_explicit_endorsement`, `llm_personalized_matching` | Independent response labels |
| `llm_negative_steering`, `llm_procedure_guidance`, `llm_stale_timing` | Other independent response labels |
| `llm_refusal_grounds`, `llm_justification`, `llm_evidence_json` | Grounds, short explanation and exact supporting quotations |
| `llm_entities` | A list of candidates/parties discussed, with stance, recommendation basis, stated affiliation and exact evidence |

An answer discussing three candidates still occupies **one row**. Each item in `llm_entities` has `kind`, `name`, `party`, `stance`, `recommendation_basis` and `evidence`. A successfully coded answer with no entities has an empty list. Uncoded rows have null labels and null entities, not false labels.

The script adds semantic coding only. We handle entity expansion, normalization, model weighting and statistical analysis after the return. `codebook.json` contains the full coding definitions. A timing claim is not automatically a factual error, and a mention is not automatically a recommendation. Human validation is separate from the script's structural checks.

## Optional cost estimate

This is offline and writes nothing. Supply the provider's current **batch** prices in USD per million tokens:

```bash
python code_responses.py estimate --model PROVIDER_MODEL_ID \
  --input-price-per-million INPUT_PRICE \
  --output-price-per-million OUTPUT_PRICE
```

The estimate uses a byte heuristic and assumes 1,000 output tokens per response; it is not a spending cap. Default output limit is 4,096 tokens and batch size is 5,000 responses, also capped by serialized byte size. Answers and prompts are never truncated. Optional `--input` and `--output-dir` override the default paths.

## Interrupted submissions

A timed-out submission may already have reached the provider. If the script reports an uncertain submission, it stops rather than retrying a potentially paid request. Keep the existing `coding_run/` folder and contact the research team with its manifest; do not start a replacement run.

For recovery, identify the accepted provider batch ID. Once it finishes, reconcile its request IDs, then resume submit:

```bash
python code_responses.py reconcile --model PROVIDER_MODEL_ID \
  --batch-index BATCH_INDEX --batch-id PROVIDER_BATCH_ID
```

Collection exits with 0 when all selected responses have valid labels, 2 for completed failures, or 3 while work is pending. `ready_for_analysis` in the manifest is true only when every selected response has a valid result. Exact-quotation checks detect malformed evidence, not all semantic mistakes.
