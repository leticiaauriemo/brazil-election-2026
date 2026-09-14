# Put regex and returned semantic labels on the same measurement scale.
# Inputs: responses, coding, entity_mentions Parquet; data/ranqia/llm/*/ final packages;
#         explicit name aliases and, when supplied, candidate_registry.csv.
# Outputs: coding_comparison.parquet (all instruments), coding_analysis.parquet
#          and entity_mentions_analysis.parquet (BRAZIL_CODER), coding coverage.
# Political direction uses stated affiliation unless an external registry resolves
# the person. Neither frequency in the corpus nor the judge supplies ground truth.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))

# 1. Import instruments from the delivered final package -----------------------
# The return is final: 3,493 selected responses have no semantic label. They stay
# in the sample with label_status = "missing" and NA outcomes, never as "no advice".
# Failures are concentrated in Sabiá, Grok and DeepSeek and in longer, name-dense
# answers, so dropping them or filling them with the regex coder would bias rates.
regex <- read_parquet(derived_path("coding"))
regex_entities <- read_parquet(derived_path("entity_mentions")) %>%
  mutate(recommendation_basis = case_when(
    stance_tier == "strong" ~ "explicit_endorsement",
    stance_tier == "aligned" ~ "personalized_matching", TRUE ~ "none"))
semantics <- regex %>% select(source, response_id, coder, refusal_language,
  refusal_grounds, procedure_guidance, stale_timing) %>%
  mutate(semantic_explicit = NA, semantic_matching = NA, semantic_negative = NA, label_status = "labelled")
entities <- regex_entities %>% select(source, response_id, coder, entity_kind,
  entity, entity_party, party_source, stance, recommendation_basis, evidence)
returns <- list.files(file.path(repo_dir, "data", "ranqia", "llm"),
  pattern = "^responses_coded_final.parquet$", full.names = TRUE, recursive = TRUE)
for (path in returns) {
  folder <- dirname(path)
  manifest <- fromJSON(file.path(folder, "final_manifest.json"), simplifyVector = FALSE)
  # Ranqia adapted the runner to OpenAI, so the script hash differs from the handoff;
  # the input data and codebook version must still be the frozen ones.
  hashes <- str_split_fixed(readLines(file.path(repo_dir, "output", "ranqia_handoff", "SHA256SUMS")), "  ", 2)
  expected_hash <- setNames(hashes[, 1], hashes[, 2])
  codebook_version <- fromJSON(file.path(analysis_dir, "codebook.json"), simplifyVector = FALSE)$version
  stopifnot(identical(manifest$input_sha256, unname(expected_hash["responses.parquet"])),
    identical(manifest$codebook_version, codebook_version))
  coder <- paste0("llm_", manifest$model)
  ledger <- readr::read_csv(file.path(folder, "failed_requests_final.csv"), col_types = readr::cols(.default = "c"))
  # Check the full returned row set without loading the original answer text.
  original <- read_parquet(file.path(repo_dir, "output", "ranqia_handoff", "responses.parquet"),
    col_select = c("source", "response_id", "llm_selected"))
  returned <- open_dataset(path) %>% select(all_of(c("source", "response_id", "llm_selected",
    "llm_status", "llm_coder", "llm_refusal_language", "llm_refusal_grounds",
    "llm_procedure_guidance", "llm_stale_timing", "llm_explicit_endorsement",
    "llm_personalized_matching", "llm_negative_steering", "llm_entities"))) %>% collect()
  stopifnot(!anyDuplicated(original[c("source", "response_id")]),
    !anyDuplicated(returned[c("source", "response_id")]), nrow(returned) == nrow(original),
    nrow(anti_join(original, returned, by = c("source", "response_id", "llm_selected"))) == 0,
    all(returned$llm_status[returned$llm_selected] %in% c("succeeded", "failed")),
    all(returned$llm_status[!returned$llm_selected] == "not_selected"))
  ids <- readr::read_csv(file.path(tables_dir, "coding_sample_ids.csv"), col_types = readr::cols(.default = "c"))
  returned <- returned %>% filter(llm_selected)
  succeeded <- returned %>% filter(llm_status == "succeeded")
  failed <- returned %>% filter(llm_status == "failed")
  stopifnot(nrow(returned) == nrow(ids),
    nrow(anti_join(ids, returned, by = c("source", "response_id"))) == 0,
    nrow(succeeded) == manifest$final_valid_selected, nrow(failed) == manifest$residual_failures,
    nrow(failed) == nrow(ledger), nrow(anti_join(failed, ledger, by = c("source", "response_id"))) == 0,
    all(succeeded$llm_coder == coder), !any(map_lgl(succeeded$llm_entities, is.null)))
  semantics <- bind_rows(semantics, returned %>% transmute(source, response_id,
    coder = coder, refusal_language = llm_refusal_language,
    refusal_grounds = llm_refusal_grounds, procedure_guidance = llm_procedure_guidance,
    stale_timing = llm_stale_timing, semantic_explicit = llm_explicit_endorsement,
    semantic_matching = llm_personalized_matching, semantic_negative = llm_negative_steering,
    label_status = if_else(llm_status == "succeeded", "labelled", "missing")))
  # Candidates and parties occupy extra rows only inside the analysis pipeline.
  returned_entities <- succeeded %>% select(source, response_id, llm_entities) %>% mutate(coder = coder) %>%
    unnest(llm_entities) %>% rename(all_of(c(entity_kind = "kind", entity = "name", entity_party = "party"))) %>%
    mutate(party_source = if_else(!is.na(entity_party), "tag", "none"))
  entities <- bind_rows(entities, returned_entities)
}
stopifnot(!anyDuplicated(semantics[c("source", "response_id", "coder")]))
responses <- read_parquet(derived_path("responses"), col_select = c("source", "response_id",
  "model_key", "cell_id", "condition_id", "question_id", "level", "archetype", "gender",
  "office", "ask", "run_date", "complete_response", "citation_count", "search_used", "answer_chars"))
