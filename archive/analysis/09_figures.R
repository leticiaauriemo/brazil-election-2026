# Draw a candidate set of reader-facing exhibits, not a preselected narrative.
# Inputs: reviewed/<coder>/tables. Outputs: reviewed/<coder>/figures and captions.
# Every chart states its denominator. Model panels retain heterogeneity; figures
# are descriptive for the constructed prompts and remain provisional without
# held-out human validation. Small multiples use common axes.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))
focus <- c("gpt56_luna", "chatgpt_web", "gemini_pro", "claude_sonnet5", "grok46")
model_name <- function(x) factor(unname(model_labels[as.character(x)]), levels = rev(unname(model_labels[model_levels])))
status <- if (main_coder == "regex") "Provisional regex coding; human validation pending." else "Automated semantic coding without completed human validation; specific-candidate wording; unlabelled responses excluded from rates."
base_caption <- paste(status, "Equal dates within prompt; equal prompts within model. Constructed profiles, not voter prevalence.")
captions <- tibble(figure = character(), question = character(), denominator = character())
export <- function(name, plot, question, denominator, width = 9, height = 5) {
  plot <- plot + labs(caption = stringr::str_wrap(paste(status, denominator), width = round(width * 15))) + theme_round(11)
  if (startsWith(name, "07_")) plot <- plot + theme(axis.text.x = element_text(angle = 50, hjust = 1, size = 8), panel.grid.major.x = element_blank())
  ggsave(file.path(result_dir, "figures", paste0(name, ".png")), plot, width = width, height = height, dpi = 180, bg = "white")
  ggsave(file.path(result_dir, "figures", paste0(name, ".pdf")), plot, width = width, height = height)
  captions <<- bind_rows(captions, tibble(figure = name, question = question, denominator = denominator))
}

# 1. Whole panel overview: independent disclaimers beside positive advice ---------
rates <- read_result("rates_by_model")
p <- rates %>% filter(outcome %in% c("gives_advice", "explicit_endorsement", "refusal_language")) %>%
  mutate(model = model_name(model_key), measure = recode(outcome, gives_advice = "Any positive advice",
    explicit_endorsement = "Explicit endorsement", refusal_language = "Refusal language")) %>%
  ggplot(aes(rate, model, color = measure)) + geom_point(position = position_dodge(width = .45), size = 2.5) +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) + labs(x = "Share of coded responses", y = NULL, color = NULL)
export("01_advice_and_disclaimers", p, "What happens when voters request advice?", "Within-model standardized response shares among labelled responses. Flags can overlap.")
# Advice rate with its 95% interval across prompt cells; the share of unlabelled responses is printed beside it.
p <- rates %>% filter(outcome %in% c("gives_advice", "not_coded")) %>%
  select(model_key, outcome, rate, se) %>% pivot_wider(names_from = outcome, values_from = c(rate, se)) %>% mutate(model = model_name(model_key)) %>%
  ggplot(aes(y = model)) + geom_errorbarh(aes(xmin = rate_gives_advice - 1.96 * se_gives_advice, xmax = rate_gives_advice + 1.96 * se_gives_advice), height = 0, color = "grey55") +
  geom_point(aes(x = rate_gives_advice), color = palette[["navy"]], size = 2.5) +
  geom_text(aes(x = rate_gives_advice + 1.96 * se_gives_advice, label = scales::percent(rate_not_coded, accuracy = 1)), hjust = -.3, size = 2.8, color = palette[["grey"]]) +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1.05)) + labs(x = "Probability of positive advice", y = NULL)
export("01b_advice_with_missing_bounds", p, "How often does each configuration advise?", "Point: share of labelled responses with positive advice; whiskers: 95% interval across prompt cells. Label: share of responses without a semantic label.")
# The ladder as levels: L1 bare, L2 issue only, L3 biography only, L4 both, L5 attitudes added.
level_rates <- read_result("rates_by_level")
p <- level_rates %>% filter(outcome == "gives_advice") %>% select(model_key, level, gives_advice = rate, se) %>%
  mutate(model = factor(unname(model_labels[model_key]), levels = unname(model_labels[model_levels])),
    level = factor(level, levels = level_order, labels = str_replace(unname(level_labels[level_order]), "Biography \\+ issue", "Bio +\nissue"))) %>%
  ggplot(aes(level, gives_advice, group = model)) + geom_ribbon(aes(ymin = pmax(gives_advice - 1.96 * se, 0), ymax = pmin(gives_advice + 1.96 * se, 1)), fill = "grey80", alpha = .6) +
  geom_line(color = palette[["navy"]]) + geom_point(color = palette[["navy"]], size = 1.8) + facet_wrap(~model, nrow = 3) +
  scale_y_continuous(labels = scales::label_percent(), limits = c(0, 1)) + labs(x = "What the voter reveals", y = "Probability of positive advice")
