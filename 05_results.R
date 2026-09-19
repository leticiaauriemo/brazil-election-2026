# Every number behind the figures, in one place.
# Input:  output/derived/{sample,entities,regex,web_captures,web_citations,web_queries,
#         web_rule_links}.parquet (responses_{api,web} only for the quoted examples),
#         reference/*.csv
# Output: output/tables/*.csv (one table per figure) and values.csv (numbers quoted in the text)
# Weights: collection days are averaged within a prompt, prompts within a model, models
# equally in any pooled number. Rates use labelled responses; the unlabelled share is
# reported alongside, never imputed.
# Sample rule: unless a table varies it by construction, the sample is the full profile
# (attitudes added) asked with the specific-candidate wording. Tables that vary the level
# use the specific wording across all five levels. Both wordings enter only the wording
# contrast, which is quoted as one number.
# Outcome rule: the question asks for one specific candidate, and advice means the answer
# settles on one, as an endorsement or as the voter's best match, including the case where
# one is endorsed and others are listed as alternatives. Everything else, including a
# shortlist of equals, a party without a person or a disclaimer, declines to name one. Only
# the category table decomposes that refusal.
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup.R"
))
sample <- read_parquet(derived("sample"))
main <- sample %>%
  filter(ask == "candidate")
full <- main %>%
  filter(level == "L5")

# 1. Advice rates by configuration (full profiles) and by level -------------------------
# advice is the outcome; steers_tse is the electoral court's wider standard; stale flags an
# answer that treats the election as future or unknown or leans on outdated facts.
outcomes <- c("advice", "refusal", "explicit", "steers_tse", "stale")
cells <- main %>%
  filter(labelled) %>%
  group_by(model_key, level, office, prompt_cell, run_date) %>%
  summarise(across(all_of(outcomes), mean), .groups = "drop") %>%
  group_by(model_key, level, office, prompt_cell) %>%
  summarise(across(all_of(outcomes), mean), .groups = "drop")
rates <- function(d, ...) {
  d %>%
    group_by(model_key, ...) %>%
    summarise(
      prompts = n(),
      across(all_of(outcomes), ~ sd(.x) / sqrt(n()), .names = "{.col}_se"),
      across(all_of(outcomes), mean),
      .groups = "drop"
    )
}
not_coded <- full %>%
  group_by(model_key) %>%
  summarise(not_coded = mean(!labelled), .groups = "drop")
write_table(
  rates(cells %>% filter(level == "L5")) %>% left_join(not_coded, by = "model_key"),
  "rates_by_model"
)
write_table(rates(cells, level), "rates_by_level")
# The same by level with configurations weighted equally: the narrow outcome and the
# broader steering measure side by side.
write_table(rates(cells, level) %>%
  group_by(level) %>%
  summarise(
    configurations = n(),
    across(c(advice, steers_tse), list(
      mean = mean, min = min, max = max, se = ~ sd(.x) / sqrt(n())
    ), .names = "{.col}_{.fn}"),
    .groups = "drop"
  ), "rates_by_level_pooled")

# 2. What the answer does, by configuration and office (mutually exclusive categories) -
categories <- full %>%
  count(model_key, office, prompt_cell, run_date, category) %>%
  group_by(model_key, office, prompt_cell, run_date) %>%
  mutate(share = n / sum(n)) %>%
  ungroup() %>%
  complete(nesting(model_key, office, prompt_cell, run_date), category, fill = list(share = 0)) %>%
  group_by(model_key, office, prompt_cell, category) %>%
  summarise(share = mean(share), .groups = "drop") %>%
  group_by(model_key, office, category) %>%
  summarise(share = mean(share), .groups = "drop")
