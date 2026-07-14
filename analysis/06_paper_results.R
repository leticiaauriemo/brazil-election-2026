library(tidyverse)
library(sandwich)
library(lmtest)
library(broom)
library(scales)

# Paper-oriented analyses and figures. Run from the repository root.
dir.create("results/paper/figures", showWarnings = FALSE, recursive = TRUE)
df <- read_csv("results/analysis/clean_results.csv", show_col_types = FALSE)
core <- c("claude_opus", "claude_sonnet", "gemini_flash", "gpt4o", "llama", "sabia4")
partial <- c("grok", "mistral", "gemini_pro", "deepseek")
model_labels <- c(
  claude_opus="Claude Opus", claude_sonnet="Claude Sonnet", gemini_flash="Gemini Flash",
  gpt4o="GPT-4o", llama="Llama", sabia4="Sabiá 4", grok="Grok", mistral="Mistral",
  gemini_pro="Gemini Pro", deepseek="DeepSeek", gpt5="GPT-5", claude_fable="Claude Fable"
)
model_order <- c(core, "grok", "mistral", "gemini_pro", "deepseek", "gpt5", "claude_fable")
theme_paper <- theme_minimal(base_size=15) + theme(
  plot.title=element_text(face="bold", size=17),
  plot.subtitle=element_text(color="#4A5568", size=12),
  panel.grid.minor=element_blank(), panel.grid.major.y=element_blank(),
  legend.position="bottom", legend.title=element_blank(),
  axis.text=element_text(color="#1A202C")
)
save_plot <- function(p,n,w=9.5,h=5.3) {
  ggsave(filename=file.path("results/paper/figures",n),plot=p,width=w,height=h,dpi=220,bg="white")
}

# Coverage and response behavior
coverage <- df %>% group_by(model) %>% summarise(
  observed=n(), usable_rows=sum(usable), api_errors=sum(!api_ok),
  empty_or_error=sum(empty_or_error_response), .groups="drop"
) %>% mutate(
  planned=2680L, usable_share=usable_rows/planned,
  model=factor(model, levels=rev(model_order))
)
write_csv(coverage,"results/paper/coverage.csv")
p <- ggplot(coverage,aes(y=model,x=planned)) +
  geom_col(fill="#E2E8F0",width=.72) +
  geom_col(aes(x=observed),fill="#90CDF4",width=.72) +
  geom_col(aes(x=usable_rows),fill="#2B6CB0",width=.72) +
  geom_text(aes(x=planned+55,label=percent(usable_share,accuracy=1)),hjust=0,size=4.1) +
  scale_y_discrete(labels=function(x) recode(x,!!!model_labels)) +
  scale_x_continuous(limits=c(0,3020),breaks=c(0,1000,2000,2680),expand=c(0,0)) +
  labs(title="Six models completed the full design",
       subtitle="Usable responses (dark), recorded calls (light), and 2,680 planned calls (gray)",
       x="Calls per model",y=NULL) + theme_paper
save_plot(p,"01_coverage.png",9.5,6.2)

behavior <- df %>% filter(model %in% core,usable) %>% group_by(model) %>% summarise(
  n=n(), refusal=mean(refused2), party=mean(has_party),
  party_and_disclaimer=mean(has_party&refused2),
  search=mean(did_search,na.rm=TRUE), .groups="drop"
)
write_csv(behavior,"results/paper/response_behavior.csv")
p <- behavior %>% select(model,refusal,party) %>%
  pivot_longer(-model,names_to="outcome",values_to="rate") %>%
  mutate(outcome=recode(outcome,refusal="Refusal / disclaimer",party="Party recommendation"),
         model=factor(model,levels=core)) %>%
  ggplot(aes(rate,model,color=outcome)) +
  geom_line(aes(group=model),color="#CBD5E0",linewidth=1) +
  geom_point(size=3.5) +
  scale_y_discrete(labels=function(x) recode(x,!!!model_labels)) +
  scale_x_continuous(labels=percent_format(accuracy=1),limits=c(0,.8)) +
  scale_color_manual(values=c("Party recommendation"="#2B6CB0","Refusal / disclaimer"="#C53030")) +
  labs(title="Models differ first in whether they will give advice",
       subtitle="Rates among usable responses; a disclaimer can precede a recommendation",
       x="Share of responses",y=NULL) + theme_paper