export("03_information_ladder_levels", p, "Which information triggers advice: the issue or the person?", "Biography and issue are separate additions to the bare question; the last two conditions add the issue to the biography, then attitudes and identities. Band: 95% interval across prompt cells.", width = 12, height = 7.5)
p <- read_result("categories_by_model") %>% mutate(model = model_name(model_key), category = unname(category_labels[response_category])) %>%
  ggplot(aes(share, model, fill = category)) + geom_col() + scale_x_continuous(labels = scales::label_percent()) +
  labs(x = "Share of coded responses", y = NULL, fill = NULL) + guides(fill = guide_legend(nrow = 3))
export("02_response_categories", p, "What help does each configuration provide?", "Mutually exclusive categories; independent flags reported separately.", height = 6)

# 2. Show the branches of personalization as before/after rates -------------------
contrasts <- read_result("contrasts_by_model")
contrast_labels <- c(issue_added_to_biography = "Add issue to biography", biography_added_to_issue = "Add biography to issue",
  attitudes_added_to_biography_and_issue = "Add attitudes and identities", specific_candidate_minus_open = "Ask for a specific candidate",
  deputy_minus_president = "President to federal deputy", woman_minus_man = "Man to woman", issue_added_to_state = "Add issue to state")
for (panel in c("focus", "all")) {
  p <- contrasts %>% filter(outcome == "gives_advice", contrast %in% names(contrast_labels)[1:3]) %>%
    filter(panel == "all" | model_key %in% focus) %>% mutate(model = model_name(model_key), contrast = unname(contrast_labels[contrast])) %>%
    ggplot(aes(y = model)) + geom_segment(aes(x = baseline, xend = treatment, yend = model), color = "grey65") +
    geom_point(aes(x = baseline, color = "Before"), size = 2.3) + geom_point(aes(x = treatment, color = "After"), size = 2.3) +
    scale_color_manual(values = c(Before = "#2A9D8F", After = "#E76F51"), breaks = c("Before", "After")) +
    facet_wrap(~contrast, nrow = 1) + scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
    labs(x = "Probability of positive advice", y = NULL, color = NULL)
  export(paste0("03_personal_information_", panel), p, "When does personal information unlock advice or restraint?", "Matched prompts within each model. Lines connect condition averages, not paired executions.", width = 12, height = if (panel == "all") 6 else 4.5)
}

# 3. Office and ordinary question wording ---------------------------------------
p <- read_result("rates_by_office") %>% filter(outcome %in% c("single_named", "shortlist", "party_only")) %>%
  mutate(model = model_name(model_key), office = recode(office, president = "President", federal_deputy = "Federal deputy, São Paulo"),
    form = recode(outcome, single_named = "One named person", shortlist = "Several named people", party_only = "Party without a named person")) %>%
  ggplot(aes(rate, model, fill = form)) + geom_col() + facet_wrap(~office) + scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
  labs(x = "Share of all coded responses", y = NULL, fill = NULL) + guides(fill = guide_legend(nrow = 2))
export("04_office_and_specificity", p, "How does advice differ down-ballot?", "Bar length gives positive advice probability. Number of names is specificity, not endorsement strength.", width = 10)
p <- contrasts %>% filter(outcome == "gives_advice", contrast %in% c("specific_candidate_minus_open", "woman_minus_man")) %>%
  mutate(model = model_name(model_key), contrast = unname(contrast_labels[contrast])) %>% ggplot(aes(difference, model)) +
  geom_vline(xintercept = 0, color = "grey70") + geom_errorbarh(aes(xmin = conf_low, xmax = conf_high), height = 0, color = "grey55") +
  geom_point(color = palette[["navy"]]) + facet_wrap(~contrast) +
  scale_x_continuous(labels = function(x) paste0(round(100*x), " pp")) + labs(x = "Change in positive advice probability", y = NULL)
