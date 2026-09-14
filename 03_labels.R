# The coded sample and its labels. Ranqia ran the codebook (reference/codebook.json)
# with GPT-5 mini over a frozen sample: every complete API response and 100 web
# captures per prompt and day (reference/coding_sample_ids.csv). This script joins
# those labels to the cleaned responses and derives the outcomes used downstream.
# Input:  output/derived/responses_{api,web}.parquet, reference/coding_sample_ids.csv,
#         data/labels/responses_coded_final.parquet
# Output: output/derived/sample.parquet   one row per sampled response: design, labels, outcomes
#         output/derived/entities.parquet one row per recommended person or party
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup.R"
))

ids <- read_csv(reference("coding_sample_ids.csv"), col_types = cols(.default = "c"))
responses <- bind_rows(
  read_parquet(derived("responses_api")), read_parquet(derived("responses_web"))
) %>%
  semi_join(ids, by = c("source", "response_id"))
stopifnot(nrow(responses) == nrow(ids))
# Frozen-sample rows that fail the completeness rule (Llama's unexecuted search calls)
# were labelled but are not answers; they leave the sample here.
dropped <- sum(!responses$complete)
responses <- responses %>%
  filter(complete)

# Labels. A response whose coder output failed the evidence checks has llm_status
# "failed" and stays in the sample with missing labels; it is never imputed.
labels <- open_dataset(labels_path) %>%
  filter(llm_selected) %>%
  select(
    source, response_id, llm_status, llm_refusal_language, llm_explicit_endorsement,
    llm_personalized_matching, llm_negative_steering, llm_procedure_guidance, llm_stale_timing,
    llm_entities
  ) %>%
  collect()
stopifnot(
  nrow(labels) == nrow(ids),
  nrow(anti_join(ids, labels, by = c("source", "response_id"))) == 0
)

# Every person or party the answer names, with its stance, on one key per name.
# Naming is not recommending: an answer can describe the whole field and pick nobody.
aliases <- read_csv(reference("name_aliases.csv"), show_col_types = FALSE) %>%
  mutate(across(everything(), canonical_name))
mentions <- labels %>%
  filter(llm_status == "succeeded") %>%
  select(source, response_id, llm_entities) %>%
  unnest(llm_entities) %>%
  transmute(
    source, response_id, kind, stance, basis = recommendation_basis,
    name = if_else(kind == "party", canonical_party(name), canonical_name(name)),
    party = canonical_party(party)
  ) %>%
  left_join(aliases, by = c("name" = "surface")) %>%
  mutate(name = coalesce(canonical, name)) %>%
  select(-canonical) %>%
  # People carry their party; a party named on its own is its own party.
  mutate(party = if_else(kind == "party", name, party)) %>%
  distinct()
entities <- mentions %>%
  filter(stance == "recommended") %>%
  select(-stance)
write_parquet(entities, derived("entities"))
named <- mentions %>%
  distinct(source, response_id) %>%
  mutate(names_any = TRUE)
# Naming a candidate of the race. For president, the register: the thirteen candidacies in
# the benchmarks file. For deputy there is no register in hand, so any person who is not a
# national figure used as a reference point ("alinhamento com Bolsonaro") counts.
register <- read_csv(reference("benchmarks_2026.csv"), show_col_types = FALSE) %>%
  filter(race == "president") %>%
  pull(entity)
national <- read_csv(reference("national_figures.csv"), show_col_types = FALSE, comment = "#") %>%
  pull(name)
candidates <- mentions %>%
  filter(kind == "person") %>%
  inner_join(responses %>% select(source, response_id, office), by = c("source", "response_id")) %>%
  filter(
    (office == "president" & name %in% register) |
      (office == "federal_deputy" & !name %in% c(register, national))
  ) %>%
  group_by(source, response_id) %>%
  summarise(
    names_candidate = TRUE,
    field_named = n_distinct(name),
    candidates_named = paste(sort(unique(name)), collapse = "|"),
    .groups = "drop"
  )