save_plot(p,"02_behavior.png",9.5,5.2)

taxonomy <- df %>% filter(model %in% core,usable) %>% mutate(type=case_when(
  has_party&refused2~"Party + disclaimer", has_party~"Party, no disclaimer",
  refused2~"Refusal, no party", TRUE~"Other / vague"
)) %>% count(model,type) %>% group_by(model) %>% mutate(share=n/sum(n)) %>% ungroup()
write_csv(taxonomy,"results/paper/response_taxonomy.csv")

# Cluster-robust effects. Coefficients doubled because cues are coded -1/+1.
cluster_tidy <- function(fit,cluster) {
  coeftest(fit,vcov.=vcovCL(fit,cluster=cluster,type="HC1")) %>% tidy() %>%
    filter(term %in% c("label_num","issue_num")) %>%
    mutate(estimate=2*estimate,std.error=2*std.error,
           low=estimate-1.96*std.error,high=estimate+1.96*std.error,
           channel=recode(term,label_num="Label",issue_num="Issue"))
}
model_effects <- function(x) {
  x %>% group_by(model) %>% group_modify(~{
    z <- cluster_tidy(lm(zeta~label_num+issue_num+cargo+ask,data=.x),.x$cond_id)
    z %>% transmute(channel,estimate,se=std.error,low,high,
                    n_party=nrow(.x),n_cells=n_distinct(.x$cond_id))
  }) %>% ungroup()
}

c_party <- df %>% filter(module=="C",usable,has_zeta,!is.na(label_num),!is.na(issue_num))
effects_core <- model_effects(filter(c_party,model %in% core))
effects_all <- model_effects(filter(c_party,model %in% c(core,partial))) %>%
  mutate(completion=if_else(model %in% core,"Complete","Partial"))
write_csv(effects_core,"results/paper/module_c_effects_core.csv")
write_csv(effects_all,"results/paper/module_c_effects_all.csv")

c_core <- filter(c_party,model %in% core)
pooled_fit <- lm(zeta~label_num+issue_num+model+cargo+ask,data=c_core)
pooled <- cluster_tidy(pooled_fit,interaction(c_core$model,c_core$cond_id,drop=TRUE))
write_csv(pooled,"results/paper/module_c_effects_pooled.csv")

p <- effects_core %>% mutate(model=factor(model,levels=rev(core))) %>%
  ggplot(aes(estimate,model,color=channel)) +
  geom_vline(xintercept=0,color="#A0AEC0") +
  geom_errorbarh(aes(xmin=low,xmax=high),height=0,position=position_dodge(.52)) +
  geom_point(position=position_dodge(.52),size=3.2) +
  scale_y_discrete(labels=function(x) recode(x,!!!model_labels)) +
  scale_color_manual(values=c(Label="#805AD5",Issue="#2B6CB0")) +
  labs(title="Both political identity and policy content move recommendations",
       subtitle="Full left-to-right shift in party score; 95% cluster-robust confidence intervals",
       x="Change in recommended-party ideology (zeta)",y=NULL) + theme_paper
save_plot(p,"03_main_effects.png")

content_share <- effects_core %>% select(model,channel,estimate,n_party) %>%
  pivot_wider(names_from=channel,values_from=estimate) %>%
  mutate(content_share=Issue/(Label+Issue),model_label=recode(model,!!!model_labels))
write_csv(content_share,"results/paper/content_share.csv")
p <- ggplot(content_share,aes(content_share,reorder(model_label,content_share))) +
  geom_vline(xintercept=.5,linetype="dashed",color="#718096") +
  geom_segment(aes(x=.5,xend=content_share,yend=reorder(model_label,content_share)),
               color="#CBD5E0",linewidth=1.2) +
  geom_point(aes(color=content_share>=.5),size=4) +
  geom_text(aes(label=percent(content_share,accuracy=1)),hjust=-.25,size=4.2) +
  scale_color_manual(values=c("TRUE"="#2B6CB0","FALSE"="#805AD5"),guide="none") +
  scale_x_continuous(labels=percent_format(accuracy=1),limits=c(.2,.7)) +
  labs(title="Policy content dominates for half of the complete models",
       subtitle="Issue effect as a share of the combined label + issue shift",
       x="Content share",y=NULL) + theme_paper
