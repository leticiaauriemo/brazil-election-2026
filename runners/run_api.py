"""
runners/run_api.py — run the pilot prompts against the models via OpenRouter.

Saves one raw JSON per (condition, model, rep) to results/raw/. Skips files that
already exist, so it's safe to stop/resume. temp = 1.0 (from cues.json). Web
search is enabled via OpenRouter's :online suffix (Sabiá-4 runs without it — it's
on the Maritaca API, not OpenRouter); did_search = whether any citations came back.

  ┌──────────────────────────────────────────────────────────────────────────┐
  │  MODEL SET IS NOT CONFIRMED. Do not run blind.                            │
  │  The PILOT_MODELS list below is a PROPOSAL. Before running (and before     │
  │  spending credits), CONFIRM THE MODEL LIST WITH LETICIA. Then pass         │
  │  --confirmed to acknowledge. Without that flag the script refuses to run.  │
  └──────────────────────────────────────────────────────────────────────────┘

Usage (after confirming models with Leticia):
  export OPENROUTER_API_KEY=...   # and MARITACA_API_KEY=... if running Sabiá-4
  python runners/run_api.py --confirmed                       # full pilot
  python runners/run_api.py --confirmed --models gpt4o        # one model
  python runners/run_api.py --confirmed --dry-run             # count only, no calls
"""

import os
import sys
import json
import time
import argparse
from pathlib import Path

from openai import OpenAI

sys.path.insert(0, str(Path(__file__).parent.parent / "queries"))
from templates import build_all, load_cues  # noqa: E402

RESULTS_DIR = Path(__file__).parent.parent / "results" / "raw"

# ── PROPOSED pilot model set — CONFIRM WITH LETICIA BEFORE RUNNING ────────────
# ids are OpenRouter ids (port from brazil-politics-eval/models.py); Sabiá-4 is
# on the Maritaca API and gets its own client.
PILOT_MODELS = {
    "gpt4o":        {"id": "openai/gpt-4o",                         "provider": "openrouter"},
    "gpt5":         {"id": "openai/gpt-5.5-pro-20260423",           "provider": "openrouter"},
    "claude_sonnet":{"id": "anthropic/claude-sonnet-4.6",           "provider": "openrouter"},
    "claude_opus":  {"id": "anthropic/claude-opus-4.8-20260528",    "provider": "openrouter"},
    "gemini_flash": {"id": "google/gemini-2.5-flash",               "provider": "openrouter"},
    "grok":         {"id": "x-ai/grok-4.3-20260430",               "provider": "openrouter"},
    "mistral":      {"id": "mistralai/mistral-medium-3.5-20260430", "provider": "openrouter"},
    "sabia4":       {"id": "sabia-4",                               "provider": "maritaca",
                     "base_url": "https://chat.maritaca.ai/api", "api_key_env": "MARITACA_API_KEY"},
}
# GPT-5 included despite high refusal in exp 1 — refusal is itself an outcome here.
# Llama not available on OpenRouter. Gemini Pro only has image variants; Flash kept.
# Verify all OpenRouter IDs at openrouter.ai/models before running.

_clients = {}


def client_for(model):
    prov = model["provider"]
    if prov == "openrouter":
        if "openrouter" not in _clients:
            _clients["openrouter"] = OpenAI(
                base_url="https://openrouter.ai/api/v1",
                api_key=os.environ.get("OPENROUTER_API_KEY"),
            )
        return _clients["openrouter"]
    if prov == "maritaca":
        key = "maritaca"
        if key not in _clients:
            _clients[key] = OpenAI(
                base_url=model["base_url"],
                api_key=os.environ.get(model.get("api_key_env", "MARITACA_API_KEY")),
            )
        return _clients[key]
    raise ValueError(f"unknown provider {prov}")


def query(model, prompt, temperature, search):
    """Return (content, did_search, citations, error)."""
    model_id = model["id"]
    if search and model["provider"] == "openrouter":
        model_id = model_id + ":online"  # OpenRouter web search
    try:
        resp = client_for(model).chat.completions.create(
            model=model_id,
            messages=[{"role": "user", "content": prompt}],
            temperature=temperature,
            max_tokens=1024,
        )
        msg = resp.choices[0].message
        content = msg.content or "ERROR: empty response"
        annotations = getattr(msg, "annotations", None) or []
        citations = [
            {"title": getattr(a.url_citation, "title", None), "url": a.url_citation.url}
            for a in annotations
            if getattr(a, "type", "") == "url_citation" and hasattr(a, "url_citation")
        ]
        return content, len(citations) > 0, citations, None
    except Exception as e:
        return f"ERROR: {e}", False, [], str(e)


def run(models, reps, temperature, search, dry_run):
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    rows = build_all()
    total = len(rows) * len(models) * reps
    print(f"{len(rows)} conditions × {len(models)} models × {reps} reps = {total} prompts "
          f"(temp={temperature}, search={search})
")
    if dry_run:
        print("dry run — no API calls made.")
        return

    done = skipped = 0
    for model_key in models:
        model = PILOT_MODELS[model_key]
        for r in rows:
            for rep in range(reps):
                out_file = RESULTS_DIR / f"{r['cond_id']}_{model_key}_{rep}.json"
                if out_file.exists():
                    skipped += 1
                    continue
                content, did_search, citations, error = query(model, r["prompt"], temperature, search)
                out = {**r, "model": model_key, "rep": rep, "temperature": temperature,
                       "channel": "api", "response": content,
                       "did_search": did_search, "citations": citations, "error": error,
                       "party_rec": None, "candidate_rec": None, "zeta": None,
                       "refused": None, "refusal_text": None}
                out_file.write_text(json.dumps(out, ensure_ascii=False, indent=2))
                done += 1
                flag = " 🔍" if did_search else ""
                err = f"  ERROR: {error[:60]}" if error else ""
                print(f"  {r['cond_id']} | {model_key} | rep {rep}{flag}  ({len(content)} chars){err}")
                time.sleep(0.4)
    print(f"
Done. {done} new, {skipped} skipped. Raw in {RESULTS_DIR}/")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--confirmed", action="store_true",
                        help="Acknowledge that the model list was confirmed with Leticia.")
    parser.add_argument("--models", nargs="+", default=list(PILOT_MODELS),
                        choices=list(PILOT_MODELS))
    parser.add_argument("--reps", type=int, default=None, help="default: cues.json metadata.fixed.reps")
    parser.add_argument("--temperature", type=float, default=None, help="default: cues.json (1.0)")
    parser.add_argument("--no-search", action="store_true", help="disable :online web search")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.confirmed and not args.dry_run:
        sys.exit(
            "
MODEL SET NOT CONFIRMED.
"
            "The PILOT_MODELS list is a proposal — confirm it with Leticia before running.
"
            f"Proposed: {list(PILOT_MODELS)}
"
            "Then re-run with --confirmed (or use --dry-run to just count).
"
        )

    fixed = load_cues()["metadata"]["fixed"]
    run(models=args.models,
        reps=args.reps if args.reps is not None else fixed["reps"],
        temperature=args.temperature if args.temperature is not None else fixed["temperature"],
        search=not args.no_search,
        dry_run=args.dry_run)