write_table(categories, "categories_by_office")
# Refusal language against steering, both offices pooled: the two-by-two per configuration
# behind the section on refusals that still recommend. Shares of labelled answers; the
# four cells sum to one; names_one is a subset of the two steering cells.
write_table(full %>%
  filter(labelled) %>%
  group_by(model_key) %>%
  summarise(
    answers = n(),
    refuses_no_steer = mean(refusal & !steers_tse),
    refuses_and_steers = mean(refusal & steers_tse),
    steers_no_refusal = mean(!refusal & steers_tse),
    neither = mean(!refusal & !steers_tse),
    names_one = mean(advice),
    steer_given_refusal = sum(refusal & steers_tse) / sum(refusal),
    refusal_given_steer = sum(refusal & steers_tse) / sum(steers_tse),
    .groups = "drop"
  ), "refusal_by_steering")
# How complete a description of the presidential field is: among answers that describe
# candidates without steering, the number of the thirteen registered candidates named.
write_table(full %>%
  filter(office == "president", names_candidate, !steers) %>%
  group_by(model_key, prompt_cell, run_date) %>%
  summarise(named = mean(field_named), whole = mean(field_named == 13), .groups = "drop") %>%
  group_by(model_key, prompt_cell) %>%
  summarise(named = mean(named), whole = mean(whole), .groups = "drop") %>%
  group_by(model_key) %>%
  summarise(prompts = n(), named = mean(named), whole = mean(whole), .groups = "drop"),
  "field_coverage")
# Listings of the presidential field: answers that name registered candidates without
# steering. All five conditions, because at full profile most API systems steer rather than
# list. How many of the thirteen a listing names, by system; and which candidates a listing
# includes, by the voter's side, in the profiled conditions.
listings <- main %>%
  filter(labelled, office == "president", names_candidate, !steers)
write_table(listings %>%
  count(model_key, field_named, name = "answers") %>%
  group_by(model_key) %>%
  mutate(share = answers / sum(answers)) %>%
  ungroup(), "field_listing_size")
by_side <- listings %>%
  filter(level %in% c("L4", "L5")) %>%
  mutate(side = unname(side_labels[archetype]))
# Within configuration, so a change in which systems list cannot produce the pattern;
# the figure keeps the configurations with enough listings on every side.
field_register <- read_csv(reference("benchmarks_2026.csv"), show_col_types = FALSE) %>%
  filter(race == "president") %>%
  transmute(candidate = entity, label, poll = replace_na(share, 0))
listing_sizes <- by_side %>%
  count(model_key, side, name = "listings")
write_table(listing_sizes %>%
  cross_join(field_register) %>%
  left_join(
    by_side %>%
      separate_rows(candidates_named, sep = "\\|") %>%
      count(model_key, side, candidate = candidates_named, name = "answers"),
    by = c("model_key", "side", "candidate")
  ) %>%
  mutate(answers = replace_na(answers, 0L), share = answers / listings),
  "field_candidates_by_side")

# Registration check for the deputies the systems pick, when the TSE register is present.
# The TSE blocks automated downloads; place consulta_cand_2026_SP.csv (from the
# dadosabertos.tse.jus.br "Candidatos 2026" dataset, ZIP for SP, semicolon-separated,
# Latin-1) under data/tse/ and rerun. Output: pick_validation.csv.
tse_path <- file.path(here, "data", "tse", "consulta_cand_2026_SP.csv")
if (file.exists(tse_path)) {
  tse <- read_delim(
    tse_path, delim = ";", locale = locale(encoding = "latin1"), show_col_types = FALSE
  ) %>%
    filter(DS_CARGO == "DEPUTADO FEDERAL") %>%
    transmute(
      ballot_name = canonical_name(NM_URNA_CANDIDATO),
      full_name = canonical_name(NM_CANDIDATO),
      tse_party = canonical_party(SG_PARTIDO),
      status = DS_SITUACAO_CANDIDATURA
    )
  write_table(picks %>%
    filter(office == "federal_deputy", advice) %>%
    count(pick, pick_party, name = "answers", sort = TRUE) %>%
    mutate(
      registered = pick %in% c(tse$ballot_name, tse$full_name),
      tse_party = tse$tse_party[match(pick, tse$ballot_name)],
      status = tse$status[match(pick, tse$ballot_name)]
    ), "pick_validation")
}
# Refusal language and advice coexist: the share of advice-giving answers that open by declining.
write_table(full %>%
  filter(labelled, advice) %>%
  group_by(model_key, office, prompt_cell, run_date) %>%
  summarise(share = mean(refusal), n = n(), .groups = "drop") %>%
  group_by(model_key, office, prompt_cell) %>%
  summarise(share = mean(share), n = sum(n), .groups = "drop") %>%
  group_by(model_key, office) %>%
  summarise(disclaimer_share = mean(share), picks = sum(n), .groups = "drop"),
  "disclaimer_among_advice")

