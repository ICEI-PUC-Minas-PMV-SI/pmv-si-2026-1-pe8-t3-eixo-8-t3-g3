-- =============================================================================
-- 08_comissao_score.sql — Aba 08 (Comissão e Score) — SIMULAÇÃO
-- Fonte PBI: vw_agent_month_performance
-- ATENÇÃO: cálculo NÃO oficial. A view gold.vw_agent_commission ainda é draft
-- (bd/gold/drafts/). Aqui a lógica DAX (faixas, Zona de Isenção, aceleradores,
-- score) é reproduzida em SQL CASE WHEN apenas para conferência/simulação.
-- Sem meta oficial de trade/unique no HML → aceleradores tendem a 0.
-- Garantia PRO NÃO incluída (agent_level parcial: 9/45).
-- Competência fixa: abril/2026.
-- =============================================================================
\pset pager off
\set comp '2026-04'
\echo '################ 08 — COMISSÃO E SCORE (SIMULAÇÃO) ################'
\echo 'Competência: 2026-04 | valores SIMULADOS, não oficiais'

WITH base AS (
    SELECT
        agent_name, team_name, agent_level,
        net_deposit_month_usd                              AS net,
        target_deposit_month_usd                           AS meta,
        COALESCE(target_pct_deposit,0)/100.0               AS dep_pct,   -- 0-1
        COALESCE(target_pct_trade, 0)/100.0                AS trade_pct, -- 0-1 (0 sem meta)
        COALESCE(target_pct_unique,0)/100.0                AS uniq_pct,  -- 0-1 (0 sem meta)
        unique_deposit_month, trading_client_days_month
    FROM gold.vw_agent_month_performance
    WHERE year_month = :'comp'
),
calc AS (
    SELECT
        b.*,
        CASE WHEN dep_pct   >= 1 THEN 1 ELSE 0 END AS hit_deposit,
        CASE WHEN trade_pct >= 1 THEN 1 ELSE 0 END AS hit_trade,
        CASE WHEN uniq_pct  >= 1 THEN 1 ELSE 0 END AS hit_unique,
        CASE WHEN net >= 70000 THEN 1 ELSE 0 END   AS zona_isencao,
        -- % fixo da Zona de Isenção por faixa
        CASE
            WHEN net >= 120000 THEN 0.11
            WHEN net >= 100000 THEN 0.10
            WHEN net >=  90000 THEN 0.09
            WHEN net >=  70000 THEN 0.08
            ELSE NULL
        END AS zona_pct,
        -- % base abaixo de 70k
        CASE
            WHEN net >= 60000 THEN 0.05
            WHEN net >= 20000 THEN 0.04
            WHEN net >      0  THEN 0.04
            ELSE 0
        END AS base_pct
    FROM base b
)
SELECT
    agent_name, team_name, agent_level,
    ROUND(net, 2)                           AS net_deposit_usd,
    ROUND(meta, 2)                          AS target_deposit_usd,
    ROUND(dep_pct, 4)                       AS deposit_pct,    -- 0-1
    ROUND(trade_pct, 4)                     AS trade_pct,      -- 0-1
    ROUND(uniq_pct, 4)                      AS unique_pct,     -- 0-1
    (hit_deposit + hit_trade + hit_unique)  AS parameter_hits,
    zona_isencao,
    -- acelerador (apenas abaixo de 70k): +1% unique + +1% trade se hit
    ROUND(CASE WHEN zona_isencao = 0
               THEN (CASE WHEN hit_unique=1 THEN 0.01 ELSE 0 END)
                  + (CASE WHEN hit_trade =1 THEN 0.01 ELSE 0 END)
               ELSE 0 END, 4)               AS acelerador_pct,
    -- comissão simulada total %
    ROUND(CASE WHEN zona_isencao = 1 THEN zona_pct
               ELSE base_pct
                  + (CASE WHEN hit_unique=1 THEN 0.01 ELSE 0 END)
                  + (CASE WHEN hit_trade =1 THEN 0.01 ELSE 0 END)
          END, 4)                           AS comissao_sim_pct,
    -- comissão simulada total USD
    ROUND(net * CASE WHEN zona_isencao = 1 THEN zona_pct
                     ELSE base_pct
                        + (CASE WHEN hit_unique=1 THEN 0.01 ELSE 0 END)
                        + (CASE WHEN hit_trade =1 THEN 0.01 ELSE 0 END)
                END, 2)                     AS comissao_sim_usd,
    -- Score gerencial cap 100 e cap 120
    ROUND(LEAST(dep_pct,1)*0.50 + LEAST(trade_pct,1)*0.30 + LEAST(uniq_pct,1)*0.20, 4)       AS score_cap100,
    ROUND(LEAST(dep_pct,1.2)*0.50 + LEAST(trade_pct,1.2)*0.30 + LEAST(uniq_pct,1.2)*0.20, 4) AS score_cap120
FROM calc
ORDER BY net_deposit_usd DESC;
