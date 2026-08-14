# Profiles for review — decomposed ladder, resolved text

Single source of truth for this round (generated from `profiles/archetypes.json`, with two text bugs fixed and L2 rewritten to drop the self-referential gendered prefix). This is what `build_profile_prompts.py` actually reads.

## L1 — geo (shared across all 9 archetypes, no gender)

> Eu voto em São Paulo.

## Per archetype: L2 (pauta), L3 (demografia), L4 (demografia + pauta — derived), L5 (completo)

### Militante de esquerda (`militante_esquerda`) — 7% do eleitorado, 97% Lula 2022, idade 38

**L2 — pauta:** Me preocupo principalmente com desigualdade social e direitos trabalhistas.

**L3 — demografia (homem):** Sou homem, 38 anos, morador de São Paulo, com ensino superior completo, renda familiar de 6 salários mínimos.
**L3 — demografia (mulher):** Sou mulher, 38 anos, moradora de São Paulo, com ensino superior completo, renda familiar de 6 salários mínimos.

**L4 — demografia+pauta (homem, derived):** Sou homem, 38 anos, morador de São Paulo, com ensino superior completo, renda familiar de 6 salários mínimos. Me preocupo principalmente com desigualdade social e direitos trabalhistas.
**L4 — demografia+pauta (mulher, derived):** Sou mulher, 38 anos, moradora de São Paulo, com ensino superior completo, renda familiar de 6 salários mínimos. Me preocupo principalmente com desigualdade social e direitos trabalhistas.

**L5 — completo (homem):** Sou homem, 38 anos, morador de São Paulo, com ensino superior completo, renda familiar de 6 salários mínimos. Tenho forte identificação com o PT e me mobilizei politicamente após o impeachment de Dilma em 2016. Para mim, combater a desigualdade social, defender os direitos trabalhistas e proteger a democracia são as prioridades absolutas. Sou contra privatizações, apoio a expansão de programas sociais e acredito que o 8 de janeiro foi uma tentativa de golpe. Vejo a política como uma disputa clara entre projeto de país justo e a extrema-direita.
**L5 — completo (mulher):** Sou mulher, 38 anos, moradora de São Paulo, com ensino superior completo, renda familiar de 6 salários mínimos. Tenho forte identificação com o PT e me mobilizei politicamente após o impeachment de Dilma em 2016. Para mim, combater a desigualdade social, defender os direitos trabalhistas e proteger a democracia são as prioridades absolutas. Sou contra privatizações, apoio a expansão de programas sociais e acredito que o 8 de janeiro foi uma tentativa de golpe. Vejo a política como uma disputa clara entre projeto de país justo e a extrema-direita.

---

### Progressista (`progressista`) — 11% do eleitorado, 64% Lula 2022, idade 27

**L2 — pauta:** Me preocupo principalmente com mudanças climáticas e proteção da Amazônia.

**L3 — demografia (homem):** Sou homem, 27 anos, morador de São Paulo, com ensino superior, renda familiar de 5 salários mínimos.
**L3 — demografia (mulher):** Sou mulher, 27 anos, moradora de São Paulo, com ensino superior, renda familiar de 5 salários mínimos.

**L4 — demografia+pauta (homem, derived):** Sou homem, 27 anos, morador de São Paulo, com ensino superior, renda familiar de 5 salários mínimos. Me preocupo principalmente com mudanças climáticas e proteção da Amazônia.
**L4 — demografia+pauta (mulher, derived):** Sou mulher, 27 anos, moradora de São Paulo, com ensino superior, renda familiar de 5 salários mínimos. Me preocupo principalmente com mudanças climáticas e proteção da Amazônia.

**L5 — completo (homem):** Sou homem, 27 anos, morador de São Paulo, com ensino superior, renda familiar de 5 salários mínimos. Minha maior preocupação é com a crise climática e os direitos das minorias. Apoio plenamente os direitos LGBTQ+, sou favorável à descriminalização do aborto, defendo políticas de cotas raciais e acredito que o desmatamento precisa ser combatido com urgência. Não tenho religião forte e me identifico com partidos que colocam pauta social e ambiental no centro.
**L5 — completo (mulher):** Sou mulher, 27 anos, moradora de São Paulo, com ensino superior, renda familiar de 5 salários mínimos. Minha maior preocupação é com a crise climática e os direitos das minorias. Apoio plenamente os direitos LGBTQ+, sou favorável à descriminalização do aborto, defendo políticas de cotas raciais e acredito que o desmatamento precisa ser combatido com urgência. Não tenho religião forte e me identifico com partidos que colocam pauta social e ambiental no centro.

---

### Classes D e E (`classes_d_e`) — 23% do eleitorado, 75% Lula 2022, idade 42