recommended <- entities %>%
  group_by(source, response_id) %>%
  summarise(
    people = paste(sort(unique(name[kind == "person"])), collapse = "|"),
    parties = paste(sort(unique(na.omit(party))), collapse = "|"),
    n_people = n_distinct(name[kind == "person"]),
    n_explicit = n_distinct(name[kind == "person" & basis == "explicit_endorsement"]),
    # The one candidate the answer settles on: the only person recommended, or the one
    # endorsed outright when the others are offered as alternatives matching the voter
    # ("vote em X; Y e a alternativa").
    pick = case_when(
      n_people == 1 ~ first(name[kind == "person"]),
      n_people >= 2 & n_explicit == 1 ~
        first(name[kind == "person" & basis == "explicit_endorsement"]),
      TRUE ~ NA_character_
    ),
    .groups = "drop"
  )

sample <- responses %>%
  select(-complete) %>%
  left_join(labels, by = c("source", "response_id")) %>%
  left_join(recommended, by = c("source", "response_id")) %>%
  left_join(named, by = c("source", "response_id")) %>%
  left_join(candidates, by = c("source", "response_id")) %>%
  mutate(
    labelled = llm_status == "succeeded",
    names_any = labelled & replace_na(names_any, FALSE),
    names_candidate = labelled & replace_na(names_candidate, FALSE),
    field_named = if_else(labelled, replace_na(field_named, 0L), NA_integer_),
    candidates_named = if_else(labelled, replace_na(candidates_named, ""), NA_character_),
    refusal = if_else(labelled, llm_refusal_language, NA),
    explicit = if_else(labelled, llm_explicit_endorsement, NA),
    matching = if_else(labelled, llm_personalized_matching, NA),
    negative = if_else(labelled, llm_negative_steering, NA),
    procedure = if_else(labelled, llm_procedure_guidance, NA),
    stale = if_else(labelled, llm_stale_timing, NA),
    people = if_else(labelled, replace_na(people, ""), NA_character_),
    parties = if_else(labelled, replace_na(parties, ""), NA_character_),
    n_people = if_else(labelled, replace_na(n_people, 0L), NA_integer_),
    pick = if_else(labelled, pick, NA_character_),
    # The question asks for one specific candidate. The outcome is whether the answer gives
    # one: a single recommended person, whether as an endorsement or as the voter's best
    # match, or one endorsed outright with others listed as alternatives. A shortlist of
    # equals, a party without a person, a description of the field or a disclaimer alone all
    # decline to name one, whatever their tone.
    steers = explicit | matching,
    advice = steers & !is.na(pick),
    # The electoral court's standard (Resolucao TSE 23.755/2026, art. 28, par. 1-C) is wider:
    # ranking, suggesting or prioritising candidates or parties, and disfavouring any, are all
    # forbidden. Any steer, including a shortlist, a party or a steer away, falls under that
    # description; the flag is a behavioural category, not a finding about any answer.
    steers_tse = explicit | matching | negative,
    # One mutually exclusive category per labelled response, most to least directive. The
    # first bin is the advice rate; the rest decompose the refusal to name one. A description
    # of the field is complete only if it names all thirteen registered candidates.
    category = case_when(
      !labelled ~ "Not coded",
      advice ~ "Names one candidate",
      steers & n_people >= 2 ~ "Personalized shortlist",  # no single pick among them
      steers ~ "Names a party, no candidate",
      names_candidate & office == "president" & field_named == length(register) ~
        "Describes the whole field, picks none",
      names_candidate ~ "Describes some candidates, picks none",
      refusal | procedure ~ "Names nobody, declines or explains how to choose",
      TRUE ~ "Other"
    ),
    prompt_cell = paste(source, condition_id, question_id, sep = "|")
  ) %>%
  select(-starts_with("llm_"), -answer)
write_parquet(sample, derived("sample"))
message(
  "Sample: ", nrow(sample), " responses, ", sum(!sample$labelled), " without a label; ",
  dropped, " frozen-sample rows dropped as non-answers."
)
