---
updated: 2026-06-06
sources: [wiki/wiki/dashboard/02-performance-por-agente.md, wiki/wiki/entities/powerbi-semantic-model.md, wiki/wiki/indicators/call-list.md, Power BI MCP 2026-06-06, prints do usuario 2026-06-06]
tags: [dashboard, power-bi, call-list, trading, kpi]
status: validada-tecnica
---

# Aba 03 — Operação Diária / Call List

> [!note] Estado atual (2026-06-06)
> Aba **finalizada e aprovada** em 2026-06-06. Montada no Power BI com dados reais via DAX queries ao modelo `BI - BrokerLab`. Print de aceite recebido pelo usuário. Mockup HTML gerado em `artefatos/dashboard/aba03-operacao-diaria-call-list-mockup.html`. Medidas HTML Content criadas: `Call List Coverage Bar HTML`, `Call List Pendentes por Agente HTML`, `Call List Por Prioridade HTML`, `Call List Lead Status HTML`.

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

## Layout implementado

Estrutura final observada no print de aceite de 2026-06-06:

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
| Pend. Alta | `Call List Pendentes Alta QTD` | 22 |
| C/ Saldo | `Call List Clientes Com Saldo QTD` | 1.429 |
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
| `gold dim_agente` | Slicers de equipe, agente, nível e status; TREATAS para propagar filtro. |

## Medidas criadas nesta sessão

### Medidas escalares (pasta `Call List`)

```DAX
Call List Pendentes Alta QTD =
CALCULATE (
    COUNTROWS ( 'gold vw_call_list_today' ),
    'gold vw_call_list_today'[is_pending_today] = TRUE (),
    'gold vw_call_list_today'[priority_label] = "Alta",
    TREATAS (
        VALUES ( 'gold dim_agente'[agente_sk] ),
        'gold vw_call_list_today'[agente_sk]
    )
)

Call List Clientes Com Saldo QTD =
CALCULATE (
    COUNTROWS ( 'gold vw_call_list_today' ),
    FILTER (
        'gold vw_call_list_today',
        COALESCE ( 'gold vw_call_list_today'[balance], 0 ) > 0
            || COALESCE ( 'gold vw_call_list_today'[equity], 0 ) > 0
    ),
    TREATAS (
        VALUES ( 'gold dim_agente'[agente_sk] ),
        'gold vw_call_list_today'[agente_sk]
    )
)

Call List Last Deposit Amount USD =
CALCULATE (
    SUM ( 'gold vw_call_list_today'[last_deposit_amount_usd] ),
    TREATAS (
        VALUES ( 'gold dim_agente'[agente_sk] ),
        'gold vw_call_list_today'[agente_sk]
    )
)
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
Calcula _alta, _media, _baixa via CALCULATE + TREATAS
Barra relativa ao MAX das três categorias
Rodapé com total de pendentes
Variáveis: _W_Total, _H_Bar, _R_Dot, _Row_Margin, _Font_*, _Gap_Dot, _Label_MB
```

**`Call List Lead Status HTML`** — barras horizontais TOPN(5) por lead_status_text:

```text
Cor: >= 80% cinza-azul | >= 20% amarelo | resto cinza-azul
Variáveis: _W_Total, _W_Label, _W_Value, _H_Bar, _Gap, _Row_Margin, _Font_*
```

## Dados reais validados (abr/2026, todos os agentes)

| Métrica | Valor |
|---|---|
| Carteira | 1.849 |
| Operaram hoje | 220 (11,9%) |
| Pendentes hoje | 1.629 (88,1%) |
| Pendentes Alta | 22 |
| Clientes c/ Saldo | 1.429 |
| Balance Total | $252,46 Mi |
| Equity Total | $983,99 Mi |
| Último Dep. Total | $1,52 Mi |

**Top 6 agentes por pendentes:** James Lago 125 · Alessio Ferri 116 · Mickael Vian 87 · Beatriz Mariano 86 · Angelo Costa 84 · Brian Lima 81

**Distribuição prioridade (pendentes):** Alta 22 · Média 89 · Baixa 1.518

**Lead status (pendentes):** Telemarketing 1.412 · Callback 120 · No Answer 1 67 · New1 20 · Test 7

## Regra de carteira MVP

```text
carteira         = clientes atribuídos ao Retention Owner
operaram hoje    = clientes da carteira com operação CMD 0/1 aberta hoje
pendentes hoje   = carteira − operaram hoje
```

Contas bloqueadas, readonly, desabilitadas ou deletadas não são excluídas no MVP.

> **Importante:** o refresh do Power BI é Import/batch. Esta página não é real-time até existir fluxo em Grafana ou refresh adequado.

## Nota sobre TREATAS

As medidas `Call List *` usam `TREATAS(VALUES('gold dim_agente'[agente_sk]), 'gold vw_call_list_today'[agente_sk])` para propagar o filtro do slicer de agente para a view, enquanto não existir relacionamento formal entre `dim_agente` e `vw_call_list_today` no modelo semântico. Ver [[powerbi-semantic-model]].

## Artefatos gerados

| Artefato | Caminho |
|---|---|
| Mockup HTML | `artefatos/dashboard/aba03-operacao-diaria-call-list-mockup.html` |
| Medidas DAX | Criadas diretamente no Power BI Desktop (pasta `Call List` e `HTML Content`) |

## Validações executadas

- ✅ `Carteira (1849) = Operaram (220) + Pendentes (1629)`
- ✅ Dados validados via DAX queries diretas ao modelo via MCP (`localhost:57023`)
- ✅ Print de aceite visual recebido pelo usuário em 2026-06-06

## Ver também

- [[02-performance-por-agente]]
- [[04-rankings-competicao]]
- [[call-list]]
- [[powerbi-semantic-model]]
- [[guia-analista-dados-powerbi]]
- [[progresso-abas]]
