# Aba 01 — Visao Executiva do Piso

## Objetivo

Primeira tela do gestor/diretoria. Deve responder rapidamente:

- se o piso esta batendo a meta mensal de net deposit;
- se esta acima ou abaixo do run rate;
- qual e a carteira do dia e quantos clientes ainda nao operaram;
- quais agentes puxam o resultado;
- como esta a evolucao diaria de net deposit contra a meta diaria.

## Fontes usadas

| Tabela no Power BI | Uso na pagina |
|---|---|
| `gold vw_team_month_performance` | KPIs consolidados de piso/equipe: deposito, withdrawal, net deposit, meta, run rate, gaps, trades, unique e volume. |
| `gold vw_agent_month_performance` | Ranking de agentes, `agent_level`, meta por agente, net deposit, trades e unique trading. |
| `gold vw_agent_day_performance` | Evolucao diaria, metas diarias e sparklines dos cards de deposito/withdrawal. |
| `gold vw_call_list_today` | Carteira, clientes que operaram hoje, pendentes hoje e filtros operacionais. |
| `gold dim_tempo` | Segmentador de mes (`year_month`) e propagacao de filtro para as views mensais/diarias. |
| `Medidas` | Todas as medidas DAX e medidas HTML auxiliares. |

Relacionamentos criticos para esta aba:

- `gold vw_team_month_performance[competence_month]` -> `gold dim_tempo[date]`.
- `gold vw_agent_month_performance[competence_month]` -> `gold dim_tempo[date]`.
- `gold vw_agent_day_performance[ref_date]` -> `gold dim_tempo[date]`.

Esses relacionamentos garantem que o slicer de mes filtre cards, gauge, evolucao diaria e ranking.

## Filtros da pagina

Filtros implementados:

| Filtro | Campo | Observacao |
|---|---|---|
| Mes Referencia | `gold dim_tempo[year_month]` | Segmentador principal em botoes. Abril/2026 tem meta real documentada. |
| Equipe/Piso | `team_name` | Pode filtrar views de time, agente e call list. |
| Agente | `agent_name` | Drill rapido no ranking e carteira. |
| Agent Level | `agent_level` | `pro`, `inter`, `trainee`; cadastro ainda parcial no HML. |
| Operou Hoje | `traded_today` | Filtro operacional da call list. |
| Pendencia Hoje | `is_pending_today` | Complementar ao filtro de operou hoje. |
| Pais | `country` | Segmentacao de carteira. |
| Lead Status | `lead_status_text` | Status vira filtro, nao exclusao de carteira. |
| Has FTD | `has_ftd` | Apoio para analise de carteira. |
| Prioridade | `priority_label` | Provisorio; nao e regra oficial validada de score. |

## KPIs e visuais construidos

### Cards superiores

| Visual | Medida | Leitura |
|---|---|---|
| Net Deposit Mes | `Team Month Net Deposit USD` | KPI principal da meta oficial. |
| % Meta | `Team Month Target Deposit %` | Atingimento de meta mensal, recalculado em DAX. |
| Withdrawal Mes | `Team Month Withdrawal USD` | Efeito de retiradas aprovadas no mes. |
| Deposit Mes | `Team Month Deposit USD` | Depositos brutos aprovados no mes. |
| Run Rate | `Team Month Run Rate USD` | Valor esperado acumulado pelo calendario de negocios. |
| Gap Run Rate | `Team Month Gap Run Rate USD` | Realizado menos run rate; negativo indica abaixo do ritmo. |
| Clientes Hoje | `Call List Clientes Operaram Hoje QTD`, `Call List Clientes Pendentes Hoje QTD`, `Call List Carteira Clientes QTD` | Operacao diaria da carteira. |
| % Atendidos Hoje | `Call List  Carteira Operando Hoje %` | Percentual da carteira que operou hoje. |

### Atingimento da meta

Gauge visual de meta mensal:

- percentual central: `Team Month Target Deposit %`;
- realizado: `Team Month Net Deposit USD`;
- meta: `Team Month Target Deposit USD`;
- status: `Status Meta`;
- arco customizado: `Gauge HTML`.

### Evolucao diaria

Grafico combinado:

- colunas: `Agent Day Net Deposit USD`;
- linha/meta: `Agent Day Target Deposit USD`;
- eixo de data: `gold vw_agent_day_performance[ref_date]`;
- filtrado pelo mes selecionado em `gold dim_tempo[year_month]`.

Uso: mostrar variacao diaria e comparar cada dia contra a meta diaria.

### Resumo operacional

Bloco compacto com:

- `Team Month Net Deposit USD`;
- `Team Month Target Deposit %`;
- `Team Month Target Deposit USD`;
- `Team Month Gap Meta USD`, exibido no layout como "Falta para Meta";
- `Team Month Run Rate USD`;
- `Team Month Gap Run Rate USD`.

Nota: `Team Month Gap Meta USD` e calculado como `meta - realizado`, portanto positivo significa valor que falta para bater a meta.

### Ranking de agentes

Tabela/matriz com:

- `agent_name`;
- `agent_level`;
- `Rank Chart`;
- `Agent Month Net Deposit USD`;
- `Agent Month Target %`;
- `Agent Month Target USD`;
- `Agent Month Trades QTD`;
- `Agent Month Unique Trades QTD`.

Uso: identificar os agentes que mais puxam o resultado mensal. O rank usa `Agent Month Rank Net Deposit`.

## Medidas DAX atuais no PBIX

### Visao Executiva

```DAX
Team Month Deposit USD =
SUM ( 'gold vw_team_month_performance'[deposit_month_usd] )

Team Month Withdrawal USD =
SUM ( 'gold vw_team_month_performance'[withdrawal_month_usd] )

Team Month Net Deposit USD =
SUM ( 'gold vw_team_month_performance'[net_deposit_month_usd] )

Team Month Target Deposit USD =
SUM ( 'gold vw_team_month_performance'[target_deposit_month_usd] )

Team Month Target Deposit % =
DIVIDE ( [Team Month Net Deposit USD], [Team Month Target Deposit USD] )

Team Month Run Rate USD =
SUM ( 'gold vw_team_month_performance'[run_rate_usd] )

Team Month Gap Run Rate USD =
[Team Month Net Deposit USD] - [Team Month Run Rate USD]

Team Month Gap Meta USD =
[Team Month Target Deposit USD] - [Team Month Net Deposit USD]

Team Month Unique Deposit QTD =
SUM ( 'gold vw_team_month_performance'[unique_deposit_month] )

Team Month Target Unique QTD =
SUM ( 'gold vw_team_month_performance'[target_unique_month] )

Team Month Target Unique % =
DIVIDE ( [Team Month Unique Deposit QTD], [Team Month Target Unique QTD] )

Team Month Unique Trading QTD =
SUM ( 'gold vw_team_month_performance'[unique_trading_month] )

Team Month Trading Client Days QTD =
SUM ( 'gold vw_team_month_performance'[trading_client_days_month] )

Team Month Target Trade QTD =
SUM ( 'gold vw_team_month_performance'[target_trade_month] )

Team Month Target Trade % =
DIVIDE ( [Team Month Trading Client Days QTD], [Team Month Target Trade QTD] )

Team Month Total Trades QTD =
SUM ( 'gold vw_team_month_performance'[total_trades_month] )

Status Meta =
SWITCH (
    TRUE (),
    [Team Month Target Deposit %] >= 1, "Meta atingida",
    [Team Month Target Deposit %] >= 0.7, FORMAT ( [Team Month Target Deposit %], "Percent" ) & " da Meta",
    "Abaixo da Meta"
)
```

### Call List

