# Booktabs tables for the results outline, written from the reviewed tables so
# no number is retyped. Inputs: output/reviewed/llm_gpt-5-mini-2025-08-07/tables.
# Outputs: table_models.tex, table_ladder.tex, table_convergence.tex, values.tex.
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(stringr)})
R <- '../../output/reviewed/llm_gpt-5-mini-2025-08-07/tables'
rd <- function(n) read_csv(file.path(R, paste0(n, '.csv')), show_col_types = FALSE)
labels <- c(gpt4o = "GPT-4o", gpt56_luna = "GPT-5.6 Luna", gpt56_sol = "GPT-5.6 Sol", claude_sonnet5 = "Claude Sonnet 5",
  claude_opus5 = "Claude Opus 5", gemini_pro = "Gemini 3.1 Pro", deepseek_v4_pro = "DeepSeek V4 Pro", grok46 = "Grok 4.6",
  llama_maverick = "Llama 4 Maverick", sabia4 = "Sabi\\'a 4", chatgpt_web = "ChatGPT (web)")
order <- names(labels)
f1 <- function(x) formatC(100 * x, format = "f", digits = 1)
f0 <- function(x) { v <- round(100 * x); v[v == 0] <- 0; formatC(v, format = "f", digits = 0) }
tab <- function(lines, file) writeLines(lines, file)

# Table 1: behaviour by model
m <- rd('rates_by_model') %>% select(model_key, outcome, rate, se) %>%
  pivot_wider(names_from = outcome, values_from = c(rate, se)) %>% mutate(model_key = factor(model_key, order)) %>% arrange(model_key)
rows <- m %>% transmute(row = sprintf("%s & %s & (%s) & %s--%s & %s & %s & %s & %s & %s \\\\", labels[as.character(model_key)],
  f1(rate_gives_advice), f1(se_gives_advice), f1(pmax(rate_gives_advice - 1.96 * se_gives_advice, 0)), f1(pmin(rate_gives_advice + 1.96 * se_gives_advice, 1)), f1(rate_refusal_language),
  f1(rate_disclaimer_with_advice), f1(rate_explicit_endorsement), f1(rate_procedure_guidance), f1(rate_not_coded)))
tab(c("\\begin{tabular}{lrrrrrrrr}", "\\toprule",
  " & \\multicolumn{3}{c}{Positive advice} & Refusal & Disclaimer & Explicit & Procedural & Not \\\\",
  "Configuration & \\% & (s.e.) & 95\\% interval & language & then advice & endorsement & guidance & coded \\\\", "\\midrule",
  rows$row, "\\bottomrule", "\\end{tabular}"), "table_models.tex")

# Table 2: the information ladder as levels, with the issue contrast and its bounds
lv <- rd('rates_by_level') %>% filter(outcome == 'gives_advice') %>% select(model_key, level, rate) %>%
  pivot_wider(names_from = level, values_from = rate)
ct <- rd('contrasts_by_model_bounds') %>% filter(contrast == 'issue_added_to_biography') %>% select(model_key, difference, se, difference_lower, difference_upper)
ct5 <- rd('contrasts_by_model_bounds') %>% filter(contrast == 'attitudes_added_to_biography_and_issue') %>% select(model_key, d5 = difference, se5 = se, robust5 = sign_robust)
rows <- lv %>% left_join(ct, by = 'model_key') %>% left_join(ct5, by = 'model_key') %>% mutate(model_key = factor(model_key, order)) %>% arrange(model_key) %>%
  transmute(row = sprintf("%s & %s & %s & %s & %s & %s & %s & (%s) & %s--%s & %s & (%s)%s \\\\", labels[as.character(model_key)],
    f0(L1), f0(L3), f0(L2), f0(L4), f0(L5), f0(difference), f1(se), f0(difference_lower), f0(difference_upper), f0(d5), f1(se5), if_else(robust5, "", "$^{\\dagger}$")))
tab(c("\\begin{tabular}{lrrrrrrrrrr}", "\\toprule",
  " & \\multicolumn{5}{c}{Advice probability by what the voter reveals (\\%)} & \\multicolumn{3}{c}{Issue added to biography} & \\multicolumn{2}{c}{Attitudes added} \\\\",
  "\\cmidrule(lr){2-6} \\cmidrule(lr){7-9} \\cmidrule(lr){10-11}",
  "Configuration & Nothing & Biography & Issue & Bio + issue & + Attitudes & pp & (s.e.) & bounds & pp & (s.e.) \\\\", "\\midrule",
  rows$row, "\\bottomrule", "\\end{tabular}"), "table_ladder.tex")