# 3. Matched contrasts: same prompt otherwise, one thing changed --------------------
# Each pair is one prompt cell against its counterpart; se across pairs within a model.
pair_cells <- function(d, keys) {
  d %>%
    filter(labelled) %>%
    group_by(model_key, across(all_of(keys)), prompt_cell, run_date) %>%
    summarise(advice = mean(advice), .groups = "drop") %>%
    group_by(model_key, across(all_of(keys))) %>%
    summarise(advice = mean(advice), .groups = "drop")
}
contrast <- function(d, keys, variable, treated, control, name) {
  wide <- pair_cells(d, c(keys, variable)) %>%
    pivot_wider(names_from = all_of(variable), values_from = advice) %>%
    filter(!is.na(.data[[treated]]), !is.na(.data[[control]])) %>%
    mutate(difference = .data[[treated]] - .data[[control]])
  wide %>%
    group_by(model_key) %>%
    summarise(
      contrast = name,
      pairs = n(),
      se = sd(difference) / sqrt(n()),
      control = mean(.data[[control]]),
      treated = mean(.data[[treated]]),
      difference = mean(difference),
      .groups = "drop"
    )
}
contrasts <- bind_rows(
  contrast(
    main, c("archetype", "gender", "office"), "level", "L4", "L3", "issue_added_to_biography"
  ),
  contrast(main, c("archetype", "gender", "office"), "level", "L5", "L4", "attitudes_added"),
  contrast(sample, c("condition_id", "office"), "ask", "candidate", "open", "specific_wording"),
  contrast(
    main %>% filter(level %in% c("L3", "L4", "L5")),
    c("archetype", "level", "office"), "gender", "mulher", "homem", "woman"
  )
)
write_table(contrasts, "contrasts_by_model")
write_table(contrasts %>%
  group_by(contrast) %>%
  summarise(
    models = n(),
    se = sqrt(sum(se^2)) / n(),
    min_model = min(difference),
    max_model = max(difference),
    control = mean(control),
    treated = mean(treated),
    difference = mean(difference),
    .groups = "drop"
  ), "contrasts_pooled")
# The issue step by profile: which stated priority unlocks advice.
write_table(pair_cells(
  main %>% filter(level %in% c("L3", "L4")), c("archetype", "gender", "office", "level")
) %>%
  pivot_wider(names_from = level, values_from = advice) %>%
  filter(!is.na(L4), !is.na(L3)) %>%
  group_by(model_key, archetype) %>%
  summarise(difference = mean(L4 - L3), .groups = "drop"), "issue_step_by_profile")

# 4. The same estimands as one linear probability model per configuration -------------
# Specific-candidate wording, all levels. Biography-only is the reference level; errors
# clustered by prompt. Gender is unspecified exactly when the level is L1 or L2, so that
# dummy is collinear and fixest drops it.
rows <- main %>%
  filter(labelled) %>%
  mutate(
    level = factor(level, c("L3", "L1", "L2", "L4", "L5")),
    office = factor(office, c("president", "federal_deputy")),
    gender = factor(replace_na(gender, "unspecified"), c("homem", "mulher", "unspecified"))
  )
regression <- map_dfr(split(rows, rows$model_key), function(d) {
  fit <- fixest::feols(advice ~ level + office + gender, data = d, cluster = ~prompt_cell)
  as.data.frame(fixest::coeftable(fit)) %>%
    tibble::rownames_to_column("term") %>%
    transmute(
      model_key = d$model_key[1],
      term,
      estimate = Estimate,
      se = `Std. Error`,
      n = stats::nobs(fit)
    )
}) %>%
  filter(term != "(Intercept)")
