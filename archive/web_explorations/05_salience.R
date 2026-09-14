# Salience without a recommendation. Among the answers that name no single candidate,
# who is mentioned, how early, and with what tone, by the voter's profile. Uses Ranqia's
# entity mentions (a 0-100 sentiment score, 50 neutral) for the labelled captures.
# Output: tables/salience_by_profile.csv, figures/05_*
source(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]))), "00_setup_explore.R"))
web <- web_sample() %>% filter(ask == "candidate", level == "L5", office == "president", !advice)
candidates <- c("Lula", "Flávio Bolsonaro", "Romeu Zema", "Ronaldo Caiado", "Renan Santos", "Augusto Cury", "Tarcísio de Freitas")
mentions <- open_dataset(file.path(raw, "entity_mention_snippets.parquet")) %>%
  filter(status == "COMPUTED", entity_name %in% candidates) %>%
  select(execution_id, entity_name, start_index, sentiment_score) %>% filter(execution_id %in% web$execution_id) %>% collect() %>%
  inner_join(web %>% select(execution_id, archetype, answer_chars), by = "execution_id")
per_answer <- mentions %>% group_by(execution_id, archetype, entity_name) %>%
  summarise(first_position = min(start_index) / first(answer_chars), sentiment = mean(sentiment_score, na.rm = TRUE), .groups = "drop")
denominators <- web %>% count(archetype, name = "refusing_answers")
salience <- per_answer %>% group_by(archetype, entity_name) %>%
  summarise(answers_mentioning = n(), first_position = mean(first_position), sentiment = mean(sentiment, na.rm = TRUE), .groups = "drop") %>%
  inner_join(denominators, by = "archetype") %>% mutate(share_mentioning = answers_mentioning / refusing_answers)
write_table(salience, "salience_by_profile")
place <- function(d) d %>% mutate(profile = factor(unname(archetype_labels[archetype]), rev(unname(archetype_labels[archetype_levels]))),
  entity_name = factor(entity_name, candidates))
p <- place(salience) %>%
  ggplot(aes(entity_name, profile, fill = share_mentioning)) + geom_tile(color = "grey90") +
  geom_text(aes(label = pct(share_mentioning)), size = 2.6, color = if_else(salience$share_mentioning > .55, "white", palette[["ink"]])) +
  scale_fill_gradient(low = "white", high = palette[["navy"]], labels = pct, limits = c(0, 1)) +
  labs(x = NULL, y = NULL, fill = "Share of refusing answers that mention the candidate",
    caption = "ChatGPT web, full profiles, specific-candidate wording, presidential answers that name no single candidate.")
save_figure("05_salience_mentions", p, 9, 5)
p <- place(salience) %>% filter(entity_name %in% candidates[1:4], answers_mentioning >= 20) %>%
  ggplot(aes(sentiment, profile, color = entity_name)) + geom_vline(xintercept = 50, color = "grey70") +
  geom_point(size = 2.4) + scale_color_manual(values = unname(palette[c("coral", "navy", "teal", "gold")])) +
  labs(x = "Mean sentiment of the candidate's mentions (0-100, 50 neutral)", y = NULL, color = NULL,
    caption = "Same answers; Ranqia's sentiment score per mention, averaged within answer then across answers; candidates with at least 20 mentioning answers per profile.")
save_figure("05_salience_sentiment", p, 9, 5)
message("Mentions: ", nrow(mentions), " in ", n_distinct(mentions$execution_id), " refusing answers.")