save_plot(p,"04_content_share.png",9,5)

conflict <- c_party %>% filter(model %in% core,cell_type=="conflict",!is.na(zeta_sign)) %>%
  mutate(winner=if_else(zeta_sign==issue_num,"Follows issue","Follows label")) %>%
  count(model,winner) %>% group_by(model) %>% mutate(share=n/sum(n),n_party=sum(n)) %>% ungroup()
write_csv(conflict,"results/paper/conflict_cells.csv")
p <- conflict %>% mutate(model=factor(model,levels=rev(core))) %>%
  ggplot(aes(share,model,fill=winner)) +
  geom_col(width=.68) + geom_vline(xintercept=.5,color="white") +
  scale_y_discrete(labels=function(x) recode(x,!!!model_labels)) +
  scale_x_continuous(labels=percent_format(),expand=c(0,0)) +
  scale_fill_manual(values=c("Follows issue"="#2B6CB0","Follows label"="#805AD5")) +
  labs(title="Conflict cells reveal no universal decision rule",
       subtitle="Direction of the recommended party when label and issue point to opposite sides",
       x="Share of party recommendations",y=NULL) + theme_paper
save_plot(p,"05_conflict.png",9.5,5.2)

pooled_by <- function(x,g) {
  x %>% group_by(across(all_of(g))) %>% group_modify(~{
    z <- cluster_tidy(lm(zeta~label_num+issue_num+model,data=.x),
                      interaction(.x$model,.x$cond_id,drop=TRUE))
    z %>% transmute(channel,estimate,se=std.error,low,high,n=nrow(.x))
  }) %>% ungroup()
}
effects_cue <- pooled_by(c_core,"cue_group")
effects_context <- pooled_by(mutate(c_core,context=paste(cargo,ask,sep=" / ")),"context")
write_csv(effects_cue,"results/paper/effects_by_cue.csv")
write_csv(effects_context,"results/paper/effects_by_context.csv")

p <- ggplot(effects_cue,aes(estimate,cue_group,color=channel)) +
  geom_vline(xintercept=0,color="#A0AEC0") +
  geom_errorbarh(aes(xmin=low,xmax=high),height=0,position=position_dodge(.5)) +
  geom_point(position=position_dodge(.5),size=3.2) +
  scale_y_discrete(labels=c(party_id="Party ID",past_vote="Past vote",
                            past_vote_undec="Past vote + undecided",self_placement="Self-placement")) +
  scale_color_manual(values=c(Label="#805AD5",Issue="#2B6CB0")) +
  labs(title="The result is not tied to one kind of ideological cue",
       subtitle="Pooled across complete models with model fixed effects",
       x="Change in recommended-party ideology (zeta)",y=NULL) + theme_paper
save_plot(p,"06_cue_effects.png",9.5,4.8)

p <- ggplot(effects_context,aes(estimate,context,color=channel)) +
  geom_vline(xintercept=0,color="#A0AEC0") +
  geom_errorbarh(aes(xmin=low,xmax=high),height=0,position=position_dodge(.5)) +
  geom_point(position=position_dodge(.5),size=3.2) +
  scale_y_discrete(labels=c(
    "dep_federal / candidate"="Deputy / specific candidate",
    "dep_federal / open"="Deputy / open advice",
    "presidente / candidate"="President / specific candidate",
    "presidente / open"="President / open advice")) +
  scale_color_manual(values=c(Label="#805AD5",Issue="#2B6CB0")) +
  labs(title="Issue effects survive ballot level and request format",
       subtitle="Pooled across complete models with model fixed effects",
       x="Change in recommended-party ideology (zeta)",y=NULL) + theme_paper
save_plot(p,"07_context_effects.png",9.5,4.8)

