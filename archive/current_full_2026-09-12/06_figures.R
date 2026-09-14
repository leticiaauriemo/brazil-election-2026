# The figures for the blog, one block each, from output/tables.
# Input:  output/tables/*.csv   Output: output/figures/*.png and .pdf
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup.R"
))
model_name <- function(x) {
  factor(
    unname(model_labels[as.character(x)]),
    levels = rev(unname(model_labels[model_levels]))
  )
}
level_name <- function(x) {
  factor(
    x, level_order,
    labels = str_replace(unname(level_labels[level_order]), "Biography \\+ issue", "Bio +\nissue")
  )
}
pct <- scales::label_percent(accuracy = 1)
library(forcats)

# 1. Does the assistant name one candidate? -----------------------------------------------
by_model <- read_table("rates_by_model") %>%
  mutate(model = model_name(model_key))
# The dark point is our outcome; the light point is the electoral court's wider standard,
# which also counts a shortlist, a party or a steer away from someone.
p <- ggplot(by_model, aes(y = model)) +
  geom_errorbarh(
    aes(
      xmin = pmax(steers_tse - 1.96 * steers_tse_se, 0),
      xmax = pmin(steers_tse + 1.96 * steers_tse_se, 1)
    ),
    height = 0, color = "grey80"
  ) +
  geom_errorbarh(
    aes(xmin = pmax(advice - 1.96 * advice_se, 0), xmax = pmin(advice + 1.96 * advice_se, 1)),
    height = 0, color = "grey55"
  ) +
  geom_point(aes(x = steers_tse, shape = "Any personalized steering, our broader measure"),
    size = 2.6, color = palette[["teal"]]
  ) +
  geom_point(aes(x = advice, shape = "Names one candidate"),
    size = 2.6, color = palette[["navy"]]
  ) +
  geom_text(
    data = by_model, aes(x = 1.02, y = model, label = pct(not_coded)),
    inherit.aes = FALSE, hjust = 0, size = 2.6, color = palette[["grey"]]
  ) +
  scale_x_continuous(labels = pct, breaks = seq(0, 1, .25), limits = c(0, 1.1)) +
  scale_shape_manual(
    values = c("Names one candidate" = 16, "Any personalized steering, our broader measure" = 1)
  ) +
  guides(shape = guide_legend(override.aes = list(
    color = c(palette[["teal"]], palette[["navy"]])
  ))) +
  labs(
    x = "Share of answers", y = NULL,
    caption = paste0(
      "Full profiles, specific-candidate wording. Filled point: share of labelled responses ",
      "that settle on one candidate, as an endorsement or as the voter's best match, others ",
      "at most listed as alternatives; every other answer declines to name one. Open point: ",
      "share that endorses, matches or steers away from any candidate or party, including ",
      "shortlists and party-only answers; the broader measure is motivated by Resolucao TSE ",
      "23.755/2026, which forbids ranking, suggesting or prioritising candidates or parties, ",
      "but it is a behavioural category, not a legal finding. Whiskers: 95% intervals across ",
      "prompts. Label: share of responses the coder could not label."
    )
  )
save_figure("01_advice_by_model", p, 9, 5.4)

# 2. The issue unlocks advice, the person does not ---------------------------------------
levels <- read_table("rates_by_level") %>%
  mutate(
    model = factor(unname(model_labels[model_key]), unname(model_labels[model_levels])),
    level = level_name(level)
  )
p <- ggplot(levels, aes(level, advice, group = model)) +
  geom_ribbon(
    aes(ymin = pmax(advice - 1.96 * advice_se, 0), ymax = pmin(advice + 1.96 * advice_se, 1)),
    fill = "grey80", alpha = .6
  ) +
  geom_line(color = palette[["navy"]]) +
  geom_point(color = palette[["navy"]], size = 1.8) +
  facet_wrap(~model, nrow = 3) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  labs(
    x = "What the voter reveals", y = "Probability of naming one candidate",
    caption = paste0(
      "Specific-candidate wording, all five conditions. Biography and issue are separate ",
      "additions to the bare question; the last two conditions add the issue to the biography, ",
      "then attitudes and identities. Band: 95% interval across prompts. The bare ",
      "question rests on two prompts and about ten answers per API configuration."
    )
  )
save_figure("02_ladder_by_model", p, 12, 7.5)

# 3. Which stated priority unlocks advice: the issue step, profile by configuration ------
step <- read_table("issue_step_by_profile") %>%
  mutate(
    model = factor(unname(model_labels[model_key]), unname(model_labels[model_levels])),
    profile = factor(
      unname(archetype_labels[archetype]), rev(unname(archetype_labels[archetype_levels]))
    )
  )
