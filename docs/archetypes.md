# Voter archetypes

> **Primary source:** Felipe Nunes, *Brasil no espelho*, Chapter 8, “O Brasil em segmentos,” PDF pages 144–179.
>
> The book uses cluster analysis on nearly 10,000 respondents and 197 variables to assign respondents probabilistically to nine identity segments. The labels are the author's interpretive names for the clusters, not mutually exclusive natural kinds or literal descriptions of every member.
>
> The operational prompts use synthetic biographical anchors—specific ages, education levels, incomes, and individual circumstances—to make the profiles concrete and parallel. Those exact biographical values are research-design choices, not estimates reported in the book. Substantive attitudes and voting motivations should remain grounded in the chapter.

## Methodological interpretation

The segmentation is designed to move beyond conventional sociodemographic categories. What determines classification is the combination of values, attitudes, and the factor that most strongly organizes electoral choice. The book's example is a low-income evangelical voter: economic dependence and social programs point toward the Dependente do Estado cluster, while a vote guided primarily by a church, pastor, or priest points toward Conservador cristão.

Accordingly:

- group percentages describe tendencies, not attributes shared by every member;
- deterministic first-person prompts are synthetic realizations of a cluster;
- exact ages, incomes, education, and occupations may be chosen for plausibility;
- distinctive beliefs should be selected from the book rather than imported from a generic partisan persona;
- the experiment crosses man and woman variants even where the book reports an unequal gender distribution.

## Overview

| Segment | Population | Lula, 2022 runoff | Source-defined core |
| --- | ---: | ---: | --- |
| Conservador cristão | 27% | 31% | Religion-guided vote, traditional family, order, security |
| Dependente do Estado | 23% | 73% | Economic vulnerability, cost of living, employment, social programs |
| Agro | 13% | 27% | Rural/sertanejo identity, traditionalism, weaker environmental and land restrictions |
| Progressista | 11% in overview; 12% in its section | 64% | Minorities, nontraditional gender/family norms, climate |
| Militante de esquerda | 7% | 100% | PT identification, political engagement, polarization |
| Empresário | 6% | 25% | Economic elite, privatization, lower state participation |
| Liberal social | 5% | 66% | Center/third way, democracy, anti-polarization, privatization |
| Empreendedor individual | 5% | 52% | Work without employment protections, individual effort, lower taxes |
| Extrema direita | 3% | 0% | Rejection of democracy, strong nationalist government, traditionalism |

The book itself is internally inconsistent about the size of the Progressista segment: the chapter overview reports 11%, while the dedicated section reports 12%. The operational prompts do not use population shares.

## Operational decomposition

The canonical inventory is round_2026-08-14/profile_variants.json.

- **L1:** shared São Paulo geography.
- **L2:** exact L1 plus one segment-specific political priority.
- **L3:** synthetic, gender-specific biography with the same fields for all nine segments: age, São Paulo residence, education, and household income.
- **L4:** exact L3 plus the exact L2 priority sentence.
- **L5:** exact L4 plus occupation, religion where relevant, attitudes, identities, and political behavior.

Occupation, religion, benefit receipt, and attitudinal material are kept out of L3 because they are often defining substantive signals rather than neutral demographics.

## Segment profiles

### Conservador cristão

The largest segment is mostly evangelical but also includes conservative Catholics who attend church frequently. Its worldview emphasizes order, obedience, respect for elders, traditional gender roles, defense of the family, public security, and openly conservative candidates.

Key chapter evidence:

- 56% attend church weekly, the highest share among the nine groups.
- 77% agree that the man should be the household provider.
- 78% oppose marijuana legalization.
- Religion may determine the vote even among otherwise low-income voters.

Operational anchor:

- biography: 44 years old, completed secondary education, household income of three minimum wages;
- L2: public security and defense of the family according to Christian values;
- L5: evangelical identity, weekly attendance, religion-guided vote, order, traditional roles, conservative candidates, and opposition to marijuana legalization.

### Dependente do Estado

The book calls this cluster “classe DE — Dependentes do Estado.” It has limited purchasing power and is especially sensitive to food prices, economic shocks, and difficulty finding work. Members want a government capable of improving material conditions, but the group also shares the broader Brazilian suspicion that benefits can reduce work incentives.

Key chapter evidence:

- 37% receive Bolsa Família or live with someone who does, versus 22% nationally.
- 56% support raising taxes on everyone to help the poor.
- 73% agree that government programs can make people less willing to work.
- The group is especially concerned with the economic agenda, food prices, and employment.

Operational anchor:

- biography: 42 years old, completed secondary education, household income of one minimum wage;
- L2: cost of living, employment, and continuity of social programs;
- L5: informal work, Bolsa Família receipt, sensitivity to food prices and employment, desire for government support, and concern about poorly designed benefits.

### Agro

The Agro segment is broader than landowners or producers. It includes large producers, rural workers, and people who identify with the sertanejo cultural lifestyle. It is concentrated in the Center-West, South, and the interior of São Paulo and Minas Gerais.

Key chapter evidence:

- 71% identify as traditional/conservative.
- 40% support facilitating gun ownership, tied with Empresários and below only Extrema direita.
- The group favors loosening environmental regulation and protections of Indigenous lands.
- It strongly opposed Lula and supported Bolsonaro.

Operational anchor:

- biography: 52 years old, completed secondary education, household income between five and eight minimum wages;
- L2: rural-sector policy and environmental and land restrictions on agribusiness;
- L5: rural producer, sertanejo identity, traditionalism, looser gun and environmental rules, and support for agribusiness-aligned and Bolsonaro-aligned candidates.

### Progressista

This is the group that most clearly diverges from the other segments on gender norms, family stereotypes, minority rights, and climate. The chapter describes a larger proportion of women, younger people, and people with above-average income.

Key chapter evidence:

- only 3% agree that a woman who has an abortion should be imprisoned;
- 65% reject the idea that Brazil is a racial democracy;
- the group is the least likely to put faith above science, though 69% still do;
- it is especially concerned with the climate crisis and its effects on vulnerable people;
- it consumes more information through digital channels.

Operational anchor:

- biography: 27 years old, completed higher education, household income of five minimum wages;
- L2: minority rights and the effects of the climate crisis on vulnerable people;
- L5: nontraditional gender/family norms, opposition to imprisoning women for abortion, rejection of the racial-democracy claim, and digital information use.

### Militante de esquerda

This cluster is uniquely characterized by strong party identification, especially with the PT, above-average schooling, and high political interest. The impeachment of Dilma Rousseff prompted remobilization, and the group tends to interpret politics through a polarized government-versus-opposition lens.

Key chapter evidence:

- all members in the chapter's 2022 runoff comparison voted for Lula;
- the impeachment experience increased mobilization;
- members tend to evaluate the Lula government positively and opposition proposals negatively;
- the group nevertheless supports democracy and institutional political participation.

Operational anchor:

- biography: 38 years old, completed higher education, household income of six minimum wages;
- L2: political participation and defense of social and labor rights;
- L5: PT identification, high political interest, post-2016 mobilization, polarized evaluations, and institutional participation.

### Empresário

This cluster represents an older, predominantly white economic elite concentrated in the South and Southeast. It prefers a liberal economic system and privatization and opposes government benefits targeted at poorer people.

Key chapter evidence:

- 69% support privatizing state-owned enterprises.
- 68% are satisfied with household income, the highest result.
- The group obtains information primarily through digital channels and sees itself as modern.
- It is relatively less dependent on religion than most groups, although 92% still say God is very important.

Operational anchor:

- biography: 55 years old, completed higher education, household income above fifteen minimum wages;
- L2: privatization and reduction of state participation in the economy;
- L5: business ownership, economic liberalism, opposition to benefits targeted at the poor, income satisfaction, and digital information use.

### Liberal social

The Liberal social segment occupies the political center, supported Simone Tebet in the first round of 2022, favors a third way, defends democracy, and wants an end to polarization. Its economic and punitive positions are stronger than the moderate label may suggest.

Key chapter evidence:

- 89% believe public health and education would improve if privatized.
- 65% say they vote only because voting is mandatory.
- 85% support the death penalty for crimes such as rape.
- The group favors individual freedom, lower taxes, a smaller state, and Brazil's international standing.

Operational anchor:

- biography: 45 years old, completed higher education, household income of eight minimum wages;
- L2: defense of democracy and the end of polarization;
- L5: Tebet-to-Lula voting history, center/third-way identity, lower taxes, optional voting, privatization, democratic institutions, and punitive criminal-justice preferences.

### Empreendedor individual

This segment consists of workers in the new economy who lack a conventional employment relationship and associated benefits but understand themselves as entrepreneurs. The book says the group is mostly male and emphasizes individual effort and aspiration.

Key chapter evidence:

- 72% support wage differences as incentives for effort.
- 71% say help should go only to those who deserve it.
- 63% support privatization.
- The group is resistant to unions, favors lower taxes, and holds negative views of politics and Brazilian democracy.

Operational anchor:

- biography: 33 years old, completed secondary education, household income between three and four minimum wages;
- L2: lower taxes and better conditions for self-employed workers;
- L5: work without a formal employment contract or benefits, entrepreneurial self-image, effort and differentiated rewards, resistance to unions, privatization, and political dissatisfaction.

### Extrema direita

The book deliberately distinguishes this small group from the broader right, Bolsonaro voters, Conservadores cristãos, Agro, and Empresários. Its defining variable is rejection of democracy as the best form of government.

Key chapter evidence:

- 100% agree that a dictatorship can be preferable to democracy in some circumstances.
- The group prefers a strong, nationalist central power that imposes order.
- It favors less state participation in the economic, social, and environmental spheres.
- It is religious and supports highly traditional gender norms.
- No member in the chapter's 2022 runoff comparison voted for Lula.

Operational anchor:

- biography: 48 years old, completed secondary education, household income of four minimum wages;
- L2: restoration of order through a strong nationalist government;
- L5: practicing Christian identity, traditional norms, explicit openness to dictatorship, reduced state participation, and support for Bolsonaro.

Claims about persecution by the STF or media, electoral-system distrust, globalism, and political correctness were excluded because they do not define this cluster in Chapter 8.
