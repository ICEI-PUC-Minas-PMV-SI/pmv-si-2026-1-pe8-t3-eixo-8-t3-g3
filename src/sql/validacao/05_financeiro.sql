-- =============================================================================
-- 05_financeiro.sql — Aba 05 (Análise Financeira)
-- Fonte PBI: fato_movimentacao_financeira (data oficial = approved_on)
-- Competência fixa: abril/2026. Reproduz as medidas DAX da aba 05.
-- Regra: o net deposit aqui DEVE bater com a aba 01 no mesmo filtro.
-- =============================================================================
\pset pager off
\set comp '2026-04'
\echo '################ 05 — ANÁLISE FINANCEIRA ################'
\echo 'Competência: 2026-04 | data oficial = approved_on'

-- ---------------------------------------------------------------------------
-- [05.1] Big Numbers financeiros do mês
--   DAX: Finance Deposit/Withdrawal/Net Deposit USD, Deposit/Withdrawal
--        Transactions, Average Deposit Ticket, FTD Count,
--        Unique Deposit/Withdrawal Clients, Withdrawal/Deposit Ratio.
--   Obs.: FTD Count = COUNTROWS (linhas), não distinct cliente (espelha o DAX).
-- ---------------------------------------------------------------------------
\echo '[05.1] Financeiro do mês:'
SELECT
    ROUND(SUM(deposit_amount_usd), 2)                              AS deposit_usd,
    ROUND(SUM(withdrawal_amount_usd), 2)                           AS withdrawal_usd,
    ROUND(SUM(net_deposit_usd), 2)                                 AS net_deposit_usd,
    COUNT(*) FILTER (WHERE deposit_amount_usd > 0)                 AS qtd_depositos,
    COUNT(*) FILTER (WHERE withdrawal_amount_usd > 0)              AS qtd_withdrawals,
    ROUND(SUM(deposit_amount_usd)
          / NULLIF(COUNT(*) FILTER (WHERE deposit_amount_usd>0),0), 2) AS ticket_medio_deposito,
    COUNT(*) FILTER (WHERE eh_ftd AND eh_aprovada)                 AS ftd_count,
    COUNT(DISTINCT cliente_sk) FILTER (WHERE deposit_amount_usd>0)    AS unique_deposit_clients,
    COUNT(DISTINCT cliente_sk) FILTER (WHERE withdrawal_amount_usd>0) AS unique_withdrawal_clients,
    ROUND(SUM(withdrawal_amount_usd)
          / NULLIF(SUM(deposit_amount_usd),0), 4)                  AS withdrawal_deposit_ratio
FROM gold.fato_movimentacao_financeira
WHERE eh_aprovada = TRUE
  AND approved_on IS NOT NULL
  AND TO_CHAR(approved_on, 'YYYY-MM') = :'comp';

-- ---------------------------------------------------------------------------
-- [05.2] Matriz por agente (deposito, withdrawal, net, tickets, unique, FTD)
-- ---------------------------------------------------------------------------
\echo '[05.2] Por agente:'
SELECT
    da.agent_name, da.team_name,
    ROUND(SUM(f.deposit_amount_usd), 2)                AS deposit_usd,
    ROUND(SUM(f.withdrawal_amount_usd), 2)             AS withdrawal_usd,
    ROUND(SUM(f.net_deposit_usd), 2)                   AS net_deposit_usd,
    COUNT(*) FILTER (WHERE f.deposit_amount_usd>0)     AS qtd_depositos,
    COUNT(DISTINCT f.cliente_sk) FILTER (WHERE f.deposit_amount_usd>0) AS unique_deposit_clients,
    COUNT(*) FILTER (WHERE f.eh_ftd AND f.eh_aprovada) AS ftd_count
FROM gold.fato_movimentacao_financeira f
LEFT JOIN gold.dim_agente da ON da.agente_sk = f.agente_sk
WHERE f.eh_aprovada = TRUE
  AND f.approved_on IS NOT NULL
  AND TO_CHAR(f.approved_on, 'YYYY-MM') = :'comp'
GROUP BY da.agent_name, da.team_name
ORDER BY net_deposit_usd DESC;

-- ---------------------------------------------------------------------------
-- [05.3] Por método de pagamento (barras)
-- ---------------------------------------------------------------------------
\echo '[05.3] Por método de pagamento:'
SELECT
    COALESCE(payment_method_name, '(sem método)') AS payment_method_name,
    COUNT(*)                                       AS qtd,
    ROUND(SUM(deposit_amount_usd), 2)              AS deposit_usd
FROM gold.fato_movimentacao_financeira
WHERE eh_aprovada = TRUE
  AND approved_on IS NOT NULL
  AND TO_CHAR(approved_on, 'YYYY-MM') = :'comp'
GROUP BY 1
ORDER BY deposit_usd DESC;