p <- ggplot(step, aes(model, profile, fill = difference)) +
  geom_tile(color = "white") +
  geom_text(
    aes(label = round(100 * difference)), size = 3,
    color = if_else(step$difference > .45, "white", palette[["ink"]])
  ) +
  scale_fill_gradient(low = "white", high = palette[["navy"]], labels = pct, limits = c(0, 1)) +
  labs(
    x = NULL, y = NULL, fill = "Change in the probability of naming one candidate",
    caption = paste0(
      "Specific-candidate wording. Percentage-point change in the probability of naming one ",
      "candidate when ",
      "the voter's priority is added to the biography, by profile (one issue statement each) ",
      "and configuration."
    )
  ) +
  theme(axis.text.x = element_text(angle = 35, hjust = 1))
save_figure("03_issue_step_heatmap", p, 11, 5.5)

# 4. Recommendations next to the polls and the last result -----------------------------
# President only: few answers name a single deputy, so deputy shares rest on a handful.
bench <- read_table("benchmark_comparison") %>%
  filter(office == "president") %>%
  filter(!is.na(benchmark) | models_equal >= .02 | advice_weighted >= .02) %>%
  mutate(
    benchmark = replace_na(benchmark, 0),
    race = recode(office,
      president = "President: Genial/Quaest, 10-13 Aug 2026",
      federal_deputy = "Federal deputy, SP: 2022 seat share"
    )
  ) %>%
  pivot_longer(
    c(benchmark, models_equal, advice_weighted), names_to = "series", values_to = "value"
  ) %>%
  mutate(series = factor(
    recode(series,
      benchmark = "Poll or election result",
      models_equal = "AI recommendations, models weighted equally",
      advice_weighted = "AI recommendations, models weighted by how often they name one"
    ),
    c(
      "Poll or election result",
      "AI recommendations, models weighted equally",
      "AI recommendations, models weighted by how often they name one"
    )
  ))
# The main figure carries the primary weighting only (configurations equal); the version
# with the advice-weighted alternative is an appendix figure.
benchmark_plot <- function(d, colors, shapes, extra_caption = "") {
  d %>%
    group_by(race) %>%
    mutate(label = reorder(label, value, FUN = max)) %>%
    ungroup() %>%
    ggplot(aes(value, label, color = series, shape = series)) +
    geom_point(size = 2.4, position = position_dodge(width = .5)) +
    facet_wrap(~race) +
    scale_x_continuous(labels = pct) +
    scale_color_manual(values = colors) +
    scale_shape_manual(values = shapes) +
    labs(
      x = NULL, y = NULL,
      caption = paste0(
        "Full profiles, specific-candidate wording, answers that settle on one candidate; ",
        "profiles weighted by their population share in Neto's segmentation, configurations ",
        "weighted equally. Poll shares rescaled to valid votes, undecided and blank excluded. ",
        "Not a forecast.", extra_caption
      )
    ) +
    guides(color = guide_legend(nrow = 3))
}
p <- benchmark_plot(
  bench %>% filter(series != "AI recommendations, models weighted by how often they name one"),
  unname(palette[c("gold", "navy")]), c(16, 16)
)
save_figure("04_recommendations_vs_benchmarks", p, 12, 6.5)
p <- benchmark_plot(
  bench, unname(palette[c("gold", "navy", "teal")]), c(16, 16, 17),
  paste0(
    " The triangle weights configurations by how often they name one candidate, so it is ",
    "close to Grok's answer."
  )
)
save_figure("04b_recommendations_vs_benchmarks_weightings", p, 12, 6.5)

# 5. Same company, different surface -----------------------------------------------------
openai <- c("gpt4o", "gpt56_luna", "gpt56_sol", "chatgpt_web")
p <- read_table("rates_by_level") %>%
  filter(model_key %in% openai) %>%
  mutate(
    model = factor(unname(model_labels[model_key]), unname(model_labels[openai])),
    level = level_name(level)
  ) %>%
  ggplot(aes(level, advice, color = model, group = model)) +
  geom_line(linewidth = .9) +
  geom_errorbar(
    aes(ymin = pmax(advice - 1.96 * advice_se, 0), ymax = pmin(advice + 1.96 * advice_se, 1)),
    width = .1
  ) +
  geom_point(size = 2.2) +
  scale_color_manual(values = unname(palette[c("coral", "gold", "teal", "navy")])) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  labs(
    x = "What the voter reveals", y = "Probability of naming one candidate",
    caption = paste0(
      "Specific-candidate wording, all five conditions. OpenAI API configurations and the ",
      "ChatGPT web surface, which runs an unidentified model. Whiskers: 95% intervals."
    )
  )
save_figure("05_web_vs_api_ladder", p, 8, 4.8)

