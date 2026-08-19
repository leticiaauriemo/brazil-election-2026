source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]), winslash = "/")), "R", "utils.R"))

summary_path <- file.path(derived_dir, "summary_tables.rds")
if (!file.exists(summary_path)) stop("Run 02_summarize_results.R first.")
t <- readRDS(summary_path)

label_models <- function(x) factor(unname(model_labels[as.character(x)]), levels = rev(unname(model_labels[model_levels])))
percent_axis <- scales::label_percent(accuracy = 1)
pp_axis <- scales::label_percent(accuracy = 1, suffix = " pp", scale = 100)

key_outcomes <- c("explicit_refusal", "person_mention", "single_best_match")
key_labels <- c(
  explicit_refusal = "Explicit refusal",
  person_mention = "Named political figure",
  single_best_match = "Single best match"
)
key_colors <- c(
  "Explicit refusal" = palette[["coral"]],
  "Named political figure" = palette[["blue"]],
  "Single best match" = palette[["teal"]]
)

p <- t$model_outcomes %>%
  filter(outcome %in% key_outcomes) %>%
  mutate(model = label_models(model_key), metric = unname(key_labels[outcome])) %>%
  ggplot(aes(rate, model, color = metric)) +
  geom_point(size = 3.2) +
  scale_x_continuous(labels = percent_axis, limits = c(0, 1), breaks = seq(0, 1, .2)) +
  scale_color_manual(values = key_colors) +
  labs(title = "Models follow sharply different response policies", x = "Share of complete responses", y = NULL,
       caption = "Single-best-match is a deliberately high-precision text indicator; it is not a full semantic classifier.") +
  theme_round()
save_plot("01_model_outcomes.png", p)

style_levels <- c(
  "Single best match", "Best match despite refusal", "Person/shortlist",
  "Refusal + named person", "Refusal, no person", "Party only", "No named person or party"
)
style_colors <- c(
  "Single best match" = palette[["teal"]], "Best match despite refusal" = "#74C0B3",
  "Person/shortlist" = palette[["blue"]], "Refusal + named person" = palette[["gold"]],
  "Refusal, no person" = palette[["coral"]], "Party only" = "#8EA6BF",
  "No named person or party" = palette[["light"]]
)
p <- t$style_by_model %>%
  mutate(model = label_models(model_key), response_style = factor(response_style, levels = style_levels)) %>%
  ggplot(aes(rate, model, fill = response_style)) +
  geom_col(width = .72) +
  scale_x_continuous(labels = percent_axis, expand = expansion(mult = c(0, .01))) +
  scale_fill_manual(values = style_colors, drop = FALSE) +
  labs(title = "A refusal often still contains political names", x = "Composition of complete responses", y = NULL) +
  theme_round(11) + theme(legend.position = "bottom", legend.box = "vertical")
save_plot("02_response_styles.png", p)

p <- t$level_outcomes %>%
  filter(outcome %in% key_outcomes) %>%
  mutate(metric = unname(key_labels[outcome])) %>%
  ggplot(aes(level, rate, color = metric, group = metric)) +
  geom_line(linewidth = 1.1) + geom_point(size = 3) +
  scale_y_continuous(labels = percent_axis, limits = c(0, .85)) +
  scale_color_manual(values = key_colors) +
  labs(title = "Issue information restores specificity; rich profiles amplify it", x = "Information level", y = "Share of complete responses",
       caption = "L1 geography only; L2 issue priority; L3 biography; L4 biography + issue; L5 full profile.") +
  theme_round()
save_plot("03_information_ladder.png", p)

p <- t$model_level_outcomes %>%
  filter(outcome == "person_mention") %>%
  mutate(model = label_models(model_key)) %>%
  ggplot(aes(level, model, fill = rate)) +
  geom_tile(color = "white", linewidth = .7) +
  geom_text(aes(label = scales::percent(rate, accuracy = 1)), size = 3.2, color = palette[["ink"]]) +
  scale_fill_gradient(low = "#F3F6F8", high = palette[["blue"]], labels = percent_axis) +
  labs(title = "The information ladder interacts with model policy", x = "Information level", y = NULL, fill = NULL) +
  theme_round()
