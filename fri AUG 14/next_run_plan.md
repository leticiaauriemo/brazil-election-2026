# Next run — plan (not yet executed)

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
| `llama` | `meta-llama/llama-4-maverick` | kept — this is the model behind WhatsApp's AI features, directly relevant to a Brazil piece regardless of the GPT-market-share framing |
| `deepseek` | `deepseek/deepseek-v4-pro` | **added back** — both DeepSeek and Llama are in, rather than choosing one over the other |

**RESOLVED — Gemini version and all model ids (checked 2026-08-14 via each model's live OpenRouter page directly, not just search snippets):**

| id | Confirmed live? | Notes |
|---|---|---|
| `openai/gpt-5.6-sol` | ✅ | |
| `openai/gpt-5.6-luna` | ✅ | |
| `anthropic/claude-opus-5` | ✅ | |
| `anthropic/claude-sonnet-5` | ✅ | |
| `x-ai/grok-4.6` | ✅ | $2/$6 per M tokens |
| `google/gemini-3.1-pro-preview` | ✅ | **note the exact slug needs `-preview`** — `google/gemini-3.1-pro` alone does not exist. Chosen over 3.6 Flash because it's the frontier reasoning model, the natural successor to the original pilot's `gemini_pro` role as the refusal/agreement outlier |

All six now hardcoded into `run_new_round.py`'s `ROUND_MODELS` — no more placeholders.

## Design: decomposed rich profiles — redesigned

The first draft's L1–L4 ladder had two problems: (1) the "call count" math was wrong because L1 (geo) doesn't actually vary by archetype — it's the same sentence regardless, so counting it as 9 separate conditions was double-counting; (2) the ladder didn't cleanly isolate anything, because L4 ("full profile") bundles demographics together with issue positions, values, and history all at once, so a L4-vs-L3 comparison can't tell you *which* addition moved the recommendation.

**Redesigned levels** (full resolved text for all 9 archetypes in `fri AUG 14/profiles_reviewed.md`, generated from `fri AUG 14/profiles_data.json` — this is now the single clean source of truth for the round, not `profiles/archetypes.json` + `profiles/cues.json` directly):

| Level | What it is | Varies by archetype? | Varies by gender? | Base conditions |
|---|---|---|---|---|
| **L1 — geo** | "Eu voto em São Paulo." | No — literally the same sentence for all 9 | No | **1** (shared) |
| **L2 — pauta** | One stated issue/concern, nothing else | Yes | No | **9** |
| **L3 — demografia** | Demographics only (occupation, income, religion where relevant) — no politics | Yes | Yes | **18** |
| **L4 — demografia + pauta** | L3 + L2 concatenated, nothing more — the clean two-factor combination  | Yes | Yes | **18** (derived at generation time, not separately authored) |
| **L5 — completo** | The full bundled profile (what the original pilot already ran) — demographics + pauta + values + political history + other issues | Yes | Yes | **18** |

**Total: 64 base conditions.** L4 vs. L3 isolates "does adding one stated issue move the recommendation, on top of demographics alone." L5 vs. L4 isolates "does everything else in the full narrative (values, history, other issues) move it further, beyond what demographics+one-issue already explains." This is a clean, comparable structure — not an all-or-nothing ladder.

**Two source-data bugs fixed.** To be clear: the actual prompts sent to models never contain "(a)"/"(ã)" — that notation is only an internal marker in `profiles_data.json` that `build_profile_prompts.py` resolves into plain "morador"/"moradora" etc. before the prompt is built. The bugs were about which words get resolved:
- `progressista`'s demographics/full-profile text hardcoded "moradora" (feminine-only) — fixed to resolve properly for both genders.
- `empreendedor_individual`'s full-profile text had a subtler bug: "empreendedor" appears twice — once self-referential ("Me vejo como empreendedor —") and once generic ("...deixe o empreendedor trabalhar," a category reference, not about the speaker, same pattern as `agro`'s "candidato que defenda o produtor rural"). The first fix incorrectly resolved *both* occurrences, which produced "o empreendedora" (broken — masculine article, feminine noun) in the mulher arm. **Corrected 2026-08-14**: only the self-referential mention resolves by gender now; the generic one is left alone. Verified: homem reads "...deixe o empreendedor trabalhar," mulher reads "Me vejo como empreendedora... deixe o empreendedor trabalhar" — natural in both.

