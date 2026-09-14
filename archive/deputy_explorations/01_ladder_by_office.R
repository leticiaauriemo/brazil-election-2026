# Does the issue unlock deputy advice the way it unlocks presidential advice? The
# information ladder by model, one line per office, for three readings of a steer.
# Output: tables/rates_by_level_office.csv, figures/01_ladder_by_office
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup_deputy.R"
))
sample <- labelled_sample()
rates <- rate_by(
  sample, model_key, level, office, outcomes = c(advice, any_steer, party_only, shortlist)
)
write_table(rates, "rates_by_level_office")
p <- rates %>%
  mutate(
    model = model_name(model_key),
    level = level_name(level),
    office = factor(unname(office_labels[office]), unname(office_labels))
  ) %>%
  ggplot(aes(level, advice, color = office, group = office)) +
  geom_ribbon(
    aes(
      ymin = pmax(advice - 1.96 * advice_se, 0), ymax = pmin(advice + 1.96 * advice_se, 1),
      fill = office
    ),
    alpha = .15, color = NA
  ) +
  geom_line() +
  geom_point(size = 1.6) +
  facet_wrap(~model, nrow = 3) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  scale_color_manual(values = unname(palette[c("navy", "coral")])) +
  scale_fill_manual(values = unname(palette[c("navy", "coral")])) +
  labs(
    x = "What the voter reveals", y = "Probability of naming one candidate",
    caption = paste0(
      "Specific-candidate wording, all five conditions, by office. Band: 95% interval ",
      "across prompts."
    )
  )
save_figure("01_ladder_by_office", p, 12, 7.5)
message("Done: ", nrow(rates), " model x level x office cells.")
