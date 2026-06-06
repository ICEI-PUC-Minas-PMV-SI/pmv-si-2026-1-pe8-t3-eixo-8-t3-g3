-- =============================================================================
-- 00_reconciliacao.sql — Baseline e reconciliação financeira gold vs silver
-- HML: db_brokerlab_reimport_test
-- Objetivo: garantir que a base está íntegra ANTES de validar Big Numbers.
-- Espelha bd/gold/gold_checks.sql [G1] + contagens do baseline 24/24.
-- Executar: psql -U postgres -d db_brokerlab_reimport_test -f 00_reconciliacao.sql
-- =============================================================================
\pset pager off
\echo '################ 00 — RECONCILIAÇÃO / BASELINE ################'

-- ---------------------------------------------------------------------------
-- [00.1] Reconciliação financeira gold vs silver  (esperado: gold = silver)
--        Net deposit total esperado ≈ USD 5.682.668,98
-- ---------------------------------------------------------------------------
\echo '[00.1] Reconciliacao gold vs silver (deposit / withdrawal / net):'
SELECT
    'gold'   AS origem,
    SUM(deposit_amount_usd)     AS total_deposit,
    SUM(withdrawal_amount_usd)  AS total_withdrawal,
    SUM(net_deposit_usd)        AS total_net_deposit
FROM gold.fato_movimentacao_financeira
WHERE eh_aprovada = TRUE
UNION ALL
SELECT
    'silver',
    SUM(CASE WHEN eh_deposito  AND eh_aprovada THEN usd_value ELSE 0 END),
    SUM(CASE WHEN eh_withdrawal AND eh_aprovada THEN usd_value ELSE 0 END),
    SUM(CASE WHEN eh_deposito  AND eh_aprovada THEN  usd_value
             WHEN eh_withdrawal AND eh_aprovada THEN -usd_value
             ELSE 0 END)
FROM silver.transaction_clean;

-- ---------------------------------------------------------------------------
-- [00.2] Contagens das tabelas gold (baseline congelado)
-- ---------------------------------------------------------------------------
\echo '[00.2] Contagens gold (baseline):'
SELECT
    (SELECT COUNT(*) FROM gold.dim_tempo)                    AS dim_tempo,
    (SELECT COUNT(*) FROM gold.dim_agente)                   AS dim_agente,
    (SELECT COUNT(*) FROM gold.dim_ativo)                    AS dim_ativo,
    (SELECT COUNT(*) FROM gold.dim_cliente)                  AS dim_cliente,
    (SELECT COUNT(*) FROM gold.fato_meta_agente_mes)         AS fato_meta,
    (SELECT COUNT(*) FROM gold.fato_movimentacao_financeira) AS fato_fin,
    (SELECT COUNT(*) FROM gold.fato_operacao)                AS fato_op,
    (SELECT COUNT(*) FROM gold.fato_cliente_trade_dia)       AS fato_trade_dia;

-- ---------------------------------------------------------------------------
-- [00.3] Net deposit por mês de competência (contexto: abril/2026 é o foco)
-- ---------------------------------------------------------------------------
\echo '[00.3] Net deposit por mes (aprovado):'
SELECT
    TO_CHAR(DATE_TRUNC('month', approved_on), 'YYYY-MM') AS year_month,
    COUNT(*)                       AS qtd_transacoes,
    ROUND(SUM(deposit_amount_usd),    2) AS deposit_usd,
    ROUND(SUM(withdrawal_amount_usd), 2) AS withdrawal_usd,
    ROUND(SUM(net_deposit_usd),       2) AS net_deposit_usd
FROM gold.fato_movimentacao_financeira
WHERE eh_aprovada = TRUE AND approved_on IS NOT NULL
GROUP BY 1
ORDER BY 1;