**`{state}` → "São Paulo"** (spelled out, not "SP") and **`{gender}` → "homem"/"mulher"** — both confirmed earlier, unchanged by the redesign.

## Exactly how many times this runs

**Cargo×ask crossing — kept.** "Quase 10.000 prompts" is a better line for a media piece than "só 2.000," unless cost becomes a bigger concern later. Both options stay wired into the code via `--no-cross`:

| Option | Total | |
|---|---|---|
| **Cross with cargo×ask (default, kept)** | 64 × 4 × 5 reps × 10 models = **12,800** | |
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

## Code written (not yet run) — fully self-contained in `fri AUG 14/`

Everything needed to run this round now lives in this one folder, including copies of the two live-repo files it depends on (`cues.json`, `run_api.py`) — nothing outside `fri AUG 14/` is touched or required, other than your `OPENROUTER_API_KEY` / `MARITACA_API_KEY` environment variables and the `openai` Python package:

1. **`profiles_data.json`** — the clean, machine-readable source: per archetype, the pauta/demografia/completo text with the two bugs already fixed and L2's prefix already stripped. Generated once from `profiles/archetypes.json`.
2. **`profiles_reviewed.md`** — human-readable version of the same data, fully resolved (both genders, São Paulo filled in) for manual review before running. **This is what to actually read to check the prompt wording.**
3. **`cues.json`** — a copy of `profiles/cues.json`, used only for the shared cargo/ask closing-question strings ("Pra quem devo votar para presidente...", etc.), not archetype content. **Snapshot, not a live link** — if the original changes upstream, re-copy manually.
4. **`run_api.py`** — a copy of `runners/run_api.py`, used for its `query()`/`client_for()` functions (the actual "call the model" logic) and `PILOT_MODELS` (existing model ids for gpt4o/sabia4/llama/deepseek). **Snapshot, not a live link** — already has the `max_tokens=8000` fix baked in as of today; if that file gets fixed again upstream, re-copy it here too.
5. **`build_profile_prompts.py`** — generates the 64/256 condition list from `profiles_data.json` + `cues.json` (both local now). Verified working: `python3 "fri AUG 14/build_profile_prompts.py"` prints 256 conditions, matches the table above.
6. **`run_new_round.py`** — the actual API runner. Imports from the local `run_api.py`. Writes to `fri AUG 14/results/raw/` only. All 10 model ids hardcoded and confirmed (see above) — no placeholders left. Gated behind `--confirmed` (refuses to run without it). Verified working in `--dry-run` mode: correctly reports 12,800 total, **makes zero API calls**.

## Decision checklist

**RESOLVED:**
- ✅ Models: gpt4o, gpt56_sol, gpt56_luna, claude_opus5, claude_sonnet5, grok46, sabia4, llama, deepseek — 9 of 10, all confirmed. Both DeepSeek and Llama are in.
- ✅ Data separation, `{state}`, `{gender}`, the two template bugs, level redesign, gender-neutral L1/L2 wording (re-verified 2026-08-14 with a fresh scan of all 9 archetypes — no other hardcoded gender issues found beyond the two already fixed).
- ✅ Cargo×ask crossing — kept. Total = **12,800**.
- ✅ **All 10 model ids confirmed live on OpenRouter directly** (Gemini resolved to `gemini-3.1-pro-preview`, Grok to `grok-4.6`) — no more placeholders.
- ✅ **Folder is fully self-contained** — `cues.json` and `run_api.py` copied in from the live repo; nothing outside `fri AUG 14/` is required to run this.

**OPEN:**
1. **Still not running anything against a real model** — waiting on final review of `profiles_reviewed.md` and the go-ahead to run.
