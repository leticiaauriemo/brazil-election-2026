# Web-only explorations

Candidate analyses that use only the ChatGPT-web arm, kept here until one is promoted to `current/`.
Each script is self-contained, reads `current/output/derived/` and Ranqia's raw exports under
`../data/ranqia/raw/`, and writes to `tables/` and `figures/` in this folder.

| Script | Question | Figure |
|---|---|---|
| `01_search_queries.R` | What does the interface search for, and does the voter's profile enter the query? | `01_search_query_terms` |
| `02_search_on_off.R` | Same prompt, with and without a search: does it name a candidate more often, and whom? | `02_search_on_off` |
| `03_sources_by_profile.R` | Which outlets feed the answer, by the voter's side? | `03_press_outlets_by_side` |
| `04_full_corpus_regex.R` | The dictionary regex on all 947,000 captures: tight per-prompt rates and a representativeness check of the labelled sample. Slow (tens of minutes). | `04_full_corpus_vs_sample` |
| `05_salience.R` | Among answers that name nobody, who is mentioned, how early, and with what tone? | `05_salience_mentions`, `05_salience_sentiment` |

Sample rule as in `current/`: full profiles and the specific-candidate wording unless the script varies the level.

Promoted to `current/` on 2026-09-10: exploration 1 (search-query terms by level, table
`web_query_terms`, figure 13) and exploration 3 (domains by side, table `web_domains_by_side`,
figure 14). Explorations 2, 4 and 5 stay here as documented nulls and checks.