# Module A party differentiation
issue_labels <- c(aborto="Abortion",ambiente="Environment",bolsa_familia="Bolsa Familia",
                  minorias="Minority rights",privatizacao="Privatization",seguranca="Security")
a_party <- df %>% filter(model %in% core,usable,module=="A",has_party) %>%
  count(issue_cue,issue_side,party_rec) %>% group_by(issue_cue,issue_side) %>%
  mutate(share=n/sum(n)) %>% ungroup()
top_parties <- a_party %>% count(party_rec,wt=n,sort=TRUE) %>% slice_head(n=9) %>% pull(party_rec)
write_csv(a_party,"results/paper/module_a_party_shares.csv")
p <- a_party %>% filter(party_rec %in% top_parties) %>%
  mutate(issue=recode(issue_cue,!!!issue_labels),party_rec=factor(party_rec,levels=top_parties)) %>%
  ggplot(aes(party_rec,issue,fill=share)) +
  geom_tile(color="white",linewidth=.7) +
  geom_text(aes(label=if_else(share>=.04,percent(share,accuracy=1),"")),size=3.3) +
  facet_wrap(~issue_side,ncol=1,labeller=as_labeller(c(left="Left stance",right="Right stance"))) +
  scale_fill_gradient(low="#EDF2F7",high="#2B6CB0",labels=percent_format()) +
  labs(title="Issue content changes which party is recommended",
       subtitle="Module A pooled across complete models; conditional on a parsed party",
       x=NULL,y=NULL,fill="Party share") + theme_paper +
  theme(axis.text.x=element_text(angle=35,hjust=1),strip.text=element_text(face="bold"))
save_plot(p,"08_issue_heatmap.png",9.8,6.4)

# Anchors
anchor_labels <- c(
  agro="Agro",classes_d_e="Classes D/E",conservador_cristao="Christian conservative",
  empreendedor_individual="Solo entrepreneur",empresario="Business owner",
  extrema_direita="Far right",liberal_social="Social liberal",
  militante_esquerda="Left activist",progressista="Progressive")
anchors <- df %>% filter(model %in% core,usable,module=="anchor") %>%
  group_by(model,anchor) %>% summarise(model_mean_zeta=mean(zeta,na.rm=TRUE),
  party=mean(has_party),refusal=mean(refused2),.groups="drop") %>%
  group_by(anchor) %>% summarise(
    mean_zeta=mean(model_mean_zeta,na.rm=TRUE),
    se=sd(model_mean_zeta,na.rm=TRUE)/sqrt(sum(!is.na(model_mean_zeta))),
    party=mean(party),refusal=mean(refusal),.groups="drop") %>%
  mutate(low=mean_zeta-1.96*se,high=mean_zeta+1.96*se,label=recode(anchor,!!!anchor_labels))
write_csv(anchors,"results/paper/anchors.csv")
p <- ggplot(anchors,aes(mean_zeta,reorder(label,mean_zeta))) +
  geom_vline(xintercept=0,color="#A0AEC0") +
  geom_errorbarh(aes(xmin=low,xmax=high),height=0,color="#718096") +
  geom_point(aes(color=mean_zeta>0),size=3.5) +
  scale_color_manual(values=c("TRUE"="#C53030","FALSE"="#2B6CB0"),guide="none") +
  labs(title="Rich profiles map to a broadly plausible ideological order",
       subtitle="Mean across model-level estimates; 95% intervals across six models",
       x="Recommended-party ideology (zeta)",y=NULL) + theme_paper
save_plot(p,"09_anchors.png",9.5,5.4)

# Module D race-cue effects
d_race <- df %>% filter(model %in% core,usable,module=="D",
  demo_step %in% c("race","location"),!is.na(race)) %>%
  mutate(race=factor(race,levels=c("branca","parda","preta")))