# Table 3: convergence at the party level, pooled over models
profile_labels <- c(militante_esquerda = "Left activist", progressista = "Progressive", classes_d_e = "State-dependent",
  liberal_social = "Social liberal", empreendedor_individual = "Solo entrepreneur", conservador_cristao = "Christian conservative",
  agro = "Agribusiness", empresario = "Business owner", extrema_direita = "Far right")
cv <- rd('convergence_pooled') %>% filter(unit == 'party') %>% mutate(archetype = factor(archetype, names(profile_labels))) %>% arrange(archetype, desc(office)) %>%
  transmute(row = sprintf("%s & %s & %d & %s & %s & %s & %.1f \\\\", profile_labels[as.character(archetype)],
    recode(office, president = "President", federal_deputy = "Deputy"), n_models, str_replace_all(str_to_title(str_to_lower(modal_top_option)), "\\b(Pt|Pl|Psol|Novo|Psd|Mdb|Pp)\\b", toupper), f0(models_agreeing), f0(mean_top_share), effective_options))
tab(c("\\begin{tabular}{llrlrrr}", "\\toprule",
  "Profile & Office & Models & Modal top party & Agreeing (\\%) & Top share (\\%) & Eff.\\ parties \\\\", "\\midrule",
  cv$row, "\\bottomrule", "\\end{tabular}"), "table_convergence.tex")
cp <- rd('convergence_pooled') %>% filter(unit == 'person') %>% mutate(archetype = factor(archetype, names(profile_labels))) %>% arrange(desc(office), archetype) %>%
  transmute(row = sprintf("%s & %s & %d & %s & %s & %s & %.1f \\\\", profile_labels[as.character(archetype)],
    recode(office, president = "President", federal_deputy = "Deputy"), n_models, str_to_title(modal_top_option), f0(models_agreeing), f0(mean_top_share), effective_options))
tab(c("\\begin{tabular}{llrlrrr}", "\\toprule",
  "Profile & Office & Models & Modal top candidate & Agreeing (\\%) & Top share (\\%) & Eff.\\ candidates \\\\", "\\midrule",
  cp$row, "\\bottomrule", "\\end{tabular}"), "table_convergence_person.tex")

