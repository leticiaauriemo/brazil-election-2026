"""
queries/templates.py — prompt generator for the AI voting-advice pilot.

Builds every prompt from profiles/cues.json. The design is a pure-ideology cue
(L) × pure-issue cue (I) factorial, organized into additive modules:

  A — issue-only      (L = none × issue)         : Japan replication + dispersion test
  B — ideology-only   (ideology cue × no issue)  : pure-label baseline
  C — label × issue   (label × issue)            : the causal core (β vs γ); conflict cells
  D — demographic     (personalization ladder)   : demographic AMCE + refusal
  anchors — 9 Neto archetypes (bundled profiles)
  control — bare question (no cue)

Every condition is crossed with cargo ∈ {presidente, dep_federal} and
ask ∈ {open, candidate}. Demographics are NOT crossed into A/B/C — the cues are
kept pure; demographic effects are isolated in Module D.

Usage:
  python queries/templates.py            # print counts + one example per module
  python queries/templates.py --dump all # print every prompt
"""

import json
import argparse
from pathlib import Path
from itertools import product

CUES_FILE = Path(__file__).parent.parent / "profiles" / "cues.json"


def load_cues():
    return json.loads(CUES_FILE.read_text())


def _assemble(parts, closing):
    """Join non-empty sentence parts + the closing question with single spaces."""
    return " ".join([p for p in parts if p] + [closing])


def build_all():
    """Return a list of condition dicts (one per unique prompt, before reps)."""
    c = load_cues()
    cargos = c["cargos"]
    asks = c["asks"]
    ideology = c["ideology_cues"]
    issues = c["issue_cues"]
    issue_sentence = c["issue_sentence"]
    c_labels = c["metadata"]["module_c_labels"]

    rows = []

    def emit(base, cargo_key, ask_key, prompt_parts):
        closing = asks[ask_key].format(cargo=cargos[cargo_key])
        prompt = _assemble(prompt_parts, closing)
        cond_id = "_".join([base["module"]] + [str(v) for v in base["_idparts"]] + [cargo_key, ask_key])
        row = {k: v for k, v in base.items() if not k.startswith("_")}
        row.update({"cargo": cargo_key, "ask": ask_key, "cond_id": cond_id, "prompt": prompt})
        rows.append(row)

    for cargo_key, ask_key in product(cargos, asks):

        # control — bare
        emit({"module": "control", "ideology_cue": None, "issue_cue": None,
              "issue_side": None, "_idparts": ["bare"]}, cargo_key, ask_key, [])

        # Module A — issue-only
        for issue_id, sides in issues.items():
            for side in ("left", "right"):
                txt = issue_sentence.format(stance=sides[side])
                emit({"module": "A", "ideology_cue": None, "issue_cue": issue_id,
                      "issue_side": side, "_idparts": [issue_id, side]},
                     cargo_key, ask_key, [txt])

        # Module B — ideology-only
        for cue_id, cue in ideology.items():
            emit({"module": "B", "ideology_cue": cue_id, "issue_cue": None,
                  "issue_side": None, "_idparts": [cue_id]},
                 cargo_key, ask_key, [cue["text"]])

        # Module C — label × issue
        for label_id in c_labels:
            label = ideology[label_id]
            for issue_id, sides in issues.items():
                for side in ("left", "right"):
                    cell = "conflict" if label["side"] != side else "congruent"
                    txt = issue_sentence.format(stance=sides[side])
                    emit({"module": "C", "ideology_cue": label_id, "issue_cue": issue_id,
                          "issue_side": side, "cell_type": cell,
                          "_idparts": [label_id, issue_id, side]},
                         cargo_key, ask_key, [label["text"], txt])

        # Module D — demographic ladder
        for step in c["demographic_ladder"]:
            if "{race}" in step["prefix"]:
                for race in c["demographic_race_sweep"]:
                    emit({"module": "D", "demo_step": step["id"], "race": race,
                          "ideology_cue": None, "issue_cue": None,
                          "_idparts": [step["id"], race]},
                         cargo_key, ask_key, [step["prefix"].format(race=race)])
            else:
                emit({"module": "D", "demo_step": step["id"], "race": None,
                      "ideology_cue": None, "issue_cue": None,
                      "_idparts": [step["id"]]},
                     cargo_key, ask_key, [step["prefix"]] if step["prefix"] else [])

        # Anchors — 9 Neto archetypes
        for anchor_id, text in c["anchors"].items():
            emit({"module": "anchor", "anchor": anchor_id,
                  "ideology_cue": None, "issue_cue": None,
                  "_idparts": [anchor_id]},
                 cargo_key, ask_key, [text])

    return rows


def summary(rows):
    from collections import Counter
    by_module = Counter(r["module"] for r in rows)
    reps = load_cues()["metadata"]["fixed"]["reps"]
    print(f"Total unique conditions (cargo × ask included): {len(rows)}")
    print(f"Per module: {dict(by_module)}")
    print(f"× {reps} reps × N models. Example: {len(rows)} × {reps} = {len(rows) * reps} prompts/model.\n")
    seen = set()
    for r in rows:
        if r["module"] in seen:
            continue
        seen.add(r["module"])
        print(f"--- {r['module']} | {r['cond_id']} ---\n{r['prompt']}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dump", choices=["all"], default=None)
    args = parser.parse_args()
    rows = build_all()
    if args.dump == "all":
        for r in rows:
            print(f"[{r['module']}] {r['cond_id']}\n  {r['prompt']}\n")
    else:
        summary(rows)