# 6. The web surface rarely advises, and when it does it repeats itself -----------------
pretty <- function(x, k) if_else(k == "person", str_to_title(x), x)
stab <- read_table("web_stability") %>%
  mutate(
    prompt = factor(
      paste0(
        unname(archetype_labels[archetype]), ", ",
        recode(gender, homem = "man", mulher = "woman")
      ),
      rev(paste0(
        rep(unname(archetype_labels[archetype_levels]), each = 2), ", ", c("man", "woman")
      ))
    ),
    office = factor(unname(office_labels[office]), unname(office_labels)),
    note = case_when(
      n_advice == 0 ~ "no advice in any capture",
      is.na(second) ~ sprintf(
        "%s %s  (n = %d)", pretty(lead, lead_kind), pct(n_lead / n_advice), n_advice
      ),
      TRUE ~ sprintf(
        "%s %s, also %s %s  (n = %d)",
        pretty(lead, lead_kind), pct(n_lead / n_advice),
        pretty(second, second_kind), pct(second_n / n_advice), n_advice
      )
    )
  )
bars <- stab %>%
  transmute(
    prompt, office,
    `No advice` = 1 - n_advice / n,
    `Advice naming the lead option` = n_lead / n,
    `Advice naming another option` = (n_advice - n_lead) / n
  ) %>%
  pivot_longer(-c(prompt, office), names_to = "bin", values_to = "share") %>%
  mutate(bin = factor(
    bin, c("Advice naming another option", "Advice naming the lead option", "No advice")
  ))
p <- ggplot(bars, aes(share, prompt, fill = bin)) +
  geom_col(width = .7) +
  geom_text(
    data = stab, aes(x = 1.03, y = prompt, label = note),
    inherit.aes = FALSE, hjust = 0, size = 2.2, color = palette[["ink"]]
  ) +
  facet_wrap(~office) +
  scale_x_continuous(
    labels = pct, breaks = seq(0, 1, .25), limits = c(0, 2.35), expand = c(0, 0)
  ) +
  scale_fill_manual(values = c(
    `No advice` = "grey88", `Advice naming the lead option` = palette[["navy"]],
    `Advice naming another option` = palette[["coral"]]
  )) +
  labs(
    x = "Share of labelled captures of the prompt", y = NULL,
    caption = paste0(
      "Full profiles, specific-candidate wording, 300-400 labelled captures per bar. ",
      "The lead option is the candidate that single-candidate answers name most often; the ",
      "text gives it and the runner-up with their shares of the n single-candidate answers."
    )
  ) +
  guides(fill = guide_legend(reverse = TRUE))
save_figure("06_web_stability", p, 14, 6.5)

# 7. What the web surface cites when it advises ------------------------------------------
sources <- read_table("web_citation_sources") %>%
  mutate(
    answer = sprintf(
      "%s\n(%s answers, %s links)",
      if_else(advice, "Answers that settle on one candidate", "Answers that do not"),
      format(answers, big.mark = ",", trim = TRUE), format(links_total, big.mark = ",", trim = TRUE)
    ),
    answer = fct_reorder(answer, advice),
    source_type = factor(source_type, c(
      "TSE pages about the AI rule", "Official (TSE, Congress, government)", "Press and news",
      "Wikipedia", "Candidate and campaign sites", "Party and movement sites", "Social media",
      "Other"
    ))
  )
p <- ggplot(sources, aes(share, answer, fill = source_type)) +
  geom_col() +
  scale_x_continuous(labels = pct) +
  scale_fill_manual(values = c(
    "#C0392B", palette[["navy"]], palette[["gold"]], palette[["teal"]],
    palette[["coral"]], "#F4A582", "#7A8793", "#D9DEE3"
  ), drop = FALSE) +
  labs(
    x = "Share of links shown in the answer", y = NULL,
    caption = paste0(
      "ChatGPT web, full profiles, specific-candidate wording; one link occurrence is one ",
      "citation, classified by domain. Advice is the narrow outcome, an answer that settles on ",
      "one candidate. TSE pages about the AI rule are the resolution text or TSE news on the ",
      "rules for AI. An association: answers that advise show more press links; the design ",
      "does not say whether the sources produce the advice."
    )
  ) +
  guides(fill = guide_legend(nrow = 2))
save_figure("07_web_citation_sources", p, 10, 3.6)

# 8. What the answer does, by configuration and office ----------------------------------
# Six bins from most to least directive. A description of the presidential field counts as
# whole only if it names all thirteen registered candidates; the label gives the average
# number named when a system describes the field.
category_levels <- c(
  "Names one candidate", "Personalized shortlist", "Names a party, no candidate",
  "Describes the whole field, picks none", "Describes some candidates, picks none",
  "Names nobody, declines or explains how to choose", "Other", "Not coded"
)
cats <- read_table("categories_by_office") %>%
  mutate(
    model = model_name(model_key),
    office = factor(unname(office_labels[office]), unname(office_labels)),
    category = factor(category, category_levels)
  )