save_plot("04_level_by_model_heatmap.png", p)

p <- t$ask_contrasts %>%
  filter(outcome %in% key_outcomes) %>%
  mutate(model = label_models(model_key), metric = unname(key_labels[outcome])) %>%
  ggplot(aes(candidate_minus_open, model, color = metric)) +
  geom_vline(xintercept = 0, color = palette[["grey"]], linewidth = .5) +
  geom_point(size = 2.8) +
  facet_wrap(~metric, nrow = 1, scales = "free_x") +
  scale_x_continuous(labels = pp_axis) +
  scale_color_manual(values = key_colors, guide = "none") +
  labs(title = "Asking for a specific candidate triggers more refusal—and fewer names", x = "Explicit-candidate ask minus open ask", y = NULL) +
  theme_round(10)
save_plot("05_ask_contrasts.png", p)

p <- t$office_contrasts %>%
  filter(outcome %in% key_outcomes) %>%
  mutate(model = label_models(model_key), metric = unname(key_labels[outcome])) %>%
  ggplot(aes(president_minus_deputy, model, color = metric)) +
  geom_vline(xintercept = 0, color = palette[["grey"]], linewidth = .5) +
  geom_point(size = 2.8) +
  facet_wrap(~metric, nrow = 1, scales = "free_x") +
  scale_x_continuous(labels = pp_axis) +
  scale_color_manual(values = key_colors, guide = "none") +
  labs(title = "Presidential answers name people much more often", x = "President minus federal deputy", y = NULL) +
  theme_round(10)
save_plot("06_office_contrasts.png", p)

p <- t$layer_contrasts %>%
  filter(outcome %in% c("explicit_refusal", "person_mention")) %>%
  mutate(
    model = label_models(model_key),
    metric = recode(outcome, explicit_refusal = "Explicit refusal", person_mention = "Named political figure")
  ) %>%
  ggplot(aes(mean_difference, model, color = metric)) +
  geom_vline(xintercept = 0, color = palette[["grey"]], linewidth = .5) +
  geom_point(size = 2.8) +
  facet_grid(metric ~ contrast, scales = "free_x") +
  scale_x_continuous(labels = pp_axis) +
  scale_color_manual(values = key_colors, guide = "none") +
  labs(title = "Issue and rich-profile increments are concentrated in advice-giving models", x = "Mean within-cell change", y = NULL) +
  theme_round(9)
save_plot("07_layer_contrasts.png", p, height = 6.1)

p <- t$gender_contrasts %>%
  filter(outcome %in% c("explicit_refusal", "person_mention")) %>%
  mutate(model = label_models(model_key), metric = unname(key_labels[outcome])) %>%
  ggplot(aes(diff_woman_minus_man, model, color = metric)) +
  geom_vline(xintercept = 0, color = palette[["grey"]], linewidth = .5) +
  geom_point(size = 2.8) +
  facet_wrap(~metric, nrow = 1) +
  scale_x_continuous(labels = pp_axis, limits = c(-.08, .08)) +
  scale_color_manual(values = key_colors, guide = "none") +
  labs(title = "Gender differences are small relative to model and information effects", x = "Woman minus man (L3–L5)", y = NULL) +
  theme_round(10)
save_plot("08_gender_contrasts.png", p)

p <- t$party_archetype %>%
  mutate(
    archetype_label = factor(unname(archetype_labels[as.character(archetype)]), levels = rev(unname(archetype_labels[archetype_levels]))),
    party = forcats::fct_reorder(party, rate, .fun = sum)
  ) %>%
  ggplot(aes(party, archetype_label, fill = rate)) +
  geom_tile(color = "white", linewidth = .6) +
  geom_text(aes(label = ifelse(rate >= .08, scales::percent(rate, accuracy = 1), "")), size = 2.8) +
  scale_fill_gradient(low = "#F5F7F9", high = palette[["teal"]], labels = percent_axis) +
  labs(title = "Full profiles produce a recognizable party map", x = NULL, y = NULL, fill = NULL,
       caption = "Share of complete L5 responses mentioning each party; mentions are not necessarily endorsements.") +
  theme_round(10) + theme(axis.text.x = element_text(angle = 35, hjust = 1))
