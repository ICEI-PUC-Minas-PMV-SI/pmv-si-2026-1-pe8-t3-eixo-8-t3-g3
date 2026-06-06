---
updated: 2026-06-05
sources: [wiki/wiki/dashboard/01-visao-executiva-piso.md, wiki/wiki/entities/powerbi-semantic-model.md, Power BI MCP 2026-06-05, prints do usuario 2026-06-05]
tags: [dashboard, power-bi, kpi, metas, run-rate, call-list]
status: validada-tecnica
---

# Aba 02 — Performance por Agente

> [!note] Estado atual
> Aba montada no Power BI em 2026-06-05 e revisada por prints do usuário. A página segue o padrão visual dark BrokerLab aprovado na [[01-visao-executiva-piso]], mas com foco individual por agente. Status operacional atual: **revisada visualmente**, aguardando ajustes finos/aceite final antes de marcar como aprovada.

## Objetivo

Tela de acompanhamento individual para gestor e agente. A página responde:

> Este agente está performando no mês e quais clientes precisam de ação hoje?

Perguntas cobertas:

- O agente está acima ou abaixo da meta mensal?
- O agente está acima ou abaixo do run rate?
- Qual é o resultado financeiro do mês e do dia?
- Quantos clientes da carteira operaram hoje?
- Quais clientes pendentes precisam ser priorizados?
- A performance diária está consistente ou concentrada em poucos dias?

## Layout implementado

Estrutura final observada nos prints de 2026-06-05:

| Área | Conteúdo |
|---|---|
| Cabeçalho | Logo BrokerLab, título `Performance Agentes`, slicer de agente e botão de filtros. |
| Menu lateral | Mesmo padrão dark/ícones da Aba 01, com aba de performance destacada. |
| Coluna esquerda superior | Card `Performance Agente` com nome, nível/país/status, rank, net hoje, atingimento da meta, carteira operada hoje e status de ritmo. |
| Coluna esquerda inferior | Card `Net Deposit` com net mês, net hoje, deposit/withdrawal do dia e sparkline/acumulado mensal. |
| Topo central | Cards `Run Rate`, `Trades Mês` e `Unique Deposit`. |
| Centro | Gráfico combinado `Evolução Diária do Agente`, com colunas de net deposit diário e linha tracejada de meta diária. |
| Direita superior | Card `Atingimento da Meta`, com rosca HTML e resumo de net/meta/gap. |
| Direita média | Card `Carteira de Clientes`, com carteira, operaram, pendentes e barra de percentual operando. |
| Rodapé | Tabela `Clientes Pendentes Hoje` com cliente, lead status, balance, equity, último depósito, valor do último depósito e prioridade. |

## Filtros

| Filtro | Campo recomendado | Status |
|---|---|---|
| Mês referência | `gold dim_tempo[year_month]` | Reutiliza relação validada com views de performance. |
| Agente | `gold dim_agente[agent_name]` | Deve ser single-select na leitura individual. |
| Equipe/Piso | `gold dim_agente[team_name]` | Opcional no painel de filtros. |
| Agent Level | `gold dim_agente[agent_level]` | Útil para segmentar `pro`, `inter`, `trainee`; cadastro ainda parcial no HML. |
| Operou hoje | `gold vw_call_list_today[traded_today]` | Filtro operacional. |
| Pendência hoje | `gold vw_call_list_today[is_pending_today]` | Usado na tabela de pendentes. |
| Prioridade | `gold vw_call_list_today[priority_label]` | Provisório até regra oficial de score/priorização. |

### Observação de modelagem

O slicer de agente deve usar `gold dim_agente`. As medidas novas da Aba 02 aplicam o filtro da dimensão sobre as views com `TREATAS`, porque `gold vw_agent_month_performance`, `gold vw_agent_day_performance` e `gold vw_call_list_today` não possuem relacionamento direto documentado com `gold dim_agente`.

Recomendação futura: avaliar relacionamento direto `gold dim_agente[agente_sk] -> views[agente_sk]` para simplificar DAX, mantendo cuidado com direção de filtro e cardinalidade.

## Medidas por visual

### Card `Performance Agente`

