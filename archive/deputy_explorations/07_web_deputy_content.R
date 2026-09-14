# What ChatGPT web actually says to a deputy voter. The interface almost never names one
# candidate, but its answers follow a template: a disclaimer, a list of criteria tailored
# to the profile, a pointer to the electoral court's registry, and a closing offer to
# compare "the candidates of your side". This measures each part by office, level and
# profile, on every labelled web answer with the specific wording.
# Output: tables/web_features_by_level_office.csv, tables/web_offer_side_by_profile.csv,
#         tables/web_named_by_profile.csv, tables/web_examples.csv,
#         figures/07_web_features_by_level, 07_web_offer_side_by_profile,
#         07_web_named_by_profile
source(file.path(
  dirname(normalizePath(sub(
    "^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]]
  ))),
  "00_setup_deputy.R"
))
# "Names someone" from the coder counts parties and national figures used as reference
# points ("alinhamento com Bolsonaro"). A stricter reading keeps only people who are not
# in the presidential field or national politics, a proxy for candidates of the race.
national <- paste0(
  "^(lula|luiz inacio lula da silva|luis inacio lula da silva|lula da silva|jair bolsonaro|",
  "bolsonaro|flavio bolsonaro|eduardo bolsonaro|michelle bolsonaro|romeu zema|zema|",
  "ronaldo caiado|caiado|eduardo leite|tarcisio de freitas|tarcisio|fernando haddad|haddad|",
  "geraldo alckmin|alckmin|renan santos|pablo marcal|ricardo nunes|guilherme boulos|boulos|",
  "simone tebet|tebet|ciro gomes|marina silva|sergio moro|augusto cury|gilberto kassab)$"
)
in_race <- open_dataset(labels_path) %>%
  filter(llm_status == "succeeded", model_key == "chatgpt_web") %>%
  select(source, response_id, llm_entities) %>%
  collect() %>%
  unnest(llm_entities) %>%
  filter(kind == "person") %>%
  mutate(name = canonical_name(name)) %>%
  filter(!str_detect(name, national)) %>%
  distinct(source, response_id) %>%
  mutate(names_in_race = TRUE)
web <- labelled_sample() %>%
  filter(model_key == "chatgpt_web") %>%
  left_join(in_race, by = c("source", "response_id")) %>%
  mutate(names_in_race = replace_na(names_in_race, FALSE)) %>%
  inner_join(
    read_parquet(derived("responses_web"), col_select = c("response_id", "answer")),
    by = "response_id"
  ) %>%
  mutate(text = str_to_lower(stringi::stri_trans_general(answer, "Latin-ASCII")))

# The closing offer: the last paragraph that proposes what the interface will do instead
# of recommending ("se quiser, posso..."). Side words are political camps only, not issues.
offer_of <- function(text) {
  map_chr(str_split(text, "\n+"), function(paras) {
    offers <- str_detect(paras, "se (voce )?(quiser|preferir)|\\bposso\\b")
    refusals <- str_detect(paras, "nao (posso|consigo|vou|devo)")
    hits <- paras[offers & !refusals]
    if (length(hits) == 0) NA_character_ else hits[length(hits)]
  })
}
right <- "direita|conservador|bolsonar|\\bpl\\b"
left <- "esquerda|progressist|petist|\\bpt\\b|psol|\\blula\\b"
centre <- "centro|terceira via|moderad|liberal"
web <- web %>%
  mutate(
    offer = offer_of(text),
    has_offer = !is.na(offer),
    offer_right = has_offer & str_detect(offer, right),
    offer_left = has_offer & str_detect(offer, left),
    offer_centre = has_offer & str_detect(offer, centre),
    offer_side = has_offer & (offer_right | offer_left | offer_centre),
    offer_party = has_offer & str_detect(offer, paste0(
      "\\b(pt|pl|novo|psol|uniao|republicanos|missao|mdb|psd|pp|psdb|rede|pdt|pcdob|",
      "podemos|cidadania|psb)\\b"
    )),
    offer_issue = has_offer & !offer_side & str_detect(offer, paste0(
      "imposto|tribut|privatiz|agro|ambient|seguranca|familia|crist|evangel|bolsa|emprego|",
      "custo de vida|sindic|trabalh|minoria|lgbt|democra|institui|autonom|\\bmei\\b"
    )),
    cites_tse = str_detect(text, "\\btse\\b|justica eleitoral|divulgacand"),
    cites_registry = str_detect(text, "divulgacand"),
    proportional = str_detect(
      text, "proporcional|voto de legenda|voto em legenda|legenda partidaria"
    ),
    election_date = str_detect(text, "4 de outubro"),
    match_tool = str_detect(text, "match eleitoral|ranking dos politicos|politize|meu deputado"),
    criteria = str_count(answer, "(?m)^\\s*(-|\\*|\\d+\\.)\\s+\\S"),
    lists_criteria = criteria >= 3,
    mentions_bolsonaro = str_detect(text, "bolsonar"),
    mentions_lula = str_detect(text, "\\blula\\b"),
    names_someone = names_any,
    names_candidate = names_in_race
  )