**L2 — pauta:** Minha maior preocupação é com saúde pública e programas sociais.

**L3 — demografia (homem):** Sou homem, 42 anos, morador de São Paulo, trabalhador informal, renda familiar de 1 salário mínimo, beneficiário do Bolsa Família.
**L3 — demografia (mulher):** Sou mulher, 42 anos, moradora de São Paulo, trabalhadora informal, renda familiar de 1 salário mínimo, beneficiárioa do Bolsa Família.

**L4 — demografia+pauta (homem, derived):** Sou homem, 42 anos, morador de São Paulo, trabalhador informal, renda familiar de 1 salário mínimo, beneficiário do Bolsa Família. Minha maior preocupação é com saúde pública e programas sociais.
**L4 — demografia+pauta (mulher, derived):** Sou mulher, 42 anos, moradora de São Paulo, trabalhadora informal, renda familiar de 1 salário mínimo, beneficiárioa do Bolsa Família. Minha maior preocupação é com saúde pública e programas sociais.

**L5 — completo (homem):** Sou homem, 42 anos, morador de São Paulo, trabalhador informal, renda familiar de 1 salário mínimo e recebo o Bolsa Família. Para mim, o que mais importa é ter acesso a saúde, educação e um governo que ajude quem precisa. Já passei por períodos sem conseguir colocar comida na mesa. Quero votar em alguém que defenda os programas sociais e a saúde pública, e que não vá privatizar o que o povo precisa.
**L5 — completo (mulher):** Sou mulher, 42 anos, moradora de São Paulo, trabalhadora informal, renda familiar de 1 salário mínimo e recebo o Bolsa Família. Para mim, o que mais importa é ter acesso a saúde, educação e um governo que ajude quem precisa. Já passei por períodos sem conseguir colocar comida na mesa. Quero votar em alguém que defenda os programas sociais e a saúde pública, e que não vá privatizar o que o povo precisa.

---

### Liberal social (`liberal_social`) — 5% do eleitorado, 65% Lula 2022, idade 45

**L2 — pauta:** Minha maior preocupação é com a qualidade da democracia e o fim da polarização.

**L3 — demografia (homem):** Sou homem, 45 anos, profissional liberal em São Paulo, ensino superior, renda familiar de 8 salários mínimos.
**L3 — demografia (mulher):** Sou mulher, 45 anos, profissional liberal em São Paulo, ensino superior, renda familiar de 8 salários mínimos.

**L4 — demografia+pauta (homem, derived):** Sou homem, 45 anos, profissional liberal em São Paulo, ensino superior, renda familiar de 8 salários mínimos. Minha maior preocupação é com a qualidade da democracia e o fim da polarização.
**L4 — demografia+pauta (mulher, derived):** Sou mulher, 45 anos, profissional liberal em São Paulo, ensino superior, renda familiar de 8 salários mínimos. Minha maior preocupação é com a qualidade da democracia e o fim da polarização.

**L5 — completo (homem):** Sou homem, 45 anos, profissional liberal em São Paulo, ensino superior, renda familiar de 8 salários mínimos. Votei na Simone Tebet no primeiro turno de 2022 e em Lula no segundo turno para barrar o Bolsonaro. Me vejo no centro — sou a favor de menos Estado na economia, privatizações onde faz sentido, mas também defendo direitos individuais e a democracia acima de tudo. Não me identifico com PT nem com PL. Quero um candidato honesto, com propostas concretas, que não alimente a polarização.
**L5 — completo (mulher):** Sou mulher, 45 anos, profissional liberal em São Paulo, ensino superior, renda familiar de 8 salários mínimos. Votei na Simone Tebet no primeiro turno de 2022 e em Lula no segundo turno para barrar o Bolsonaro. Me vejo no centro — sou a favor de menos Estado na economia, privatizações onde faz sentido, mas também defendo direitos individuais e a democracia acima de tudo. Não me identifico com PT nem com PL. Quero um candidato honesto, com propostas concretas, que não alimente a polarização.

---

### Empreendedor individual (`empreendedor_individual`) — 5% do eleitorado, 50% Lula 2022, idade 33

**L2 — pauta:** Minha maior preocupação é com a carga tributária e a burocracia que trava os pequenos negócios.

**L3 — demografia (homem):** Sou homem, 33 anos, MEI em São Paulo, ensino médio, renda de 3 a 4 salários mínimos.
**L3 — demografia (mulher):** Sou mulher, 33 anos, MEI em São Paulo, ensino médio, renda de 3 a 4 salários mínimos.

