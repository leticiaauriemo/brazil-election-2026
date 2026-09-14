# AI Voting Advice in Brazil’s 2026 Elections

Research with Leticia Auriemo and Andrew Hall. The current collection asks how electoral guidance changes when constructed São Paulo voter profiles supply issues, demographics, and political information. The design measures response behavior, not effects on voters or an identified internal reasoning mechanism.

Project substance and decisions live in the vault project note, available through the workspace `notes/` link. This repository contains collection records and reproducible analysis.

## Layout

- `round_2026-08-14/`: canonical profiles, exact handoff prompts, collection runner, settings, party scales, and archived API responses.
- `analysis/`: unified clean → code → summarize pipeline for API and ChatGPT web. Read `analysis/README.md` for commands, data contracts, weighting, and validation.
- `data/ranqia/raw/`: immutable web export; `data/ranqia/llm/<run>/`: complete semantic-coder returns.
- `output/`: local derived data, hand-label sheets, revised results, and portable Ranqia package; gitignored.

The 64 bodies cross four questions: president/federal deputy × open/specific-candidate wording. L1 is state only; L2 adds an issue. L3 is a demographic biography; L4 adds the same issue; L5 adds attitudes and identities. L2 and L3 are branches, not successive nested levels. Ten API configurations each have five repetitions per prompt; the web surface has an unidentified underlying model and uneven collection dates.

```bash
Rscript analysis/run_all.R
```

The local pipeline makes no paid calls. Ranqia’s standalone semantic-coding instructions are in `analysis/RANQIA_README.md`. Outputs remain provisional until independent human validation is complete. The unified `analysis/` directory is the only analysis pipeline; `output/README.md` maps the current run.
