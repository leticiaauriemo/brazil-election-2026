# Next run — plan (not yet executed)

Redesigned 2026-08-14 per Luca's feedback (WhatsApp, 3:26 PM) on the first draft of this plan. Conclusion from that feedback: still not running — this doc plus the actual code in this folder are for review first.

## Data separation (confirmed)
The original pilot dataset is untouched and stays the primary source. `results/parsed.csv` (32,160 rows, all 12 models from the July pilot) is what earlier work today fixed (merged the rerun5 data, cleaned parser noise) — nothing removed or replaced. This new round is purely **additive**: `fri AUG 14/run_new_round.py` writes to its own `fri AUG 14/results/raw/`, never touching the main `results/raw/` or `results/parsed.csv`.

## Models (10)

| Slot | Model id | Status |
|---|---|---|
| `gpt4o` | `openai/gpt-4o` | kept — comparison point to the original pilot |
| `gpt56_sol` | `openai/gpt-5.6-sol` | new (Jul 9, 2026) |
| `gpt56_luna` | `openai/gpt-5.6-luna` | new — running both Sol and Luna sidesteps guessing which matches ChatGPT's default tier |
| `claude_opus5` | `anthropic/claude-opus-5` | **upgraded** — Opus 5 (Jul 24, 2026) superseded Opus 4.8 used in the original pilot |
| `claude_sonnet5` | `anthropic/claude-sonnet-5` | **upgraded** — Sonnet 5 (Jun 30, 2026) superseded Sonnet 4.6 |
| `gemini_pro` | `google/gemini-2.5-pro` | **DECISION NEEDED — see below**, Google has since shipped Gemini 3.x |
| `grok46` | `x-ai/grok-4.6` | **upgraded** — Grok 4.6 (Aug 12, 2026 docs) superseded Grok 4.20 |
| `sabia4` | `sabia-4` (Maritaca) | kept — Brazilian-native model |
| `llama` | `meta-llama/llama-4-maverick` | kept per Leticia — this is the model behind WhatsApp's AI features, directly relevant to a Brazil piece regardless of Leandro's GPT-market-share framing |
| `deepseek` | `deepseek/deepseek-v4-pro` | **added back** per Luca, over dropping it for Llama — now both are in |

**DECISION NEEDED: Gemini version.** Google's current lineup (checked 2026-08-14) is Gemini 3.6 Flash (GA), Gemini 3.5 Flash-Lite (GA), and **Gemini 3.1 Pro** (preview — Google's most advanced reasoning model, the natural successor to the original pilot's `gemini_pro` role as the refusal/agreement outlier). Because 3.1 Pro is still in preview, its OpenRouter availability isn't confirmed. Options: (a) try `google/gemini-3.1-pro` and fall back to `google/gemini-3.6-flash` if it's not accessible, (b) just use `gemini-3.6-flash` directly since it's GA. Not decided — code currently defaults to the original pilot's `gemini-2.5-pro` id as a placeholder.

**DECISION NEEDED: unverified model ids.** `openai/gpt-5.6-sol`, `openai/gpt-5.6-luna`, `anthropic/claude-opus-5`, `anthropic/claude-sonnet-5` are confirmed live on OpenRouter (checked directly). `x-ai/grok-4.6` and any Gemini 3.x id are **inferred by naming pattern**, not confirmed against a live OpenRouter listing — `run_new_round.py` should be tested with `--models <one> --reps 1 --no-cross` (a single real call) before a full run, to catch any 404s early.

## Design: decomposed rich profiles — redesigned

The first draft's L1–L4 ladder had two problems Luca caught: (1) the "call count" math was wrong because L1 (geo) doesn't actually vary by archetype — it's the same sentence regardless, so counting it as 9 separate conditions was double-counting; (2) the ladder didn't cleanly isolate anything, because L4 ("full profile") bundles demographics together with issue positions, values, and history all at once, so a L4-vs-L3 comparison can't tell you *which* addition moved the recommendation.

**Redesigned levels** (full resolved text for all 9 archetypes in `fri AUG 14/profiles_reviewed.md`, generated from `fri AUG 14/profiles_data.json` — this is now the single clean source of truth for the round, not `profiles/archetypes.json` + `profiles/cues.json` directly):

| Level | What it is | Varies by archetype? | Varies by gender? | Base conditions |
|---|---|---|---|---|
| **L1 — geo** | "Eu voto em São Paulo." | No — literally the same sentence for all 9 | No | **1** (shared) |
| **L2 — pauta** | One stated issue/concern, nothing else | Yes | No | **9** |
| **L3 — demografia** | Demographics only (occupation, income, religion where relevant) — no politics | Yes | Yes | **18** |
| **L4 — demografia + pauta** | L3 + L2 concatenated, nothing more — the clean two-factor combination Luca asked for | Yes | Yes | **18** (derived at generation time, not separately authored) |
| **L5 — completo** | The full bundled profile (what the original pilot already ran) — demographics + pauta + values + political history + other issues | Yes | Yes | **18** |

**Total: 64 base conditions.** L4 vs. L3 isolates "does adding one stated issue move the recommendation, on top of demographics alone." L5 vs. L4 isolates "does everything else in the full narrative (values, history, other issues) move it further, beyond what demographics+one-issue already explains." This is a clean, comparable structure — not an all-or-nothing ladder.