export("05_wording_and_gender", p, "Do ordinary wording and gender changes matter?", "Matched mean differences with 95% intervals from the across-pair standard error, separately by model; no population-voter inference.")
# The ladder steps as coefficients with intervals.
p <- contrasts %>% filter(outcome == "gives_advice", contrast %in% c("issue_added_to_state", "issue_added_to_biography", "attitudes_added_to_biography_and_issue", "biography_added_to_issue")) %>%
  mutate(model = model_name(model_key), contrast = factor(unname(contrast_labels[contrast]), levels = unname(contrast_labels[c("issue_added_to_state", "issue_added_to_biography", "biography_added_to_issue", "attitudes_added_to_biography_and_issue")]))) %>%
  ggplot(aes(difference, model)) + geom_vline(xintercept = 0, color = "grey70") +
  geom_errorbarh(aes(xmin = conf_low, xmax = conf_high), height = 0, color = "grey55") + geom_point(color = palette[["navy"]]) +
  facet_wrap(~contrast, nrow = 1) + scale_x_continuous(labels = function(x) paste0(round(100*x), " pp")) + labs(x = "Change in positive advice probability", y = NULL)
export("03c_ladder_contrasts_ci", p, "How large are the information effects, with uncertainty?", "Matched mean differences with 95% intervals from the across-pair standard error. Specific-candidate wording.", width = 13, height = 4.8)
# Regression coefficients, one linear probability model per configuration, cell-clustered errors.
reg <- read_result("regression_by_model") %>% filter(outcome == "gives_advice") %>%
  mutate(model = model_name(model_key), term_label = factor(term_label, levels = c("Bare question (vs biography only)", "Issue only (vs biography only)",
    "Biography and issue (vs biography only)", "Attitudes added (vs biography only)", "Federal deputy (vs president)", "Specific-candidate wording (vs open)", "Woman (vs man)")))
p <- ggplot(reg, aes(estimate, model)) + geom_vline(xintercept = 0, color = "grey70") +
  geom_errorbarh(aes(xmin = conf_low, xmax = conf_high), height = 0, color = "grey55") + geom_point(color = palette[["navy"]]) +
  facet_wrap(~term_label, nrow = 2, labeller = label_wrap_gen(28)) + scale_x_continuous(labels = function(x) paste0(round(100*x), " pp")) +
  labs(x = "Coefficient, linear probability model for positive advice", y = NULL)
export("17_regression_coefficients", p, "Regression view: which prompt features move advice, by configuration?", "One OLS per configuration on labelled responses, both wordings: level dummies (biography-only reference), office, wording, gender. 95% intervals, standard errors clustered by prompt.", width = 13, height = 7)
# The wording exhibit as levels: open question on the left, specific-candidate question on the right.
p <- contrasts %>% filter(outcome %in% c("gives_advice", "refusal_language"), contrast == "specific_candidate_minus_open") %>%
  mutate(model = model_name(model_key), outcome = recode(outcome, gives_advice = "Positive advice", refusal_language = "Refusal language")) %>%
  ggplot(aes(y = model)) + geom_segment(aes(x = baseline, xend = treatment, yend = model), color = "grey65") +
  geom_point(aes(x = baseline, color = "Open: 'Em quem devo votar'"), size = 2.3) + geom_point(aes(x = treatment, color = "Specific: 'Em qual candidato específico'"), size = 2.3) +
  scale_color_manual(values = setNames(c(palette[["teal"]], palette[["coral"]]), c("Open: 'Em quem devo votar'", "Specific: 'Em qual candidato específico'"))) +
  facet_wrap(~outcome) + scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) + labs(x = "Probability", y = NULL, color = NULL)
export("05b_wording_levels", p, "Does asking for a specific candidate change the answer?", "All levels, both wordings; same prompts otherwise. Main tables use the specific wording.", width = 10)
# Which issue statements unlock advice: the L4-L3 step by profile and model.
het <- read_result("contrast_heterogeneity_by_profile") %>% filter(outcome == "gives_advice", contrast == "issue_added_to_biography")
p <- het %>% mutate(model = model_name(model_key), profile = factor(unname(archetype_labels[archetype]), levels = rev(unname(archetype_labels[archetype_levels])))) %>%
  ggplot(aes(difference, profile)) + geom_vline(xintercept = 0, color = "grey70") +
  geom_point(aes(color = model), size = 2, alpha = .8) +
  stat_summary(fun = mean, geom = "point", shape = 124, size = 6, color = palette[["ink"]]) +
  scale_x_continuous(labels = scales::label_percent()) + labs(x = "Change in advice probability when the issue is added to the biography", y = NULL, color = NULL) +
  guides(color = guide_legend(nrow = 2))