coverage <- read_table("field_coverage") %>%
  mutate(
    model = model_name(model_key),
    office = factor(office_labels[["president"]], unname(office_labels)),
    label = paste0("names ", format(round(named, 1), nsmall = 1), " of 13")
  )
p <- ggplot(cats, aes(share, model, fill = category)) +
  geom_col() +
  geom_text(
    data = coverage, aes(x = 1.02, y = model, label = label),
    inherit.aes = FALSE, hjust = 0, size = 2.3, color = palette[["grey"]]
  ) +
  facet_wrap(~office) +
  scale_x_continuous(
    labels = pct, breaks = seq(0, 1, .25), limits = c(0, 1.3), expand = c(0, 0)
  ) +
  scale_fill_manual(values = c(
    palette[["navy"]], "#7FA1CC", "#D0DCEB", palette[["teal"]], "#A8D5CF",
    "#B0B8C1", "#D9DEE3", "grey95"
  )) +
  labs(
    x = "Share of responses", y = NULL,
    caption = paste0(
      "Full profiles, specific-candidate wording. Mutually exclusive bins, most to least ",
      "directive. The dark bin is the advice rate of the other figures; every other bin is a ",
      "way of declining to name one candidate. A description of the presidential field is ",
      "whole only if it names all thirteen registered candidates; the label is the average ",
      "number named when the system describes the field. For deputies, national figures ",
      "named as reference points do not count as candidates."
    )
  ) +
  guides(fill = guide_legend(nrow = 3))
save_figure("08_categories_by_office", p, 13, 6)

# 9 and 12 (president), 23 and 24 (deputy). Who gets recommended, by full profile and
# configuration: the share of all answers, then the share among answers that name one.
# For deputies the option is the picked candidate's party. In the conditional view a
# system that rarely names anyone is no longer blank; its naming rate is printed at the
# end of the row, and rows under 2% are left empty.
recommendation_heatmaps <- function(race, name_all, name_conditional,
                                    table = "options_by_profile", people = race == "president") {
  opts <- read_table(table) %>%
    filter(office == race)
  top <- opts %>%
    group_by(option) %>%
    summarise(p = mean(unconditional), .groups = "drop") %>%
    slice_max(p, n = 6)
  pretty_option <- function(x) {
    if (people) str_wrap(str_to_title(x), 14) else x
  }
  place <- function(d) d %>%
    mutate(
      model = factor(unname(model_labels[model_key]), unname(model_labels[model_levels])),
      profile = factor(
        unname(archetype_labels[archetype]), rev(unname(archetype_labels[archetype_levels]))
      )
    )
  what <- if (people) "this candidate" else "a candidate from this party"
  p <- opts %>%
    semi_join(top, by = "option") %>%
    place() %>%
    mutate(option = pretty_option(option)) %>%
    ggplot(aes(option, profile, fill = unconditional)) +
    geom_tile(color = "grey90") +
    facet_wrap(~model, nrow = 2, drop = FALSE) +
    scale_fill_gradient(low = "white", high = palette[["navy"]], labels = pct, limits = c(0, 1)) +
    labs(
      x = NULL, y = NULL, fill = "Share of responses recommending",
      caption = paste0(
        unname(office_labels[race]), "; full profiles, specific-candidate wording; share of all ",
        "labelled responses that settle on ", what, ", including answers that name nobody."
      )
    ) +
    theme(axis.text.x = element_text(angle = 50, hjust = 1, size = 7))
  save_figure(name_all, p, 15, 7)

  named <- opts %>%
    semi_join(top, by = "option") %>%
    mutate(share = if_else(advice_rate >= .02, share, NA_real_))
  rate_labels <- expand_grid(model_key = model_levels, archetype = archetype_levels) %>%
    left_join(
      opts %>% distinct(model_key, archetype, advice_rate), by = c("model_key", "archetype")
    ) %>%
    mutate(
      advice_rate = replace_na(advice_rate, 0),
      label = if_else(advice_rate >= .02, pct(advice_rate), "<2%")
    )
  option_levels <- c(pretty_option(top$option[order(-top$p)]), "names one")
  p <- place(named) %>%
    mutate(option = factor(pretty_option(option), option_levels)) %>%
    ggplot(aes(option, profile, fill = share)) +
    geom_tile(color = "grey90") +
    geom_text(
      data = place(rate_labels) %>% mutate(option = factor("names one", option_levels)),
      aes(option, profile, label = label), inherit.aes = FALSE, size = 2.3,
      color = palette[["grey"]]
    ) +
    facet_wrap(~model, nrow = 2, drop = FALSE) +
    scale_x_discrete(drop = FALSE) +
    scale_fill_gradient(
      low = "white", high = palette[["navy"]], labels = pct, limits = c(0, 1), na.value = "grey96"
    ) +
    labs(
      x = NULL, y = NULL, fill = paste0("Share of single-candidate answers naming ", what),
      caption = paste0(
        unname(office_labels[race]), "; full profiles, specific-candidate wording. Among the ",
        "answers that settle on one candidate, the share going to ", what, "; the last column ",
        "is the share of all answers that name one. Rows where fewer than 2% of answers name ",
        "one are left blank."
      )
    ) +
    theme(axis.text.x = element_text(angle = 50, hjust = 1, size = 7))
  save_figure(name_conditional, p, 15, 7)
}
recommendation_heatmaps(
  "president", "09_president_recommendations", "12_president_recommendations_conditional"
)
recommendation_heatmaps(
  "federal_deputy", "23_deputy_recommendations", "24_deputy_recommendations_conditional"
)
recommendation_heatmaps(
  "federal_deputy", "25_deputy_recommendations_people",
  "26_deputy_recommendations_people_conditional",
  table = "options_by_profile_deputy_people", people = TRUE
)