# Values used in the text
b <- rd('benchmark_comparison'); w <- rd('web_prompt_rates'); c <- rd('web_people_consistency'); pl <- rd('pooled_by_level') %>% filter(outcome == 'gives_advice')
pos <- rd('party_share_by_position')
v <- function(name, x) sprintf("\\newcommand{\\%s}{%s}", name, x)
val <- function(race, ent, col) b %>% filter(race == !!race, entity == ent) %>% pull(col)
tab(c(
  v("webAdvice", f1(rd('rates_by_model') %>% filter(model_key == 'chatgpt_web', outcome == 'gives_advice') %>% pull(rate))),
  v("webNeverAdvise", f0(mean(w$gives_advice == 0))), v("webMostlyAdvise", f0(mean(w$gives_advice >= .5))),
  v("webPairAgreement", f0(mean(c$pair_agreement, na.rm = TRUE))), v("webEligiblePrompts", sum(!is.na(c$pair_agreement))),
  v("poolLone", f1(pl$rate[pl$level == 'L1'])), v("poolLtwo", f1(pl$rate[pl$level == 'L2'])), v("poolLthree", f1(pl$rate[pl$level == 'L3'])),
  v("poolLfour", f1(pl$rate[pl$level == 'L4'])), v("poolLfive", f1(pl$rate[pl$level == 'L5'])),
  v("zemaRec", f0(val('president', 'romeu zema', 'recommended'))), v("zemaPoll", f0(val('president', 'romeu zema', 'benchmark'))),
  v("lulaRec", f0(val('president', 'luiz inacio lula da silva', 'recommended'))), v("lulaPoll", f0(val('president', 'luiz inacio lula da silva', 'benchmark'))),
  v("flavioRec", f0(val('president', 'flavio bolsonaro', 'recommended'))), v("flavioPoll", f0(val('president', 'flavio bolsonaro', 'benchmark'))),
  v("caiadoRec", f0(val('president', 'ronaldo caiado', 'recommended'))), v("caiadoPoll", f0(val('president', 'ronaldo caiado', 'benchmark'))),
  v("curyRec", f1(val('president', 'augusto cury', 'recommended'))), v("curyPoll", f0(val('president', 'augusto cury', 'benchmark'))),
  v("renanRec", f0(val('president', 'renan santos', 'recommended'))), v("renanPoll", f0(val('president', 'renan santos', 'benchmark'))),
  v("novoRec", f0(val('federal_deputy', 'NOVO', 'recommended'))), v("novoSeats", f1(val('federal_deputy', 'NOVO', 'benchmark'))),
  v("zemaRecEq", f0(val('president', 'romeu zema', 'recommended_equal'))), v("novoRecEq", f0(val('federal_deputy', 'NOVO', 'recommended_equal'))),
  v("zemaRecAdv", f0(val('president', 'romeu zema', 'recommended_advice_weighted'))), v("novoRecAdv", f0(val('federal_deputy', 'NOVO', 'recommended_advice_weighted'))),
  v("lulaRecAdv", f0(val('president', 'luiz inacio lula da silva', 'recommended_advice_weighted'))), v("flavioRecAdv", f0(val('president', 'flavio bolsonaro', 'recommended_advice_weighted'))),
  v("caiadoRecAdv", f0(val('president', 'ronaldo caiado', 'recommended_advice_weighted'))), v("plRecAdv", f0(val('federal_deputy', 'PL', 'recommended_advice_weighted'))), v("ptRecAdv", f0(val('federal_deputy', 'PT', 'recommended_advice_weighted'))),
  v("lulaRecEq", f0(val('president', 'luiz inacio lula da silva', 'recommended_equal'))), v("flavioRecEq", f0(val('president', 'flavio bolsonaro', 'recommended_equal'))),
  v("plRec", f0(val('federal_deputy', 'PL', 'recommended'))), v("plSeats", f0(val('federal_deputy', 'PL', 'benchmark'))),
  v("ptRec", f0(val('federal_deputy', 'PT', 'recommended'))), v("ptSeats", f0(val('federal_deputy', 'PT', 'benchmark'))),
  v("leftPT", f0(pos %>% filter(side == 'Left profiles', office == 'federal_deputy', entity == 'PT') %>% pull(share))),
  v("leftPSOL", f0(pos %>% filter(side == 'Left profiles', office == 'federal_deputy', entity == 'PSOL') %>% pull(share))),
  v("leftPCdoB", f0(pos %>% filter(side == 'Left profiles', office == 'federal_deputy', entity == 'PCDOB') %>% pull(share))),
  v("rightPL", f0(pos %>% filter(side == 'Right profiles', office == 'federal_deputy', entity == 'PL') %>% pull(share))),
  v("rightNOVO", f0(pos %>% filter(side == 'Right profiles', office == 'federal_deputy', entity == 'NOVO') %>% pull(share))),
  v("centreNOVO", f0(pos %>% filter(side == 'Centre profiles', office == 'federal_deputy', entity == 'NOVO') %>% pull(share)))
), "values.tex")

# Table 4: secondary flags by configuration
m2 <- rd('rates_by_model') %>% select(model_key, outcome, rate) %>% pivot_wider(names_from = outcome, values_from = rate) %>% mutate(model_key = factor(model_key, order)) %>% arrange(model_key)
rows <- m2 %>% transmute(row = sprintf("%s & %s & %s & %s & %s & %s & %s & %s \\\\", labels[as.character(model_key)], f1(single_named), f1(shortlist), f1(party_only),
  f1(negative_steering), f1(names_any_person), f1(slate_enumeration), f1(stale_timing)))
tab(c("\\begin{tabular}{lrrrrrrr}", "\\toprule", " & \\multicolumn{3}{c}{Form of positive advice} & Negative & Names any & Recites a & Claims 2026 \\\\",
  "Configuration & one person & several & party only & steering & person & slate & undefined \\\\", "\\midrule", rows$row, "\\bottomrule", "\\end{tabular}"), "table_flags.tex")

# Table 5: refusal grounds
g <- rd('refusal_grounds_by_model') %>% pivot_wider(names_from = refusal_grounds, values_from = share) %>% mutate(model_key = factor(model_key, order)) %>% arrange(model_key)
rows <- g %>% transmute(row = sprintf("%s & %s & %s & %s & %s & %s \\\\", labels[as.character(model_key)], f1(none), f1(values_neutrality), f1(candidacies_undefined), f1(epistemic_uncertainty), f1(unknown)))
tab(c("\\begin{tabular}{lrrrrr}", "\\toprule", "Configuration & No refusal & Neutrality, autonomy & Candidacies undefined & Knowledge limits & Unclear ground \\\\", "\\midrule", rows$row, "\\bottomrule", "\\end{tabular}"), "table_grounds.tex")