save_plot("09_party_archetype_heatmap.png", p, height = 6.1)

p <- t$person_archetype %>%
  mutate(
    archetype_label = factor(unname(archetype_labels[as.character(archetype)]), levels = rev(unname(archetype_labels[archetype_levels]))),
    person = forcats::fct_reorder(person, rate, .fun = sum)
  ) %>%
  ggplot(aes(person, archetype_label, fill = rate)) +
  geom_tile(color = "white", linewidth = .6) +
  geom_text(aes(label = ifelse(rate >= .08, scales::percent(rate, accuracy = 1), "")), size = 2.7) +
  scale_fill_gradient(low = "#F5F7F9", high = palette[["blue"]], labels = percent_axis) +
  labs(title = "Presidential mappings polarize around a small candidate set", x = NULL, y = NULL, fill = NULL,
       caption = "Share of complete presidential L5 responses mentioning each figure; mentions are not necessarily endorsements.") +
  theme_round(9) + theme(axis.text.x = element_text(angle = 38, hjust = 1))
save_plot("10_candidate_archetype_heatmap.png", p, height = 6.1)

p <- t$repetition_stability %>%
  select(model_key, party_exact_stability, person_exact_stability) %>%
  pivot_longer(-model_key, names_to = "signature", values_to = "rate") %>%
  mutate(
    model = label_models(model_key),
    signature = recode(signature, party_exact_stability = "Identical party set", person_exact_stability = "Identical person set")
  ) %>%
  ggplot(aes(rate, model, color = signature)) +
  geom_point(size = 3) +
  scale_x_continuous(labels = percent_axis, limits = c(0, .9)) +
  scale_color_manual(values = c("Identical party set" = palette[["teal"]], "Identical person set" = palette[["blue"]])) +
  labs(title = "Advice-giving models vary substantially across five repetitions", x = "Cells with the exact same mention set in all five runs", y = NULL) +
  theme_round()
save_plot("11_repetition_stability.png", p)

p <- t$operations %>%
  mutate(model = unname(model_labels[as.character(model_key)])) %>%
  ggplot(aes(median_latency, citation_rate, label = model, size = median_words)) +
  geom_point(color = palette[["teal"]], alpha = .75) +
  ggrepel::geom_text_repel(size = 3.3, color = palette[["ink"]], max.overlaps = Inf, seed = 20260814) +
  scale_y_continuous(labels = percent_axis, limits = c(0, 1.03)) +
  scale_size_continuous(range = c(3, 9)) +
  labs(title = "Citation-rich answers can be expensive in latency", x = "Median latency (seconds)", y = "Responses with at least one citation", size = "Median words",
       caption = "Citation presence is observable; OpenRouter does not report verified search-use telemetry in these files.") +
  theme_round()
save_plot("12_citations_latency.png", p)

p <- t$model_outcomes %>%
  filter(outcome == "stale_timing") %>%
  mutate(model = label_models(model_key)) %>%
  ggplot(aes(rate, model)) +
  geom_col(fill = palette[["coral"]], width = .65) +
  geom_text(aes(label = scales::percent(rate, accuracy = 1)), hjust = -.1, size = 3.2) +
  scale_x_continuous(labels = percent_axis, limits = c(0, .52), expand = expansion(mult = c(0, .02))) +
  labs(title = "Llama frequently answered as if the 2026 field were not yet defined", x = "Stale election-timing claim", y = NULL) +
  theme_round()
save_plot("13_stale_timing.png", p)

p <- t$operations %>%
  filter(cost_known_n > 0) %>%
  mutate(model = label_models(model_key)) %>%
  ggplot(aes(total_cost_usd, model)) +
  geom_col(fill = palette[["navy"]], width = .65) +
  geom_text(aes(label = scales::dollar(total_cost_usd, accuracy = 1)), hjust = -.08, size = 3.1) +
  scale_x_continuous(labels = scales::label_dollar(), expand = expansion(mult = c(0, .13))) +
  labs(title = "Observed OpenRouter cost varies by almost two orders of magnitude", x = "Total reported cost for 1,280 responses", y = NULL,
       caption = "Maritaca/Sabiá cost is not present in the raw usage metadata and is therefore omitted.") +
  theme_round()