write_table(regression, "regression_by_model")

# 5. Where advice points: options recommended to the full profiles ---------------------
# p(option) per prompt cell and day, then dates, then prompts; the conditional share
# divides by the sum over options, so a shortlist is split rather than double counted.
entities <- read_parquet(derived("entities"))
full <- full %>%
  filter(labelled)
# Only answers that settle on one candidate count, and only that candidate; for deputies
# the option is that candidate's party.
single <- full %>%
  filter(advice) %>%
  select(source, response_id, pick)
# A presidential pick outside the register (a governor, a former president) is a coder
# slip or a non-candidate; it does not enter the shares.
register <- read_csv(reference("benchmarks_2026.csv"), show_col_types = FALSE) %>%
  filter(race == "president") %>%
  pull(entity)
option_rows <- bind_rows(
  single %>%
    transmute(source, response_id, race = "president", option = pick) %>%
    filter(option %in% register),
  single %>%
    inner_join(
      entities %>%
        filter(kind == "person", !is.na(party), str_detect(party, "^[A-Z]{2,13}$")) %>%
        distinct(source, response_id, name, party),
      by = c("source", "response_id", "pick" = "name")
    ) %>%
    transmute(source, response_id, race = "federal_deputy", option = party)
) %>%
  distinct()
# Every option observed for an office gets an explicit zero in every prompt cell and
# day where no answer named it; otherwise averaging over cells overstates the share.
option_shares <- function(rows) {
  cell_base <- full %>%
    group_by(model_key, archetype, office, prompt_cell, run_date) %>%
    summarise(n = n(), advice_rate = mean(advice), .groups = "drop")
  counts <- full %>%
    select(source, response_id, model_key, archetype, office, prompt_cell, run_date) %>%
    inner_join(rows, by = c("source", "response_id"), relationship = "many-to-many") %>%
    filter(race == office) %>%
    count(model_key, archetype, office, prompt_cell, run_date, option, name = "k")
  cell_base %>%
    inner_join(
      rows %>% distinct(office = race, option), by = "office", relationship = "many-to-many"
    ) %>%
    left_join(
      counts, by = c("model_key", "archetype", "office", "prompt_cell", "run_date", "option")
    ) %>%
    mutate(p = replace_na(k, 0L) / n) %>%
    group_by(model_key, archetype, office, prompt_cell, option) %>%
    summarise(p = mean(p), advice_rate = mean(advice_rate), .groups = "drop") %>%
    group_by(model_key, archetype, office, option) %>%
    summarise(unconditional = mean(p), advice_rate = mean(advice_rate), .groups = "drop") %>%
    group_by(model_key, archetype, office) %>%
    filter(sum(unconditional) > 0) %>%
    mutate(share = unconditional / sum(unconditional)) %>%
    ungroup()
}
by_profile <- option_shares(option_rows)
write_table(by_profile, "options_by_profile")
# The same for deputies with the person, not the party, as the option.
write_table(option_shares(
  single %>%
    inner_join(full %>% select(source, response_id, office), by = c("source", "response_id")) %>%
    filter(office == "federal_deputy") %>%
    transmute(source, response_id, race = "federal_deputy", option = pick)
), "options_by_profile_deputy_people")

# The party behind each single pick, both offices, for the two exhibits below.
pick_party <- entities %>%
  filter(kind == "person", !is.na(party), str_detect(party, "^[A-Z]{2,13}$")) %>%
  distinct(source, response_id, name, party) %>%
  group_by(source, response_id, name) %>%
  slice_head(n = 1) %>%
  ungroup()
picks <- main %>%
  filter(labelled) %>%
  left_join(pick_party, by = c("source", "response_id", "pick" = "name")) %>%
  mutate(pick_party = if_else(advice, party, NA_character_)) %>%
  select(-party)

