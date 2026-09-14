# The consumer surface. ChatGPT on the web is what most Brazilian users see, so
# it gets its own exhibits: the same ladder as the OpenAI API models, how stable
# the answer is across hundreds of captures of one prompt, which options it
# names, and what it cites when it advises. Specific-candidate wording unless
# stated; L5 option shares pool both wordings, as in 07b.
# Inputs: reviewed tables from 07/07b, coding_analysis, responses,
#         data/ranqia/raw/citations.parquet.
# Outputs: reviewed/<coder>/tables/web_*, figures 14_-16_.

this_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
source(file.path(dirname(normalizePath(this_file)), "R", "utils.R"))
status <- "Automated semantic coding without completed human validation; ChatGPT web captures by Ranqia, 21-29 August 2026; specific-candidate wording."
export <- function(name, plot, denominator, width = 9, height = 5) {
  plot <- plot + labs(caption = str_wrap(paste(status, denominator), width = round(width * 15))) + theme_round(11)
  ggsave(file.path(result_dir, "figures", paste0(name, ".png")), plot, width = width, height = height, dpi = 180, bg = "white")
  ggsave(file.path(result_dir, "figures", paste0(name, ".pdf")), plot, width = width, height = height)
}

# 1. Same company, different surface: the ladder for the OpenAI models and the web --
openai <- c("gpt4o", "gpt56_luna", "gpt56_sol", "chatgpt_web")
ladder <- read_result("rates_by_level") %>% filter(model_key %in% openai, outcome %in% c("gives_advice", "refusal_language")) %>%
  select(model_key, level, outcome, rate, se) %>% pivot_wider(names_from = outcome, values_from = c(rate, se)) %>%
  rename(gives_advice = rate_gives_advice, refusal_language = rate_refusal_language)
write_result(ladder, "web_vs_api_by_level")
p <- ladder %>% mutate(model = factor(unname(model_labels[model_key]), levels = unname(model_labels[openai])),
    level = factor(level, level_order, labels = str_replace(unname(level_labels[level_order]), "Biography \\+ issue", "Bio +\nissue"))) %>%
  ggplot(aes(level, gives_advice, color = model, group = model)) + geom_line(linewidth = .9) +
  geom_errorbar(aes(ymin = pmax(gives_advice - 1.96 * se_gives_advice, 0), ymax = pmin(gives_advice + 1.96 * se_gives_advice, 1)), width = .1) + geom_point(size = 2.2) +
  scale_color_manual(values = setNames(c(palette[["coral"]], palette[["gold"]], palette[["teal"]], palette[["navy"]]), unname(model_labels[openai]))) +
  scale_y_continuous(labels = scales::label_percent(), limits = c(0, 1)) + labs(x = "What the voter reveals", y = "Probability of positive advice", color = NULL)
export("14_web_vs_api_ladder", p, "Whiskers: 95% intervals across prompt cells. The web surface runs an unidentified model; API rows are the named configurations.", width = 8, height = 4.8)

# 2. Stability of the web answer across captures of the same prompt ---------------
coding <- read_parquet(derived_path("coding_analysis")) %>% filter(label_status == "labelled")
meta <- read_parquet(derived_path("responses"), col_select = c("source", "response_id", "model_key", "cell_id", "condition_id",
  "question_id", "archetype", "level", "gender", "office", "ask", "run_date", "citation_count", "search_used", "answer_chars"))
web <- meta %>% filter(source == "chatgpt_web") %>% inner_join(coding, by = c("source", "response_id"))
# Prompts with at least 20 advice-giving captures: how often is the same option named?
option_col <- function(kind) if (kind == "people") "recommended_people" else "recommended_parties"
stability <- map_dfr(c("people", "parties"), function(kind) {
  web %>% filter(ask == "candidate", gives_advice, .data[[option_col(kind)]] != "") %>%
    separate_rows(all_of(option_col(kind)), sep = "\\|") %>% rename(option = all_of(option_col(kind))) %>%
    group_by(cell_id, level, gender, office, archetype) %>% mutate(n_advice_answers = n_distinct(response_id)) %>%
    count(cell_id, level, gender, office, archetype, n_advice_answers, option, name = "answers_naming") %>%
    mutate(share_naming = answers_naming / n_advice_answers) %>% group_by(cell_id, level, gender, office, archetype, n_advice_answers) %>%
    summarise(distinct_options = n(), top_option = option[which.max(share_naming)], top_share = max(share_naming), .groups = "drop") %>%
    mutate(kind = kind)
})
write_result(stability, "web_prompt_option_stability")
# One row per prompt: how often the advice names the same person, and who that is.
# Full profiles only, the same eighteen prompts for each office. Every labelled capture
# of a prompt falls in one of three bins: no advice; advice naming the prompt's lead
# option (the person, or the party when no person is named, that advice-giving captures
# name most often); advice naming something else. The lead option and the runner-up are
# printed beside the bar, with their shares among advice-giving captures.
captures <- web %>% filter(ask == "candidate", level == "L5") %>%
  mutate(options = case_when(!gives_advice ~ "", recommended_people != "" ~ recommended_people, TRUE ~ recommended_parties),
    option_kind = if_else(recommended_people != "", "person", "party"))
