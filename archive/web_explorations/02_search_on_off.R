# Same prompt, with and without a web search. About 43% of captures ran a search; does
# the interface name a candidate more often when it did, and does it name someone else?
# Observational: whether a search runs is the interface's choice, not ours.
# Output: tables/search_on_off_by_prompt.csv, figures/02_*
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]))), "00_setup_explore.R"))
web <- web_sample() %>% filter(ask == "candidate", level == "L5")
by_prompt <- web %>% group_by(prompt_cell, archetype, gender, office, search_used) %>%
  summarise(n = n(), naming = mean(advice), lead = if (any(advice)) names(which.max(table(people[advice]))) else NA_character_, .groups = "drop") %>%
  mutate(search_used = if_else(search_used, "searched", "no_search")) %>%
  pivot_wider(names_from = search_used, values_from = c(n, naming, lead))
write_table(by_prompt, "search_on_off_by_prompt")
pooled <- by_prompt %>% filter(n_searched >= 20, n_no_search >= 20) %>%
  summarise(prompts = n(), searched = mean(naming_searched), no_search = mean(naming_no_search),
    difference = mean(naming_searched - naming_no_search), se = sd(naming_searched - naming_no_search) / sqrt(n()))
write_table(pooled, "search_on_off_pooled")
p <- by_prompt %>% filter(n_searched >= 20, n_no_search >= 20) %>%
  mutate(prompt = paste0(unname(archetype_labels[archetype]), ", ", recode(gender, homem = "man", mulher = "woman")),
    prompt = factor(prompt, rev(paste0(rep(unname(archetype_labels[archetype_levels]), each = 2), ", ", c("man", "woman")))),
    office = factor(unname(office_labels[office]), unname(office_labels))) %>%
  ggplot(aes(y = prompt)) + geom_segment(aes(x = naming_no_search, xend = naming_searched, yend = prompt), color = "grey70") +
  geom_point(aes(x = naming_no_search, color = "Without a search"), size = 2.2) +
  geom_point(aes(x = naming_searched, color = "With a search"), size = 2.2) +
  facet_wrap(~office) + scale_x_continuous(labels = pct, limits = c(0, 1)) +
  scale_color_manual(values = c(`Without a search` = palette[["grey"]], `With a search` = palette[["navy"]])) +
  labs(x = "Share of captures naming one candidate", y = NULL, color = NULL,
    caption = "ChatGPT web, full profiles, specific-candidate wording, labelled captures; prompts with at least 20 captures of each kind. Whether a search ran is the interface's choice.")
save_figure("02_search_on_off", p, 11, 6)
# Whom it names, with and without a search: the distribution of single-candidate answers over
# names, by the voter's side, president only.
whom <- web %>% filter(office == "president", advice) %>%
  mutate(side = unname(side[archetype]), search = if_else(search_used, "With a search", "Without a search")) %>%
  count(side, search, people, name = "answers") %>% group_by(side, search) %>% mutate(share = answers / sum(answers), n = sum(answers)) %>% ungroup()
write_table(whom, "search_on_off_whom")
p <- whom %>% filter(n >= 20) %>%
  mutate(candidate = str_to_title(people), side = factor(side, c("Left profiles", "Centre profiles", "Right profiles"))) %>%
  ggplot(aes(share, reorder(candidate, share, FUN = max), color = search)) + geom_point(size = 2.4, position = position_dodge(width = .5)) +
  facet_wrap(~side) + scale_x_continuous(labels = pct, limits = c(0, 1)) +
  scale_color_manual(values = c(`With a search` = palette[["navy"]], `Without a search` = palette[["grey"]])) +
  labs(x = "Share of single-candidate answers naming this candidate", y = NULL, color = NULL,
    caption = paste0("ChatGPT web, full profiles, specific-candidate wording, presidential answers that name one candidate (",
      paste(whom %>% distinct(side, search, n) %>% arrange(side, search) %>% mutate(s = paste0(side, ", ", str_to_lower(search), ": ", n)) %>% pull(s), collapse = "; "), ")."))
save_figure("02_search_on_off_whom", p, 12, 5)
message("Pooled difference (searched minus not): ", round(100 * pooled$difference, 1), " pp over ", pooled$prompts, " prompts.")