# Party concentration before explicit partisan cues: for PT, Novo and PL, the share of
# answers whose single pick belongs to the party, at issue only, biography with issue and
# the full profile. Days within prompt, prompts within configuration, offices equal within
# a configuration, configurations equal in the pooled line.
focus <- c("PT", "NOVO", "PL")
party_cells <- picks %>%
  filter(level %in% c("L2", "L4", "L5")) %>%
  select(model_key, level, archetype, office, prompt_cell, run_date, pick_party) %>%
  cross_join(tibble(party = focus)) %>%
  mutate(hit = replace_na(pick_party == party, FALSE)) %>%
  group_by(model_key, level, archetype, office, party, prompt_cell, run_date) %>%
  summarise(share = mean(hit), .groups = "drop") %>%
  group_by(model_key, level, archetype, office, party, prompt_cell) %>%
  summarise(share = mean(share), .groups = "drop") %>%
  group_by(model_key, level, archetype, party) %>%
  summarise(share = mean(share), .groups = "drop")
write_table(bind_rows(
  party_cells,
  party_cells %>%
    group_by(level, archetype, party) %>%
    summarise(share = mean(share), .groups = "drop") %>%
    mutate(model_key = "all")
), "party_by_level_profile")

# Agreement across configurations, president versus deputy, at the candidate and at the
# party level. For each profile, every configuration with at least five single picks
# contributes its most frequent pick (or the pick's party); agreement is the share of
# contributing configurations whose top option is the plurality top option. Profiles
# with at least two contributing configurations are averaged equally.
top_picks <- picks %>%
  filter(level == "L5", advice) %>%
  pivot_longer(c(pick, pick_party), names_to = "unit", values_to = "option") %>%
  filter(!is.na(option)) %>%
  mutate(unit = recode(unit, pick = "Candidate", pick_party = "Party")) %>%
  count(office, unit, archetype, model_key, option) %>%
  group_by(office, unit, archetype, model_key) %>%
  filter(sum(n) >= 5) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup()
agreement <- top_picks %>%
  group_by(office, unit, archetype) %>%
  filter(n() >= 2) %>%
  mutate(plurality = names(which.max(table(option)))) %>%
  summarise(
    configurations = n(),
    agreement = mean(option == plurality),
    plurality = first(plurality),
    .groups = "drop"
  )
write_table(agreement, "agreement_by_profile")
write_table(agreement %>%
  group_by(office, unit) %>%
  summarise(
    profiles = n(),
    cells = sum(configurations),
    agreement = mean(agreement),
    .groups = "drop"
  ), "agreement_by_office")

population <- read_csv(reference("archetype_population_shares.csv"), show_col_types = FALSE) %>%
  select(archetype, population_share)
weighted <- by_profile %>%
  inner_join(population, by = "archetype") %>%
  group_by(model_key, office) %>%
  mutate(w = population_share / sum(population_share[!duplicated(archetype)])) %>%
  group_by(model_key, office, option) %>%
  summarise(
    share = sum(share * w),
    advice_mass = sum(share * advice_rate * population_share),
    .groups = "drop"
  )
advice_total <- by_profile %>%
  distinct(model_key, archetype, office, advice_rate) %>%
  inner_join(population, by = "archetype") %>%
  group_by(office) %>%
  summarise(total = sum(advice_rate * population_share), .groups = "drop")
recommended <- weighted %>%
  group_by(office) %>%
  mutate(models = n_distinct(model_key)) %>%
  group_by(office, option) %>%
  summarise(
    models_equal = sum(share) / first(models),
    advice_mass = sum(advice_mass),
    .groups = "drop"
  ) %>%
  inner_join(advice_total, by = "office") %>%
  mutate(advice_weighted = advice_mass / total) %>%
  select(-advice_mass, -total)
# Poll shares are of all respondents, undecided and blank included; rescaled to valid
# votes so they compare with recommendation shares, which sum to one. Seat shares already do.
benchmarks <- read_csv(reference("benchmarks_2026.csv"), show_col_types = FALSE) %>%
  select(office = race, option = entity, label, benchmark = share) %>%
  group_by(office) %>%
  mutate(benchmark = benchmark / sum(benchmark, na.rm = TRUE)) %>%
  ungroup()
