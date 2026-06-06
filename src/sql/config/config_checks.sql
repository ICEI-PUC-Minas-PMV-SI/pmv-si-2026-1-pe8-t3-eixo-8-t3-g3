-- =============================================================================
-- config_checks.sql — Validações pós-carga do schema config
-- Criado: 2026-05-12
-- Executar após todos os seeds. Resultado esperado: 0 linhas em cada check bloqueante.
-- =============================================================================

\echo '=== CONFIG CHECKS ==='

-- ---------------------------------------------------------------------------
-- [C1] Agente ativo (individual) sem alias primário no CRM
-- Bloqueante: todo agente ativo precisa ter alias para resolver retention_owner_name
-- ---------------------------------------------------------------------------
\echo '[C1] Agentes ativos sem alias primario CRM:'
SELECT ap.agent_id, ap.agent_name, ap.team_name
FROM config.agent_profile ap
WHERE ap.is_active = TRUE
  AND ap.agent_type = 'individual'
  AND NOT EXISTS (
    SELECT 1 FROM config.agent_alias aa
    WHERE aa.agent_id = ap.agent_id
      AND aa.source_system = 'CRM'
      AND aa.is_primary = TRUE
  )
ORDER BY ap.agent_name;

-- ---------------------------------------------------------------------------
-- [C2] Alias duplicado: mesmo normalized_alias + source_system → mais de 1 agente
-- Bloqueante: causaria resolução ambígua em gold.dim_cliente
-- ---------------------------------------------------------------------------
\echo '[C2] Aliases duplicados (mesmo texto, agentes diferentes):'
SELECT aa.normalized_alias, aa.source_system, COUNT(DISTINCT aa.agent_id) AS agents
FROM config.agent_alias aa
GROUP BY aa.normalized_alias, aa.source_system
HAVING COUNT(DISTINCT aa.agent_id) > 1
ORDER BY aa.normalized_alias;

-- ---------------------------------------------------------------------------
-- [C3] Meta ativa duplicada (mais de uma linha ativa por agente/mês)
-- Bloqueante: quebraria joins 1:1 em gold.fato_meta_agente_mes
-- ---------------------------------------------------------------------------
\echo '[C3] Metas ativas duplicadas por agente/mes:'
SELECT t.competence_month, t.agent_id, ap.agent_name, COUNT(*) AS linhas
FROM config.agent_target_month t
JOIN config.agent_profile ap ON ap.agent_id = t.agent_id
WHERE t.is_active = TRUE
GROUP BY t.competence_month, t.agent_id, ap.agent_name
HAVING COUNT(*) > 1
ORDER BY t.competence_month, ap.agent_name;

-- ---------------------------------------------------------------------------
-- [C4] Metas negativas
-- Bloqueante: inválido por constraint, mas verificar se chegou algum
-- ---------------------------------------------------------------------------
\echo '[C4] Metas com valor negativo:'
SELECT t.target_month_id, ap.agent_name, t.competence_month,
       t.target_deposit_month_usd, t.target_trade_day, t.target_unique_month
FROM config.agent_target_month t
JOIN config.agent_profile ap ON ap.agent_id = t.agent_id
WHERE t.target_deposit_month_usd < 0
   OR t.target_trade_day < 0
   OR t.target_unique_month < 0;

-- ---------------------------------------------------------------------------
-- [C5] Meses sem dias úteis no calendário
-- Bloqueante: causaria divisão por zero em run rate
-- ---------------------------------------------------------------------------
\echo '[C5] Meses sem dias uteis:'
SELECT year, month, COUNT(*) FILTER (WHERE is_business_day) AS business_days
FROM config.business_calendar
GROUP BY year, month
HAVING COUNT(*) FILTER (WHERE is_business_day) = 0
ORDER BY year, month;

-- ---------------------------------------------------------------------------
-- [C6] Datas duplicadas no calendário
-- ---------------------------------------------------------------------------
\echo '[C6] Datas duplicadas no calendario:'
SELECT date, COUNT(*) FROM config.business_calendar GROUP BY date HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------------
-- [C7] Símbolos de trade mercado sem catálogo
-- Warning: degradação de dim_ativo; não bloqueante no MVP mas documentar
-- ---------------------------------------------------------------------------
\echo '[C7] Simbolos de trade CMD 0/1 sem entrada no asset_catalog:'
SELECT DISTINCT t.symbol_key
FROM silver.trade_clean t
WHERE t.eh_operacao_mercado = TRUE
  AND t.symbol_key IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM config.asset_catalog a
    WHERE a.sirix_symbol = t.symbol_key
  )
ORDER BY t.symbol_key;

-- ---------------------------------------------------------------------------
-- [C8] Retention owners do CRM sem alias
-- Warning: clientes com esses owners não terão agente resolvido em gold
-- ---------------------------------------------------------------------------
\echo '[C8] Retention owner names sem alias CRM (nao resolvidos em gold):'
SELECT DISTINCT ac.retention_owner_name, COUNT(*) AS clientes
FROM silver.account_clean ac
WHERE ac.retention_owner_name IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM config.agent_alias aa
    WHERE aa.normalized_alias = LOWER(TRIM(ac.retention_owner_name))
      AND aa.source_system = 'CRM'
  )
GROUP BY ac.retention_owner_name
ORDER BY clientes DESC;

-- ---------------------------------------------------------------------------
-- Resumo de contagens
-- ---------------------------------------------------------------------------
\echo '[SUMMARY] Contagens config:'
SELECT
    (SELECT COUNT(*) FROM config.agent_profile)                                          AS agent_profiles,
    (SELECT COUNT(*) FROM config.agent_profile WHERE is_active AND agent_type='individual') AS agents_ativos,
    (SELECT COUNT(*) FROM config.agent_alias)                                            AS aliases,
    (SELECT COUNT(*) FROM config.business_calendar)                                      AS dias_calendario,
    (SELECT COUNT(*) FILTER (WHERE is_business_day) FROM config.business_calendar)      AS dias_uteis,
    (SELECT COUNT(*) FROM config.asset_catalog)                                          AS ativos,
    (SELECT COUNT(*) FROM config.agent_target_month WHERE is_active)                     AS metas_ativas;