# Free-text party strings ("partidos e federacoes situados no campo...") are the answer's
# phrasing, not an option; only acronyms count as parties.
named <- captures %>% filter(gives_advice, options != "") %>% separate_rows(options, sep = "\\|") %>% rename(option = options) %>%
  filter(option_kind == "person" | str_detect(option, "^[A-Z]{2,13}(-[A-Z]{2,13})?$")) %>%
  count(cell_id, option_kind, option, name = "answers_naming")
ranking <- named %>% group_by(cell_id) %>% arrange(desc(answers_naming), option, .by_group = TRUE) %>%
  summarise(lead = first(option), lead_kind = first(option_kind), lead_n = first(answers_naming),
    second = nth(option, 2), second_kind = nth(option_kind, 2), second_n = nth(answers_naming, 2), distinct_options = n(), .groups = "drop")
lead <- captures %>% left_join(ranking, by = "cell_id") %>% group_by(cell_id, gender, office, archetype) %>%
  summarise(n_labelled = n(), n_advice = sum(gives_advice),
    n_lead = sum(gives_advice & str_detect(paste0("|", options, "|"), fixed(paste0("|", first(lead), "|"))), na.rm = TRUE),
    lead = first(lead), lead_kind = first(lead_kind), second = first(second), second_kind = first(second_kind), second_n = first(second_n),
    distinct_options = first(distinct_options), .groups = "drop") %>%
  mutate(n_other = n_advice - n_lead, share_no_advice = 1 - n_advice / n_labelled, share_lead = n_lead / n_labelled, share_other = n_other / n_labelled,
    lead_share_of_advice = if_else(n_advice > 0, n_lead / n_advice, NA_real_), second_share_of_advice = if_else(n_advice > 0, second_n / n_advice, NA_real_))
write_result(lead %>% select(-starts_with("share_")), "web_prompt_lead_option")
pretty <- function(x, kind) if_else(kind == "person", str_to_title(x), x)
shown <- lead %>%
  mutate(prompt = paste0(unname(archetype_labels[archetype]), ", ", recode(gender, homem = "man", mulher = "woman")),
    prompt = factor(prompt, levels = rev(paste0(rep(unname(archetype_labels[archetype_levels]), each = 2), ", ", c("man", "woman")))),
    office = factor(recode(office, president = "President", federal_deputy = "Federal deputy, SP"), c("President", "Federal deputy, SP")),
    note = case_when(n_advice == 0 ~ "no advice in any capture",
      is.na(second) ~ sprintf("%s %s  (n = %d)", pretty(lead, lead_kind), scales::percent(lead_share_of_advice, accuracy = 1), n_advice),
      TRUE ~ sprintf("%s %s, also %s %s  (n = %d)", pretty(lead, lead_kind), scales::percent(lead_share_of_advice, accuracy = 1),
        pretty(second, second_kind), scales::percent(second_share_of_advice, accuracy = 1), n_advice)))
bars <- shown %>% select(prompt, office, share_no_advice, share_lead, share_other) %>%
  pivot_longer(starts_with("share_"), names_to = "bin", values_to = "share") %>%
  mutate(bin = factor(recode(bin, share_no_advice = "No advice", share_lead = "Advice naming the lead option", share_other = "Advice naming another option"),
    levels = c("Advice naming another option", "Advice naming the lead option", "No advice")))
p <- ggplot(bars, aes(share, prompt, fill = bin)) + geom_col(width = .7) +
  geom_text(data = shown, aes(x = 1.03, y = prompt, label = note), inherit.aes = FALSE, hjust = 0, size = 2.2, color = palette[["ink"]]) +
  facet_wrap(~office) + scale_x_continuous(labels = scales::label_percent(), breaks = seq(0, 1, .25), limits = c(0, 2.35), expand = c(0, 0)) +
  scale_fill_manual(values = c(`No advice` = "grey88", `Advice naming the lead option` = palette[["navy"]], `Advice naming another option` = palette[["coral"]])) +
  labs(x = "Share of labelled captures of the prompt", y = NULL, fill = NULL) + guides(fill = guide_legend(reverse = TRUE))
export("15_web_option_stability", p, "Full profiles (attitudes added), specific-candidate wording; one bar per prompt, 300-400 labelled captures each. The lead option is the person, or the party when no person is named, that advice-giving captures name most often; the text gives it and the runner-up with their shares of the n advice-giving captures; shares can both be high when answers name a shortlist.", width = 14, height = 6.5)