| Elemento | Campo/medida |
|---|---|
| Nome | `gold dim_agente[agent_name]` |
| Nível | `gold dim_agente[agent_level]` |
| País/segmento exibido | Campo de apoio disponível no visual; nos prints aparece como `Italy`/`Brazil`. |
| Status | `gold dim_agente[is_active]` ou label visual equivalente. |
| Rank | `Agent Month Rank Net Deposit` |
| Net Deposit Hoje | `Agent Day Net Deposit USD` |
| Atingimento da Meta | `Agent Month Target Deposit %` |
| Carteira Operada Hoje | `Call List Carteira Operando Hoje %` |
| Status Ritmo | `Agent Month Gap Run Rate Label TXT` |

### Card `Net Deposit`

| Elemento | Medida |
|---|---|
| Net Deposit mês | `Agent Month Net Deposit USD` |
| Net Deposit hoje | `Agent Day Net Deposit USD` |
| Deposit hoje | `Agent Day Deposit USD` |
| Withdrawal hoje | `Agent Day Withdrawal USD` |
| Acumulado mensal / sparkline | `Agent Day Net Deposit Acumulado USD` por `gold vw_agent_day_performance[ref_date]` |

### Cards superiores

| Card | Medida principal | Apoio/tooltip |
|---|---|---|
| `Run Rate` | `Agent Month Run Rate USD` | `Agent Month Gap Run Rate USD`, `Agent Month Gap Run Rate Label TXT` |
| `Trades Mês` | `Agent Month Total Trades QTD` | `Agent Month Trading Client Days QTD`, `Agent Day Total Trades QTD` |
| `Unique Deposit` | `Agent Month Unique Deposit QTD` | `Agent Month Target Unique QTD`, `Agent Month Target Unique %` |

### Gráfico `Evolução Diária do Agente`

| Papel no visual | Campo/medida |
|---|---|
| Eixo X | `gold vw_agent_day_performance[ref_date]` |
| Colunas | `Agent Day Net Deposit USD` |
| Linha | `Agent Day Target Deposit USD` |
| Tooltip | `Agent Day Deposit USD`, `Agent Day Withdrawal USD`, `Agent Day Target Deposit %`, `Agent Day Clientes Operaram QTD` |

### Card `Atingimento da Meta`

| Elemento | Medida/campo |
|---|---|
| Rosca HTML | `Agent Month Target Donut HTML` |
| Net Deposit | `Agent Month Net Deposit USD` |
| Meta Mensal | `Agent Month Target Deposit USD` |
| Gap Meta | `Agent Month Gap Meta USD` |
| Status Meta | `Agent Month Status Meta TXT` |

Medida HTML criada:

```DAX
Agent Month Target Donut HTML
```

Pasta: `HTML Content`.

Comportamento:

- Usa `Agent Month Target Deposit %` como base.
- Limita o preenchimento da rosca em 100%, mas mantém o valor real no centro; exemplo: `284,41%`.
- Cor verde quando `>= 100%`, âmbar entre `70%` e `99,99%`, vermelho abaixo de `70%`.
- Última revisão deixou somente donut + valor central.

Variáveis de ajuste dentro da medida:

| Variável | Uso |
|---|---|
| `DonutSize` | Tamanho geral da rosca. |
| `CenterFontSize` | Tamanho bruto da fonte central. |
| `CenterValueScale` | Escala visual do texto central; use primeiro para evitar texto colado no anel. |
| `RingStroke` | Espessura do anel. |
| `InnerRadius` | Raio do miolo/área interna. |

Versão validada em 2026-06-05:

- `DonutSize = "150px"`
- `CenterFontSize = "24px"`
- `CenterValueScale = "0.82"`
- `RingStroke = "10"`
- `InnerRadius = "34"`

### Card `Carteira de Clientes`

| Elemento | Medida |
|---|---|
| Carteira | `Call List Carteira Clientes QTD` |
| Operaram | `Call List Clientes Operaram Hoje QTD` |
| Pendentes | `Call List Clientes Pendentes Hoje QTD` |
| Barra / percentual | `Call List Carteira Operando Hoje %` |

### Tabela `Clientes Pendentes Hoje`

Fonte: `gold vw_call_list_today`.

Filtro visual obrigatório:

```text
gold vw_call_list_today[is_pending_today] = TRUE
```

Colunas:

| Coluna visual | Campo |
|---|---|
| Cliente | `cliente_nome` |
| Lead Status | `lead_status_text` |
| Balance | `balance` |
| Equity | `equity` |
| DT Último Dep. | `last_deposit_date` |
| $ Último Dep. | `last_deposit_amount_usd` |
| Prioridade | `priority_label` |

Melhoria visual recomendada: transformar `Prioridade` em badge/chip, com vermelho para alta, neutro para baixa e âmbar para média.

## Medidas criadas/normalizadas para a Aba 02

As medidas foram criadas/atualizadas em `Medidas`, respeitando a convenção:

```text
<alias tabela> <medida> <formato>
```

Principais pastas:

| Pasta | Escopo |
|---|---|
| `Agent Month` | KPIs mensais por agente: net, deposit, withdrawal, target, target %, run rate, gaps, unique, trades, volume, PnL, rank e labels. |
| `Agent Day` | KPIs diários/acumulados: deposit, withdrawal, net, meta diária, acumulado, clientes operaram, total trades e target trade. |
| `Call List` | Carteira, operaram hoje, pendentes hoje, percentual operando, balance e equity. |
| `HTML Content` | Medidas HTML para rosca/progresso/funil/strip. |

HTMLs disponíveis:

| Medida | Uso |
|---|---|
| `Agent Month Target Donut HTML` | Rosca de atingimento da meta, usada no card direito superior. |
| `Agent Month Progress HTML` | Barra/progresso mensal; mantida como alternativa. |
| `Agent Month Status Card HTML` | Card completo de status/rank; mantido como alternativa. |
| `Call List Funnel HTML` | Funil carteira/operaram/pendentes; mantido como alternativa. |
| `Agent Month KPI Strip HTML` | Strip compacto de net, unique, trades e pendentes; mantido como alternativa. |

## Validação técnica

Validações via Power BI MCP/DAX em 2026-06-05:

| Contexto | Resultado |
|---|---|
| Abril/2026 consolidado | Medidas retornaram valores compatíveis com referência da Aba 01 para net/meta/carteira. |
| `Alessio Ferri` | Rosca validada com `284,41%`, anel verde cheio e valor central correto. |
| `Arthur Moreau` | Rosca validada com `33,19%`, anel vermelho parcial e valor central correto. |

Valores de referência observados nos prints:

| Agente | Net mês | Meta | Atingimento | Run Rate | Gap Run Rate | Carteira | Operaram | Pendentes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Alessio Ferri | `$142,20 Mil` | `$50,00 Mil` | `284,41%` | `$156,42 Mil` | `($14,22 Mil)` | `122` | `6` | `116` |
| Arthur Moreau | `$16,59 Mil` | `$50,00 Mil` | `33,19%` | `$18,25 Mil` | `($1,66 Mil)` | `69` | `17` | `52` |

## Feedback visual aplicado

- Rosca substituiu o velocímetro para diferenciar a Aba 02 da Aba 01.
- Card `Atingimento da Meta` foi simplificado; a medida HTML final mantém apenas donut e percentual central.
- Ajustado espaçamento do valor central na rosca com `CenterValueScale`, `RingStroke` e `InnerRadius`.
- Layout geral aprovado como coerente com a Aba 01: dark BrokerLab, cards compactos, ícones amarelos, tabela operacional e gráfico diário central.

## Pendências e próximos ajustes

- Ajustar pequenos acabamentos visuais conforme revisão final: cor verde da rosca pode ser suavizada se competir com os demais elementos.
- Avaliar badge/chip para `Prioridade` na tabela.
- Confirmar se metas de trade/unique serão preenchidas oficialmente no template; a estrutura já está preparada.
- Avaliar relacionamento direto de `gold dim_agente` com as views de agente/call list para reduzir uso de `TREATAS`.
- Fazer validação final por print antes de marcar a Aba 02 como `Aprovada`.

## Ver também

- [[01-visao-executiva-piso]]
- [[powerbi-semantic-model]]
- [[powerbi-dim-tempo-relacionamento]]
- [[guia-analista-dados-powerbi]]
- [[call-list]]