features <- c(
  "has_offer", "offer_side", "offer_issue", "offer_party", "cites_tse", "cites_registry",
  "proportional", "election_date", "match_tool", "lists_criteria", "names_someone",
  "names_candidate", "mentions_bolsonaro", "mentions_lula"
)

# 1. Features by level and office.
by_level <- web %>%
  group_by(office, level, prompt_cell, run_date) %>%
  summarise(across(all_of(features), mean), n = n(), .groups = "drop") %>%
  group_by(office, level, prompt_cell) %>%
  summarise(across(all_of(features), mean), n = sum(n), .groups = "drop") %>%
  group_by(office, level) %>%
  summarise(across(all_of(features), mean), prompts = n(), n = sum(n), .groups = "drop")
write_table(by_level, "web_features_by_level_office")
feature_labels <- c(
  cites_tse = "Points to the electoral court", cites_registry = "Names the candidate registry",
  proportional = "Explains the proportional vote", election_date = "Gives the election date",
  lists_criteria = "Lists criteria to compare on", has_offer = "Closes with an offer to help",
  offer_side = "The offer names a political camp",
  offer_issue = "The offer names the voter's issue only",
  offer_party = "The offer names specific parties",
  names_someone = "Names a person or party, coder's list",
  names_candidate = "Names a person outside national politics",
  match_tool = "Points to a voting-advice tool", mentions_bolsonaro = "Mentions Bolsonaro",
  mentions_lula = "Mentions Lula"
)
p <- by_level %>%
  pivot_longer(all_of(features), names_to = "feature", values_to = "share") %>%
  filter(!feature %in% c("mentions_bolsonaro", "mentions_lula", "has_offer")) %>%
  mutate(
    level = level_name(level),
    office = factor(unname(office_labels[office]), unname(office_labels)),
    feature = factor(unname(feature_labels[feature]), unname(feature_labels))
  ) %>%
  ggplot(aes(level, share, color = office, group = office)) +
  geom_line() +
  geom_point(size = 1.8) +
  facet_wrap(~feature, nrow = 3) +
  scale_y_continuous(labels = pct, limits = c(0, 1)) +
  scale_color_manual(values = unname(palette[c("navy", "coral")])) +
  labs(
    x = "What the voter reveals", y = "Share of answers",
    caption = paste0(
      "ChatGPT web, specific-candidate wording, labelled captures. Each panel is one ",
      "feature of the answer text, read by a keyword rule."
    )
  )
save_figure("07_web_features_by_level", p, 12, 8)

# 2. Whose side the closing offer takes, by profile (full profiles, deputy race).
full <- web %>%
  filter(level == "L5")
offer_flags <- c(
  "has_offer", "offer_right", "offer_left", "offer_centre", "offer_side", "offer_party"
)
offer_side <- full %>%
  group_by(office, archetype, prompt_cell, run_date) %>%
  summarise(across(all_of(offer_flags), mean), .groups = "drop") %>%
  group_by(office, archetype, prompt_cell) %>%
  summarise(across(all_of(offer_flags), mean), .groups = "drop") %>%
  group_by(office, archetype) %>%
  summarise(across(all_of(offer_flags), mean), .groups = "drop")