# 3. Where the web surface sends each full profile, next to the API modal party ------
parties <- read_result("party_recommendations_by_model") %>% filter(str_detect(entity, "^[A-Z]{2,13}(-[A-Z]{2,13})?$"), unconditional > 0) %>%
  group_by(model_key, archetype, office) %>% mutate(share = unconditional / sum(unconditional)) %>% ungroup()
web_top <- parties %>% filter(model_key == "chatgpt_web") %>% group_by(archetype, office) %>%
  summarise(web_advice_rate = first(advice_rate), web_top_party = entity[which.max(share)], web_top_share = max(share), .groups = "drop")
api_top <- parties %>% filter(model_key != "chatgpt_web") %>% group_by(model_key, archetype, office) %>% slice_max(share, n = 1, with_ties = FALSE) %>%
  group_by(archetype, office) %>% summarise(api_models = n(), api_modal_party = names(which.max(table(entity))),
    api_models_agreeing = mean(entity == api_modal_party), .groups = "drop")
write_result(full_join(web_top, api_top, by = c("archetype", "office")) %>% arrange(office, archetype), "web_vs_api_top_party")

# 4. What the web surface cites, by whether the answer advises ---------------------
citations <- read_parquet(file.path(ranqia_raw_dir, "citations.parquet"), col_select = c("execution_id", "domain", "cited_in_answer")) %>%
  filter(cited_in_answer) %>% mutate(domain = str_remove(str_to_lower(domain), "^www\\."))
classify <- function(d) case_when(
  str_detect(d, "tse\\.jus\\.br|\\.gov\\.br|camara\\.leg\\.br|senado\\.leg\\.br|\\.jus\\.br|planalto") ~ "Official (TSE, Congress, government)",
  str_detect(d, "wikipedia") ~ "Wikipedia",
  str_detect(d, "globo\\.com|folha\\.uol|uol\\.com|estadao|cnnbrasil|poder360|metropoles|veja\\.abril|cartacapital|band\\.uol|r7\\.com|terra\\.com|correiobraziliense|gazetadopovo|jota\\.info|nexojornal|valor|infomoney|exame|istoe|oglobo|bbc\\.com|reuters|nytimes|elpais|dw\\.com|agenciabrasil|congressoemfoco|brasildefato|revistaforum|oantagonista|gazetadopovo|jovempan|cnn\\.com|theintercept|piaui") ~ "Press and news",
  str_detect(d, "instagram|facebook|youtube|twitter|x\\.com|tiktok|linkedin|threads") ~ "Social media",
  str_detect(d, "\\.org\\.br|partido|psol|pt\\.org|novo\\.org|pl\\.org|mbl|missao") ~ "Party and movement sites",
  TRUE ~ "Other")
web_cites <- web %>% filter(ask == "candidate") %>% mutate(execution_id = as.integer(response_id)) %>%
  select(execution_id, level, gives_advice) %>% inner_join(citations, by = "execution_id") %>% mutate(category = classify(domain))
cite_rates <- web %>% filter(ask == "candidate") %>% group_by(level, gives_advice) %>%
  summarise(n = n(), share_with_citation = mean(citation_count > 0), share_search = mean(search_used), mean_citations = mean(citation_count), .groups = "drop")
write_result(cite_rates, "web_citation_rates")
domains <- web_cites %>% count(gives_advice, category, domain, name = "citations") %>% group_by(gives_advice) %>%
  mutate(share = citations / sum(citations)) %>% ungroup() %>% arrange(gives_advice, desc(citations))
write_result(domains, "web_cited_domains")
categories <- web_cites %>% count(gives_advice, category, name = "citations") %>% group_by(gives_advice) %>% mutate(share = citations / sum(citations)) %>% ungroup()
write_result(categories, "web_cited_categories")
p <- categories %>% mutate(answer = if_else(gives_advice, "Answers that advise", "Answers that do not"),
    category = factor(category, levels = c("Official (TSE, Congress, government)", "Press and news", "Wikipedia", "Party and movement sites", "Social media", "Other"))) %>%
  ggplot(aes(share, answer, fill = category)) + geom_col() + scale_x_continuous(labels = scales::label_percent()) +
  scale_fill_manual(values = unname(palette[c("navy", "gold", "teal", "coral", "blue", "light")])) +
  labs(x = "Share of citations shown in the answer", y = NULL, fill = NULL) + guides(fill = guide_legend(nrow = 2))
export("16_web_citation_sources", p, "Citations rendered in the visible answer, classified by domain; one citation is one link occurrence.", width = 10, height = 3.6)
message("Web exhibits written to ", result_dir)
