-- =============================================================================
-- 01_visao_executiva.sql — Aba 01 (Visão Executiva do Piso)
-- Fonte PBI: vw_team_month_performance, vw_agent_month_performance, vw_call_list_today
-- Competência fixa: abril/2026 (único mês com meta oficial)
-- Cada bloco reproduz uma medida DAX da aba 01.
-- =============================================================================
\pset pager off
\set comp '2026-04'
\echo '################ 01 — VISÃO EXECUTIVA DO PISO ################'
\echo 'Competência: 2026-04 | Escala dos target_pct_* da view = 0-100 (DAX usa 0-1)'

-- ---------------------------------------------------------------------------
-- [01.1] Big Numbers do piso (mês) — agrega vw_team_month_performance
--   DAX: Piso Deposit/Withdrawal/Net Deposit/Target Deposit Month USD,
--        Piso Run Rate USD, Piso Gap Run Rate/Gap Meta, Piso Unique Deposit,
--        Piso Trading Client Days, Piso Unique Trading, Piso Total Trades.
--   Obs.: run_rate_usd só é preenchido p/ o mês corrente (CURRENT_DATE);
--         para abril vem NULL → SUM = 0/blank no Power BI.
-- ---------------------------------------------------------------------------
\echo '[01.1] Piso — totais do mês (vw_team_month_performance):'
SELECT
    ROUND(SUM(deposit_month_usd),     2)            AS piso_deposit_usd,
    ROUND(SUM(withdrawal_month_usd),  2)            AS piso_withdrawal_usd,
    ROUND(SUM(net_deposit_month_usd), 2)            AS piso_net_deposit_usd,
    ROUND(SUM(target_deposit_month_usd), 2)         AS piso_target_deposit_usd,
    ROUND(SUM(net_deposit_month_usd) * 100.0
          / NULLIF(SUM(target_deposit_month_usd),0), 2) AS piso_target_deposit_pct, -- escala 0-100
    ROUND(SUM(run_rate_usd), 2)                     AS piso_run_rate_usd,           -- NULL fora do mes corrente
    ROUND(SUM(target_deposit_month_usd) - SUM(net_deposit_month_usd), 2) AS piso_gap_meta_usd,
    SUM(unique_deposit_month)                       AS piso_unique_deposit,
    SUM(trading_client_days_month)                  AS piso_trading_client_days,
    SUM(unique_trading_month)                       AS piso_unique_trading,
    SUM(total_trades_month)                         AS piso_total_trades,
    SUM(volume_lots_month)                          AS piso_volume_lots,
    SUM(target_trade_month)                         AS piso_target_trade,  -- 0 no HML (sem meta)
    SUM(target_unique_month)                        AS piso_target_unique  -- 0 no HML (sem meta)
FROM gold.vw_team_month_performance
WHERE year_month = :'comp';

-- ---------------------------------------------------------------------------
-- [01.2] Quebra por equipe (barras "Net Deposit por equipe")
-- ---------------------------------------------------------------------------
\echo '[01.2] Por equipe:'
SELECT
    team_name,
    ROUND(net_deposit_month_usd, 2)     AS net_deposit_usd,
    ROUND(target_deposit_month_usd, 2)  AS target_deposit_usd,
    target_pct_deposit,                 -- escala 0-100
    unique_deposit_month,
    agentes_ativos
FROM gold.vw_team_month_performance
WHERE year_month = :'comp'
ORDER BY net_deposit_usd DESC;

-- ---------------------------------------------------------------------------
-- [01.3] Ranking de agentes por net deposit (parte inferior da aba)
--   Fonte: vw_agent_month_performance
-- ---------------------------------------------------------------------------
\echo '[01.3] Ranking agentes (vw_agent_month_performance):'
SELECT
    agent_name, team_name,
    ROUND(net_deposit_month_usd, 2)     AS net_deposit_usd,
    ROUND(target_deposit_month_usd, 2)  AS target_deposit_usd,
    target_pct_deposit,                 -- escala 0-100
    ROUND(gap_meta_usd, 2)              AS gap_meta_usd,
    unique_deposit_month,
    unique_trading_month,
    total_trades_month
FROM gold.vw_agent_month_performance
WHERE year_month = :'comp'
ORDER BY net_deposit_usd DESC;

-- ---------------------------------------------------------------------------
-- [01.4] Call list hoje (cards Carteira / Operaram / Pendentes)
--   DAX: Carteira Clientes, Clientes Operaram Hoje, Clientes Pendentes Hoje.
--   ATENÇÃO: vw_call_list_today usa CURRENT_DATE. Hoje (2026-06) > último dado
--   PRD (abril) → "operaram hoje" = 0. Reproduz o Power BI 1:1 nesta data.
-- ---------------------------------------------------------------------------
\echo '[01.4] Call list hoje (CURRENT_DATE — reproduz o Power BI nesta data):'
SELECT
    COUNT(*)                                          AS carteira_clientes,
    COUNT(*) FILTER (WHERE traded_today)              AS operaram_hoje,
    COUNT(*) FILTER (WHERE is_pending_today)          AS pendentes_hoje,
    ROUND(COUNT(*) FILTER (WHERE traded_today) * 100.0
          / NULLIF(COUNT(*),0), 2)                    AS pct_operando_hoje
FROM gold.vw_call_list_today;