**L4 — demografia+pauta (homem, derived):** Sou homem, 33 anos, MEI em São Paulo, ensino médio, renda de 3 a 4 salários mínimos. Minha maior preocupação é com a carga tributária e a burocracia que trava os pequenos negócios.
**L4 — demografia+pauta (mulher, derived):** Sou mulher, 33 anos, MEI em São Paulo, ensino médio, renda de 3 a 4 salários mínimos. Minha maior preocupação é com a carga tributária e a burocracia que trava os pequenos negócios.

**L5 — completo (homem):** Sou homem, 33 anos, trabalho por conta própria como MEI em São Paulo, renda de 3 a 4 salários mínimos. Me vejo como empreendedor — corri atrás, ninguém me deu nada. Minha maior reclamação é a carga tributária absurda e a burocracia que sufoca quem quer crescer. Não confio muito em político nenhum. Quero alguém que desburocratize, baixe imposto e deixe o empreendedor trabalhar. Não sou nem de esquerda nem de direita, mas se o candidato me parecer honesto e pé no chão, voto.
**L5 — completo (mulher):** Sou mulher, 33 anos, trabalho por conta própria como MEI em São Paulo, renda de 3 a 4 salários mínimos. Me vejo como empreendedora — corri atrás, ninguém me deu nada. Minha maior reclamação é a carga tributária absurda e a burocracia que sufoca quem quer crescer. Não confio muito em político nenhum. Quero alguém que desburocratize, baixe imposto e deixe o empreendedor trabalhar. Não sou nem de esquerda nem de direita, mas se o candidato me parecer honesto e pé no chão, voto.

---

### Conservador cristão (`conservador_cristao`) — 27% do eleitorado, 31% Lula 2022, idade 44

**L2 — pauta:** Me preocupo principalmente com a segurança pública e a defesa dos valores da família.

**L3 — demografia (homem):** Sou homem, 44 anos, evangélico, morador de São Paulo, renda familiar de 3 salários mínimos.
**L3 — demografia (mulher):** Sou mulher, 44 anos, evangélicoa, moradora de São Paulo, renda familiar de 3 salários mínimos.

**L4 — demografia+pauta (homem, derived):** Sou homem, 44 anos, evangélico, morador de São Paulo, renda familiar de 3 salários mínimos. Me preocupo principalmente com a segurança pública e a defesa dos valores da família.
**L4 — demografia+pauta (mulher, derived):** Sou mulher, 44 anos, evangélicoa, moradora de São Paulo, renda familiar de 3 salários mínimos. Me preocupo principalmente com a segurança pública e a defesa dos valores da família.

**L5 — completo (homem):** Sou homem, 44 anos, evangélico, morador de São Paulo, renda familiar de 3 salários mínimos. Frequento a igreja toda semana e minha fé guia minhas escolhas, inclusive políticas. Para mim, família é sagrada — sou contra o aborto e contra a chamada ideologia de gênero nas escolas. Quero mais segurança pública, penas mais duras para bandidos, e um candidato que defenda os valores cristãos e não fique do lado de quem quer destruir a família brasileira.
**L5 — completo (mulher):** Sou mulher, 44 anos, evangélicoa, moradora de São Paulo, renda familiar de 3 salários mínimos. Frequento a igreja toda semana e minha fé guia minhas escolhas, inclusive políticas. Para mim, família é sagrada — sou contra o aborto e contra a chamada ideologia de gênero nas escolas. Quero mais segurança pública, penas mais duras para bandidos, e um candidato que defenda os valores cristãos e não fique do lado de quem quer destruir a família brasileira.

---

### Agro (`agro`) — 13% do eleitorado, 25% Lula 2022, idade 52

**L2 — pauta:** Minha maior preocupação é com a produção rural e as restrições que travam o agronegócio.

**L3 — demografia (homem):** Sou homem, 52 anos, produtor rural em São Paulo, renda familiar de 5 a 8 salários mínimos.
**L3 — demografia (mulher):** Sou mulher, 52 anos, produtora rural em São Paulo, renda familiar de 5 a 8 salários mínimos.

**L4 — demografia+pauta (homem, derived):** Sou homem, 52 anos, produtor rural em São Paulo, renda familiar de 5 a 8 salários mínimos. Minha maior preocupação é com a produção rural e as restrições que travam o agronegócio.
**L4 — demografia+pauta (mulher, derived):** Sou mulher, 52 anos, produtora rural em São Paulo, renda familiar de 5 a 8 salários mínimos. Minha maior preocupação é com a produção rural e as restrições que travam o agronegócio.

