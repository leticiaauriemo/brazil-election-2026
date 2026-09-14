"""Code a frozen response sample using Anthropic Message Batches.

Inputs: stacked Parquet (source, response_id, prompt, answer, llm_selected), codebook.
Output: original response rows with added LLM columns and nested entities.
Supporting files: raw results, failure ledger and run manifest.

Run estimate without credentials; submit is the only command that purchases coding.
The input is immutable. Statistical outcomes and party resolution belong in R.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from datetime import datetime, timezone

import jsonschema
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

# 1. Define the handoff's identifiers and output columns -------------------------

FLAGS = ["refusal_language", "explicit_endorsement", "personalized_matching",
         "negative_steering", "procedure_guidance", "stale_timing"]
# Nested entities keep every original response in a single row, including answers
# discussing several candidates. Null labels distinguish uncoded from negative.
ENTITY_TYPE = pa.list_(pa.struct([
    pa.field(name, pa.string()) for name in
    ["kind", "name", "party", "stance", "recommendation_basis", "evidence"]
]))
ADDED_SCHEMA = pa.schema([
    pa.field("llm_status", pa.string()), pa.field("llm_error", pa.string()),
    pa.field("llm_coder", pa.string()), pa.field("llm_codebook_version", pa.string()),
    *[pa.field("llm_" + flag, pa.bool_()) for flag in FLAGS],
    pa.field("llm_refusal_grounds", pa.string()), pa.field("llm_justification", pa.string()),
    pa.field("llm_evidence_json", pa.string()), pa.field("llm_entities", ENTITY_TYPE),
])
FAILURE_COLUMNS = ["source", "response_id", "custom_id", "result_type", "detail"]
MAX_BATCH_BYTES = 200_000_000  # Below the provider limit, including JSON overhead.


def write_json(path, value):
    """Replace a checkpoint only after its complete contents reach disk."""
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.flush()
        os.fsync(handle.fileno())
    temporary.replace(path)


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def request_params(row, book, args):
    # JSON encoding keeps the research text distinct from the coding instructions.
    return {
        "model": args.model,
        "max_tokens": args.max_tokens,
        "system": book["system_prompt"],
        "messages": [{"role": "user", "content": json.dumps(
            {"voter_prompt": row.prompt, "assistant_answer": row.answer}, ensure_ascii=False)}],
        "output_config": {"format": {"type": "json_schema", "schema": book["output_schema"]}},
    }


def batch_requests(sample, book, args):
    """Keep batches below both request-count and serialized-size limits."""
    chunk, size = [], 20
    for row in sample.itertuples():
        request = {"custom_id": row.custom_id, "params": request_params(row, book, args)}
        request_size = len(json.dumps(request, ensure_ascii=True).encode("utf-8")) + 2
        if request_size > MAX_BATCH_BYTES:
            raise ValueError(f"Single request exceeds batch size: {row.custom_id}")
        if chunk and (len(chunk) >= args.batch_size or size + request_size > MAX_BATCH_BYTES):
            yield chunk
            chunk, size = [], 20
        chunk.append(request)
        size += request_size
    if chunk:
        yield chunk


# 2. Validate semantic records before they enter the analysis --------------------

def validate_record(data, answer, book):
    jsonschema.validate(data, book["output_schema"])
    for flag in FLAGS:
        quotes = data["evidence"][flag]
        if data[flag] != bool(quotes):
            raise ValueError(f"Evidence inconsistent with {flag}")
        if any(not quote or quote not in answer for quote in quotes):
            raise ValueError(f"Evidence is not an exact answer substring: {flag}")
    if (data["refusal_grounds"] == "none") == data["refusal_language"]:
        raise ValueError("Refusal grounds inconsistent with refusal language")
    seen = set()
    for entity in data["entities"]:
        key = (entity["kind"], entity["name"].casefold(), entity["stance"])
        if key in seen:
            raise ValueError(f"Duplicate entity and stance: {key}")
        seen.add(key)
        if not entity["name"].strip() or not entity["evidence"] or entity["evidence"] not in answer:
            raise ValueError("Entity requires a name and exact answer evidence")
        if entity["kind"] == "party" and entity["party"] is not None:
            raise ValueError("Party records must have null party affiliation")
        recommended = entity["stance"] == "recommended"
        if recommended == (entity["recommendation_basis"] == "none"):
            raise ValueError("Entity stance and recommendation basis disagree")
        if recommended and not data[entity["recommendation_basis"]]:
            raise ValueError("Entity recommendation basis lacks its response flag")
    positive = [entity for entity in data["entities"] if entity["stance"] == "recommended"]
    if bool(positive) != (data["explicit_endorsement"] or data["personalized_matching"]):
        raise ValueError("Positive steering requires a named recommended entity")
    if data["explicit_endorsement"] and not any(e["recommendation_basis"] == "explicit_endorsement" for e in positive):
        raise ValueError("Explicit endorsement requires an explicitly endorsed entity")
    if data["negative_steering"] != any(e["stance"] == "rejected" for e in data["entities"]):
        raise ValueError("Negative steering and rejected entities disagree")


# 3. Submit batches with a checkpoint before and after every paid request --------

def submit_batches(client, sample, book, args, manifest):
    path = args.output_dir / "manifest.json"
    for index, requests in enumerate(batch_requests(sample, book, args)):
        if index < len(manifest["batches"]):
            entry = manifest["batches"][index]
            if entry["status"] == "submitted":
                continue
            raise RuntimeError(
                f"Batch {index} has an uncertain submission. Do not resubmit. "
                "Identify its provider batch ID and use reconcile; see README.")
        entry = {"index": index, "custom_ids": [r["custom_id"] for r in requests],
                 "status": "submitting", "submitted_at": datetime.now(timezone.utc).isoformat()}
        manifest["batches"].append(entry)
        write_json(path, manifest)
        # Automatic retries are disabled in main: a timed-out create may have succeeded.
        try:
            batch = client.messages.batches.create(requests=requests)
        except Exception as error:
            entry["submission_error"] = f"{type(error).__name__}: {error}"
            write_json(path, manifest)
            raise RuntimeError(f"Submission {index} uncertain; reconcile before continuing") from error
        entry.update({"status": "submitted", "batch_id": batch.id})
        write_json(path, manifest)
        print(f"Submitted batch {index}: {batch.id}, {len(requests)} requests", flush=True)
    manifest["all_submitted"] = True
    write_json(path, manifest)


def download_results(client, batch_id, expected, raw_path):
    temporary = raw_path.with_suffix(".jsonl.part")
    found = set()
    with temporary.open("w", encoding="utf-8") as handle:
        for item in client.messages.batches.results(batch_id):
            record = item.model_dump()
            custom_id = record["custom_id"]
            if custom_id not in expected or custom_id in found:
                raise ValueError(f"Unexpected or duplicate result ID in {batch_id}: {custom_id}")
            found.add(custom_id)
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
        handle.flush()
        os.fsync(handle.fileno())
    if found != expected:
        raise ValueError(f"Incomplete download for {batch_id}: missing {len(expected - found)} results")
    temporary.replace(raw_path)


def write_enriched_responses(input_path, output_path, labels, failures):
    """Append coding to the original Arrow batches without changing their rows."""
    source = pq.ParquetFile(input_path)
    collisions = set(source.schema_arrow.names) & set(ADDED_SCHEMA.names)
    if collisions:
        raise ValueError(f"Input already contains output columns: {sorted(collisions)}")
    coded = {(row["source"], row["response_id"]): row for row in labels}
    unsuccessful = {(row["source"], row["response_id"]): row for row in failures}
    schema = pa.schema(list(source.schema_arrow) + list(ADDED_SCHEMA), metadata=source.schema_arrow.metadata)
    temporary = output_path.with_suffix(".parquet.tmp")
    # Streaming preserves input types and ordering without loading the full corpus.
    with pq.ParquetWriter(temporary, schema, compression="zstd") as writer:
        for batch in source.iter_batches(batch_size=4096):
            original = pa.Table.from_batches([batch])
            keys = original.select(["source", "response_id", "llm_selected"]).to_pylist()
            appended = []
            for key in keys:
                row_key = (key["source"], key["response_id"])
                if not key["llm_selected"]:
                    row = {"llm_status": "not_selected"}
                elif row_key in coded:
                    row = {"llm_status": "succeeded", **coded[row_key]}
                else:
                    failure = unsuccessful[row_key]
                    row = {"llm_status": "pending" if failure["result_type"] == "pending" else "failed",
                           "llm_error": failure["result_type"] + ": " + failure["detail"]}
                appended.append(row)
            additions = pa.Table.from_pylist(appended, schema=ADDED_SCHEMA)
            for field in ADDED_SCHEMA:
                original = original.append_column(field, additions[field.name])
            writer.write_table(original)
    temporary.replace(output_path)


# 4. Collect every selected response, including explicit failures and pending work

def collect_batches(client, sample, book, args, manifest):
    lookup = sample.set_index("custom_id").to_dict("index")
    records, seen = [], set()
    for entry in manifest["batches"]:
        if entry["status"] != "submitted":
            continue
        raw_path = args.output_dir / "raw" / f"batch_{entry['index']:05d}.jsonl"
        expected = set(entry["custom_ids"])
        if not raw_path.exists():
            batch = client.messages.batches.retrieve(entry["batch_id"])
            if batch.processing_status != "ended":
                continue
            download_results(client, entry["batch_id"], expected, raw_path)
        batch_records = [json.loads(line) for line in raw_path.read_text().splitlines()]
        ids = [record["custom_id"] for record in batch_records]
        if len(ids) != len(set(ids)) or set(ids) != expected or seen.intersection(ids):
            raise ValueError(f"Invalid cached result coverage in {raw_path}")
        seen.update(ids)
        records.extend(batch_records)

    labels, failures = [], []
    for record in records:
        custom_id = record["custom_id"]
        row = lookup[custom_id]
        key = {"source": row["source"], "response_id": row["response_id"]}
        result = record["result"]
        if result["type"] != "succeeded":
            failures.append({**key, "custom_id": custom_id, "result_type": result["type"],
                             "detail": json.dumps(result, ensure_ascii=False)})
            continue
        try:
            message = result["message"]
            if message["stop_reason"] != "end_turn":
                raise ValueError(f"Incomplete judge output: stop_reason={message['stop_reason']}")
            content = [block["text"] for block in message["content"] if block["type"] == "text"]
            if len(content) != 1:
                raise ValueError("Expected exactly one structured text block")
            data = json.loads(content[0])
            validate_record(data, row["answer"], book)
        except (ValueError, KeyError, TypeError, jsonschema.ValidationError) as error:
            failures.append({**key, "custom_id": custom_id, "result_type": "invalid_output", "detail": str(error)})
            continue
        coder = f"llm_{args.model}"
        labels.append({**key, "llm_coder": coder, "llm_codebook_version": book["version"],
                       **{"llm_" + flag: data[flag] for flag in FLAGS},
                       "llm_refusal_grounds": data["refusal_grounds"],
                       "llm_justification": data["justification"],
                       "llm_evidence_json": json.dumps(data["evidence"], ensure_ascii=False),
                       "llm_entities": data["entities"]})
    for custom_id in sorted(set(lookup) - seen):
        row = lookup[custom_id]
        failures.append({"source": row["source"], "response_id": row["response_id"],
                         "custom_id": custom_id, "result_type": "pending", "detail": "No completed result collected"})
    if len(labels) + len(failures) != len(sample):
        raise ValueError("Collected labels and failure ledger do not cover the selected sample")
    write_enriched_responses(args.input, args.output_dir / "responses_coded.parquet", labels, failures)
    pd.DataFrame(failures, columns=FAILURE_COLUMNS).to_csv(args.output_dir / "failed_requests.csv", index=False)
    pending = sum(failure["result_type"] == "pending" for failure in failures)
    manifest["collection"] = {"selected": len(sample), "valid": len(labels),
                              "failed": len(failures) - pending, "pending": pending,
                              "ready_for_analysis": not failures}
    write_json(args.output_dir / "manifest.json", manifest)
    print(json.dumps(manifest["collection"], indent=2))
    return 3 if pending else 2 if failures else 0


# 5. Read the frozen sample and run the requested stage --------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["estimate", "submit", "collect", "reconcile"])
    parser.add_argument("--input", type=Path, default=Path(__file__).with_name("responses.parquet"))
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).with_name("coding_run"))
    parser.add_argument("--codebook", type=Path, default=Path(__file__).with_name("codebook.json"))
    parser.add_argument("--model", required=True, help="Provider model ID, fixed for the entire run")
    parser.add_argument("--max-tokens", type=int, default=4096)
    parser.add_argument("--batch-size", type=int, default=5000)
    parser.add_argument("--input-price-per-million", type=float)
    parser.add_argument("--output-price-per-million", type=float)
    parser.add_argument("--bytes-per-token", type=float, default=3.0)
    parser.add_argument("--assumed-output-tokens", type=int, default=1000)
    parser.add_argument("--batch-index", type=int, help="Uncertain batch index for reconcile")
    parser.add_argument("--batch-id", help="Provider batch ID for reconcile")
    args = parser.parse_args(argv)
    if not 1 <= args.batch_size <= 100_000 or args.max_tokens <= 0:
        parser.error("batch-size must be 1..100000 and max-tokens positive")
    book = json.loads(args.codebook.read_text())
    jsonschema.Draft202012Validator.check_schema(book["output_schema"])
    collisions = set(pq.read_schema(args.input).names) & set(ADDED_SCHEMA.names)
    if collisions:
        raise ValueError(f"Input already contains output columns: {sorted(collisions)}")
    columns = ["source", "response_id", "prompt", "answer", "llm_selected"]
    frame = pq.read_table(args.input, columns=["source", "response_id", "llm_selected"]).to_pandas()
    if str(frame.llm_selected.dtype) not in ("bool", "boolean") or frame.llm_selected.isna().any():
        raise ValueError("llm_selected must be nonmissing boolean")
    if frame[["source", "response_id"]].isna().any().any() or frame.duplicated(["source", "response_id"]).any():
        raise ValueError("source + response_id must uniquely identify every input row")
    # Read answer text only for selected rows; the full web corpus stays on disk.
    sample = pq.read_table(args.input, columns=columns[:-1],
                           filters=[("llm_selected", "=", True)]).to_pandas()
    del frame
    if sample.empty:
        raise ValueError("No selected responses")
    for column in columns[:-1]:
        if not sample[column].map(lambda value: isinstance(value, str) and bool(value.strip())).all():
            raise ValueError(f"Selected {column} values must be nonempty strings")
    sample = sample.sort_values(["source", "response_id"]).reset_index(drop=True)
    sample["custom_id"] = [hashlib.sha256(json.dumps([r.source, r.response_id]).encode()).hexdigest()
                           for r in sample.itertuples()]

    if args.command == "estimate":
        if args.input_price_per_million is None or args.output_price_per_million is None:
            parser.error("estimate requires explicit current batch input/output prices per million tokens")
        if min(args.input_price_per_million, args.output_price_per_million) < 0 or args.bytes_per_token <= 0 or not 0 < args.assumed_output_tokens <= args.max_tokens:
            parser.error("Prices must be nonnegative, bytes-per-token positive, output assumption 1..max-tokens")
        byte_count = sum(len(json.dumps(request_params(row, book, args), ensure_ascii=False).encode())
                         for row in sample.itertuples())
        input_tokens = math.ceil(byte_count / args.bytes_per_token)
        estimated_cost = (input_tokens * args.input_price_per_million + len(sample) * args.assumed_output_tokens * args.output_price_per_million) / 1e6
        print(json.dumps({"model": args.model, "selected": len(sample),
                          "by_source": sample.source.value_counts().to_dict(), "estimated_input_tokens": input_tokens,
                          "assumed_output_tokens_per_response": args.assumed_output_tokens,
                          "approximate_cost_usd": estimated_cost, "bytes_per_token": args.bytes_per_token,
                          "caveat": "Offline byte heuristic, not provider token counting or a spending cap. No cache discount assumed."}, indent=2))
        return 0

    fingerprint = {"input_sha256": file_hash(args.input), "codebook_sha256": file_hash(args.codebook),
                   "script_sha256": file_hash(Path(__file__)), "model": args.model,
                   "max_tokens": args.max_tokens, "batch_size": args.batch_size}
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "raw").mkdir(exist_ok=True)
    manifest_path = args.output_dir / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        if manifest["fingerprint"] != fingerprint:
            raise ValueError("Input, codebook, script, model, or batch settings changed; use a new output directory")
    elif args.command == "submit":
        manifest = {"fingerprint": fingerprint, "codebook_version": book["version"],
                    "created_utc": datetime.now(timezone.utc).isoformat(), "selected": len(sample),
                    "all_submitted": False, "batches": []}
        write_json(manifest_path, manifest)
        sample[["source", "response_id", "custom_id"]].to_csv(args.output_dir / "selected_ids.csv", index=False)
        write_json(args.output_dir / "codebook_used.json", book)
    else:
        raise ValueError("No submitted run found; collect/reconcile cannot create a run")

    import anthropic
    client = anthropic.Anthropic(max_retries=0)
    if args.command == "submit":
        submit_batches(client, sample, book, args, manifest)
        return 0
    if args.command == "collect":
        return collect_batches(client, sample, book, args, manifest)
    if args.batch_index is None or not args.batch_id:
        parser.error("reconcile requires --batch-index and --batch-id")
    entry = manifest["batches"][args.batch_index]
    if entry["status"] != "submitting":
        raise ValueError("Only an uncertain submission can be reconciled")
    if any(batch.get("batch_id") == args.batch_id for batch in manifest["batches"]):
        raise ValueError("Provider batch ID already belongs to this run")
    batch = client.messages.batches.retrieve(args.batch_id)
    if batch.processing_status != "ended":
        raise ValueError("Wait until the provider batch ends so its full request IDs can be verified")
    download_results(client, args.batch_id, set(entry["custom_ids"]),
                     args.output_dir / "raw" / f"batch_{entry['index']:05d}.jsonl")
    entry.update({"status": "submitted", "batch_id": args.batch_id, "reconciled": True})
    write_json(manifest_path, manifest)
    print("Reconciled verified request IDs. Run submit again to continue remaining batches.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
