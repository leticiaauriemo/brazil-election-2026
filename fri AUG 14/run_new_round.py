"""
fri AUG 14/run_new_round.py — runs the decomposed-profile round against the API.

Writes raw JSON to fri AUG 14/results/raw/ — a SEPARATE directory from the main
results/raw/, so this can never mix into or overwrite the original 32,160-response
pilot dataset. Reuses query()/client_for() from run_api.py -- a copy of
runners/run_api.py kept in this folder so the whole round is self-contained. If the
live runners/run_api.py gets fixed again upstream (e.g. another max_tokens tweak),
re-copy it here manually -- this is a snapshot, not a live link.

Model list for this round (10) — see fri AUG 14/next_run_plan.md for the reasoning
behind each pick. All 10 model ids are now confirmed live on OpenRouter directly
(checked 2026-08-14): gpt-5.6-sol, gpt-5.6-luna, claude-opus-5, claude-sonnet-5,
gemini-3.1-pro-preview, and grok-4.6 were all verified against their live OpenRouter
pages, not just inferred by naming pattern.

Usage:
  export OPENROUTER_API_KEY=...   MARITACA_API_KEY=...
  python3 "fri AUG 14/run_new_round.py" --dry-run                # count only
  python3 "fri AUG 14/run_new_round.py" --confirmed               # full run, crossed
  python3 "fri AUG 14/run_new_round.py" --confirmed --no-cross    # smaller, 2,560 prompts
  python3 "fri AUG 14/run_new_round.py" --confirmed --models gpt4o gpt56_sol
"""

import sys
import time
import json
import argparse
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))

from run_api import query, client_for, PILOT_MODELS  # noqa: E402
from build_profile_prompts import build_all  # noqa: E402

RESULTS_DIR = HERE / "results" / "raw"

# 10 models for this round — reuses run_api.PILOT_MODELS entries where they already
# exist (gpt4o, sabia4, llama, deepseek), adds the new GPT-5.6 variants, and upgrades
# Claude/Gemini/Grok to their latest releases as of 2026-08-14 (Claude Opus 5 /
# Sonnet 5, Gemini 3.1 Pro Preview, Grok 4.6). All six new ids confirmed live on
# OpenRouter directly, not just inferred from vendor announcements.
ROUND_MODELS = {
    "gpt4o":         PILOT_MODELS["gpt4o"],
    "gpt56_sol":      {"id": "openai/gpt-5.6-sol", "provider": "openrouter"},
    "gpt56_luna":     {"id": "openai/gpt-5.6-luna", "provider": "openrouter"},
    "claude_opus5":   {"id": "anthropic/claude-opus-5", "provider": "openrouter"},
    "claude_sonnet5": {"id": "anthropic/claude-sonnet-5", "provider": "openrouter"},
    "gemini_pro":     {"id": "google/gemini-3.1-pro-preview", "provider": "openrouter"},
    "grok46":         {"id": "x-ai/grok-4.6", "provider": "openrouter"},
    "sabia4":         PILOT_MODELS["sabia4"],
    "llama":          PILOT_MODELS["llama"],
    "deepseek":       PILOT_MODELS["deepseek"],
}


def run(models, reps, temperature, cross_cargo_ask, dry_run):
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    rows = build_all(cross_cargo_ask=cross_cargo_ask)
    total = len(rows) * len(models) * reps
    print(f"{len(rows)} conditions x {len(models)} models x {reps} reps = {total} prompts "
          f"(temp={temperature}, cross_cargo_ask={cross_cargo_ask})\n")
    if dry_run:
        print("dry run -- no API calls made.")
        return

    done = skipped = 0
    for model_key in models:
        model = ROUND_MODELS[model_key]
        for r in rows:
            for rep in range(reps):
                out_file = RESULTS_DIR / f"{r['cond_id']}_{model_key}_{rep}.json"
                if out_file.exists():
                    skipped += 1
                    continue
                content, did_search, citations, error = query(model, r["prompt"], temperature, search=True)
                out = {**r, "model": model_key, "rep": rep, "temperature": temperature,
                       "channel": "api", "response": content,
                       "did_search": did_search, "citations": citations, "error": error}
                out_file.write_text(json.dumps(out, ensure_ascii=False, indent=2))
                done += 1
                flag = " search" if did_search else ""
                err = f"  ERROR: {error[:60]}" if error else ""
                print(f"  {r['cond_id']} | {model_key} | rep {rep}{flag}  ({len(content)} chars){err}")
                time.sleep(0.4)
    print(f"\nDone. {done} new, {skipped} skipped. Raw in {RESULTS_DIR}/")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--confirmed", action="store_true",
                         help="Acknowledge the model list and design were confirmed before running.")
    parser.add_argument("--models", nargs="+", default=list(ROUND_MODELS), choices=list(ROUND_MODELS))
    parser.add_argument("--reps", type=int, default=5)
    parser.add_argument("--temperature", type=float, default=1.0)
    parser.add_argument("--no-cross", action="store_true", help="skip cargo x ask crossing")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.confirmed and not args.dry_run:
        sys.exit(
            "\nMODEL SET / DESIGN NOT CONFIRMED.\n"
            f"Proposed models: {list(ROUND_MODELS)}\n"
            "Review fri AUG 14/next_run_plan.md and fri AUG 14/profiles_reviewed.md first.\n"
            "Then re-run with --confirmed (or use --dry-run to just count).\n"
        )

    run(models=args.models, reps=args.reps, temperature=args.temperature,
        cross_cargo_ask=not args.no_cross, dry_run=args.dry_run)
