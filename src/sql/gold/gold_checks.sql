-- =============================================================================
-- gold_checks.sql — Validações pós-carga do schema gold
-- Criado: 2026-05-12
-- Executar após gold_load_facts.sql + gold_views.sql
-- Critério de parada: ver plano de execução (gold_checks README)
-- =============================================================================

\echo '=== GOLD CHECKS ==='

-- ---------------------------------------------------------------------------
-- [G1] Reconciliação financeira: gold vs silver
-- Bloqueante: diferença > 0.01 USD
-- ---------------------------------------------------------------------------
\echo '[G1] Reconciliacao financeira gold vs silver:'
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
-- [G2] Tickets únicos em fato_operacao
-- Bloqueante: duplicidade de chave natural
-- ---------------------------------------------------------------------------
\echo '[G2] Tickets duplicados em fato_operacao:'
SELECT ticket, COUNT(*) AS cnt
FROM gold.fato_operacao
GROUP BY ticket
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 10;

-- ---------------------------------------------------------------------------
-- [G3] Operações mercado CMD 0/1 sem ativo resolvido
-- Warning: degradação de dim_ativo
-- ---------------------------------------------------------------------------
\echo '[G3] Operacoes mercado sem ativo_sk:'
SELECT
    COUNT(*)                                    AS sem_ativo,
    ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM gold.fato_operacao WHERE eh_operacao_mercado), 0), 2)
                                                AS pct_sem_ativo
FROM gold.fato_operacao
WHERE eh_operacao_mercado = TRUE
  AND ativo_sk IS NULL;

-- ---------------------------------------------------------------------------
-- [G4] Transações sem cliente resolvido
-- ---------------------------------------------------------------------------
\echo '[G4] Transacoes sem cliente_sk:'
SELECT
    COUNT(*)                                    AS sem_cliente,
    ROUND(COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM gold.fato_movimentacao_financeira), 0), 2)
                                                AS pct_sem_cliente
FROM gold.fato_movimentacao_financeira
WHERE cliente_sk IS NULL;

-- ---------------------------------------------------------------------------
-- [G5] Duplicidade em fato_cliente_trade_dia (PK: tempo_sk + cliente_sk)
-- Bloqueante
-- ---------------------------------------------------------------------------
\echo '[G5] Duplicidade em fato_cliente_trade_dia:'
SELECT tempo_sk, cliente_sk, COUNT(*) AS cnt
FROM gold.fato_cliente_trade_dia
GROUP BY tempo_sk, cliente_sk
HAVING COUNT(*) > 1
LIMIT 10;

-- ---------------------------------------------------------------------------
-- [G6] Divisão por zero em fato_meta_agente_mes
-- ---------------------------------------------------------------------------
\echo '[G6] Metas com business_days_in_month = 0:'
SELECT competence_month_sk, agente_sk, business_days_in_month
FROM gold.fato_meta_agente_mes
WHERE business_days_in_month = 0 OR business_days_in_month IS NULL;

-- ---------------------------------------------------------------------------
-- [G7] % clientes sem agente resolvido (threshold: <15% aceitável no MVP)
-- ---------------------------------------------------------------------------
\echo '[G7] % clientes sem agente resolvido:'
SELECT
    COUNT(*)                                        AS total_clientes,
    COUNT(*) FILTER (WHERE _agente_quality != 'resolved')
                                                    AS sem_agente,
    ROUND(COUNT(*) FILTER (WHERE _agente_quality != 'resolved') * 100.0
          / NULLIF(COUNT(*), 0), 2)                 AS pct_sem_agente
FROM gold.dim_cliente;

-- ---------------------------------------------------------------------------
-- [G8] Agentes ativos sem nenhuma transação no período
-- ---------------------------------------------------------------------------
\echo '[G8] Agentes individuais ativos sem transacoes no gold:'
SELECT da.agent_name, da.team_name
FROM gold.dim_agente da
WHERE da.agent_type = 'individual'
  AND da.is_active = TRUE
  AND NOT EXISTS (
    SELECT 1 FROM gold.fato_movimentacao_financeira f
    WHERE f.agente_sk = da.agente_sk
  )
ORDER BY da.agent_name;

-- ---------------------------------------------------------------------------
-- [G8b] Agentes individuais ativos sem nível operacional
-- ---------------------------------------------------------------------------
\echo '[G8b] Agentes individuais ativos sem agent_level:'
SELECT da.agent_name, da.team_name
FROM gold.dim_agente da
WHERE da.agent_type = 'individual'
  AND da.is_active = TRUE
  AND da.agent_level IS NULL
ORDER BY da.agent_name;

-- ---------------------------------------------------------------------------
-- [G9] Metas sem agente resolvido
-- ---------------------------------------------------------------------------
\echo '[G9] Agentes individuais ativos sem meta no mes corrente:'
SELECT da.agent_name
FROM gold.dim_agente da
WHERE da.agent_type = 'individual'
  AND da.is_active = TRUE
  AND NOT EXISTS (
    SELECT 1 FROM gold.fato_meta_agente_mes meta
    WHERE meta.agente_sk       = da.agente_sk
      AND meta.competence_month = DATE_TRUNC('month', CURRENT_DATE)::date
  )
ORDER BY da.agent_name;

-- ---------------------------------------------------------------------------
-- [G10] Sanidade call list: verificar se retorna clientes para hoje
-- ---------------------------------------------------------------------------
\echo '[G10] Call list hoje — contagem por agente:'
SELECT agent_name, team_name,
       COUNT(*)                                         AS total_carteira,
       SUM(CASE WHEN traded_today  THEN 1 ELSE 0 END)  AS operaram_hoje,
       SUM(CASE WHEN is_pending_today THEN 1 ELSE 0 END) AS pendentes_hoje
FROM gold.vw_call_list_today
GROUP BY agent_name, team_name
ORDER BY total_carteira DESC
LIMIT 20;

-- ---------------------------------------------------------------------------
-- Resumo de contagens gold
-- ---------------------------------------------------------------------------
\echo '[SUMMARY] Contagens gold:'
SELECT
    (SELECT COUNT(*) FROM gold.dim_tempo)                   AS dim_tempo,
    (SELECT COUNT(*) FROM gold.dim_agente)                  AS dim_agente,
    (SELECT COUNT(*) FROM gold.dim_ativo)                   AS dim_ativo,
    (SELECT COUNT(*) FROM gold.dim_cliente)                 AS dim_cliente,
    (SELECT COUNT(*) FROM gold.fato_meta_agente_mes)        AS fato_meta,
    (SELECT COUNT(*) FROM gold.fato_movimentacao_financeira) AS fato_fin,
    (SELECT COUNT(*) FROM gold.fato_operacao)               AS fato_op,
    (SELECT COUNT(*) FROM gold.fato_cliente_trade_dia)      AS fato_trade_dia;
