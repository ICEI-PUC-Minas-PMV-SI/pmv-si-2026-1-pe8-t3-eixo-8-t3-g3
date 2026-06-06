-- =============================================================================
-- 02_performance_agente.sql — Aba 02 (Performance por Agente)
-- Fonte PBI: vw_agent_month_performance, vw_agent_day_performance, vw_call_list_today
-- Competência fixa: abril/2026. KPIs por agente (filtro obrigatório: agent_name).
-- =============================================================================
\pset pager off
\set comp '2026-04'
\echo '################ 02 — PERFORMANCE POR AGENTE ################'
\echo 'Competência: 2026-04 | target_pct_* em escala 0-100'

-- ---------------------------------------------------------------------------
-- [02.1] Matriz mensal por agente (todos os KPIs de topo da aba)
--   DAX: Agent Net Deposit Month, Target Deposit Month, Target Deposit %,
--        Run Rate, Gap Run Rate, Target Deposit Day, Unique Deposit,
--        Trading Client Days, Unique Trading, Total Trades.
-- ---------------------------------------------------------------------------
\echo '[02.1] Mensal por agente (vw_agent_month_performance):'
SELECT
    agent_name, team_name, agent_level, is_active,
    ROUND(net_deposit_month_usd, 2)     AS net_deposit_usd,
    ROUND(target_deposit_month_usd, 2)  AS target_deposit_usd,
    target_pct_deposit,                 -- escala 0-100
    ROUND(run_rate_usd, 2)              AS run_rate_usd,   -- NULL fora do mes corrente
    ROUND(gap_meta_usd, 2)             AS gap_meta_usd,
    ROUND(target_deposit_day_usd, 2)    AS target_deposit_day_usd,
    unique_deposit_month,
    trading_client_days_month,
    unique_trading_month,
    total_trades_month,
    volume_lots_month
FROM gold.vw_agent_month_performance
WHERE year_month = :'comp'
ORDER BY net_deposit_usd DESC;

-- ---------------------------------------------------------------------------
-- [02.2] Total consolidado dos agentes (quando nenhum agente é selecionado)
-- ---------------------------------------------------------------------------
\echo '[02.2] Consolidado de todos os agentes (mês):'
SELECT
    COUNT(*)                                AS qtd_linhas_agente,
    ROUND(SUM(net_deposit_month_usd), 2)    AS net_deposit_usd,
    ROUND(SUM(target_deposit_month_usd), 2) AS target_deposit_usd,
    SUM(unique_deposit_month)               AS unique_deposit,
    SUM(trading_client_days_month)          AS trading_client_days,
    SUM(total_trades_month)                 AS total_trades
FROM gold.vw_agent_month_performance
WHERE year_month = :'comp';

-- ---------------------------------------------------------------------------
-- [02.3] Série diária por agente (gráfico combinado + linha acumulada)
--   DAX: Agent Net Deposit Today, Net Deposit Acumulado Mês, Clientes Operaram Dia.
--   Filtro de competência via year_month da view de dia.
-- ---------------------------------------------------------------------------
\echo '[02.3] Diário por agente (vw_agent_day_performance) — abril:'
SELECT
    ref_date, agent_name, team_name,
    ROUND(deposit_day, 2)               AS deposit_day,
    ROUND(withdrawal_day, 2)            AS withdrawal_day,
    ROUND(net_deposit_day, 2)           AS net_deposit_day,
    ROUND(net_deposit_acumulado_mes, 2) AS net_deposit_acumulado_mes,
    ROUND(target_deposit_day_usd, 2)    AS target_deposit_day_usd,
    clientes_operaram_dia,
    total_trades_dia
FROM gold.vw_agent_day_performance
WHERE year_month = :'comp'
ORDER BY agent_name, ref_date;