write_table(full_join(benchmarks, recommended, by = c("office", "option")) %>%
  mutate(
    across(c(models_equal, advice_weighted), ~ replace_na(.x, 0)),
    label = coalesce(label, if_else(office == "president", str_to_title(option), option))
  ) %>%
  arrange(office, desc(benchmark), desc(models_equal)), "benchmark_comparison")

# Domain classes for the links an answer shows. Candidate campaign sites and party sites are
# kept apart; an ".org.br" address alone is not a party.
press_domains <- paste0(
  "globo|folha|uol|estadao|cnnbrasil|poder360|metropoles|veja|cartacapital|r7\\.com|",
  "terra\\.com|correiobraziliense|gazetadopovo|jota|nexojornal|valor|infomoney|exame|istoe|",
  "bbc|reuters|elpais|dw\\.com|agenciabrasil|congressoemfoco|brasildefato|oantagonista|",
  "jovempan|piaui|sbt|band|clicrbs|opovo|em\\.com\\.br|acritica|neofeed|tribunapr|osul|",
  "jornaldotocantins|moneytimes|seudinheiro|hubpolitico|apublica|cancaonova|diarioesp|",
  "tvpampa|planopolitico|politicaporinteiro|almapreta|agenciasertao|spacemoney|mundocoop|",
  "brasilagro|comunhao|agenciasebrae"
)
party_domains <- paste0(
  "(^|\\.)(pt|novo|psd|psdb|pcdob|psol|pcb|pstu|republicanos|partidoliberal|mdb|pdt|psb|rede|",
  "cidadania|podemos|uniao|uniaobrasil|avante|prtb|unidadepopular|missao|mbl|brasilnovo|",
  "fpabramo|mst)[a-z0-9-]*\\.org\\.br|partido|missao\\.org|mbl\\.org|psd-sp"
)
campaign_domains <- paste0(
  "ronaldocaiado|marinahelena|renanpresidente|campanhaflavio|flaviobolsonaro|adrianaventura|",
  "marcovinholi|direitasp|ladoalado2026|lpbraganca|claudiodantas|romeuzema|zema2026|",
  "lula2026|kimkataguiri|erikahilton|renatobolsonaro|alexisfonteyne|pablomarcal"
)
classify_domain <- function(domain) {
  case_when(
    str_detect(domain, "^gov\\.br$|tse\\.jus\\.br|\\.gov\\.br|\\.leg\\.br|\\.jus\\.br|planalto") ~
      "Official (TSE, Congress, government)",
    str_detect(domain, "wikipedia") ~ "Wikipedia",
    str_detect(domain, "instagram|facebook|youtube|twitter|x\\.com|tiktok|linkedin|threads") ~
      "Social media",
    str_detect(domain, campaign_domains) ~ "Candidate and campaign sites",
    str_detect(domain, party_domains) ~ "Party and movement sites",
    str_detect(domain, press_domains) ~ "Press and news",
    TRUE ~ "Other"
  )
}

# 6. The web surface: stability of its advice per prompt, what it cites, what it searches --
web <- full %>%
  filter(model_key == "chatgpt_web")
named <- web %>%
  filter(advice) %>%
  transmute(prompt_cell, kind = "person", option = pick) %>%
  count(prompt_cell, kind, option, name = "naming")
ranking <- named %>%
  group_by(prompt_cell) %>%
  arrange(desc(naming), option, .by_group = TRUE) %>%
  summarise(
    lead = first(option),
    lead_kind = first(kind),
    second = nth(option, 2),
    second_kind = nth(kind, 2),
    second_n = nth(naming, 2),
    .groups = "drop"
  )
stability <- web %>%
  left_join(ranking, by = "prompt_cell") %>%
  group_by(prompt_cell, archetype, gender, office) %>%
  summarise(
    n = n(),
    n_advice = sum(advice),
    n_lead = sum(advice & pick == first(lead), na.rm = TRUE),
    across(c(lead, lead_kind, second, second_kind, second_n), first),
    .groups = "drop"
  )
write_table(stability, "web_stability")
citations <- read_parquet(derived("web_citations")) %>%
  inner_join(web %>% select(response_id, advice, archetype), by = "response_id") %>%
  mutate(
    side = unname(side_labels[archetype]),
    source_type = if_else(rule_page, "TSE pages about the AI rule", classify_domain(domain))
  )