stopifnot(nrow(anti_join(semantics, responses, by = c("source", "response_id"))) == 0)

# 2. Resolve transparent text aliases, keeping conflicting stances visible --------
aliases <- readr::read_csv(file.path(analysis_dir, "reference", "name_aliases.csv"), show_col_types = FALSE) %>%
  transmute(name_key = canonical_name(surface), canonical = canonical_name(canonical))
stopifnot(!anyDuplicated(aliases$name_key))
entities <- entities %>%
  mutate(surface = entity, name_key = canonical_name(entity), entity_party = canonical_party(entity_party)) %>%
  left_join(aliases, by = "name_key") %>%
  mutate(entity = if_else(entity_kind == "party", canonical_party(surface), coalesce(canonical, name_key)),
    entity_party = if_else(entity_kind == "party", entity, entity_party),
    # A corpus-imputed affiliation is never treated as an external fact.
    entity_party = if_else(party_source == "modal", NA_character_, entity_party),
    party_source = if_else(is.na(entity_party), "none", "tag")) %>%
  select(-name_key, -canonical) %>%
  left_join(responses %>% select(source, response_id, office), by = c("source", "response_id"))

# Optional reference must identify the election/office externally. Unmatched names
# remain unresolved, not 'hallucinated'. Missing reference is explicitly reported.
registry_path <- file.path(reference_dir, "candidate_registry.csv")
registry_available <- file.exists(registry_path)
if (registry_available) {
  registry <- readr::read_csv(registry_path, show_col_types = FALSE) %>%
    transmute(entity = canonical_name(name), office, registry_party = canonical_party(party),
      candidate_id = as.character(candidate_id), registry_status = status)
  stopifnot(!anyDuplicated(registry[c("entity", "office")]))
  entities <- entities %>% left_join(registry, by = c("entity", "office")) %>%
    mutate(party_source = if_else(!is.na(candidate_id) & entity_kind == "person", "registry", party_source),
      entity_party = if_else(party_source == "registry", registry_party, entity_party),
      registry_matched = !is.na(candidate_id)) %>% select(-registry_party)
} else {
  entities <- entities %>% mutate(candidate_id = NA_character_, registry_status = NA_character_, registry_matched = NA)
}
write_table(tibble(reference = registry_path, available = registry_available,
  interpretation = if (registry_available) "Registry match is not issue congruence" else "Candidate validity is not measured"), "registry_coverage")

# Conflicting recommendations are recorded rather than arbitrarily overruling
# rejections. Affiliation conflicts without a registry stay missing for ideology.
entities <- entities %>% group_by(source, response_id, coder, entity_kind, entity) %>%
  summarise(entity_party = if (n_distinct(entity_party, na.rm = TRUE) == 1) first(na.omit(entity_party)) else NA_character_,
    party_source = if (any(party_source == "registry")) "registry" else if (any(party_source == "tag")) "tag" else "none",
    stance_conflict = any(stance == "recommended") & any(stance == "rejected"),
    stance = if (any(stance == "recommended") & any(stance == "rejected")) "conflicting" else
      if (any(stance == "recommended")) "recommended" else if (any(stance == "rejected")) "rejected" else "neutral_mention",
    recommendation_basis = if (any(recommendation_basis == "explicit_endorsement")) "explicit_endorsement" else
      if (any(recommendation_basis == "personalized_matching")) "personalized_matching" else "none",
    evidence = paste(unique(evidence), collapse = "\n"),
    registry_matched = if (all(is.na(registry_matched))) NA else any(registry_matched), .groups = "drop")