save_plot("14_cost_by_model.png", p)

p <- t$archetype_level_outcomes %>%
  filter(level == "L5", outcome %in% c("explicit_refusal", "person_mention")) %>%
  mutate(
    archetype_label = factor(unname(archetype_labels[as.character(archetype)]), levels = rev(unname(archetype_labels[archetype_levels]))),
    metric = recode(outcome, explicit_refusal = "Explicit refusal", person_mention = "Named political figure")
  ) %>%
  ggplot(aes(rate, archetype_label, color = metric)) +
  geom_point(size = 3.4) +
  scale_x_continuous(labels = percent_axis, limits = c(0, .85), breaks = seq(0, .8, .2)) +
  scale_color_manual(values = key_colors) +
  labs(title = "Right-coded full profiles are not refused more - they elicit more names", x = "Share of complete L5 responses", y = NULL,
       caption = "Descriptive profile bundles, not a causal left-right manipulation.") +
  theme_round()
save_plot("15_l5_profile_outcomes.png", p)

p <- t$archetype_level_outcomes %>%
  filter(outcome == "explicit_refusal") %>%
  mutate(
    archetype_label = factor(unname(archetype_labels[as.character(archetype)]), levels = rev(unname(archetype_labels[archetype_levels]))),
    level = factor(level, levels = c("L2", "L4", "L5"))
  ) %>%
  ggplot(aes(rate, archetype_label, color = level)) +
  geom_point(size = 3.1, position = position_dodge(width = .45)) +
  scale_x_continuous(labels = percent_axis, limits = c(.45, .80), breaks = seq(.45, .80, .05)) +
  scale_color_manual(values = c(L2 = palette[["grey"]], L4 = palette[["gold"]], L5 = palette[["coral"]])) +
  labs(title = "No information level shows systematically higher refusal for the right", x = "Explicit-refusal rate", y = NULL, color = "Information level") +
  theme_round()
save_plot("16_refusal_by_archetype_level.png", p)

p <- t$model_archetype_l5_outcomes %>%
  filter(outcome == "explicit_refusal") %>%
  mutate(
    model = label_models(model_key),
    archetype_label = factor(unname(archetype_labels[as.character(archetype)]), levels = unname(archetype_labels[archetype_levels]))
  ) %>%
  ggplot(aes(archetype_label, model, fill = rate)) +
  geom_tile(color = "white", linewidth = .65) +
  geom_text(aes(label = scales::percent(rate, accuracy = 1)), size = 2.8, color = palette[["ink"]]) +
  scale_fill_gradient(low = "#F8F4F1", high = palette[["coral"]], labels = percent_axis) +
  labs(title = "Archetype differences are concentrated in advice-giving models", x = NULL, y = NULL, fill = "Refusal") +
  theme_round(9) + theme(axis.text.x = element_text(angle = 36, hjust = 1))
save_plot("17_l5_refusal_heatmap.png", p, height = 6.1)

p <- t$archetype_layer_contrasts %>%
  filter(contrast == "L4-L3", outcome %in% c("explicit_refusal", "person_mention")) %>%
  mutate(
    archetype_label = factor(unname(archetype_labels[as.character(archetype)]), levels = rev(unname(archetype_labels[archetype_levels]))),
    metric = recode(outcome, explicit_refusal = "Explicit refusal", person_mention = "Named political figure")
  ) %>%
  ggplot(aes(mean_difference, archetype_label, color = metric)) +
  geom_vline(xintercept = 0, color = palette[["grey"]], linewidth = .5) +
  geom_point(size = 3.2) +
  facet_wrap(~metric, nrow = 1, scales = "free_x") +
  scale_x_continuous(labels = pp_axis) +
  scale_color_manual(values = key_colors, guide = "none") +
  labs(title = "Adding the political priority has the largest effect for right-coded profiles", x = "L4 minus L3, averaged across matched cells", y = NULL,
       caption = "This may reflect clearer candidate-field mapping, not ideological favoritism.") +
  theme_round(10)
save_plot("18_issue_effect_by_archetype.png", p)

message("Generated 18 presentation-ready figures in ", figures_dir, ".")