# 10. Regression view (appendix) ---------------------------------------------------------
terms <- c(
  levelL1 = "Nothing (vs biography)", levelL2 = "Issue (vs biography)",
  levelL4 = "Biography + issue (vs biography)", levelL5 = "+ Attitudes (vs biography)",
  officefederal_deputy = "Federal deputy (vs president)",
  gendermulher = "Woman (vs man)"
)
p <- read_table("regression_by_model") %>%
  filter(term %in% names(terms)) %>%
  mutate(
    model = model_name(model_key),
    term = factor(unname(terms[term]), unname(terms))
  ) %>%
  ggplot(aes(estimate, model)) +
  geom_vline(xintercept = 0, color = "grey70") +
  geom_errorbarh(
    aes(xmin = estimate - 1.96 * se, xmax = estimate + 1.96 * se), height = 0, color = "grey55"
  ) +
  geom_point(color = palette[["navy"]]) +
  facet_wrap(~term, nrow = 2) +
  scale_x_continuous(labels = function(x) paste0(round(100 * x), " pp")) +
  labs(
    x = "Coefficient, linear probability model for naming one candidate", y = NULL,
    caption = paste0(
      "One OLS per configuration on labelled responses, specific-candidate wording, all ",
      "levels; 95% intervals, ",
      "standard errors clustered by prompt."
    )
  )
save_figure("10_regression_coefficients", p, 13, 6.5)

# 11. Regex robustness: a rule-based reading tracks the semantic labels --------------------
agree <- read_table("regex_agreement")
pooled <- agree %>%
  filter(model_key == "all")
p <- agree %>%
  filter(level != "all", model_key != "all") %>%
  mutate(model = factor(unname(model_labels[model_key]), unname(model_labels[model_levels]))) %>%
  ggplot(aes(advice_llm, advice_regex, color = model)) +
  geom_abline(slope = 1, intercept = 0, color = "grey70") +
  geom_point(size = 2.2) +
  scale_x_continuous(labels = pct, limits = c(0, 1)) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  coord_equal() +
  labs(
    x = "Advice rate, semantic coder", y = "Advice rate, rule-based coder",
    caption = sprintf(
      paste0(
        "One point per configuration and level, specific-candidate wording. The rule-based ",
        "coder reads advice more narrowly and misses much of it on the web arm: response-level ",
        "agreement is %s, but advice is rare, so chance-corrected agreement (kappa) is only %s. ",
        "What the rule reproduces is the ordering of configurations and levels."
      ),
      pct(pooled$agreement), format(round(pooled$kappa, 2), nsmall = 2)
    )
  ) +
  guides(color = guide_legend(nrow = 3))
save_figure("11_regex_robustness", p, 8, 7.5)
message("Figures written.")

# 13. What the web surface searches for: the issue enters the query, the person does not --
terms <- read_table("web_query_terms") %>%
  select(level, demographic, issue, politics, official) %>%
  pivot_longer(-level, names_to = "term", values_to = "share") %>%
  mutate(
    level = level_name(level),
    term = factor(
      recode(term,
        official = "TSE, registration, calendar",
        issue = "Voter's issue or values",
        politics = "Left/right, a party or a politician",
        demographic = "Voter's age, gender, income or education"
      ),
      c(
        "TSE, registration, calendar", "Voter's issue or values",
        "Left/right, a party or a politician", "Voter's age, gender, income or education"
      )
    )
  )
p <- ggplot(terms, aes(level, share, fill = term)) +
  geom_col(position = position_dodge(width = .8)) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  scale_fill_manual(values = unname(palette[c("grey", "navy", "teal", "coral")])) +
  labs(
    x = "What the voter reveals", y = "Share of search queries containing the terms",
    caption = paste0(
      "ChatGPT web, specific-candidate wording, every complete capture that ran a search; ",
      "a query can fall in several classes."
    )
  ) +
  guides(fill = guide_legend(nrow = 2))