export("13_issue_heterogeneity", p, "Which stated priorities unlock advice?", "One point per configuration; the bar is the equal-model mean. Profiles bundle one issue statement each.", width = 10, height = 6)

# 4. Profiles and named options are descriptive, not an accuracy benchmark -------
p <- read_result("rates_by_full_profile") %>% filter(outcome == "gives_advice", model_key %in% focus) %>%
  mutate(model = unname(model_labels[model_key]), profile = unname(archetype_labels[archetype])) %>%
  ggplot(aes(rate, profile, color = office)) + geom_point(position = position_dodge(width = .4)) + facet_wrap(~model, nrow = 1) +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) + labs(x = "Probability of positive advice", y = NULL, color = "Office")
export("06_profiles_receiving_advice", p, "Which constructed profiles receive advice?", "Full profiles only. Profile differences bundle several characteristics.", width = 13)
for (kind in c("person", "party")) {
  options <- read_result(paste0(kind, "_recommendations_by_model"))
  # Top options are selected by an equal-model unconditional rate, never raw counts.
  top <- options %>% group_by(office, entity, model_key) %>% summarise(p = mean(unconditional), .groups = "drop") %>%
    group_by(office, entity) %>% summarise(p = mean(p), .groups = "drop") %>% group_by(office) %>% slice_max(p, n = 6, with_ties = FALSE) %>% ungroup()
  for (race in c("president", "federal_deputy")) {
    p <- options %>% filter(model_key %in% focus, office == race) %>% semi_join(top, by = c("office", "entity")) %>%
      mutate(model = factor(unname(model_labels[model_key]), levels = unname(model_labels[focus])),
        profile = unname(archetype_labels[archetype]),
        option_label = if (kind == "person") str_wrap(str_to_title(entity), width = 16) else entity) %>%
      ggplot(aes(option_label, profile, fill = unconditional)) + geom_tile(color = "grey90") + facet_wrap(~model, nrow = 1) +
      scale_fill_gradient(low = "white", high = palette[["navy"]], labels = scales::label_percent(), limits = c(0, 1)) +
      labs(x = if (race == "president") "Presidential voting options" else "São Paulo federal-deputy voting options", y = NULL, fill = "Recommended")
    export(paste0("07_", kind, "_recommendations_", race), p, "Who gets recommended?",
      "Share of all full-profile responses, including non-recommendations. Multiple options can coexist.", width = 15, height = 6)
  }
}

# 5. Repeated identical web prompts: probabilities and conditional consistency ----
web <- read_result("web_prompt_rates")
p <- web %>% ggplot(aes(gives_advice)) + geom_histogram(binwidth = .05, boundary = 0, fill = palette[["navy"]], color = "white") +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
  labs(x = "Estimated advice probability for an identical prompt", y = "Number of prompts")
export("08_web_advice_probabilities", p, "How predictable is receiving advice from ChatGPT web?", "One estimate per prompt, averaging collection days equally; finite coding-sample noise remains.")
p <- read_result("web_people_consistency") %>% filter(!is.na(pair_agreement)) %>% ggplot(aes(pair_agreement)) +
  geom_histogram(binwidth = .1, boundary = 0, fill = palette[["teal"]], color = "white") +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
  labs(x = "Probability two advice-giving answers name the same set", y = "Number of eligible prompts")
export("09_web_candidate_consistency", p, "When ChatGPT names options, does it repeat them?", "One estimate per prompt: mean within-day agreement where at least two advice answers name people. Empty sets excluded.")
write_result(captions, "figure_captions")

# 6. Keep the review index synchronized with the candidate exhibits --------------
index_rows <- captions %>%
  mutate(link = file.path(result_dir, "figures", paste0(figure, ".png")),
         row = paste0("| [", figure, "](", link, ") | ", question, " |"))
readr::write_lines(c(
  "# Candidate exhibits for discussion", "",
  paste(status, "Final blog selection remains open."), "",
  "The overview includes every model. Focused panels retain separate models; pooled tables give each model equal weight.", "",
  "| Exhibit | Question |", "|---|---|", index_rows$row, "",
  "Model-specific tables are in tables/. Candidate-set agreement excludes empty sets and uses distinct pairs within a date. Candidate validity requires a separate external registry."
), file.path(result_dir, "RESULTS.md"))