# Table 6: ideology of recommended parties by profile (L5, both wordings), Zucco-Power
z <- rd('ideology_by_model_profile') %>% group_by(archetype, office) %>% summarise(mean_zeta = mean(mean_zeta, na.rm = TRUE), models = sum(!is.na(mean_zeta)), .groups = "drop") %>%
  pivot_wider(names_from = office, values_from = c(mean_zeta, models)) %>% mutate(archetype = factor(archetype, names(profile_labels))) %>% arrange(archetype)
rows <- z %>% transmute(row = sprintf("%s & %.2f & %d & %.2f & %d \\\\", profile_labels[as.character(archetype)], mean_zeta_president, models_president, mean_zeta_federal_deputy, models_federal_deputy))
tab(c("\\begin{tabular}{lrrrr}", "\\toprule", " & \\multicolumn{2}{c}{President} & \\multicolumn{2}{c}{Federal deputy} \\\\", "\\cmidrule(lr){2-3} \\cmidrule(lr){4-5}",
  "Profile & mean $\\zeta$ & models & mean $\\zeta$ & models \\\\", "\\midrule", rows$row, "\\bottomrule", "\\end{tabular}"), "table_ideology.tex")

# Table 7: web vs API OpenAI by level
wl <- rd('web_vs_api_by_level') %>% select(model_key, level, gives_advice) %>% pivot_wider(names_from = level, values_from = gives_advice) %>%
  mutate(model_key = factor(model_key, c("gpt4o", "gpt56_luna", "gpt56_sol", "chatgpt_web"))) %>% arrange(model_key)
rows <- wl %>% transmute(row = sprintf("%s & %s & %s & %s & %s & %s \\\\", labels[as.character(model_key)], f0(L1), f0(L3), f0(L2), f0(L4), f0(L5)))
tab(c("\\begin{tabular}{lrrrrr}", "\\toprule", "Configuration & Nothing & Biography & Issue & Bio + issue & + Attitudes \\\\", "\\midrule", rows$row, "\\bottomrule", "\\end{tabular}"), "table_web_ladder.tex")

# Table 8: where the web surface sends each full profile, next to the API modal party
wt <- rd('web_vs_api_top_party') %>% mutate(archetype = factor(archetype, names(profile_labels))) %>% arrange(desc(office), archetype)
rows <- wt %>% transmute(row = sprintf("%s & %s & %s & %s & %s & %s & %s \\\\", profile_labels[as.character(archetype)], recode(office, president = "President", federal_deputy = "Deputy"),
  f0(web_advice_rate), web_top_party, f0(web_top_share), api_modal_party, f0(api_models_agreeing)))
tab(c("\\begin{tabular}{llrlrlr}", "\\toprule", " & & \\multicolumn{3}{c}{ChatGPT web} & \\multicolumn{2}{c}{API configurations} \\\\", "\\cmidrule(lr){3-5} \\cmidrule(lr){6-7}",
  "Profile & Office & advice (\\%) & top party & share (\\%) & modal top party & agreeing (\\%) \\\\", "\\midrule", rows$row, "\\bottomrule", "\\end{tabular}"), "table_web_parties.tex")

# Table 9: what the web cites
cc <- rd('web_cited_categories') %>% select(gives_advice, category, share) %>% pivot_wider(names_from = gives_advice, values_from = share, values_fill = 0)
rows <- cc %>% arrange(desc(`TRUE`)) %>% transmute(row = sprintf("%s & %s & %s \\\\", category, f1(`FALSE`), f1(`TRUE`)))
tab(c("\\begin{tabular}{lrr}", "\\toprule", "Source type & Answers without advice & Answers with advice \\\\", "\\midrule", rows$row, "\\bottomrule", "\\end{tabular}"), "table_web_sources.tex")
cd <- rd('web_cited_domains') %>% group_by(gives_advice) %>% slice_head(n = 8) %>% ungroup() %>% mutate(advice = if_else(gives_advice, "with", "without"))
rows <- cd %>% group_by(advice) %>% summarise(row = paste0(sprintf("%s (%s)", str_replace_all(domain, "_", "\\_"), f0(share)), collapse = ", "), .groups = "drop")
tab(c(sprintf("\\newcommand{\\domainsWithout}{%s}", rows$row[rows$advice == "without"]), sprintf("\\newcommand{\\domainsWith}{%s}", rows$row[rows$advice == "with"])), "domains.tex")

