# The fifteen figures of the blog, in the order of the draft, one block each, from
# output/tables. Figures dropped on 12 September 2026 live in archive/current_full_2026-09-12.
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

# 1. The ladder, pooled: the narrow outcome and the broader measure ---------------------
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
    x = "What the voter reveals", y = "Share of answers"
  )
save_figure("01_ladder_pooled", p, 9, 5.5)

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
    x = "What the voter reveals", y = "Probability of naming one candidate"
  )
save_figure("02_ladder_by_model", p, 12, 7.5)

# 3. Does the assistant name one candidate? -----------------------------------------------
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
    x = "Share of answers", y = NULL
  )
save_figure("03_advice_by_model", p, 9, 5.4)

# 4. What the answer does, by configuration and office ----------------------------------
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
    x = "Share of responses", y = NULL
  ) +
  guides(fill = guide_legend(nrow = 3))
save_figure("04_categories_by_office", p, 13, 6)

# 5. When an answer lists the presidential field, how much of it? --------------------------
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
    x = "Registered candidates named in the answer (of 13)", y = "Share of listing answers"
  )
save_figure("05_field_listing_size", p, 12, 7)

# 7 (president) and 8 (deputy). Who gets recommended, by full profile and configuration,
# among answers that name one candidate. For deputies the option is the picked candidate's
# party. A system that rarely names anyone is not blank; its naming rate is printed at the
# end of the row, and rows under 2% are left empty.
recommendation_heatmap <- function(race, name, people = race == "president") {
  opts <- read_table("options_by_profile") %>%
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
      x = NULL, y = NULL, fill = paste0("Share of single-candidate answers naming ", what)
    ) +
    theme(axis.text.x = element_text(angle = 50, hjust = 1, size = 7))
  save_figure(name, p, 15, 7)
}
recommendation_heatmap("president", "07_president_recommendations_conditional")
recommendation_heatmap("federal_deputy", "08_deputy_recommendations_conditional")

# 9. The web surface rarely advises, and when it does it repeats itself -----------------
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
    x = "Share of labelled captures of the prompt", y = NULL
  ) +
  guides(fill = guide_legend(reverse = TRUE))
save_figure("09_web_stability", p, 14, 6.5)

# 10. Which candidates a listing leaves out, by the voter's side, within configuration -----
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
p <- ggplot(by_side, aes(share, label, color = side)) +
  geom_point(size = 2.4, position = position_dodge(width = .6)) +
  facet_wrap(~model) +
  scale_x_continuous(labels = pct, limits = c(0, 1)) +
  scale_color_manual(values = unname(palette[c("coral", "gold", "navy")])) +
  labs(
    x = "Share of listing answers that name the candidate", y = NULL
  )
save_figure("10_field_candidates_by_side", p, 12, 6.5)

# 11. What the web surface cites when it advises ------------------------------------------
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
    x = "Share of links shown in the answer", y = NULL
  ) +
  guides(fill = guide_legend(nrow = 2))
save_figure("11_web_citation_sources", p, 10, 3.6)

# 12. The interface meets the rule, and carries on ----------------------------------------
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
    x = NULL, y = NULL
  ) +
  theme(legend.position = "none", panel.grid.major.x = element_blank())
save_figure("12_web_meets_the_rule", p, 13, 5.2)

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
    x = "What the voter reveals", y = "Share of search queries containing the terms"
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
    x = "Share of the side's links shown in the answer", y = NULL
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
    x = "Share of answers with stale or wrong timing", y = NULL
  )
save_figure("15_stale_timing_by_model", p, 9, 5)

# 16. Which voters get an answer: naming rate by system and profile (appendix) -------------
heat <- read_table("advice_by_profile") %>%
  mutate(
    model = factor(
      coalesce(unname(model_labels[model_key]), "All systems, equal weight"),
      c(unname(model_labels[model_levels]), "All systems, equal weight")
    ),
    profile = factor(
      unname(archetype_labels[archetype]), rev(unname(archetype_labels[archetype_levels]))
    ),
    label = if_else(advice >= .005, as.character(round(100 * advice)), "")
  )
p <- ggplot(heat, aes(model, profile, fill = advice)) +
  geom_tile(color = "grey90") +
  geom_text(aes(label = label, color = advice > .5), size = 2.6, show.legend = FALSE) +
  scale_color_manual(values = c(`TRUE` = "white", `FALSE` = palette[["ink"]])) +
  scale_fill_gradient(low = "white", high = palette[["navy"]], labels = pct, limits = c(0, 1)) +
  labs(
    x = NULL, y = NULL, fill = "Share of answers naming one candidate",
    caption = paste0(
      "Presidential race, full profiles, specific-candidate wording. Each cell is the share ",
      "of a system's answers to that profile that settle on one candidate, days averaged ",
      "within prompt and then prompts; the last column weights the eleven systems equally."
    )
  ) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1), panel.grid = element_blank())
save_figure("16_advice_by_profile", p, 11, 5.5)
