# Aba 02 — Performance por Agente

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
| Status Ritmo | `Agent Month Gap Run Rate Label TXT` existe, mas esta na pasta `Aux`; para logica analitica, preferir `Agent Month Gap Run Rate USD` ou uma medida nova fora de `Aux`. |

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
| `Run Rate` | `Agent Month Run Rate USD` | `Agent Month Gap Run Rate USD`; labels auxiliares ficam fora do escopo analitico. |
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