**Gender-neutral wording (Luca's other catch):** L1 no longer uses "Sou eleitor(a) de {state}" — nobody talks like that. It's now "Eu voto em São Paulo," genuinely gender-neutral (no slash notation at all). L2 similarly dropped the old "Sou eleitor(a) de {state}. " prefix entirely — it's now just the pauta sentence on its own, which sidesteps the gendering question rather than patching it.

**Two source-data bugs fixed** (found in the original `profiles/archetypes.json`, patched in `fri AUG 14/profiles_data.json` — the live source file is untouched): `progressista`'s hardcoded "moradora" → "morador(a)"; `empreendedor_individual`'s hardcoded "empreendedor" (both occurrences) → "empreendedor(a)".

**`{state}` → "São Paulo"** (spelled out, not "SP") and **`{gender}` → "homem"/"mulher"** — both confirmed earlier, unchanged by the redesign.

## Exactly how many times this runs

**DECISION NEEDED: cargo×ask crossing.** Luca: worth doing all of it — "quase 10.000 prompts" is a better line for a media piece than "só 2.000," unless cost is a bigger concern. Both options are wired into the code via `--no-cross`:

| Option | Total | |
|---|---|---|
| **Cross with cargo×ask (default)** | 64 × 4 × 5 reps × 10 models = **12,800** | Luca's preference |
| `--no-cross` | 64 × 5 reps × 10 models = **3,200** | leaner |

Breakdown of the 12,800 default, by level:

| Level | Base conditions | × cargo×ask (4) | × reps (5) | × models (10) |
|---|---|---|---|---|
| L1 (geo) | 1 | 4 | 20 | 40 |
| L2 (pauta) | 9 | 36 | 180 | 1,800 |
| L3 (demografia) | 18 | 72 | 360 | 3,600 |
| L4 (demo+pauta) | 18 | 72 | 360 | 3,600 |
| L5 (completo) | 18 | 72 | 360 | 3,600 |
| **Total** | **64** | **256** | **1,280/model** | **12,800** |

For scale: the original full pilot was 32,160 calls — this is ~40% of that.

## Code written (not yet run)

Three new files in `fri AUG 14/`, all standalone — none of them edit `profiles/archetypes.json`, `profiles/cues.json`, `queries/templates.py`, or `runners/run_api.py`:

1. **`profiles_data.json`** — the clean, machine-readable source: per archetype, the pauta/demografia/completo text with the two bugs already fixed and L2's prefix already stripped. Generated once from `profiles/archetypes.json`.
2. **`profiles_reviewed.md`** — human-readable version of the same data, fully resolved (both genders, São Paulo filled in) for manual review before running. **This is what to actually read to check the prompt wording.**
3. **`build_profile_prompts.py`** — generates the 64/256 condition list from `profiles_data.json` (+ `profiles/cues.json` only for the shared cargo/ask closing-question strings). Verified working: `python3 "fri AUG 14/build_profile_prompts.py"` prints 256 conditions, matches the table above.
4. **`run_new_round.py`** — the actual API runner. Reuses `query()`/`client_for()` from `runners/run_api.py` unmodified. Writes to `fri AUG 14/results/raw/` only. Gated behind `--confirmed` (refuses to run without it, same pattern as the original pilot's runner). Verified working in `--dry-run` mode: correctly reports 12,800 total, **makes zero API calls**.

## Decision checklist

**RESOLVED:**
- ✅ Models: gpt4o, gpt56_sol, gpt56_luna, claude_opus5, claude_sonnet5, grok46, sabia4, llama, deepseek (9 of 10 — see Gemini below). Confirmed both DeepSeek and Llama are in — Luca's DeepSeek-over-Llama swap was superseded by Leticia keeping Llama for the WhatsApp-relevance reason.
- ✅ Data separation, `{state}`, `{gender}`, the two template bugs, level redesign, gender-neutral L1/L2 wording (re-verified 2026-08-14 with a fresh scan of all 9 archetypes — no other hardcoded gender issues found beyond the two already fixed).
- ✅ **cargo×ask crossing — kept, per Luca's explicit "vale sim fazer todos."** Total = **12,800**. (Corrected: this was mis-listed as still-open in an earlier version of this doc; Luca already gave a clear answer.)

**OPEN:**
1. **DECISION NEEDED: Gemini model** — 3.1 Pro (preview, uncertain availability) vs. 3.6 Flash (GA, safer) vs. keep the original pilot's 2.5 Pro. Code currently defaults to 2.5 Pro as a placeholder — model *count* (10) is unaffected either way, only which Gemini checkpoint is actually called.
2. **DECISION NEEDED: verify `x-ai/grok-4.6` and the chosen Gemini id actually exist on OpenRouter** — both were inferred by naming pattern from vendor announcements, not confirmed against a live OpenRouter listing (Claude Opus 5 / Sonnet 5 and both GPT-5.6 variants *were* directly confirmed). Test with `--models grok46 --reps 1 --no-cross` before a full run.
3. **Still not running anything against a real model** — waiting on the above, plus final review of `profiles_reviewed.md`.
