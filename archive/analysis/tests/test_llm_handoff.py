"""Verify the portable coding handoff with small synthetic responses.

No provider calls: batch transport is mocked, and the CLI estimate is offline.
Run: python -m unittest discover -s analysis/tests -p 'test_llm_handoff.py' -v
"""

# 1. Load the standalone script and a small, fully specified sample --------------

import importlib.util
import json
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

SCRIPT = Path(__file__).resolve().parents[1] / "05_classify_llm.py"
BOOK_PATH = SCRIPT.with_name("codebook.json")
spec = importlib.util.spec_from_file_location("coder", SCRIPT)
coder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coder)
BOOK = json.loads(BOOK_PATH.read_text())
ANSWER = "Vote em Lula. Ele combina com suas prioridades. Consulte as propostas."


def valid_data():
    data = {flag: False for flag in coder.FLAGS}
    data.update({"explicit_endorsement": True, "personalized_matching": True,
                 "procedure_guidance": True, "refusal_grounds": "none",
                 "justification": "Endorses and matches Lula, with procedural guidance.",
                 "evidence": {flag: [] for flag in coder.FLAGS},
                 "entities": [{"kind": "person", "name": "Lula", "party": None,
                               "stance": "recommended", "recommendation_basis": "explicit_endorsement",
                               "evidence": "Vote em Lula."}]})
    data["evidence"].update({"explicit_endorsement": ["Vote em Lula."],
                             "personalized_matching": ["Ele combina com suas prioridades."],
                             "procedure_guidance": ["Consulte as propostas."]})
    return data


def success(custom_id, data=None, stop_reason="end_turn"):
    return {"custom_id": custom_id, "result": {"type": "succeeded", "message": {
        "stop_reason": stop_reason, "content": [{"type": "text", "text": json.dumps(data or valid_data())}]}}}


def transport(records):
    client = Mock()
    client.messages.batches.retrieve.return_value = SimpleNamespace(processing_status="ended")
    client.messages.batches.results.side_effect = lambda batch_id: [
        SimpleNamespace(model_dump=lambda record=record: record) for record in records[batch_id]]
    return client


# 2. Verify resumability, coverage, schema enforcement, and substantive evidence -

class HandoffTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        (self.directory / "raw").mkdir()
        self.args = SimpleNamespace(output_dir=self.directory, model="test-judge", max_tokens=4096, batch_size=1)
        self.sample = pd.DataFrame([
            {"source": "api", "response_id": "a", "prompt": "Em quem votar?", "answer": ANSWER, "custom_id": "id_a"},
            {"source": "chatgpt_web", "response_id": "b", "prompt": "Em quem votar?", "answer": ANSWER, "custom_id": "id_b"}])
        self.args.input = self.directory / "input.parquet"
        # Keep the original order, an uncoded row, extra metadata and typed nulls.
        self.original = pd.concat([
            self.sample.drop(columns="custom_id").assign(llm_selected=True),
            pd.DataFrame([{"source": "api", "response_id": "uncoded", "prompt": "Other prompt",
                           "answer": None, "llm_selected": False}])], ignore_index=True)
        self.original["original_number"] = pd.Series([3, None, 1], dtype="Int64")
        self.original = self.original.iloc[[1, 2, 0]].reset_index(drop=True)
        self.original.to_parquet(self.args.input, index=False)
        self.manifest = {"batches": []}

    def tearDown(self):
        self.temporary.cleanup()

    def submitted(self):
        self.manifest["batches"] = [
            {"index": 0, "status": "submitted", "batch_id": "batch_a", "custom_ids": ["id_a"]},
            {"index": 1, "status": "submitted", "batch_id": "batch_b", "custom_ids": ["id_b"]}]

    def test_success_round_trip_and_cached_collection(self):
        self.submitted()
        client = transport({"batch_a": [success("id_a")], "batch_b": [success("id_b")]})
        self.assertEqual(coder.collect_batches(client, self.sample, BOOK, self.args, self.manifest), 0)
        result = pq.read_table(self.directory / "responses_coded.parquet")
        original = pq.read_table(self.args.input)
        self.assertTrue(result.select(original.column_names).equals(original))
        self.assertEqual(result.num_rows, 3)
        labels = result.to_pandas()
        selected = labels[labels.llm_selected]
        self.assertTrue(selected.llm_personalized_matching.all())
        self.assertEqual(selected.llm_status.tolist(), ["succeeded", "succeeded"])
        uncoded = labels[~labels.llm_selected].iloc[0]
        self.assertEqual(uncoded.llm_status, "not_selected")
        self.assertIsNone(uncoded.llm_entities)
        self.assertTrue(pd.isna(uncoded.llm_explicit_endorsement))
        self.assertEqual(len(selected.iloc[0].llm_entities), 1)
        self.assertFalse((self.directory / "entities_llm.parquet").exists())
        self.assertFalse((self.directory / "coding_llm.parquet").exists())
        client.reset_mock()
        self.assertEqual(coder.collect_batches(client, self.sample, BOOK, self.args, self.manifest), 0)
        client.messages.batches.retrieve.assert_not_called()
        client.messages.batches.results.assert_not_called()

    def test_multiple_entities_stay_inside_one_response(self):
        self.submitted()
        self.sample.loc[0, "answer"] += " Considere Zema."
        original = self.original.copy()
        original.loc[original.response_id == "a", "answer"] = self.sample.loc[0, "answer"]
        original.to_parquet(self.args.input, index=False)
        data = valid_data()
        data["entities"].append({"kind": "person", "name": "Zema", "party": None,
                                 "stance": "recommended", "recommendation_basis": "personalized_matching",
                                 "evidence": "Considere Zema."})
        client = transport({"batch_a": [success("id_a", data)], "batch_b": [success("id_b")]})
        self.assertEqual(coder.collect_batches(client, self.sample, BOOK, self.args, self.manifest), 0)
        result = pd.read_parquet(self.directory / "responses_coded.parquet")
        self.assertEqual(len(result), len(original))
        row = result[result.response_id == "a"].iloc[0]
        self.assertEqual([entity["name"] for entity in row.llm_entities], ["Lula", "Zema"])

    def test_success_without_entities_is_empty_list_not_uncoded(self):
        self.submitted()
        data = {flag: False for flag in coder.FLAGS}
        data.update(refusal_grounds="none", justification="No coded guidance.",
                    evidence={flag: [] for flag in coder.FLAGS}, entities=[])
        client = transport({"batch_a": [success("id_a", data)], "batch_b": [success("id_b", data)]})
        self.assertEqual(coder.collect_batches(client, self.sample, BOOK, self.args, self.manifest), 0)
        result = pq.read_table(self.directory / "responses_coded.parquet").to_pylist()
        for row in result:
            self.assertEqual(row["llm_entities"], [] if row["llm_selected"] else None)

    def test_pending_never_silently_disappears(self):
        self.submitted()
        client = transport({})
        client.messages.batches.retrieve.return_value.processing_status = "in_progress"
        self.assertEqual(coder.collect_batches(client, self.sample, BOOK, self.args, self.manifest), 3)
        self.assertEqual(self.manifest["collection"], {"selected": 2, "valid": 0, "failed": 0,
                                                     "pending": 2, "ready_for_analysis": False})
        self.assertEqual(len(pd.read_csv(self.directory / "failed_requests.csv")), 2)
        result = pq.read_table(self.directory / "responses_coded.parquet")
        self.assertEqual(result.num_rows, 3)
        self.assertEqual(result["llm_status"].to_pylist(), ["pending", "not_selected", "pending"])
        self.assertEqual(result["llm_entities"].null_count, 3)


    def test_provider_failure_and_truncation_are_explicit(self):
        self.submitted()
        failed = {"custom_id": "id_a", "result": {"type": "errored", "error": {"type": "invalid_request"}}}
        client = transport({"batch_a": [failed], "batch_b": [success("id_b", stop_reason="max_tokens")]})
        self.assertEqual(coder.collect_batches(client, self.sample, BOOK, self.args, self.manifest), 2)
        failures = pd.read_csv(self.directory / "failed_requests.csv")
        self.assertEqual(set(failures.result_type), {"errored", "invalid_output"})
        self.assertEqual(self.manifest["collection"]["failed"], 2)
        result = pq.read_table(self.directory / "responses_coded.parquet")
        self.assertEqual(result["llm_status"].to_pylist(), ["failed", "not_selected", "failed"])
        self.assertEqual(result["llm_explicit_endorsement"].null_count, 3)


    def test_incomplete_download_is_not_a_finished_cache(self):
        self.submitted()
        client = transport({"batch_a": []})
        with self.assertRaisesRegex(ValueError, "Incomplete download"):
            coder.collect_batches(client, self.sample, BOOK, self.args, self.manifest)
        self.assertFalse((self.directory / "raw" / "batch_00000.jsonl").exists())

    def test_duplicate_or_unexpected_provider_ids_fail(self):
        client = transport({"batch_a": [success("wrong_id")]})
        with self.assertRaisesRegex(ValueError, "Unexpected or duplicate"):
            coder.download_results(client, "batch_a", {"id_a"}, self.directory / "raw" / "one.jsonl")
        client = transport({"batch_a": [success("id_a"), success("id_a")]})
        with self.assertRaisesRegex(ValueError, "Unexpected or duplicate"):
            coder.download_results(client, "batch_a", {"id_a"}, self.directory / "raw" / "one.jsonl")

    def test_submit_saves_progress_and_stops_uncertain_retry(self):
        client = Mock()
        client.messages.batches.create.side_effect = [SimpleNamespace(id="batch_a"), TimeoutError("transport timeout")]
        with self.assertRaisesRegex(RuntimeError, "uncertain"):
            coder.submit_batches(client, self.sample, BOOK, self.args, self.manifest)
        saved = json.loads((self.directory / "manifest.json").read_text())
        self.assertEqual(saved["batches"][0]["batch_id"], "batch_a")
        self.assertEqual(saved["batches"][1]["status"], "submitting")
        client.reset_mock()
        with self.assertRaisesRegex(RuntimeError, "uncertain submission"):
            coder.submit_batches(client, self.sample, BOOK, self.args, saved)
        client.messages.batches.create.assert_not_called()

    def test_resume_skips_submitted_batches(self):
        self.manifest["batches"] = [{"index": 0, "status": "submitted", "batch_id": "batch_a", "custom_ids": ["id_a"]}]
        client = Mock()
        client.messages.batches.create.return_value.id = "batch_b"
        coder.submit_batches(client, self.sample, BOOK, self.args, self.manifest)
        client.messages.batches.create.assert_called_once()
        self.assertEqual(client.messages.batches.create.call_args.kwargs["requests"][0]["custom_id"], "id_b")
        self.assertTrue(self.manifest["all_submitted"])

    def test_true_flags_need_exact_evidence_and_entities(self):
        coder.validate_record(valid_data(), ANSWER, BOOK)
        data = valid_data()
        data["evidence"]["explicit_endorsement"] = ["Invented quotation"]
        with self.assertRaisesRegex(ValueError, "exact answer substring"):
            coder.validate_record(data, ANSWER, BOOK)
        data = valid_data()
        data["entities"] = []
        with self.assertRaisesRegex(ValueError, "named recommended entity"):
            coder.validate_record(data, ANSWER, BOOK)
        data = valid_data()
        data["entities"][0]["stance"] = "rejected"
        with self.assertRaisesRegex(ValueError, "stance and recommendation basis"):
            coder.validate_record(data, ANSWER, BOOK)
        data = valid_data()
        data["refusal_language"] = "false"
        with self.assertRaises(coder.jsonschema.ValidationError):
            coder.validate_record(data, ANSWER, BOOK)

    def test_cli_freezes_input_and_model_before_provider_calls(self):
        fixture = self.directory / "input.parquet"
        self.sample.drop(columns="custom_id").assign(llm_selected=True).to_parquet(fixture, index=False)
        output = self.directory / "run"
        args = ["submit", "--input", str(fixture), "--output-dir", str(output), "--model", "test-judge"]
        api = Mock()
        api.Anthropic.return_value.messages.batches.create.return_value.id = "batch_a"
        with patch.dict(sys.modules, {"anthropic": api}):
            self.assertEqual(coder.main(args), 0)
            api.Anthropic.assert_called_once_with(max_retries=0)
            api.reset_mock()
            with self.assertRaisesRegex(ValueError, "settings changed"):
                coder.main(args[:-1] + ["another-judge"])
            api.Anthropic.assert_not_called()
            self.sample.drop(columns="custom_id").assign(llm_selected=False).iloc[:1].to_parquet(fixture, index=False)
            with self.assertRaisesRegex(ValueError, "No selected"):
                coder.main(args)

    def test_cli_reconciles_uncertain_batch_only_with_matching_ids(self):
        fixture = self.directory / "input.parquet"
        self.sample.drop(columns="custom_id").assign(llm_selected=True).to_parquet(fixture, index=False)
        output = self.directory / "run"
        args = ["submit", "--input", str(fixture), "--output-dir", str(output), "--model", "test-judge"]
        api = Mock()
        api.Anthropic.return_value.messages.batches.create.side_effect = TimeoutError("uncertain")
        with patch.dict(sys.modules, {"anthropic": api}):
            with self.assertRaisesRegex(RuntimeError, "uncertain"):
                coder.main(args)
        manifest = json.loads((output / "manifest.json").read_text())
        ids = manifest["batches"][0]["custom_ids"]
        client = transport({"recovered": [success(custom_id) for custom_id in ids]})
        api.Anthropic.return_value = client
        with patch.dict(sys.modules, {"anthropic": api}):
            self.assertEqual(coder.main(["reconcile", *args[1:], "--batch-index", "0", "--batch-id", "recovered"]), 0)
        manifest = json.loads((output / "manifest.json").read_text())
        self.assertEqual(manifest["batches"][0]["batch_id"], "recovered")
        self.assertEqual(manifest["batches"][0]["status"], "submitted")

    def test_estimate_runs_offline_from_arbitrary_working_directory(self):
        fixture = self.directory / "responses.parquet"
        self.sample.drop(columns="custom_id").assign(llm_selected=[True, False]).to_parquet(fixture, index=False)
        package = self.directory / "handoff"
        package.mkdir()
        shutil.copyfile(SCRIPT, package / "code_responses.py")
        shutil.copyfile(BOOK_PATH, package / "codebook.json")
        shutil.copyfile(fixture, package / "responses.parquet")
        result = subprocess.run([sys.executable, str(package / "code_responses.py"), "estimate", "--model", "test-judge",
                                 "--input-price-per-million", "1", "--output-price-per-million", "5"],
                                cwd=self.directory, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        estimate = json.loads(result.stdout)
        self.assertEqual(estimate["selected"], 1)
        self.assertFalse((package / "coding_run").exists())
        self.assertGreater(estimate["approximate_cost_usd"], 0)


if __name__ == "__main__":
    unittest.main()