# Appendix A: regex vs semantic coder agreement
ag <- read_csv('../../output/tables/agreement_by_model.csv', show_col_types = FALSE) %>% mutate(model_key = factor(model_key, order)) %>% arrange(model_key)
rows <- ag %>% transmute(row = sprintf("%s & %s & %s & %s & %s \\\\", labels[as.character(model_key)], format(n, big.mark = ","), f1(advice_agreement), f1(refusal_agreement), f1(party_set_agreement)))
tab(c("\\begin{tabular}{lrrrr}", "\\toprule", "Configuration & Responses & Positive advice & Refusal language & Recommended-party set \\\\", "\\midrule", rows$row, "\\bottomrule", "\\end{tabular}"), "table_agreement.tex")

# Appendix B: unlabelled share by configuration and level
nc <- rd('rates_by_level') %>% filter(outcome == 'not_coded') %>% select(model_key, level, rate) %>% pivot_wider(names_from = level, values_from = rate) %>% mutate(model_key = factor(model_key, order)) %>% arrange(model_key)
rows <- nc %>% transmute(row = sprintf("%s & %s & %s & %s & %s & %s \\\\", labels[as.character(model_key)], f0(L1), f0(L3), f0(L2), f0(L4), f0(L5)))
tab(c("\\begin{tabular}{lrrrrr}", "\\toprule", "Configuration & Nothing & Biography & Issue & Bio + issue & + Attitudes \\\\", "\\midrule", rows$row, "\\bottomrule", "\\end{tabular}"), "table_missing.tex")

# Web stability values
st <- rd('web_prompt_option_stability') %>% filter(n_advice_answers >= 20)
stv <- st %>% group_by(kind) %>% summarise(prompts = n(), med_top = median(top_share), med_distinct = median(distinct_options), .groups = "drop")
cr <- rd('web_citation_rates')
cat(c(v("webStablePromptsPeople", stv$prompts[stv$kind == "people"]), v("webMedTopPerson", f0(stv$med_top[stv$kind == "people"])), v("webMedDistinctPeople", stv$med_distinct[stv$kind == "people"]),
  v("webStablePromptsParties", stv$prompts[stv$kind == "parties"]), v("webMedTopParty", f0(stv$med_top[stv$kind == "parties"])), v("webMedDistinctParties", stv$med_distinct[stv$kind == "parties"]),
  v("webCiteShare", f0(weighted.mean(cr$share_with_citation, cr$n))), v("webSearchShare", f0(weighted.mean(cr$share_search, cr$n)))), sep = "\n", file = "values.tex", append = TRUE)

# Table 10: linear probability model coefficients for positive advice, by configuration
rg <- rd('regression_by_model') %>% filter(outcome == 'gives_advice') %>% select(model_key, term, estimate, se) %>%
  pivot_wider(names_from = term, values_from = c(estimate, se)) %>% mutate(model_key = factor(model_key, order)) %>% arrange(model_key)
cell <- function(e, s) sprintf("%s (%s)", f0(e), f1(s))
rows <- rg %>% transmute(row = sprintf("%s & %s & %s & %s & %s & %s & %s \\\\", labels[as.character(model_key)],
  cell(`estimate_level::L2`, `se_level::L2`), cell(`estimate_level::L4`, `se_level::L4`), cell(`estimate_level::L5`, `se_level::L5`),
  cell(`estimate_office::federal_deputy`, `se_office::federal_deputy`), cell(`estimate_ask::candidate`, `se_ask::candidate`), cell(`estimate_gender::mulher`, `se_gender::mulher`)))
tab(c("\\begin{tabular}{lrrrrrr}", "\\toprule", " & \\multicolumn{3}{c}{Level, vs biography only} & Deputy & Specific & Woman \\\\", "\\cmidrule(lr){2-4}",
  "Configuration & Issue only & Bio + issue & Attitudes & vs president & vs open & vs man \\\\", "\\midrule", rows$row, "\\bottomrule", "\\end{tabular}"), "table_regression.tex")
cat("tables written\n")
