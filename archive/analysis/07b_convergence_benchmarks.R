# Where does advice point, and does it concentrate? Convergence of recommended
# options across models and profiles, and recommendation shares next to the
# electoral benchmarks (Genial/Quaest 10-13 August 2026; 2022 São Paulo seat shares).
# Inputs: reviewed/<coder>/tables/{party,person}_recommendations_by_model.csv,
#         analysis/reference/benchmarks_2026.csv, round party scales.
# Outputs: reviewed/<coder>/tables/convergence_*, party_share_by_position,
#          benchmark_comparison; figures 10_, 11_, 12_.
# All shares are conditional on advice at L5 (full profiles). Within a model and
# profile, both question wordings pooled, an option's share is its recommendation probability divided by the sum
# over options, so multi-option answers are split rather than double counted.
# Profiles are then averaged equally, then models. The nine designed profiles are
# not a voter population: four lean right, three left, two centre.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))
status <- "Automated semantic coding without completed human validation; full profiles (attitudes added), both wordings pooled, labelled responses, conditional on advice."
export <- function(name, plot, denominator, width = 9, height = 5) {
  plot <- plot + labs(caption = str_wrap(paste(status, denominator), width = round(width * 15))) + theme_round(11)
  ggsave(file.path(result_dir, "figures", paste0(name, ".png")), plot, width = width, height = height, dpi = 180, bg = "white")
  ggsave(file.path(result_dir, "figures", paste0(name, ".pdf")), plot, width = width, height = height)
}
model_name <- function(x) factor(unname(model_labels[as.character(x)]), levels = unname(model_labels[model_levels]))

# 1. Option shares within model x profile x office --------------------------------
# Federations and residual party strings stay as named; only single parties carry a scale position.
shares <- function(table) table %>% filter(unconditional > 0) %>% group_by(model_key, archetype, office) %>%
  mutate(share = unconditional / sum(unconditional), n_options = n()) %>% ungroup()
# Only acronyms or acronym federations count as parties; free-text strings such as
# "centro ou centro-direita" are the answer's phrasing, not an option.
party_shares <- shares(read_result("party_recommendations_by_model") %>% filter(str_detect(entity, "^[A-Z]{2,13}(-[A-Z]{2,13})?$")))
person_shares <- shares(read_result("person_recommendations_by_model"))

# 2. Convergence: does each model pick one option, and do models pick the same one? -
concentration <- function(s) s %>% group_by(model_key, archetype, office) %>%
  summarise(advice_rate = first(advice_rate), n_options = first(n_options),
    top_option = entity[which.max(share)], top_share = max(share), hhi = sum(share^2), .groups = "drop")
convergence_party <- concentration(party_shares) %>% mutate(unit = "party")
convergence_person <- concentration(person_shares) %>% mutate(unit = "person")
convergence <- bind_rows(convergence_party, convergence_person)
write_result(convergence, "convergence_by_model_profile")
# Across models: the modal top option and the share of advice-giving models that share it.
convergence_pooled <- convergence %>% group_by(unit, archetype, office) %>%
  summarise(n_models = n(), modal_top_option = names(which.max(table(top_option))),
    models_agreeing = mean(top_option == modal_top_option), mean_top_share = mean(top_share),
    mean_hhi = mean(hhi), effective_options = 1 / mean(hhi),
    models = paste(sort(as.character(model_key)), collapse = "|"), .groups = "drop")
write_result(convergence_pooled, "convergence_pooled")

# 3. Same position, same treatment? Party shares against the Zucco-Power scale -----
# Sides follow Neto's 2022 coalitions; the two centre profiles are shown separately.
side <- c(militante_esquerda = "Left profiles", progressista = "Left profiles", classes_d_e = "Left profiles",
  liberal_social = "Centre profiles", empreendedor_individual = "Centre profiles",
  conservador_cristao = "Right profiles", agro = "Right profiles", empresario = "Right profiles", extrema_direita = "Right profiles")
scales <- load_party_scales() %>% select(party, zeta_zucco_power)
# Equal weight per advice-giving profile within a model, then equal advice-giving
# models, so shares sum to one within each side and office.
pool_shares <- function(s, ...) s %>% group_by(model_key, ..., office) %>% mutate(n_profiles = n_distinct(archetype)) %>%
  group_by(model_key, ..., office, entity) %>% summarise(share = sum(share) / first(n_profiles), .groups = "drop") %>%
  group_by(..., office) %>% mutate(n_models = n_distinct(model_key)) %>%
  group_by(..., office, entity) %>% summarise(share = sum(share) / first(n_models), n_models = n(), .groups = "drop")