# Advice here is the narrow outcome: the answer settles on one candidate. Counts of
# answers and of links travel with the shares so the figure can show its base.
write_table(citations %>%
  count(advice, source_type, name = "links") %>%
  group_by(advice) %>%
  mutate(share = links / sum(links), links_total = sum(links)) %>%
  ungroup() %>%
  left_join(web %>% count(advice, name = "answers"), by = "advice"), "web_citation_sources")
write_table(citations %>%
  count(advice, domain, sort = TRUE) %>%
  group_by(advice) %>%
  mutate(share = n / sum(n)) %>%
  slice_head(n = 10) %>%
  ungroup(), "web_cited_domains")
# Which outlets feed the answer depends on the voter's side. Every domain with at least
# 80 links across all profiles, as a share of the side's links.
# By domain the rule pages are a sliver of tse.jus.br, so the domain keeps its own class.
domains <- citations %>%
  mutate(source_type = classify_domain(domain)) %>%
  count(side, domain, source_type, name = "links") %>%
  group_by(side) %>%
  mutate(share = links / sum(links)) %>%
  ungroup()
frequent <- domains %>%
  group_by(domain) %>%
  summarise(links = sum(links)) %>%
  filter(links >= 80) %>%
  pull(domain)
write_table(domains %>%
  filter(domain %in% frequent) %>%
  arrange(source_type, desc(share)), "web_domains_by_side")

# What the interface searched for, by what the voter revealed. All complete captures with
# the specific wording, whether or not they entered the coding sample; a query can fall in
# several classes.
searched <- read_parquet(
  derived("web_captures"),
  col_select = c("response_id", "level", "ask", "complete", "search_used")
) %>%
  filter(complete, ask == "candidate")
queries <- read_parquet(derived("web_queries")) %>%
  inner_join(searched, by = "response_id") %>%
  mutate(
    text = str_to_lower(stringi::stri_trans_general(query, "Latin-ASCII")),
    demographic = str_detect(
      text, "\\b(mulher|homem|anos|idade|renda|salari\\w*|ensino|escolaridade|superior|medio)\\b"
    ),
    issue = str_detect(text, paste0(
      "agroneg|rural|ambient|privatiz|imposto|tribut|autonom|\\bmei\\b|familia|crist|",
      "evangel|seguranca|minoria|lgbt|clima|democracia|polariza|bolsa familia|",
      "programa social|custo de vida|emprego|ordem|nacionalis|sindicat|trabalhista|",
      "direitos sociais|liberal|conservador|progressist"
    )),
    politics = str_detect(text, "esquerda|direita|bolsonar|lula|\\bpt\\b|petista|centro"),
    official = str_detect(text, "\\btse\\b|calendario|registro|divulgacand")
  )
write_table(queries %>%
  group_by(level) %>%
  summarise(
    queries = n(),
    captures_searched = n_distinct(response_id),
    across(c(demographic, issue, politics, official), mean),
    .groups = "drop"
  ) %>%
  left_join(searched %>%
    group_by(level) %>%
    summarise(captures = n(), searched = mean(search_used), .groups = "drop"), by = "level"),
  "web_query_terms")

# The interface and the rule. How often a full-profile capture retrieved the electoral
# court's AI rule (the resolution text or news about it), showed such a link, or mentioned
# the ban; and whether captures that retrieved it behaved differently.
captures <- read_parquet(
  derived("web_captures"),
  col_select = c("response_id", "office", "level", "ask", "complete", "mentions_ban")
) %>%
  filter(complete, ask == "candidate", level == "L5")
rule_links <- read_parquet(derived("web_rule_links"))
captures <- captures %>%
  left_join(
    rule_links %>%
      group_by(response_id) %>%
      summarise(
        retrieved = TRUE,
        resolution = any(rule_page == "resolution text"),
        shown = any(shown),
        .groups = "drop"
      ),
    by = "response_id"
  ) %>%
  mutate(across(c(retrieved, resolution, shown), ~ replace_na(.x, FALSE)))
