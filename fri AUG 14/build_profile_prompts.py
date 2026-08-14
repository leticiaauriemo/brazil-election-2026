"""
fri AUG 14/build_profile_prompts.py — prompt generator for the decomposed-profile round.

Everything this script needs lives in this folder (copied from the live repo so the
whole round is self-contained): profiles_data.json (the reviewed, cleaned single
source of truth for this round -- NOT profiles/archetypes.json or the live "anchors"
in profiles/cues.json) and cues.json (a copy of profiles/cues.json), used only for
the cargo/ask closing-question strings shared with the rest of the pilot, not
archetype content. If profiles/cues.json changes upstream, re-copy it here manually --
this is a snapshot, not a live link.

Levels (see fri AUG 14/profiles_reviewed.md for the full resolved text):
  L1 — geo only, SHARED across all 9 archetypes, no gender (1 base condition)
  L2 — pauta (one stated issue) only, per archetype, no gender (9 base conditions)
  L3 — demografia only, per archetype, x2 gender (18 base conditions)
  L4 — demografia + pauta, per archetype, x2 gender, DERIVED (demografia + " " + pauta)
  L5 — completo (full bundled profile), per archetype, x2 gender (18 base conditions)

Every level is crossed with cargo in {presidente, dep_federal} x ask in {open, candidate}
(same convention as the rest of the pilot) -- 64 base conditions x 4 = 256 unique prompts.

Usage:
  python3 "fri AUG 14/build_profile_prompts.py"             # print summary + one example per level
  python3 "fri AUG 14/build_profile_prompts.py" --dump all  # print every prompt
"""

import json
import argparse
from pathlib import Path
from itertools import product

HERE = Path(__file__).parent
PROFILES_FILE = HERE / "profiles_data.json"
CUES_FILE = HERE / "cues.json"

GENDERS = ["homem", "mulher"]


def _resolve_gendered(text, gender, age, state):
    text = text.replace("{gender}", gender).replace("{age}", str(age)).replace("{state}", state)
    if gender == "homem":
        return text.replace("(a)", "").replace("(ã)", "")
    return text.replace("(a)", "a").replace("(ã)", "ã")


def load_profiles():
    return json.loads(PROFILES_FILE.read_text(encoding="utf-8"))


def load_cues():
    return json.loads(CUES_FILE.read_text(encoding="utf-8"))


def build_all(cross_cargo_ask=True, state="São Paulo"):
    """Return a list of condition dicts (one per unique prompt, before reps)."""
    profiles = load_profiles()
    cues = load_cues()
    cargos = cues["cargos"]
    asks = cues["asks"]

    cargo_ask_pairs = list(product(cargos, asks)) if cross_cargo_ask else [("presidente", "open")]

    rows = []

    def emit(module, archetype, level, gender, body_text, cargo_key, ask_key):
        closing = asks[ask_key].format(cargo=cargos[cargo_key])
        prompt = f"{body_text} {closing}" if body_text else closing
        parts = [module, archetype or "shared", level]
        if gender:
            parts.append(gender)
        parts += [cargo_key, ask_key]
        cond_id = "_".join(parts)
        rows.append({
            "module": module, "archetype": archetype, "level": level, "gender": gender,
            "cargo": cargo_key, "ask": ask_key, "cond_id": cond_id, "prompt": prompt,
        })

    for cargo_key, ask_key in cargo_ask_pairs:
        # L1 — geo, shared across archetypes, no gender
        l1_text = profiles["shared_l1"].replace("{state}", state)
        emit("profile", None, "L1_geo", None, l1_text, cargo_key, ask_key)

        for aid, a in profiles["archetypes"].items():
            # L2 — pauta only, no gender
            emit("profile", aid, "L2_pauta", None, a["pauta"], cargo_key, ask_key)

            for gender in GENDERS:
                demografia = _resolve_gendered(a["demografia"], gender, a["age"], state)
                completo = _resolve_gendered(a["completo"], gender, a["age"], state)

                # L3 — demografia only
                emit("profile", aid, "L3_demografia", gender, demografia, cargo_key, ask_key)

                # L4 — demografia + pauta (derived)
                emit("profile", aid, "L4_demografia_pauta", gender,
                     f"{demografia} {a['pauta']}", cargo_key, ask_key)

                # L5 — completo
                emit("profile", aid, "L5_completo", gender, completo, cargo_key, ask_key)

    return rows


def summary(rows, reps):
    from collections import Counter
    by_level = Counter(r["level"] for r in rows)
    print(f"Total unique conditions: {len(rows)}")
    print(f"Per level: {dict(by_level)}")
    print(f"x {reps} reps x N models. Example: {len(rows)} x {reps} = {len(rows) * reps} prompts/model.\n")
    seen = set()
    for r in rows:
        if r["level"] in seen:
            continue
        seen.add(r["level"])
        print(f"--- {r['level']} | {r['cond_id']} ---\n{r['prompt']}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dump", choices=["all"], default=None)
    parser.add_argument("--no-cross", action="store_true", help="skip cargo x ask crossing (4x smaller)")
    parser.add_argument("--reps", type=int, default=5)
    args = parser.parse_args()

    rows = build_all(cross_cargo_ask=not args.no_cross)
    if args.dump == "all":
        for r in rows:
            print(f"[{r['level']}] {r['cond_id']}\n  {r['prompt']}\n")
    else:
        summary(rows, args.reps)