save_figure("13_web_search_queries", p, 10, 5.5)

# 14. Which outlets feed the answer, by the voter's side --------------------------------
domains <- read_table("web_domains_by_side") %>%
  mutate(
    side = factor(side, side_order),
    domain = reorder(domain, share, FUN = max),
    source_type = factor(source_type, c(
      "Official (TSE, Congress, government)", "Press and news", "Candidate and campaign sites",
      "Party and movement sites", "Wikipedia", "Social media", "Other"
    ))
  )
p <- ggplot(domains, aes(share, domain, color = side)) +
  geom_point(size = 2.2, position = position_dodge(width = .6)) +
  facet_grid(source_type ~ ., scales = "free_y", space = "free_y") +
  scale_x_continuous(labels = pct) +
  scale_color_manual(values = unname(palette[c("coral", "gold", "navy")])) +
  labs(
    x = "Share of the side's links shown in the answer", y = NULL,
    caption = paste0(
      "ChatGPT web, full profiles, specific-candidate wording, labelled captures; links ",
      "rendered in the answer, domains with at least 80 links across all profiles."
    )
  ) +
  theme(strip.text.y = element_text(angle = 0, hjust = 0))
save_figure("14_web_domains_by_side", p, 10, 9)

# 15. Does the answer know when the election is? (appendix) -------------------------------
# The coder flagged answers that treat the election as future or unknown, or lean on facts
# that were stale at collection (mid to late August 2026, after candidate registration).
p <- ggplot(by_model, aes(stale, model)) +
  geom_errorbarh(
    aes(xmin = pmax(stale - 1.96 * stale_se, 0), xmax = pmin(stale + 1.96 * stale_se, 1)),
    height = 0, color = "grey55"
  ) +
  geom_point(size = 2.6, color = palette[["coral"]]) +
  scale_x_continuous(labels = pct, breaks = seq(0, 1, .25), limits = c(0, 1)) +
  labs(
    x = "Share of answers with stale or wrong timing", y = NULL,
    caption = paste0(
      "Full profiles, specific-candidate wording. Share of labelled responses the coder ",
      "flagged for stale timing: the election treated as future or undated, candidates ",
      "described as unconfirmed after registration closed, or outdated facts. Whiskers: 95% ",
      "intervals across prompts."
    )
  )
save_figure("15_stale_timing_by_model", p, 9, 5)

# 16. The interface meets the rule, and carries on ----------------------------------------
# Left: how often a full-profile capture retrieved a page about the electoral court's AI
# rule, showed the link, or told the user about the ban. Right: naming among presidential
# captures by what they retrieved. Bars carry their value and the denominators, since
# three of the left-hand shares are a fraction of a percent.
awareness <- read_table("web_rule_awareness") %>%
  mutate(
    panel = sprintf(
      "Meeting the rule: share of %s full-profile captures", format(n, big.mark = ",")
    ),
    row = factor(measure, rev(measure)),
    label = if_else(share >= .01, pct(share), scales::label_percent(accuracy = .01)(share)),
    fill = "grey"
  )
exposure_levels <- c(
  "Retrieved neither", "Retrieved a news item or explainer about the rule",
  "Retrieved the resolution text"
)
behaviour <- read_table("web_rule_behaviour") %>%
  filter(office == "president") %>%
  pivot_longer(c(advice, steers_tse), names_to = "outcome", values_to = "share") %>%
  mutate(
    panel = "Presidential answers, by what the capture retrieved",
    outcome = factor(
      recode(outcome, advice = "Names one candidate", steers_tse = "Any steer"),
      c("Names one candidate", "Any steer")
    ),
    exposure = factor(exposure, exposure_levels),
    row = paste0(outcome, ": ", str_to_lower(exposure), " (n = ", format(n, big.mark = ","), ")"),
    label = pct(share),
    fill = recode(as.character(exposure),
      "Retrieved neither" = "navy",
      "Retrieved a news item or explainer about the rule" = "teal",
      "Retrieved the resolution text" = "gold"
    )
  ) %>%
  arrange(outcome, exposure) %>%
  mutate(row = factor(row, rev(unique(row))))
