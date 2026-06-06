# Contexto Geral do Projeto

## 1. O que é o projeto

Pipeline de engenharia de dados + dashboard analítico para uma corretora de daytrade
(**BrokerLab**). O objetivo de negócio é dar à operação de **retenção** uma visão de
performance por piso, por agente e por cliente: metas de depósito, run rate, call list
operacional, rankings e comissão.

O trabalho integra dois sistemas on-premises, ambos **read-only**:

- **Sirix** — plataforma MetaTrader 4, MySQL. Trades, contas e snapshot diário.
- **CRM MS Dynamics** — SQL Server, padrão Dataverse. Contas, agentes, transações monetárias.

Os dados são consolidados em um **data warehouse PostgreSQL** com arquitetura medalhão
(`stg_raw → bronze → silver → gold`) governada por `config`/`domain`, e servidos ao
**Power BI em modo Import**.

```
Sirix (MySQL)  ─┐
                ├─►  stg_raw ─► bronze ─► silver ─► gold ─►  Power BI (Import)
CRM (SQLServer)─┘    (TEXT)    (tipado)  (limpo)   (star)
                                            ▲
                              config / domain (governança)
```

## 2. Escopo

- Pipeline batch materializado em PostgreSQL (`stg_raw → bronze → silver → gold` +
  `config`/`domain` via `.xlsx`), hoje carregado por **scripts SQL bootstrap** no HML.
- Modelo semântico Power BI em **Import mode** com refresh agendado, consumindo as
  tabelas e views `gold`.
- Abas analíticas do dashboard.

## 3. Decisões de negócio vigentes

- Agente responsável = `Retention Owner` (em `gold.dim_cliente.agente_sk_current`).
- Data oficial de depósito/withdrawal = data de aprovação (`approved_on` / `tempo_aprovacao_sk`).
- Métrica principal de depósito = `net_deposit = deposit - withdrawal`.
- Unique oficial (meta/comissão) = clientes distintos com depósito aprovado no mês;
  unique trading é auxiliar.
- Trading hoje = cliente com operação aberta hoje (`gold.fato_cliente_trade_dia`).
- Calendário inicial = segunda a sexta, menos feriados globais cadastrados.
- Metas: no HML, apenas `target_deposit` de abril/2026 tem evidência oficial;
  `target_trade_month`/`target_unique_month` ficam como "sem meta oficial".
- Comissão: regras validadas, mas cálculo oficial depende de implementação técnica
  adicional (`vw_agent_commission`) — MVP2.

## 4. Dashboard Power BI — status das abas

| Aba | Escopo | Status |
|---|---|---|
| 01 — Visão Executiva do Piso | MVP1 | **Aprovada** (2026-06-04) |
| 02 — Performance por Agente | MVP1 | **Aprovada** (2026-06-05) |
| 03 — Operação Diária / Call List | MVP1 | **Aprovada** (2026-06-06) |
| 04 — Rankings e Competição | MVP1 | Handoff documentado, pronta p/ construção |
| 05 — Análise Financeira | MVP1 parcial | Não iniciada |
| 06 — Trading e Ativos | MVP1 parcial | Não iniciada |
| 07 — Qualidade e Reconciliação | MVP1 oculta | Não iniciada |
| 08 — Comissão e Score | Simulador / MVP2 | Não iniciada |
| 09 — Drill-through Cliente | MVP2 | Não iniciada |