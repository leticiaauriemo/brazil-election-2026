# The deputy versions of the presidential recommendation exhibits: which party the one
# named candidate belongs to, by profile and model; the same conditional on naming one;
# and party shares next to the 2022 seat shares.
# Output: figures/03_deputy_recommendations, 03_deputy_recommendations_conditional,
#         03_deputy_vs_seats
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup_deputy.R"
))
opts <- read_table("options_by_profile") %>%
  filter(office == "federal_deputy")
top <- opts %>%
  group_by(option) %>%
  summarise(p = mean(unconditional), .groups = "drop") %>%
  slice_max(p, n = 6)
place <- function(d) d %>%
  mutate(model = model_name(model_key), profile = profile_name(archetype))
p <- opts %>%
  semi_join(top, by = "option") %>%
  place() %>%
  ggplot(aes(option, profile, fill = unconditional)) +
  geom_tile(color = "grey90") +
  facet_wrap(~model, nrow = 2) +
  scale_fill_gradient(low = "white", high = palette[["navy"]], labels = pct, limits = c(0, 1)) +
  labs(
    x = NULL, y = NULL, fill = "Share of responses recommending",
    caption = paste0(
      "Federal deputy, SP; full profiles, specific-candidate wording. Share of all labelled ",
      "responses that name one candidate from this party, including answers that name nobody."
    )
  ) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1, size = 7))
save_figure("03_deputy_recommendations", p, 15, 7)

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
option_levels <- c(top$option[order(-top$p)], "names one")
p <- place(named) %>%
  mutate(option = factor(option, option_levels)) %>%
  ggplot(aes(option, profile, fill = share)) +
  geom_tile(color = "grey90") +
  geom_text(
    data = place(rate_labels) %>% mutate(option = factor("names one", option_levels)),
    aes(option, profile, label = label), inherit.aes = FALSE, size = 2.3, color = palette[["grey"]]
  ) +
  facet_wrap(~model, nrow = 2) +
  scale_x_discrete(drop = FALSE) +
  scale_fill_gradient(
    low = "white", high = palette[["navy"]], labels = pct, limits = c(0, 1), na.value = "grey96"
  ) +
  labs(
    x = NULL, y = NULL, fill = "Share of single-candidate answers from this party",
    caption = paste0(
      "Federal deputy, SP; full profiles, specific-candidate wording. Among answers that ",
      "name exactly one candidate, the share whose candidate belongs to each party; the last ",
      "column is the share of all answers that name one. Rows under 2% are left blank."
    )
  ) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1, size = 7))
save_figure("03_deputy_recommendations_conditional", p, 15, 7)

# Party shares next to the 2022 seat share, as figure 4 does for the presidential poll.
bench <- read_table("benchmark_comparison") %>%
  filter(office == "federal_deputy") %>%
  filter(!is.na(benchmark) | models_equal >= .02 | advice_weighted >= .02) %>%
  mutate(benchmark = replace_na(benchmark, 0)) %>%
  pivot_longer(
    c(benchmark, models_equal, advice_weighted), names_to = "series", values_to = "value"
  ) %>%
  mutate(series = factor(
    recode(series,
      benchmark = "2022 seat share, Sao Paulo",
      models_equal = "AI recommendations, models weighted equally",
      advice_weighted = "AI recommendations, models weighted by how often they name one"
    ),
    c(
      "2022 seat share, Sao Paulo",
      "AI recommendations, models weighted equally",
      "AI recommendations, models weighted by how often they name one"
    )
  ))
p <- bench %>%
  mutate(label = reorder(label, value, FUN = max)) %>%
  ggplot(aes(value, label, color = series, shape = series)) +
  geom_point(size = 2.4, position = position_dodge(width = .5)) +
  scale_x_continuous(labels = pct) +
  scale_color_manual(values = unname(palette[c("gold", "navy", "teal")])) +
  scale_shape_manual(values = c(16, 16, 17)) +
  labs(
    x = NULL, y = NULL,
    caption = paste0(
      "Federal deputy, SP; full profiles, specific-candidate wording, answers naming one ",
      "candidate, counted by that candidate's party; profiles weighted by population share. ",
      "Few answers name a single deputy, so the shares rest on a small base."
    )
  ) +
  guides(color = guide_legend(nrow = 3))
save_figure("03_deputy_vs_seats", p, 9, 6)
message("Deputy options: ", nrow(opts), " rows; top parties ", paste(top$option, collapse = ", "))
