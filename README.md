# brazil-election-2026

Replication code for *I Can't Tell You Who to Vote For, But…*, a study of whether AI chatbots give voting advice
to Brazilian voters in the 2026 election (Letícia Auriemo and Luca Moreno Louzada, with ChatGPT-web data collected
by Ranqia). Six R scripts take the raw model answers to the figures in the post.

**The raw data are not in this repository.** `data/` (the API responses, Ranqia's ChatGPT-web export and the
GPT-5 mini labels, about 1.5 GB) and the derived Parquet files in `output/derived/` are gitignored. The tables and
figures are committed, so the numbers in the post can be checked without the data. To rerun from scratch, place the
inputs under `data/` as described in `appendix/appendix.pdf` and run `./run.sh` (about 15 minutes).

| Path | What it is |
|---|---|
| `00_setup.R` | Paths, labels, name and party keys, figure theme; sourced by the other scripts |
| `01_clean_api.R` | Reads the API round (ten models, 12,800 responses) |
| `02_clean_web.R` | Reads the ChatGPT-web captures (947,190), the links shown and the search queries |
| `03_labels.R` | Joins the GPT-5 mini labels to the coding sample and derives the outcomes |
| `04_regex.R` | A rule-based reading of the outcome, used to check the labels |
| `05_results.R` | Every table behind the figures and the numbers quoted in the text |
| `06_figures.R` | The fifteen figures, numbered in the order of the post |
| `reference/` | Coding sample identifiers, codebook, name aliases, benchmarks, population shares |
| `output/tables/`, `output/figures/` | Results, committed |
| `appendix/` | The appendix to the post: prompts, profiles, models, coding rules, computation |
| `archive/` | Earlier pipeline, explorations and drafts, kept for reference; its data and outputs are gitignored |

Definitions in one line: *advice* is an answer that settles on one candidate; *any personalized steering* also counts
shortlists, party-only recommendations and steering away; rates average collection days within a prompt, prompts
within a model, and weight models equally. Details are in the appendix.
