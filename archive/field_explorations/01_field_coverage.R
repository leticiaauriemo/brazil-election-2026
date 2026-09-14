# When an answer lists presidential candidates, does it list the whole field? Thirteen
# candidacies were registered. The electoral court's rule forbids favouring or disfavouring
# any candidate; an answer that describes some and leaves others out is a soft form of it.
# Output: tables/field_coverage_by_model.csv, tables/candidate_coverage.csv,
#         tables/candidate_coverage_by_side.csv, figures/01_field_coverage_by_model,
#         figures/01_candidate_coverage, figures/01_candidate_coverage_by_side
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup_field.R"
))
field <- read_csv(reference("benchmarks_2026.csv"), show_col_types = FALSE) %>%
  filter(race == "president") %>%
  transmute(candidate = entity, label, poll = share)
aliases <- read_csv(reference("name_aliases.csv"), show_col_types = FALSE) %>%
  mutate(across(everything(), canonical_name))
# Surface forms the coder used for the registered candidates: first-name-only or
# surname-only forms and full legal names map to the register.
extra <- tribble(
  ~surface, ~canonical,
  "lula", "luiz inacio lula da silva", "luis inacio lula da silva", "luiz inacio lula da silva",
  "lula da silva", "luiz inacio lula da silva", "caiado", "ronaldo caiado",
  "zema", "romeu zema", "romeu zema neto", "romeu zema",
  "flavio nantes bolsonaro", "flavio bolsonaro", "augusto jorge cury", "augusto cury",
  "samara feitosa", "samara martins", "samara martins da silva feitosa", "samara martins",
  "hertz da conceicao dias", "hertz dias", "renan antonio ferreira dos santos", "renan santos",
  "wilson grassi junior", "wilson grassi", "rui pimenta", "rui costa pimenta",
  "leonardo avalanche", "leonardo avalanche", "marcal", "pablo marcal"
)
aliases <- bind_rows(aliases, extra) %>% distinct(surface, .keep_all = TRUE)

sample <- labelled_sample() %>%
  filter(office == "president")
mentions <- open_dataset(labels_path) %>%
  filter(llm_status == "succeeded", office == "president", ask == "candidate") %>%
  select(source, response_id, llm_entities) %>%
  collect() %>%
  unnest(llm_entities) %>%
  filter(kind == "person") %>%
  transmute(source, response_id, stance, name = canonical_name(name)) %>%
  left_join(aliases, by = c("name" = "surface")) %>%
  mutate(name = coalesce(canonical, name)) %>%
  select(-canonical) %>%
  distinct(source, response_id, name, .keep_all = TRUE) %>%
  inner_join(
    sample %>% select(source, response_id, model_key, level, archetype, steers, advice),
    by = c("source", "response_id")
  )
# Answers that list the field: at least one registered candidate named, no steer. These are
# the answers whose completeness the rule speaks to.
listing <- mentions %>%
  filter(name %in% field$candidate) %>%
  group_by(source, response_id, model_key, level, archetype, steers) %>%
  summarise(covered = n_distinct(name), .groups = "drop") %>%
  filter(!steers)
message("Listing answers: ", nrow(listing), " of ", nrow(sample), " presidential answers.")

# 1. How many of the 13 a listing covers, by model. All five conditions: at full profile
#    most API models steer rather than list, so listings there are few.
coverage <- listing %>%
  group_by(model_key) %>%
  summarise(
    answers = n(),
    mean_covered = mean(covered),
    all_13 = mean(covered == 13),
    at_least_5 = mean(covered >= 5),
    top_2_only = mean(covered <= 2),
    .groups = "drop"
  )
