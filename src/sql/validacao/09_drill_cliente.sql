-- =============================================================================
-- 09_drill_cliente.sql — Aba 09 (Drill-through Cliente) — FASE 2 / template
-- Fonte PBI: dim_cliente, fato_movimentacao_financeira, fato_operacao
-- Parametrizado por :cliente_sk. Para escolher um cliente, rode [09.0] e depois:
--   psql ... -v cliente_sk=<sk> -f 09_drill_cliente.sql
-- Default abaixo aponta para o maior depositante (ajuste à vontade).
-- =============================================================================
\pset pager off
-- default: maior net deposit (sobrescreva com -v cliente_sk=...)
SELECT cliente_sk AS sk_default
FROM gold.fato_movimentacao_financeira
WHERE eh_aprovada AND cliente_sk IS NOT NULL
GROUP BY cliente_sk
ORDER BY SUM(net_deposit_usd) DESC
LIMIT 1
\gset
\if :{?cliente_sk}
\else
  \set cliente_sk :sk_default
\endif
\echo '################ 09 — DRILL-THROUGH CLIENTE ################'
\echo 'cliente_sk em análise:' :cliente_sk

-- ---------------------------------------------------------------------------
-- [09.0] Candidatos (top clientes por net deposit) — para escolher o drill
-- ---------------------------------------------------------------------------
\echo '[09.0] Top clientes por net deposit:'
SELECT f.cliente_sk, dc.cliente_nome, dc.country,
       ROUND(SUM(f.net_deposit_usd),2) AS net_deposit_usd
FROM gold.fato_movimentacao_financeira f
JOIN gold.dim_cliente dc ON dc.cliente_sk = f.cliente_sk
WHERE f.eh_aprovada
GROUP BY f.cliente_sk, dc.cliente_nome, dc.country
ORDER BY net_deposit_usd DESC
LIMIT 10;

-- ---------------------------------------------------------------------------
-- [09.1] Cadastro + snapshot (dim_cliente)
--   DAX: Cliente Balance/Equity Atual, Margin Level.
-- ---------------------------------------------------------------------------
\echo '[09.1] Cadastro e snapshot do cliente:'
SELECT
    dc.cliente_sk, dc.cliente_nome, dc.crm_account_id, dc.tp_account_id,
    dc.sirix_login, da.agent_name, da.team_name, dc.country, dc.language_iso,
    dc.lead_status_text, dc.has_ftd,
    ROUND(dc.balance, 2)  AS balance,
    ROUND(dc.equity, 2)   AS equity,
    dc.margin_level, dc.last_activity_date
FROM gold.dim_cliente dc
LEFT JOIN gold.dim_agente da ON da.agente_sk = dc.agente_sk_current
WHERE dc.cliente_sk = :cliente_sk;

-- ---------------------------------------------------------------------------
-- [09.2] Financeiro total do cliente
--   DAX: Cliente Deposit/Withdrawal/Net Deposit USD, Deposit Transactions,
--        Last Deposit/Withdrawal Date.
-- ---------------------------------------------------------------------------
\echo '[09.2] Financeiro do cliente:'
SELECT
    ROUND(SUM(deposit_amount_usd), 2)                  AS deposit_usd,
    ROUND(SUM(withdrawal_amount_usd), 2)               AS withdrawal_usd,
    ROUND(SUM(net_deposit_usd), 2)                     AS net_deposit_usd,
    COUNT(*) FILTER (WHERE deposit_amount_usd>0)       AS qtd_depositos,
    MAX(approved_on) FILTER (WHERE deposit_amount_usd>0)    AS ultimo_deposito,
    MAX(approved_on) FILTER (WHERE withdrawal_amount_usd>0) AS ultimo_withdrawal
FROM gold.fato_movimentacao_financeira
WHERE eh_aprovada AND cliente_sk = :cliente_sk;

-- ---------------------------------------------------------------------------
-- [09.3] Trading do cliente
--   DAX: Cliente Market Trades, Active Assets, Volume Lots, PnL Provisional,
--        Last Trade DateTime, Open Positions.
-- ---------------------------------------------------------------------------
\echo '[09.3] Trading do cliente:'
SELECT
    COUNT(*)                                AS market_trades,
    COUNT(DISTINCT ativo_sk)                AS active_assets,
    ROUND(SUM(volume_lots), 4)              AS volume_lots,
    ROUND(SUM(profit_liquido), 2)           AS pnl_liquido_usd,
    MAX(open_time)                          AS ultimo_trade,
    COUNT(*) FILTER (WHERE eh_aberta)       AS open_positions
FROM gold.fato_operacao
WHERE eh_operacao_mercado = TRUE AND cliente_sk = :cliente_sk;