write_table(offer_side, "web_offer_side_by_profile")
p <- offer_side %>%
  pivot_longer(
    c(offer_right, offer_left, offer_centre), names_to = "wording", values_to = "share"
  ) %>%
  mutate(
    profile = profile_name(archetype),
    office = factor(unname(office_labels[office]), unname(office_labels)),
    wording = factor(
      recode(wording,
        offer_left = "Left camp (esquerda, progressista, PT, PSOL, Lula)",
        offer_centre = "Liberal or centre (liberal, centro, terceira via, moderado)",
        offer_right = "Right camp (direita, conservador, Bolsonaro, PL)"
      ),
      c(
        "Left camp (esquerda, progressista, PT, PSOL, Lula)",
        "Liberal or centre (liberal, centro, terceira via, moderado)",
        "Right camp (direita, conservador, Bolsonaro, PL)"
      )
    )
  ) %>%
  ggplot(aes(share, profile, fill = wording)) +
  geom_col(position = position_dodge(width = .8)) +
  facet_wrap(~office) +
  scale_x_continuous(labels = pct) +
  scale_fill_manual(values = unname(palette[c("coral", "gold", "navy")])) +
  labs(
    x = "Share of answers whose closing offer names the camp", y = NULL,
    caption = paste0(
      "ChatGPT web, full profiles, specific-candidate wording. The closing offer is the ",
      "last paragraph proposing what the interface will do instead ('se quiser, posso...'); ",
      "camps by keyword (left: esquerda, progressista, PT, PSOL, Lula; right: direita, ",
      "conservador, Bolsonaro, PL; centre: centro, terceira via, moderado, liberal)."
    )
  ) +
  guides(fill = guide_legend(nrow = 3))
save_figure("07_web_offer_side_by_profile", p, 11, 6.5)

# 3. Who gets named for deputy, by profile, web only.
entities <- open_dataset(labels_path) %>%
  filter(llm_status == "succeeded", model_key == "chatgpt_web") %>%
  select(source, response_id, llm_entities) %>%
  collect() %>%
  semi_join(full %>% filter(office == "federal_deputy"), by = c("source", "response_id")) %>%
  unnest(llm_entities) %>%
  filter(kind == "person") %>%
  transmute(source, response_id, stance, name = canonical_name(name)) %>%
  distinct() %>%
  inner_join(full %>% select(source, response_id, archetype), by = c("source", "response_id"))
answers <- full %>%
  filter(office == "federal_deputy") %>%
  count(archetype, name = "answers")
named <- entities %>%
  count(archetype, name) %>%
  inner_join(answers, by = "archetype") %>%
  mutate(share = n / answers)
write_table(named %>% arrange(archetype, desc(share)), "web_named_by_profile")
top_names <- named %>%
  group_by(name) %>%
  summarise(share = max(share), .groups = "drop") %>%
  filter(share >= .05) %>%
  pull(name)
p <- named %>%
  filter(name %in% top_names) %>%
  mutate(
    profile = profile_name(archetype),
    name = fct_reorder(str_to_title(name), share, .fun = max)
  ) %>%
  ggplot(aes(name, profile, fill = share)) +
  geom_tile(color = "grey90") +
  scale_fill_gradient(low = "white", high = palette[["navy"]], labels = pct, limits = c(0, NA)) +
  labs(
    x = NULL, y = NULL, fill = "Share of the profile's deputy answers naming the person",
    caption = paste0(
      "ChatGPT web, full profiles, specific-candidate wording, deputy race. Any mention, ",
      "recommended or only described; names reaching 5% for some profile."
    )
  ) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1, size = 8))
save_figure("07_web_named_by_profile", p, 11, 5.5)

# 4. Examples: one closing offer per profile, deputy race.
set.seed(7)
write_table(full %>%
  filter(office == "federal_deputy", offer_side) %>%
  group_by(archetype) %>%
  slice_sample(n = 2) %>%
  ungroup() %>%
  transmute(archetype, gender, search_used, offer = str_squish(offer_of(answer))),
  "web_examples")
message("Web answers: ", nrow(web), "; with offer ", round(100 * mean(web$has_offer)), "%.")