by_position <- party_shares %>% mutate(side = unname(side[archetype])) %>% pool_shares(side) %>%
  left_join(scales, by = c("entity" = "party")) %>% arrange(office, side, desc(share))
write_result(by_position, "party_share_by_position")

labelled <- by_position %>% filter(!is.na(zeta_zucco_power), share >= .03) %>%
  mutate(side = factor(side, levels = c("Left profiles", "Centre profiles", "Right profiles")))
p <- ggplot(labelled, aes(zeta_zucco_power, share)) + geom_vline(xintercept = 0, color = "grey80") +
  geom_point(color = palette[["navy"]], size = 2.2) + ggrepel::geom_text_repel(aes(label = entity), size = 2.6, color = palette[["ink"]], max.overlaps = 30, min.segment.length = 0, box.padding = .35) +
  facet_grid(office ~ side, labeller = labeller(office = c(president = "President", federal_deputy = "Federal deputy, SP"))) +
  scale_y_continuous(labels = scales::label_percent()) + scale_x_continuous(limits = c(-1, 1)) +
  labs(x = "Party position, Zucco-Power scale (left to right)", y = "Share of recommended options")
export("10_party_share_by_position", p, "Parties with at least 3% of recommended options and a scale position. A model's shares within a profile sum to one; profiles then models weighted equally.", width = 11, height = 6)

# 4. Convergence exhibit: top option share per model and profile -------------------
p <- convergence %>% filter(unit == "party") %>% mutate(model = model_name(model_key), profile = unname(archetype_labels[archetype]),
    office = recode(office, president = "President", federal_deputy = "Federal deputy, SP")) %>%
  ggplot(aes(top_share, profile, color = office)) + geom_point(position = position_dodge(width = .5), size = 2) +
  facet_wrap(~model, nrow = 2) + scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
  scale_color_manual(values = c(President = palette[["navy"]], `Federal deputy, SP` = palette[["coral"]])) +
  labs(x = "Share of recommended parties going to the top party", y = NULL, color = NULL)
export("11_convergence_top_party", p, "One point per model and full profile; 100% means every recommended option in that profile was one party. Only model-profile pairs with any advice appear.", width = 13, height = 6)

# 5. Recommendations next to the electoral benchmarks ----------------------------
benchmarks <- readr::read_csv(file.path(analysis_dir, "reference", "benchmarks_2026.csv"), show_col_types = FALSE)
# The nine profiles are not an electorate. For the comparison with polls and results
# they are weighted by each segment's share of the population in Neto's (2024) cluster
# model, so the recommendation share reads as "if each segment asked in proportion to
# its size". Within a model, profiles without advice drop out and the remaining weights
# are renormalized; models are then weighted equally. The equal-profile version is kept
# as a comparison series.
population <- readr::read_csv(file.path(analysis_dir, "reference", "archetype_population_shares.csv"), show_col_types = FALSE) %>% select(archetype, population_share)
stopifnot(abs(sum(population$population_share) - 1) < 1e-9, setequal(population$archetype, archetype_levels))
pool_weighted <- function(s) s %>% inner_join(population, by = "archetype") %>%
  group_by(model_key, office) %>% mutate(weight = population_share / sum(population_share[!duplicated(archetype)])) %>%
  group_by(model_key, office, entity) %>% summarise(share = sum(share * weight), .groups = "drop") %>%
  group_by(office) %>% mutate(n_models = n_distinct(model_key)) %>%
  group_by(office, entity) %>% summarise(share = sum(share) / first(n_models), n_models = n(), .groups = "drop")
# Third series: the distribution of all advice given, so a model counts in proportion to
# how often it advises (profiles still weighted by population share). Each model-profile
# cell contributes its conditional option shares (which sum to one, so shortlists are
# split rather than double counted) times its advice probability; the denominator is
# the advice probability summed over the same population-weighted cells.
pool_advice_weighted <- function(s) {
  s <- s %>% inner_join(population, by = "archetype")
  denominator <- s %>% distinct(model_key, office, archetype, advice_rate, population_share) %>% group_by(office) %>%
    summarise(total_advice = sum(advice_rate * population_share), .groups = "drop")
  s %>% group_by(office, entity) %>% summarise(mass = sum(share * advice_rate * population_share), .groups = "drop") %>%
    inner_join(denominator, by = "office") %>% transmute(office, entity, share = mass / total_advice)
}
options <- bind_rows(person_shares %>% filter(office == "president"), party_shares %>% filter(office == "federal_deputy"))
recommended <- pool_weighted(options) %>% rename(race = office, recommended = share) %>%
  full_join(pool_shares(options) %>% transmute(race = office, entity, recommended_equal = share), by = c("race", "entity")) %>%
  full_join(pool_advice_weighted(options) %>% transmute(race = office, entity, recommended_advice_weighted = share), by = c("race", "entity"))