write_table(tribble(
  ~measure, ~share, ~n,
  "Retrieved a page about the rule", mean(captures$retrieved), nrow(captures),
  "Retrieved the resolution text", mean(captures$resolution), nrow(captures),
  "Showed such a link in the answer", mean(captures$shown), nrow(captures),
  "Mentioned the ban in the text", mean(captures$mentions_ban), nrow(captures)
), "web_rule_awareness")
write_table(web %>%
  inner_join(captures %>% select(response_id, retrieved, resolution), by = "response_id") %>%
  mutate(exposure = case_when(
    resolution ~ "Retrieved the resolution text",
    retrieved ~ "Retrieved a news item or explainer about the rule",
    TRUE ~ "Retrieved neither"
  )) %>%
  group_by(office, exposure, prompt_cell) %>%
  summarise(n = n(), advice = mean(advice), steers_tse = mean(steers_tse), .groups = "drop") %>%
  group_by(office, exposure) %>%
  summarise(
    prompts = n(), n = sum(n), advice = mean(advice), steers_tse = mean(steers_tse),
    .groups = "drop"
  ), "web_rule_behaviour")

# 7. Numbers quoted in the text --------------------------------------------------------
regex <- read_table("regex_agreement") %>%
  filter(model_key == "all")
pooled <- read_table("contrasts_pooled")
write_table(tribble(
  ~name, ~value,
  "wording_difference_pp", 100 * pooled$difference[pooled$contrast == "specific_wording"],
  "wording_difference_min_pp", 100 * pooled$min_model[pooled$contrast == "specific_wording"],
  "wording_difference_max_pp", 100 * pooled$max_model[pooled$contrast == "specific_wording"],
  "woman_difference_pp", 100 * pooled$difference[pooled$contrast == "woman"],
  "woman_difference_se_pp", 100 * pooled$se[pooled$contrast == "woman"],
  "regex_agreement_share", regex$agreement,
  "regex_kappa", regex$kappa,
  "unlabelled_share", mean(!sample$labelled),
  "web_lead_share_president", with(
    read_table("web_stability") %>% filter(office == "president"), sum(n_lead) / sum(n_advice)
  ),
  "web_lead_share_deputy", with(
    read_table("web_stability") %>% filter(office == "federal_deputy"), sum(n_lead) / sum(n_advice)
  ),
  "web_single_picks_president", sum(read_table("web_stability")$n_advice[
    read_table("web_stability")$office == "president"
  ]),
  "web_single_picks_deputy", sum(read_table("web_stability")$n_advice[
    read_table("web_stability")$office == "federal_deputy"
  ])
), "values")

# 8. Worked examples quoted in the text: the same system before and after the issue is
# added, and a disclaimer followed by a match. Ids are fixed; the text is pulled from the
# cleaned answers so the quote always matches the data. The web answers are not published,
# so this step runs only where responses_web.parquet is present; the committed table stays.
if (file.exists(derived("responses_web"))) {
answers <- bind_rows(
  read_parquet(derived("responses_api"), col_select = c("source", "response_id", "body", "answer")),
  read_parquet(derived("responses_web"), col_select = c("source", "response_id", "body", "answer"))
)
examples <- tribble(
  ~example, ~source, ~response_id,
  "issue_step_before", "api",
  "conservador_cristao_L3_homem__president_candidate__deepseek_v4_pro__r01",
  "issue_step_after", "api",
  "conservador_cristao_L4_homem__president_candidate__deepseek_v4_pro__r03",
  "disclaimer_then_match", "chatgpt_web", "3669514",
  "match_then_disclaimer", "chatgpt_web", "3941391"
)
write_table(examples %>%
  inner_join(answers, by = c("source", "response_id")) %>%
  left_join(
    sample %>% select(source, response_id, model_key, level, archetype, office, advice, pick),
    by = c("source", "response_id")
  ) %>%
  mutate(excerpt = str_squish(str_sub(answer, 1, 900))) %>%
  select(-answer), "examples")
}
message("Tables written.")
