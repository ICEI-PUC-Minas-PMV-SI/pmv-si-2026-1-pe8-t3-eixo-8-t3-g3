-- =============================================================================
-- 04_rankings.sql — Aba 04 (Rankings e Competição)
-- Fonte PBI: vw_agent_month_performance
-- Competência fixa: abril/2026. Reproduz rankings + Score Gerencial 50/30/20.
-- =============================================================================
\pset pager off
\set comp '2026-04'
\echo '################ 04 — RANKINGS E COMPETIÇÃO ################'
\echo 'Competência: 2026-04 | Score em escala 0-1.2 (cap 120%)'

-- ---------------------------------------------------------------------------
-- [04.1] Ranking por net deposit + target % + score gerencial
--   DAX: Rank Net Deposit, Rank Target Deposit %, Rank Trading Client Days,
--        Rank Unique Deposit, Rank Volume Lots, RANKX(...), Score Gerencial.
--   Score = depósito% *0,50 + trade% *0,30 + unique% *0,20, cada um capado em 1,2.
--   (target_pct_* da view estão em 0-100 → /100 para virar 0-1 como no DAX.)
-- ---------------------------------------------------------------------------
\echo '[04.1] Ranking de agentes + score gerencial:'
WITH base AS (
    SELECT
        agent_name, team_name,
        net_deposit_month_usd,
        target_deposit_month_usd,
        target_pct_deposit,                       -- 0-100
        gap_meta_usd,
        run_rate_usd,
        unique_deposit_month,
        unique_trading_month,
        trading_client_days_month,
        total_trades_month,
        volume_lots_month,
        pnl_month,
        target_pct_trade,                         -- 0-100 (NULL sem meta)
        target_pct_unique                         -- 0-100 (NULL sem meta)
    FROM gold.vw_agent_month_performance
    WHERE year_month = :'comp'
)
SELECT
    RANK() OVER (ORDER BY net_deposit_month_usd DESC) AS rank_net,
    agent_name, team_name,
    ROUND(net_deposit_month_usd, 2)    AS net_deposit_usd,
    ROUND(target_deposit_month_usd, 2) AS target_deposit_usd,
    target_pct_deposit,                -- 0-100
    ROUND(gap_meta_usd, 2)            AS gap_meta_usd,
    unique_deposit_month,
    trading_client_days_month,
    total_trades_month,
    volume_lots_month,
    -- Score Gerencial 50/30/20 cap 120 (escala 0-1.2). Trade/Unique sem meta = 0.
    ROUND(
        LEAST(COALESCE(target_pct_deposit,0)/100.0, 1.2) * 0.50
      + LEAST(COALESCE(target_pct_trade,  0)/100.0, 1.2) * 0.30
      + LEAST(COALESCE(target_pct_unique, 0)/100.0, 1.2) * 0.20
    , 4)                               AS score_gerencial_cap120
FROM base
ORDER BY net_deposit_usd DESC;
