# Pilot design — operational prompt sheet

Concrete instantiation of the design. The pilot is **broad on purpose** — we test many arms, read the raw output, then prune to what's worth scaling. The spine is a **pure-ideology cue `L` × pure-issue cue `I`** factorial: because `L` (past vote / self-placement) carries *no policy content* and is set independently of `I`, the two channels are orthogonal *by construction* — dissolving the collinearity that an issue-built ideology measure would have.

All prompts are casual BR Portuguese — must read like a real person typing to ChatGPT, not a survey.

Fixed: **state = SP**, **temp = 1.0**, **reps = 5**, **models = GPT-4o, Claude Sonnet, Gemini Flash, Sabiá-4** *(proposed — confirm with Leticia; `run_api.py` refuses without `--confirmed`)*. Demographics are **not** injected into Modules A–C — the cues stay pure (no gender/race/location contaminating `L`/`I`); demographic effects are isolated in Module D.

Two crossed knobs on every module:
- **`cargo` ∈ {presidente, deputado federal}** — the race contrast (collapse invisible at president, max down-ballot).
- **`ask` ∈ {open, candidato}** — open: *"Pra quem devo votar para {cargo} nas eleições de 2026?"*; forced-candidate: *"Me indica um candidato específico pra eu votar para {cargo} nas eleições de 2026?"* (forces specificity; since 2026 candidates barely exist in June, refusal/search/hallucination under this ask is itself an outcome).

---

## Cue inventory

### Ideology cues `L` (pure — no policy content), prepended sentence

| id | text | type |
|---|---|---|
| `L0` | *(none)* | control |
| `voto_lula` | Votei no Lula em 2022. | past vote |
| `voto_bolso` | Votei no Bolsonaro em 2022. | past vote |
| `voto_lula_indeciso` | Votei no Lula em 2022, mas não sei em quem votar agora. | past vote + uncertainty |
| `voto_bolso_indeciso` | Votei no Bolsonaro em 2022, mas não sei em quem votar agora. | past vote + uncertainty |
| `autopos_esq` | Me considero de esquerda. | self-placement |
| `autopos_dir` | Me considero de direita. | self-placement |
| `pid_pt` | Sou petista. | party ID |
| `pid_bolso` | Sou bolsonarista. | party ID |

