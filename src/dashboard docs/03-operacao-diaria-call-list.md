# Aba 03 — Operação Diária / Call List

## Objetivo

Tela operacional usada durante o dia por supervisores e agentes para acompanhar a carteira, separar quem já operou de quem ainda está pendente e priorizar clientes com maior potencial de ação.

Pergunta principal:

> Quem já operou hoje, quem ainda está pendente e onde o time deve agir primeiro?

Perguntas cobertas:

- Qual é a carteira total filtrada por equipe/agente?
- Quantos clientes operaram hoje?
- Quantos clientes ainda estão pendentes?
- Qual percentual da carteira já operou hoje?
- Onde estão os pendentes de maior prioridade?
- Há concentração de pendência em algum agente, país, lead status ou nível?
- Existem clientes com saldo/equity relevante ainda sem trade hoje?

### Topbar

- Brand BrokerLab + título "Call List"
- Filtros: slicer `Prioridade` (pills Alta/Média/Baixa) + slicer `Agente` (dropdown)
- Ícone de filtros avançados

### KPI Cards (linha superior — 7 cards)

| Card | Medida | Valor real (abr/2026, todos agentes) |
|---|---|---|
| Carteira | `Call List Carteira Clientes QTD` | 1.849 |
| Operaram | `Call List Clientes Operaram Hoje QTD` | 220 |
| Pendentes | `Call List Clientes Pendentes Hoje QTD` | 1.629 |
| Pend. Alta | `Call List Clientes Pendentes Alta Prioridade QTD` | 22 |
| C/ Saldo | `Call List Clientes c Saldo QTD` | 1.429 |
| Balance Total | `Call List Balance USD` | $252,46 Mi |
| Equity Total | `Call List Equity USD` | $984,00 Mi |

### Duas tabelas centrais (lado a lado)

**Tabela esquerda — Clientes que Operaram Hoje**

- Filtro visual: `gold vw_call_list_today[traded_today] = TRUE`
- Colunas: Cliente, Agente, Balance, Equity, $ Último Dep., Prioridade
- Coverage bar HTML no header: `Call List Coverage Bar HTML` (11,90% — vermelho)
- Ordenação: maior Balance

**Tabela direita — Clientes Pendentes Hoje**

- Filtro visual: `gold vw_call_list_today[is_pending_today] = TRUE`
- Colunas: Cliente, Agente, Balance, Equity, $ Último Dep., Prioridade
- Coverage bar HTML no header: `Call List Coverage Bar HTML` (88,10% — vermelho)
- Ordenação: Prioridade Alta primeiro, depois maior Balance

### Rodapé (3 visuais HTML Content)

| Visual | Medida HTML | Descrição |
|---|---|---|
| Pendentes por Agente | `Call List Pendentes por Agente HTML` | Barras horizontais top 6 agentes; escala de cor por % do máximo |
| Por Prioridade | `Call List Por Prioridade HTML` | Alta/Média/Baixa com dots coloridos + barras + total rodapé |
| Lead Status | `Call List Lead Status HTML` | Top 5 lead statuses dos pendentes |

## Fonte de dados

| Tabela | Uso |
|---|---|
| `gold vw_call_list_today` | Fonte central: carteira, operaram, pendentes, saldo/equity, lead status, prioridade e flags operacionais. |
| `gold dim_agente` | Slicers de equipe, agente, nível e status; relacionamento ativo com `gold vw_call_list_today[agente_sk]` no modelo atual. |

## Medidas criadas nesta sessão

### Medidas escalares (pasta `Call List`)

```DAX
Call List Clientes Pendentes Alta Prioridade QTD =
CALCULATE ( [Call List Carteira Clientes QTD], 'gold vw_call_list_today'[is_pending_today]=TRUE() && 'gold vw_call_list_today'[priority_label]="Alta")

Call List Clientes c Saldo QTD =
CALCULATE ( [Call List Carteira Clientes QTD], OR('gold vw_call_list_today'[balance]>0,'gold vw_call_list_today'[equity]>0))

Call List Last Deposit USD =
SUM ( 'gold vw_call_list_today'[last_deposit_amount_usd] )
```

### Medidas HTML Content (pasta `HTML Content`)

**`Call List Coverage Bar HTML`** — barra de progresso com cor dinâmica por faixa de %:

```DAX
-- Vermelho <0.30 | Amarelo >=0.30 e <0.51 | Verde >=0.51
VAR BarColor = IF(Pct < 0.3, "#FF2A1A", IF(Pct >= 0.51, "#00D835", "#F4B321"))
```

**`Call List Pendentes por Agente HTML`** — barras horizontais TOPN(6) com CONCATENATEX:

```text
Cor por % do máximo: >= 90% vermelho | >= 68% amarelo | < 68% cinza
Variáveis de tamanho: _W_Total, _W_Label, _W_Value, _H_Bar, _Gap, _Row_Margin, _Font_*
```

**`Call List Por Prioridade HTML`** — 3 blocos (Alta/Média/Baixa) com dot + valor + barra relativa:

```text
Calcula _alta, _media, _baixa via CALCULATE sobre `gold vw_call_list_today`
Barra relativa ao MAX das três categorias
Rodapé com total de pendentes
Variáveis: _W_Total, _H_Bar, _R_Dot, _Row_Margin, _Font_*, _Gap_Dot, _Label_MB
```

**`Call List Lead Status HTML`** — barras horizontais TOPN(5) por lead_status_text:

```text
Cor: >= 80% cinza-azul | >= 20% amarelo | resto cinza-azul
Variáveis: _W_Total, _W_Label, _W_Value, _H_Bar, _Gap, _Row_Margin, _Font_*
```
## Regra de carteira

```text
carteira         = clientes atribuídos ao Retention Owner
operaram hoje    = clientes da carteira com operação CMD 0/1 aberta hoje
pendentes hoje   = carteira − operaram hoje
```