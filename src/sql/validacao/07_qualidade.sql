-- =============================================================================
-- 07_qualidade.sql — Aba 07 (Qualidade e Reconciliação)
-- Fonte PBI: vw_data_quality_summary, vw_unresolved_agent_alias,
--            vw_unresolved_client_bridge, fato_operacao, fato_movimentacao_financeira
-- Página técnica/oculta. WARN pode ser limitação esperada do dado, não erro.
-- =============================================================================
\pset pager off
\echo '################ 07 — QUALIDADE E RECONCILIAÇÃO ################'

-- ---------------------------------------------------------------------------
-- [07.1] Resumo dos checks (cards WARN / INFO / OK)
--   DAX: Quality Checks Total/WARN/INFO/OK, Quality WARN %.
-- ---------------------------------------------------------------------------
\echo '[07.1] Checks por status:'
SELECT
    COUNT(*)                                  AS checks_total,
    COUNT(*) FILTER (WHERE status='WARN')     AS checks_warn,
    COUNT(*) FILTER (WHERE status='INFO')     AS checks_info,
    COUNT(*) FILTER (WHERE status='OK')       AS checks_ok,
    ROUND(COUNT(*) FILTER (WHERE status='WARN')*100.0/NULLIF(COUNT(*),0),2) AS warn_pct
FROM gold.vw_data_quality_summary;

-- ---------------------------------------------------------------------------
-- [07.2] Tabela principal de checks (detalhe)
-- ---------------------------------------------------------------------------
\echo '[07.2] Detalhe dos checks:'
SELECT check_name, categoria, status, valor_atual, threshold, detalhes
FROM gold.vw_data_quality_summary
ORDER BY CASE status WHEN 'WARN' THEN 0 WHEN 'INFO' THEN 1 ELSE 2 END, check_name;

-- ---------------------------------------------------------------------------
-- [07.3] Cards de contagem (DAX: Unresolved Agent Aliases / Client Bridge,
--   Trades/Tx Sem Cliente, Operações Sem Ativo, Trades Suspeitos).
-- ---------------------------------------------------------------------------
\echo '[07.3] Contagens de qualidade:'
SELECT
    (SELECT COUNT(*) FROM gold.vw_unresolved_agent_alias)      AS aliases_sem_match,
    (SELECT COUNT(*) FROM gold.vw_unresolved_client_bridge)    AS bridge_nao_resolvido,
    (SELECT COUNT(*) FROM gold.fato_operacao WHERE _eh_suspeito) AS trades_suspeitos,
    (SELECT COUNT(*) FROM gold.fato_operacao WHERE cliente_sk IS NULL) AS trades_sem_cliente,
    (SELECT COUNT(*) FROM gold.fato_movimentacao_financeira WHERE cliente_sk IS NULL) AS tx_sem_cliente,
    (SELECT COUNT(*) FROM gold.fato_operacao
       WHERE eh_operacao_mercado AND ativo_sk IS NULL)         AS operacoes_sem_ativo;

-- ---------------------------------------------------------------------------
-- [07.4] % clientes sem agente resolvido (esperado alto na base PRD)
-- ---------------------------------------------------------------------------
\echo '[07.4] % clientes sem agente resolvido:'
SELECT
    COUNT(*)                                                       AS total_clientes,
    COUNT(*) FILTER (WHERE _agente_quality <> 'resolved')          AS sem_agente,
    ROUND(COUNT(*) FILTER (WHERE _agente_quality <> 'resolved')*100.0
          / NULLIF(COUNT(*),0), 2)                                AS pct_sem_agente
FROM gold.dim_cliente;