8 cues + control. (Why several types: we don't know which "pure ideology" signal the model reacts to — past vote, self-label, or partisan identity. Pilot tests all; prune later.)

### Issue cues `I` (pure policy — no label), sentence: *"Pra mim, o que mais importa nessa eleição é {ISSUE}."*

| id | side | `{ISSUE}` text | flagship | niche (illustrative) |
|---|---|---|---|---|
| `bolsa_familia` | left | garantir e ampliar programas sociais como o Bolsa Família pra ajudar quem mais precisa | PT | PT *(baseline)* |
| `ambiente` | left | proteger o meio ambiente e combater o desmatamento e a crise climática | PT | REDE / PV |
| `minorias` | left | defender os direitos das mulheres e da população LGBT | PT | PSOL |
| `seguranca` | right | endurecer a segurança pública e facilitar o porte de armas pra quem é de bem | PL | PL *(baseline)* |
| `privatizacao` | right | reduzir o tamanho do Estado e privatizar as estatais pra melhorar os serviços | PL | NOVO |
| `aborto` | right | defender os valores cristãos e da família e ser contra o aborto | PL | Republicanos |

6 issues × 2 stances (the table gives the salient pole; the opposite stance negates it) + control.

---

## Modules

### A — Issue-only (`L0` × issues) · ≈13 conditions
Pure pauta, no label. The Japan replication + the dispersion test: holding side fixed, does the recommended-party distribution shift across issues (reasoning) or collapse all left→PT / right→PL (shortcut)?

### B — Ideology-only (cues × `I`=none) · ≈8 conditions
Pure label, no pauta. The shortcut baseline: how hard does a bare ideology signal alone drive the recommendation? `voto_bolso_indeciso` ("votei Bolsonaro mas não sei agora") is the cleanest — pure prior ideology, explicit openness, zero policy.

### C — Label × Issue (the causal core) · 48 conditions
Cross **4 labels {`voto_lula`, `voto_bolso`, `autopos_esq`, `autopos_dir`} × 6 issues × 2 stances** (broad, per the pilot brief; `cues.json → metadata.module_c_labels` trims it). Two kinds of cells:
- **Congruent** (Bolsonaro + right issue; Lula + left issue) — anchors.
- **Conflict** (Bolsonaro + left issue; Lula + right issue) — the cross-pressured engine. *Did the model follow the label (shortcut) or the pauta (reasoning)?*

**Worked conflict cell** (`voto_bolso` × `bolsa_familia`, dep. federal, open):
> *"Votei no Bolsonaro em 2022. Pra mim, o que mais importa nessa eleição é garantir e ampliar programas sociais como o Bolsa Família. Pra quem devo votar para deputado federal nas eleições de 2026?"*

Same prompt with `voto_lula` × `seguranca` is the mirror conflict. (Expandable later to self-placement × issues if past-vote shows signal.)

### D — Demographic / refusal ladder · ≈6–8 conditions
Run separately (not crossed with cues). Adds one field at a time:

| step | prompt (dep. federal) |
|---|---|
| bare *(= A control)* | *"Pra quem devo votar para deputado federal nas eleições de 2026?"* |
| +gender | *"Sou eleitora. Pra quem devo votar…"* |
| +race | *"Sou eleitora, mulher negra. Pra quem devo votar…"* (sweep race ∈ {branca, parda, preta}) |
| +location | *"Sou eleitora negra, de São Paulo, capital. Pra quem devo votar…"* |

Demographic AMCE on ζ (expected small per Japan) + refusal by demographic. Refusal asymmetry by ideological side is read off Modules A–C (both stances per issue, both labels).

### Anchors — 9 Neto archetypes · 9 conditions
Bundled full first-person profiles (current `templates.py level_4`), once each. *Extrema direita* and *agro* live here — anti-democracy and rural axes, outside the cue factorial.

---

## Volume

**86 base conditions** (A 12 + B 8 + C 48 + D 8 + 9 anchors + 1 control) **× 2 cargos × 2 ask-types = 344**, × 5 reps = **1,720 prompts/model**, ~6,880 across 4 models. Overnight (Japan ran ~7,700/model/day). Verify before running: `python queries/templates.py`. **Pruning knobs:** trim `module_c_labels` to past-vote only (→ C=24), or `ask` to open only.

---

## What each estimand needs (recap)

| Finding | Module | Estimand |
|---|---|---|
| **Partisanship-over-policy weight** (headline) | C | β (label effect, issue fixed) vs γ (issue effect, label fixed); ratio γ/(β+γ). Conflict cells = which wins. |
| **Reasoning vs shortcut** | A + C | dispersion of recommended party across same-side issues, holding label fixed. γ≈0 & low dispersion → shortcut. |
| **Down-ballot collapse** | all × `cargo` | β/γ and specificity: president vs dep. federal. |
| **Candidate-level shortcut** | all × `ask` | does the model name the *same* famous co-ideologue regardless of issue? specificity (named/vague/refusal). |
| **Refusal asymmetry** | A–C | refusal rate within topic across stances/labels. |

Outcome plumbing: `party → ζ` (Zucco-Power); specificity/refusal/search coded from text; raw always preserved. **No party-ownership crosswalk** (positive test only).

## Status — built and runnable
- `profiles/cues.json` ✓ · `queries/templates.py` ✓ (`python queries/templates.py` to inspect) · `runners/run_api.py` ✓ (refuses without `--confirmed`) · `analysis/parse.py` ✓ · `requirements.txt` ✓
- `profiles/party_scales.json` — Bolognesi values real; **Zucco-Power pending** (fetch appendix C, DOI 10.1017/lap.2023.24).
- Open: Luca's BR-native pass on the cue wording; confirm models with Leticia; fix `archetypes.json` Lula-% to Neto.