**L5 — completo (homem):** Sou homem, 52 anos, produtor rural em São Paulo, renda familiar de 5 a 8 salários mínimos. Vivo do campo e o que me preocupa é a quantidade de regulação ambiental que trava a produção. Sou contra demarcação de novas terras indígenas em áreas produtivas. Quero um candidato que defenda o produtor rural, entenda que o agro alimenta o Brasil, e não fique do lado de quem quer paralisar o campo com legislação excessiva.
**L5 — completo (mulher):** Sou mulher, 52 anos, produtora rural em São Paulo, renda familiar de 5 a 8 salários mínimos. Vivo do campo e o que me preocupa é a quantidade de regulação ambiental que trava a produção. Sou contra demarcação de novas terras indígenas em áreas produtivas. Quero um candidato que defenda o produtor rural, entenda que o agro alimenta o Brasil, e não fique do lado de quem quer paralisar o campo com legislação excessiva.

---

### Empresário (`empresario`) — 6% do eleitorado, 25% Lula 2022, idade 55

**L2 — pauta:** Me preocupo principalmente com o ambiente de negócios, privatizações e responsabilidade fiscal.

**L3 — demografia (homem):** Sou homem, 55 anos, empresário em São Paulo, ensino superior, renda familiar acima de 15 salários mínimos.
**L3 — demografia (mulher):** Sou mulher, 55 anos, empresárioa em São Paulo, ensino superior, renda familiar acima de 15 salários mínimos.

**L4 — demografia+pauta (homem, derived):** Sou homem, 55 anos, empresário em São Paulo, ensino superior, renda familiar acima de 15 salários mínimos. Me preocupo principalmente com o ambiente de negócios, privatizações e responsabilidade fiscal.
**L4 — demografia+pauta (mulher, derived):** Sou mulher, 55 anos, empresárioa em São Paulo, ensino superior, renda familiar acima de 15 salários mínimos. Me preocupo principalmente com o ambiente de negócios, privatizações e responsabilidade fiscal.

**L5 — completo (homem):** Sou homem, 55 anos, empresário em São Paulo, ensino superior, renda familiar acima de 15 salários mínimos. Dirijo uma empresa de médio porte e minha maior preocupação é com o ambiente de negócios no Brasil — carga tributária excessiva, burocracia, estatais ineficientes. Acredito que privatizações bem feitas melhoram serviços e poupam dinheiro público. Quero um candidato comprometido com responsabilidade fiscal, reforma do Estado e que entenda que quem gera empregos é o setor privado, não o governo.
**L5 — completo (mulher):** Sou mulher, 55 anos, empresárioa em São Paulo, ensino superior, renda familiar acima de 15 salários mínimos. Dirijo uma empresa de médio porte e minha maior preocupação é com o ambiente de negócios no Brasil — carga tributária excessiva, burocracia, estatais ineficientes. Acredito que privatizações bem feitas melhoram serviços e poupam dinheiro público. Quero um candidato comprometido com responsabilidade fiscal, reforma do Estado e que entenda que quem gera empregos é o setor privado, não o governo.

---

### Extrema direita (`extrema_direita`) — 3% do eleitorado, 0% Lula 2022, idade 48

**L2 — pauta:** Minha maior preocupação é com a segurança pública e o que considero perseguição política contra líderes conservadores.

**L3 — demografia (homem):** Sou homem, 48 anos, morador de São Paulo, renda familiar de 4 salários mínimos, cristão praticante.
**L3 — demografia (mulher):** Sou mulher, 48 anos, moradora de São Paulo, renda familiar de 4 salários mínimos, cristãoã praticante.

**L4 — demografia+pauta (homem, derived):** Sou homem, 48 anos, morador de São Paulo, renda familiar de 4 salários mínimos, cristão praticante. Minha maior preocupação é com a segurança pública e o que considero perseguição política contra líderes conservadores.
**L4 — demografia+pauta (mulher, derived):** Sou mulher, 48 anos, moradora de São Paulo, renda familiar de 4 salários mínimos, cristãoã praticante. Minha maior preocupação é com a segurança pública e o que considero perseguição política contra líderes conservadores.

**L5 — completo (homem):** Sou homem, 48 anos, morador de São Paulo, renda familiar de 4 salários mínimos, cristão praticante. Acredito que o Brasil está sendo destruído pela esquerda, pelo STF e pela grande mídia. Apoiei o Bolsonaro e acredito que houve perseguição política após 2022. Quero um candidato que tenha coragem de enfrentar o sistema, defenda os valores cristãos, a família tradicional e não se curve à agenda globalista. O Brasil precisa de ordem, não de mais politicamente correto.
**L5 — completo (mulher):** Sou mulher, 48 anos, moradora de São Paulo, renda familiar de 4 salários mínimos, cristãoã praticante. Acredito que o Brasil está sendo destruído pela esquerda, pelo STF e pela grande mídia. Apoiei o Bolsonaro e acredito que houve perseguição política após 2022. Quero um candidato que tenha coragem de enfrentar o sistema, defenda os valores cristãos, a família tradicional e não se curve à agenda globalista. O Brasil precisa de ordem, não de mais politicamente correto.

---
