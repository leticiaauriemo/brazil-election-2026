# President versus deputy explorations

Candidate analyses on the second race, kept here until one is promoted to `current/`. Each script
sources `current/00_setup.R` for labels and theme, reads `current/output/derived/` and
`current/output/tables/`, and writes to `tables/` and `figures/` in this folder.

| Script | Question | Figures |
|---|---|---|
| `01_ladder_by_office.R` | Does the issue unlock deputy advice as it unlocks presidential advice? The ladder by model, one line per office. | `01_ladder_by_office` |
| `02_name_vs_party.R` | What a deputy steer looks like: one person, a shortlist, or only a party; and which parties the three readings point to, by side. | `02_steer_shape_by_office`, `02_deputy_parties_by_reading` |
| `03_deputy_recommendations.R` | The deputy versions of figures 4, 9 and 12, with the named candidate's party as the option. | `03_deputy_recommendations`, `03_deputy_recommendations_conditional`, `03_deputy_vs_seats` |
| `04_web_by_office.R` | ChatGPT web on the two races: category mix, cited domains, search queries. | `04_web_categories_by_office`, `04_web_domains_by_office` |
| `05_who_for_deputy.R` | How concentrated the names are by office, and which deputies get described or recommended by side. | `05_concentration_by_office`, `05_deputy_names_by_side` |
| `06_usefulness.R` | Is the assistant any use to a voter who does not know the field? Answers ordered from most to least actionable, by office, model and level. | `06_usefulness_by_office` |
| `07_web_deputy_content.R` | What ChatGPT web says to a deputy voter: the answer template (electoral-court pointer, criteria list, closing offer) by level, whose camp the closing offer names by profile, who gets named. | `07_web_features_by_level`, `07_web_offer_side_by_profile`, `07_web_named_by_profile` |

Sample rule as in `current/`: full profiles and the specific-candidate wording unless the script
varies the level. Outcome rule as in `current/`: advice is an answer naming exactly one candidate;
a party alone or a shortlist is a steer that declines to name one, shown separately where relevant.