```DAX
Call List Carteira Clientes QTD =
COUNTROWS ( 'gold vw_call_list_today' )

Call List Clientes Operaram Hoje QTD =
COALESCE (
    CALCULATE (
        COUNTROWS ( 'gold vw_call_list_today' ),
        'gold vw_call_list_today'[traded_today] = TRUE ()
    ),
    0
)

Call List Clientes Pendentes Hoje QTD =
COALESCE (
    CALCULATE (
        COUNTROWS ( 'gold vw_call_list_today' ),
        'gold vw_call_list_today'[is_pending_today] = TRUE ()
    ),
    0
)

Call List  Carteira Operando Hoje % =
DIVIDE ( [Call List Clientes Operaram Hoje QTD], [Call List Carteira Clientes QTD], 0 )
```

### Agente Mes

```DAX
Agent Month Net Deposit USD =
SUM ( 'gold vw_agent_month_performance'[net_deposit_month_usd] )

Agent Month Target USD =
SUM ( 'gold vw_agent_month_performance'[target_deposit_month_usd] )

Agent Month Target % =
SUM ( 'gold vw_agent_month_performance'[target_pct_deposit] )

Agent Month Trades QTD =
SUM ( 'gold vw_agent_month_performance'[total_trades_month] )

Agent Month Unique Deposit QTD =
SUM ( 'gold vw_agent_month_performance'[unique_deposit_month] )

Agent Month Unique Trades QTD =
SUM ( 'gold vw_agent_month_performance'[unique_trading_month] )

Agent Month Rank Net Deposit =
RANKX (
    ALLSELECTED ( 'gold vw_agent_month_performance'[agent_name] ),
    [Agent Month Net Deposit USD],
    ,
    DESC,
    DENSE
)
```

### Agente Dia

```DAX
Agent Day Deposit USD =
SUM ( 'gold vw_agent_day_performance'[deposit_day] )

Agent Day Withdrawal USD =
SUM ( 'gold vw_agent_day_performance'[withdrawal_day] )

Agent Day Net Deposit USD =
SUM ( 'gold vw_agent_day_performance'[net_deposit_day] )

Agent Day Target Deposit USD =
SUM ( 'gold vw_agent_day_performance'[target_deposit_day_usd] )

Agent Day Target Deposit % =
DIVIDE ( [Agent Day Net Deposit USD], [Agent Day Target Deposit USD], 0 )
```

### Medidas auxiliares e HTML

| Medida | Uso |
|---|---|
| `Gauge HTML` | Renderiza o arco customizado do gauge de atingimento da meta com gradiente vermelho/amarelo/verde e marcador animado. |
| `Mini Tendencia HTML` | Sparkline comparando realizado diario e meta diaria. |
| `Deposit Sparkline Area HTML` | Sparkline de area para deposito diario no card `Deposit Mes`. |
| `Withdrawal Sparkline Area HTML` | Sparkline de area para withdrawal diario no card `Withdrawal Mes`. |
| `Sparkline Bars HTML` | Barras compactas de net deposit diario. |
| `Mini Barras HTML` | Barras HTML auxiliares para comparacao compacta de realizado/meta. |
| `Rank Chart` | Retorna URL de imagem para trofeus de rank 1, 2 e 3; categoria de dados `ImageUrl`. |
| `Char Gap Run Rate` | Sinal textual `+`, vazio ou `-` conforme `Team Month Gap Run Rate USD`. |
| `Char Gap Target Deposit` | Sinal textual auxiliar baseado em `Team Month Target Deposit %`. |

## Decisoes de apresentacao

- `Net Deposit Mes` e o KPI principal, porque `net_deposit = deposit - withdrawal` e a regra oficial de meta.
- `Withdrawal Mes` e `Deposit Mes` aparecem como explicacao do net.
- `Falta para Meta` substitui o label generico `Gap Meta` no visual, para evitar ambiguidade de sinal.
- `Unique Trading` aparece como apoio operacional no ranking; nao substitui o unique oficial nem vira meta oficial enquanto o cliente nao fornecer metas de trade/unique.
- O bloco de filtros pode incluir dimensoes operacionais da call list, mas status comerciais nao excluem carteira por regra MVP.