comparison <- benchmarks %>% select(race, entity, label, benchmark = share, source) %>%
  full_join(recommended, by = c("race", "entity")) %>%
  mutate(across(c(recommended, recommended_equal, recommended_advice_weighted), ~replace_na(.x, 0)), label = coalesce(label, if_else(race == "president", str_to_title(entity), entity))) %>%
  arrange(race, desc(benchmark), desc(recommended))
write_result(comparison, "benchmark_comparison")
shown <- comparison %>% filter(!is.na(benchmark) | recommended >= .02 | recommended_equal >= .02 | recommended_advice_weighted >= .02) %>%
  mutate(race = recode(race, president = "President: Genial/Quaest, 10-13 Aug 2026", federal_deputy = "Federal deputy, SP: 2022 seat share"),
    benchmark = replace_na(benchmark, 0)) %>%
  pivot_longer(c(recommended, recommended_equal, recommended_advice_weighted, benchmark), names_to = "series", values_to = "value") %>%
  mutate(series = factor(recode(series, recommended = "AI recommendations: models equal, profiles by population share",
    recommended_equal = "AI recommendations: models equal, profiles equal",
    recommended_advice_weighted = "AI recommendations: share of all advice given (models by how often they advise, profiles by population share)",
    benchmark = "Poll or election benchmark"),
    levels = c("Poll or election benchmark", "AI recommendations: models equal, profiles by population share",
      "AI recommendations: share of all advice given (models by how often they advise, profiles by population share)", "AI recommendations: models equal, profiles equal")))
series_colors <- c(`Poll or election benchmark` = palette[["gold"]], `AI recommendations: models equal, profiles by population share` = palette[["navy"]],
  `AI recommendations: share of all advice given (models by how often they advise, profiles by population share)` = palette[["teal"]],
  `AI recommendations: models equal, profiles equal` = "grey60")
series_shapes <- setNames(c(16, 16, 17, 1), names(series_colors))
p <- shown %>% group_by(race) %>% mutate(label = reorder(label, value, FUN = max)) %>% ungroup() %>%
  ggplot(aes(value, label, color = series, shape = series)) + geom_point(size = 2.4, position = position_dodge(width = .6)) + facet_wrap(~race, scales = "free_y") +
  scale_x_continuous(labels = scales::label_percent()) + scale_color_manual(values = series_colors) + scale_shape_manual(values = series_shapes) +
  labs(x = NULL, y = NULL, color = NULL, shape = NULL) + guides(color = guide_legend(nrow = 4))
export("12_recommendations_vs_benchmarks", p, "Recommendation shares are conditional on advice at the full profile, both wordings; profiles weighted by Neto's population shares (Christian conservatives 27%, state-dependent 23%, agribusiness 13%, progressives 11%, left activists 7%, business owners 6%, social liberals 5%, solo entrepreneurs 5%, far right 3%), configurations equally (navy) or in proportion to how often they advise (teal). Not a forecast. Poll shares are of all respondents; seat shares are of 71 listed.", width = 12, height = 7)
# 6. Refusal grounds by configuration, specific-candidate wording -----------------
coding <- read_parquet(derived_path("coding_analysis")) %>% filter(label_status == "labelled")
meta <- read_parquet(derived_path("responses"), col_select = c("source", "response_id", "model_key", "condition_id", "question_id", "ask", "run_date"))
grounds <- coding %>% inner_join(meta, by = c("source", "response_id")) %>% filter(ask == "candidate") %>%
  count(model_key, condition_id, question_id, run_date, refusal_grounds) %>% group_by(model_key, condition_id, question_id, run_date) %>%
  mutate(share = n / sum(n)) %>% ungroup() %>% complete(nesting(model_key, condition_id, question_id, run_date), refusal_grounds = grounds_levels, fill = list(share = 0)) %>%
  group_by(model_key, condition_id, question_id, refusal_grounds) %>% summarise(share = mean(share), .groups = "drop") %>%
  group_by(model_key, refusal_grounds) %>% summarise(share = mean(share), .groups = "drop")
write_result(grounds, "refusal_grounds_by_model")
message("Convergence and benchmark tables written to ", result_dir)