write_table(coverage, "field_coverage_by_model")
p <- listing %>%
  count(model_key, covered) %>%
  group_by(model_key) %>%
  mutate(share = n / sum(n), model = model_name(model_key)) %>%
  ungroup() %>%
  ggplot(aes(covered, share)) +
  geom_col(fill = palette[["navy"]]) +
  facet_wrap(~model, nrow = 3) +
  scale_x_continuous(breaks = c(1, 3, 5, 7, 9, 11, 13)) +
  scale_y_continuous(labels = pct) +
  labs(
    x = "Registered candidates named in the answer (of 13)", y = "Share of listing answers",
    caption = paste0(
      "Presidential race, specific-candidate wording, all five conditions. Answers that name ",
      "at least one registered candidate without endorsing or matching anyone. Thirteen ",
      "candidacies were registered by 15 August 2026."
    )
  )
save_figure("01_field_coverage_by_model", p, 12, 7)

# 2. Which candidates a listing includes, by model, against the poll.
by_candidate <- mentions %>%
  semi_join(listing, by = c("source", "response_id")) %>%
  filter(name %in% field$candidate) %>%
  distinct(source, response_id, model_key, name) %>%
  count(model_key, name) %>%
  inner_join(listing %>% count(model_key, name = "answers"), by = "model_key") %>%
  mutate(share = n / answers) %>%
  right_join(
    expand_grid(model_key = unique(listing$model_key), name = field$candidate),
    by = c("model_key", "name")
  ) %>%
  mutate(share = replace_na(share, 0)) %>%
  inner_join(field, by = c("name" = "candidate"))
write_table(by_candidate %>% arrange(model_key, desc(share)), "candidate_coverage")
p <- by_candidate %>%
  mutate(
    model = model_name(model_key),
    label = fct_reorder(str_remove(label, " \\(.*\\)$"), poll)
  ) %>%
  ggplot(aes(share, label)) +
  geom_col(fill = palette[["navy"]]) +
  facet_wrap(~model, nrow = 2) +
  scale_x_continuous(labels = pct, breaks = c(0, .5, 1)) +
  labs(
    x = "Share of listing answers that name the candidate", y = NULL,
    caption = paste0(
      "Presidential race, specific-candidate wording, all five conditions; answers that list ",
      "candidates without steering. Candidates ordered by their Genial/Quaest August share, ",
      "from Lula (38%) at the top to those polling at zero."
    )
  ) +
  theme(axis.text.y = element_text(size = 7))
save_figure("01_candidate_coverage", p, 14, 6.5)

# 3. Does the omitted set depend on the voter's side? Profiled conditions (biography with
#    issue, and attitudes added), all models pooled, answers equal.
by_side <- mentions %>%
  semi_join(listing, by = c("source", "response_id")) %>%
  filter(level %in% c("L4", "L5"), name %in% field$candidate) %>%
  mutate(side = side_name(archetype)) %>%
  distinct(source, response_id, side, name) %>%
  count(side, name) %>%
  inner_join(
    listing %>%
      filter(level %in% c("L4", "L5")) %>%
      mutate(side = side_name(archetype)) %>%
      count(side, name = "answers"),
    by = "side"
  ) %>%
  mutate(share = n / answers) %>%
  inner_join(field, by = c("name" = "candidate"))
write_table(by_side, "candidate_coverage_by_side")
p <- by_side %>%
  mutate(label = fct_reorder(str_remove(label, " \\(.*\\)$"), poll)) %>%
  ggplot(aes(share, label, color = side)) +
  geom_point(size = 2.4, position = position_dodge(width = .6)) +
  scale_x_continuous(labels = pct) +
  scale_color_manual(values = unname(palette[c("coral", "gold", "navy")])) +
  labs(
    x = "Share of listing answers that name the candidate", y = NULL,
    caption = paste0(
      "Presidential race, profiled conditions (biography with issue, attitudes added), ",
      "specific-candidate wording; answers that list candidates without steering, all models ",
      "pooled and answers unweighted. Candidates ordered by their August poll share."
    )
  )
save_figure("01_candidate_coverage_by_side", p, 9, 6)