p <- bind_rows(awareness, behaviour) %>%
  mutate(panel = factor(panel, unique(c(awareness$panel, behaviour$panel)))) %>%
  ggplot(aes(share, row, fill = fill)) +
  geom_col(width = .6) +
  geom_text(aes(label = label), hjust = -0.15, size = 3, color = palette[["ink"]]) +
  facet_wrap(~panel, scales = "free") +
  scale_x_continuous(labels = pct, expand = expansion(mult = c(0, .3))) +
  scale_fill_manual(values = c(
    grey = "#B0B8C1", teal = palette[["teal"]], navy = palette[["navy"]], gold = palette[["gold"]]
  )) +
  labs(
    x = NULL, y = NULL,
    caption = paste0(
      "ChatGPT web, full profiles, specific-candidate wording. Left: all complete captures; ",
      "a page about the rule is either the text of Resolucao TSE 23.755/2026 or a news item ",
      "or explainer about the rules for AI in the election, retrieved during the answer's ",
      "search whether or not the link was shown; the ban mention is a keyword rule. Right: ",
      "labelled presidential captures, prompts weighted equally, by what the capture ",
      "retrieved. An association inside the web traces, not a causal test."
    )
  ) +
  theme(legend.position = "none", panel.grid.major.x = element_blank())
save_figure("16_web_meets_the_rule", p, 13, 5.2)

# 17. When an answer lists the presidential field, how much of it? --------------------------
# The panel title carries the number of listing answers, since several systems have few.
sizes <- read_table("field_listing_size") %>%
  group_by(model_key) %>%
  mutate(listings = sum(answers)) %>%
  ungroup() %>%
  mutate(
    model = factor(unname(model_labels[model_key]), unname(model_labels[model_levels])),
    panel = paste0(model, "  (n = ", format(listings, big.mark = ",", trim = TRUE), ")"),
    panel = fct_reorder(panel, as.integer(model))
  )
p <- ggplot(sizes, aes(field_named, share)) +
  geom_col(fill = palette[["navy"]]) +
  facet_wrap(~panel, nrow = 3) +
  scale_x_continuous(breaks = c(1, 3, 5, 7, 9, 11, 13), limits = c(0.4, 13.6)) +
  scale_y_continuous(labels = pct) +
  labs(
    x = "Registered candidates named in the answer (of 13)", y = "Share of listing answers",
    caption = paste0(
      "Presidential race, specific-candidate wording, all five conditions. Answers that name ",
      "at least one registered candidate without endorsing or matching anyone. Thirteen ",
      "candidacies were registered by 15 August 2026 and validated on 4 September."
    )
  )
save_figure("17_field_listing_size", p, 12, 7)

# 18. Which candidates a listing leaves out, by the voter's side, within configuration -----
# Only configurations with at least thirty listings on every side are shown, so the
# pattern cannot come from a change in which systems list.
by_side <- read_table("field_candidates_by_side") %>%
  group_by(model_key) %>%
  filter(min(listings) >= 30) %>%
  ungroup() %>%
  mutate(
    side = factor(side, side_order),
    label = fct_reorder(str_remove(label, " \\(.*\\)$"), poll),
    model = factor(unname(model_labels[model_key]), unname(model_labels[model_levels]))
  )
sizes_note <- by_side %>%
  distinct(model, side, listings) %>%
  arrange(model, side) %>%
  mutate(text = sprintf("%s %s %d", model, str_to_lower(side), listings)) %>%
  pull(text) %>%
  paste(collapse = "; ")
p <- ggplot(by_side, aes(share, label, color = side)) +
  geom_point(size = 2.4, position = position_dodge(width = .6)) +
  facet_wrap(~model) +
  scale_x_continuous(labels = pct, limits = c(0, 1)) +
  scale_color_manual(values = unname(palette[c("coral", "gold", "navy")])) +
  labs(
    x = "Share of listing answers that name the candidate", y = NULL,
    caption = paste0(
      "Presidential race, profiled conditions (biography with issue, attitudes added), ",
      "specific-candidate wording; answers that list registered candidates without steering, ",
      "within configuration. Listings per side: ", sizes_note, ". Candidates ordered by ",
      "their Genial/Quaest August share; Marcal was not tested."
    )
  )
save_figure("18_field_candidates_by_side", p, 12, 6.5)

# 19. The ladder, pooled: the narrow outcome and the broader measure ---------------------
pooled <- read_table("rates_by_level_pooled") %>%
  select(level, advice = advice_mean, steers_tse = steers_tse_mean) %>%
  pivot_longer(-level, names_to = "measure", values_to = "share") %>%
  mutate(model_key = "all")
per_model <- read_table("rates_by_level") %>%
  select(model_key, level, advice, steers_tse) %>%
  pivot_longer(c(advice, steers_tse), names_to = "measure", values_to = "share")
measure_name <- function(x) {
  factor(
    recode(x, advice = "Names one candidate", steers_tse = "Any personalized steering"),
    c("Names one candidate", "Any personalized steering")
  )
}
p <- ggplot(mapping = aes(level_name(level), share, color = measure_name(measure))) +
  geom_point(
    data = per_model, alpha = .35, size = 1.6, position = position_dodge(width = .3)
  ) +
  geom_line(data = pooled, aes(group = measure), linewidth = 1) +
  geom_point(data = pooled, size = 3) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  scale_color_manual(values = unname(palette[c("navy", "teal")])) +
  labs(
    x = "What the voter reveals", y = "Share of answers",
    caption = paste0(
      "Specific-candidate wording, all five conditions. Lines: the eleven configurations ",
      "weighted equally. Faint points: one per configuration. The broader measure counts any ",
      "endorsement, match or steer away, including shortlists and party-only answers."
    )
  )