# 3. Derive the same outcomes for each instrument --------------------------------
counts <- entities %>% group_by(source, response_id, coder) %>% summarise(
  n_people = sum(entity_kind == "person"), n_parties = sum(entity_kind == "party"),
  n_people_recommended = sum(entity_kind == "person" & stance == "recommended"),
  n_parties_recommended = sum(entity_kind == "party" & stance == "recommended"),
  explicit_endorsement = any(stance == "recommended" & recommendation_basis == "explicit_endorsement"),
  personalized_matching = any(stance == "recommended" & recommendation_basis == "personalized_matching"),
  negative_steering = any(stance == "rejected"), contradictory_stance = any(stance_conflict),
  recommended_people = paste(sort(unique(entity[entity_kind == "person" & stance == "recommended"])), collapse = "|"),
  recommended_parties = paste(sort(unique(na.omit(entity_party[stance == "recommended"]))), collapse = "|"),
  .groups = "drop")
positions <- entities %>% filter(stance == "recommended", !is.na(entity_party)) %>%
  distinct(source, response_id, coder, entity_party) %>%
  left_join(load_party_scales(), by = c("entity_party" = "party")) %>%
  group_by(source, response_id, coder) %>% summarise(
    n_recommended_parties_scaled = sum(!is.na(zeta_zucco_power)),
    n_recommended_parties_unscaled = sum(is.na(zeta_zucco_power)),
    zeta_recommended = if (all(is.na(zeta_zucco_power))) NA_real_ else mean(zeta_zucco_power, na.rm = TRUE),
    zeta_recommended_bolognesi = if (all(is.na(zeta_bolognesi_rescaled))) NA_real_ else mean(zeta_bolognesi_rescaled, na.rm = TRUE), .groups = "drop")
coding <- semantics %>% left_join(counts, by = c("source", "response_id", "coder")) %>%
  left_join(positions, by = c("source", "response_id", "coder")) %>%
  mutate(missing = label_status == "missing",
    across(c(n_people, n_parties, n_people_recommended, n_parties_recommended,
      n_recommended_parties_scaled, n_recommended_parties_unscaled), ~if_else(missing, NA_integer_, replace_na(.x, 0L))),
    across(c(explicit_endorsement, personalized_matching, negative_steering, contradictory_stance), ~replace_na(.x, FALSE)),
    across(c(recommended_people, recommended_parties), ~replace_na(.x, "")),
    explicit_endorsement = if_else(missing, NA, coalesce(semantic_explicit, explicit_endorsement)),
    personalized_matching = if_else(missing, NA, coalesce(semantic_matching, personalized_matching)),
    negative_steering = if_else(missing, NA, coalesce(semantic_negative, negative_steering)),
    gives_advice = explicit_endorsement | personalized_matching,
    gives_direction = gives_advice | negative_steering,
    response_category = case_when(missing ~ "not_coded", contradictory_stance ~ "unclear", explicit_endorsement ~ "explicit_endorsement",
      personalized_matching ~ "personalized_matching", negative_steering ~ "negative_steering",
      n_people > 0 | n_parties > 0 ~ "neutral_information", procedure_guidance ~ "procedural_guidance",
      refusal_language ~ "substantive_refusal", TRUE ~ "unclear"),
    recommendation_strength = case_when(missing ~ NA_character_, n_people_recommended == 1 ~ "single_named",
      n_people_recommended > 1 ~ "shortlist", n_parties_recommended > 0 ~ "party_only", TRUE ~ "none"),
    # Count candidates, not candidates plus their affiliated parties.
    slate_enumeration = if_else(missing, NA, n_people >= 4 & !gives_direction),
    declines = if_else(missing, NA, response_category == "substantive_refusal"),
    advice_posture = response_category,
    personalisation_language = personalized_matching) %>%
  left_join(responses %>% select(source, response_id, citation_count), by = c("source", "response_id")) %>%
  mutate(citation_any = citation_count > 0) %>% select(-citation_count, -missing)
write_parquet(coding, derived_path("coding_comparison"))
active <- coding %>% filter(coder == main_coder)
if (nrow(active) == 0) stop("No labels for BRAZIL_CODER=", main_coder)
selected <- readr::read_csv(file.path(tables_dir, "coding_sample_ids.csv"), col_types = readr::cols(.default = "c"))
stopifnot(nrow(active) == nrow(selected), nrow(anti_join(selected, active, by = c("source", "response_id"))) == 0)
write_parquet(active, derived_path("coding_analysis"))
write_parquet(entities %>% filter(coder == main_coder), derived_path("entity_mentions_analysis"))
write_table(active %>% left_join(responses %>% select(source, response_id, model_key), by = c("source", "response_id")) %>%
  count(coder, model_key, response_category), "active_coding_coverage")
write_table(active %>% left_join(responses %>% select(source, response_id, model_key), by = c("source", "response_id")) %>%
  group_by(coder, model_key) %>% summarise(selected = n(), labelled = sum(label_status == "labelled"),
    missing_share = mean(label_status == "missing"), .groups = "drop"), "active_coding_missing")
message("Normalized ", nrow(active), " selected responses for ", main_coder, ". Registry available: ", registry_available)
