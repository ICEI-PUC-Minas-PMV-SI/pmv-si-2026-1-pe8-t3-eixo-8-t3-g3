-- =============================================================================
-- 03_call_list.sql — Aba 03 (Operação Diária / Call List)
-- Fonte PBI: vw_call_list_today
-- DUAS variantes:
--   (A) view como está (CURRENT_DATE) — reproduz o Power BI 1:1 nesta data;
--   (B) data de referência FIXA (último dia com trades: 2026-05-05) — evidência,
--       reproduz a lógica da view inline para o número não vir vazio.
-- =============================================================================
\pset pager off
\set refdate '2026-05-05'
\echo '################ 03 — CALL LIST ################'

-- ---------------------------------------------------------------------------
-- [03.A] Cards da call list (vw_call_list_today, CURRENT_DATE)
--   DAX: Carteira, Operaram Hoje, Pendentes Hoje, % Operando, Pendentes Alta,
--        Clientes Com Saldo, Vistos Hoje, Equity/Balance Total, Último Depósito.
-- ---------------------------------------------------------------------------
\echo '[03.A] Cards (CURRENT_DATE — igual ao Power BI hoje):'
SELECT
    COUNT(*)                                                       AS carteira,
    COUNT(*) FILTER (WHERE traded_today)                           AS operaram_hoje,
    COUNT(*) FILTER (WHERE is_pending_today)                       AS pendentes_hoje,
    ROUND(COUNT(*) FILTER (WHERE traded_today)*100.0/NULLIF(COUNT(*),0),2) AS pct_operando,
    COUNT(*) FILTER (WHERE is_pending_today AND priority_label='Alta')     AS pendentes_alta,
    COUNT(*) FILTER (WHERE COALESCE(balance,0)>0 OR COALESCE(equity,0)>0)  AS clientes_com_saldo,
    COUNT(*) FILTER (WHERE last_activity_date = CURRENT_DATE)      AS vistos_hoje,
    ROUND(SUM(equity), 2)                                          AS equity_total,
    ROUND(SUM(balance), 2)                                         AS balance_total,
    ROUND(SUM(last_deposit_amount_usd), 2)                         AS ultimo_deposito_total
FROM gold.vw_call_list_today;

-- ---------------------------------------------------------------------------
-- [03.A2] Pendentes por agente (barras rodapé) + igualdade carteira
--   Validação: carteira = operaram + pendentes (por agente).
-- ---------------------------------------------------------------------------
\echo '[03.A2] Por agente (CURRENT_DATE):'
SELECT
    agent_name, team_name,
    COUNT(*)                                  AS carteira,
    COUNT(*) FILTER (WHERE traded_today)      AS operaram_hoje,
    COUNT(*) FILTER (WHERE is_pending_today)  AS pendentes_hoje
FROM gold.vw_call_list_today
GROUP BY agent_name, team_name
ORDER BY carteira DESC;

-- ---------------------------------------------------------------------------
-- [03.B] Variante EVIDÊNCIA — reproduz a lógica de vw_call_list_today com
--   data de referência fixa :refdate (2026-05-05, último dia com trades).
--   Mesma regra: carteira = clientes do retention owner (agente ativo);
--   operou = abriu CMD 0/1 na :refdate.
-- ---------------------------------------------------------------------------
\echo '[03.B] Cards com data de referência fixa (:refdate) — evidência:'
WITH ref_sk AS (
    SELECT REPLACE(:'refdate','-','')::INTEGER AS sk
),
operou_ref AS (
    SELECT DISTINCT ctd.cliente_sk
    FROM gold.fato_cliente_trade_dia ctd, ref_sk r
    WHERE ctd.tempo_sk = r.sk
),
carteira AS (
    SELECT
        dc.cliente_sk, dc.balance, dc.equity, dc.last_activity_date,
        CASE WHEN o.cliente_sk IS NOT NULL THEN TRUE ELSE FALSE END AS traded_ref,
        CASE
            WHEN dc.balance > 10000 THEN 'Alta'
            WHEN dc.balance > 1000  THEN 'Média'
            ELSE 'Baixa'
        END AS priority_label
    FROM gold.dim_cliente dc
    JOIN gold.dim_agente da
        ON da.agente_sk = dc.agente_sk_current
       AND da.agent_type = 'individual'
       AND da.is_active = TRUE
    LEFT JOIN operou_ref o ON o.cliente_sk = dc.cliente_sk
)
SELECT
    COUNT(*)                                                       AS carteira,
    COUNT(*) FILTER (WHERE traded_ref)                             AS operaram_ref,
    COUNT(*) FILTER (WHERE NOT traded_ref)                         AS pendentes_ref,
    ROUND(COUNT(*) FILTER (WHERE traded_ref)*100.0/NULLIF(COUNT(*),0),2) AS pct_operando,
    COUNT(*) FILTER (WHERE NOT traded_ref AND priority_label='Alta')     AS pendentes_alta,
    COUNT(*) FILTER (WHERE COALESCE(balance,0)>0 OR COALESCE(equity,0)>0)  AS clientes_com_saldo,
    ROUND(SUM(equity), 2)                                          AS equity_total,
    ROUND(SUM(balance), 2)                                         AS balance_total
FROM carteira;