save_figure("19_ladder_pooled", p, 9, 5.5)

# 20. Which parties keep coming up, and how early ----------------------------------------
# Share of answers whose single pick belongs to PT, Novo or PL, by profile, at issue only,
# biography with issue and the full profile. Configurations weighted equally; faint points
# are single configurations.
parties <- read_table("party_by_level_profile") %>%
  mutate(
    level = level_name(level),
    profile = factor(
      unname(archetype_labels[archetype]), unname(archetype_labels[archetype_levels])
    ),
    party = factor(recode(party, NOVO = "Novo"), c("PT", "Novo", "PL"))
  )
p <- ggplot(mapping = aes(level, share, color = party)) +
  geom_point(
    data = parties %>% filter(model_key != "all"), alpha = .3, size = 1.3,
    position = position_dodge(width = .4)
  ) +
  geom_line(
    data = parties %>% filter(model_key == "all"), aes(group = party), linewidth = .9
  ) +
  geom_point(data = parties %>% filter(model_key == "all"), size = 2.4) +
  facet_wrap(~profile, nrow = 3) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  scale_color_manual(
    values = c(PT = palette[["coral"]], Novo = palette[["gold"]], PL = palette[["navy"]])
  ) +
  labs(
    x = "What the voter reveals", y = "Share of answers whose pick is from the party",
    caption = paste0(
      "Specific-candidate wording, president and deputy pooled with equal weight. Share of ",
      "labelled answers that settle on one candidate from the party. Lines: configurations ",
      "weighted equally; faint points: single configurations. The issue-only condition ",
      "carries no biography and no partisan cue."
    )
  )
save_figure("20_party_by_level_profile", p, 12, 7.5)

# 21. Do the systems agree on whom? President versus deputy, candidate versus party --------
agree <- read_table("agreement_by_office") %>%
  mutate(
    office = factor(unname(office_labels[office]), unname(office_labels)),
    unit = factor(unit, c("Candidate", "Party")),
    label = sprintf("%s  (%d profiles, %d cells)", pct(agreement), profiles, cells)
  )
p <- ggplot(agree, aes(agreement, unit, color = office)) +
  geom_point(size = 3.2, position = position_dodge(width = .5)) +
  geom_text(
    aes(label = label), position = position_dodge(width = .5), hjust = -0.15, size = 2.8,
    show.legend = FALSE
  ) +
  scale_x_continuous(labels = pct, limits = c(0, 1.45), breaks = seq(0, 1, .25)) +
  scale_color_manual(values = unname(palette[c("navy", "coral")])) +
  labs(
    x = "Share of contributing configurations that pick the plurality option", y = NULL,
    caption = paste0(
      "Full profiles, specific-candidate wording. For each profile, every configuration with ",
      "at least five single picks contributes its most frequent pick, or that pick's party; ",
      "agreement is the share of contributing configurations whose top option is the ",
      "plurality option, averaged over profiles with at least two contributors. Cells: ",
      "configuration-profile pairs that contribute."
    )
  )
save_figure("21_agreement_by_office", p, 10, 3.6)

# 22. The disclaimer and the pick coexist ------------------------------------------------
# Among answers that settle on one candidate, the share that also carries refusal language.
# Systems with fewer than five such answers for an office are left out.
disc <- read_table("disclaimer_among_advice") %>%
  filter(picks >= 5) %>%
  mutate(
    model = model_name(model_key),
    office = factor(unname(office_labels[office]), unname(office_labels)),
    label = paste0("n = ", picks)
  )
p <- ggplot(disc, aes(disclaimer_share, model, color = office)) +
  geom_point(size = 3, position = position_dodge(width = .6)) +
  geom_text(
    aes(label = label, group = office), position = position_dodge(width = .6), hjust = -0.3,
    size = 2.4, show.legend = FALSE, color = palette[["grey"]]
  ) +
  scale_x_continuous(labels = pct, limits = c(0, 1.15), breaks = seq(0, 1, .25)) +
  scale_color_manual(values = unname(palette[c("navy", "coral")])) +
  labs(
    x = "Share of single-candidate answers that also say they cannot recommend", y = NULL,
    caption = paste0(
      "Full profiles, specific-candidate wording. Among answers that settle on one candidate, ",
      "the share the coder flagged for refusal language; n is the number of such answers. ",
      "Systems with fewer than five are left out."
    )
  )
save_figure("22_disclaimer_among_advice", p, 9, 5)