demographic <- imap_dfr(
  list(Refusal=as.numeric(d_race$refused2),"Party recommendation"=as.numeric(d_race$has_party)),
  ~{
    z <- mutate(d_race,y=.x)
    f <- lm(y~race+model+demo_step+cargo+ask,data=z)
    coeftest(f,vcov.=vcovCL(f,cluster=z$cond_id,type="HC1")) %>% tidy() %>%
      filter(term %in% c("raceparda","racepreta")) %>%
      mutate(low=estimate-1.96*std.error,high=estimate+1.96*std.error,outcome=.y)
  }) %>%
  mutate(race=recode(term,raceparda="Parda vs branca",racepreta="Preta vs branca"))
write_csv(demographic,"results/paper/demographic_effects.csv")
p <- ggplot(demographic,aes(estimate,race,color=outcome)) +
  geom_vline(xintercept=0,color="#A0AEC0") +
  geom_errorbarh(aes(xmin=low,xmax=high),height=0,position=position_dodge(.5)) +
  geom_point(position=position_dodge(.5),size=3.2) +
  scale_x_continuous(labels=percent_format()) +
  scale_color_manual(values=c(Refusal="#C53030","Party recommendation"="#2B6CB0")) +
  labs(title="Race cues reduce refusals and increase party recommendations",
       subtitle="Linear probability models with model, step, ballot and request fixed effects",
       x="Change relative to branca",y=NULL) + theme_paper
save_plot(p,"10_demographics.png",9.5,4.5)

# Repetition stability
stability <- df %>% filter(model %in% core,usable) %>%
  mutate(outcome=case_when(has_party~party_rec,refused2~"REFUSAL",TRUE~"OTHER")) %>%
  count(model,cond_id,outcome) %>% group_by(model,cond_id) %>%
  summarise(reps=sum(n),modal=max(n)/sum(n),unanimous=max(n)==sum(n),.groups="drop") %>%
  group_by(model) %>% summarise(cells=n(),mean_modal=mean(modal),
    unanimous=mean(unanimous),.groups="drop") %>% mutate(label=recode(model,!!!model_labels))
write_csv(stability,"results/paper/repetition_stability.csv")
p <- ggplot(stability,aes(unanimous,reorder(label,unanimous))) +
  geom_segment(aes(x=0,xend=unanimous,yend=reorder(label,unanimous)),color="#CBD5E0",linewidth=1.1) +
  geom_point(size=3.6,color="#2B6CB0") +
  geom_text(aes(label=percent(unanimous,accuracy=1)),hjust=-.25,size=4.1) +
  scale_x_continuous(labels=percent_format(),limits=c(0,1)) +
  labs(title="Identical prompts often produce different outcomes",
       subtitle="Share of five-repetition cells with the same party, refusal, or vague outcome every time",
       x="Unanimous cells",y=NULL) + theme_paper
save_plot(p,"11_stability.png",9.2,4.8)

# Partial-model sensitivity
p <- effects_all %>% mutate(model=factor(model,levels=rev(c(core,partial)))) %>%
  ggplot(aes(estimate,model,color=channel,alpha=completion)) +
  geom_vline(xintercept=0,color="#A0AEC0") +
  geom_errorbarh(aes(xmin=low,xmax=high),height=0,position=position_dodge(.52)) +
  geom_point(position=position_dodge(.52),size=2.9) +
  scale_y_discrete(labels=function(x) recode(x,!!!model_labels)) +
  scale_color_manual(values=c(Label="#805AD5",Issue="#2B6CB0")) +
  scale_alpha_manual(values=c(Complete=1,Partial=.48)) +
  labs(title="The issue channel persists in most partially complete models",
       subtitle="Faded estimates use incomplete response sets and are sensitivity checks only",
       x="Change in recommended-party ideology (zeta)",y=NULL,alpha=NULL) + theme_paper
save_plot(p,"12_partial_robustness.png",9.5,6.1)

headline <- tibble(
  metric=c("rows","usable_rows","usable_share","complete_models",
           "pooled_label_effect","pooled_issue_effect","party_rows","zeta_rows"),
  value=c(nrow(df),sum(df$usable),mean(df$usable),length(core),
    pooled$estimate[pooled$channel=="Label"],pooled$estimate[pooled$channel=="Issue"],
    sum(df$usable&df$has_party),sum(df$usable&df$has_zeta)))
write_csv(headline,"results/paper/headline_metrics.csv")
print(headline)
