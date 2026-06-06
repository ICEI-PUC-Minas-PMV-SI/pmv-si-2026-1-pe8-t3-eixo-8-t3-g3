-- =============================================================================
-- gold_load_dimensions.sql — Carga das 4 dimensões gold
-- Criado: 2026-05-12
-- Depende de: gold_ddl.sql, config seeds, silver populada
-- Ordem obrigatória: dim_tempo → dim_agente → dim_ativo → dim_cliente
-- Estratégia inicial: full refresh (TRUNCATE + INSERT)
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. dim_tempo — de config.business_calendar
-- ---------------------------------------------------------------------------
\echo '>> Carregando gold.dim_tempo...'

TRUNCATE gold.dim_tempo CASCADE;

INSERT INTO gold.dim_tempo (
    tempo_sk, date, year, quarter, month, month_start_date,
    year_month, day_of_month, day_of_week, day_name,
    is_weekend, is_business_day, is_global_holiday, holiday_name,
    business_day_number_in_month, business_days_in_month,
    remaining_business_days_in_month, _loaded_at
)
SELECT
    bc.date_sk,
    bc.date,
    bc.year,
    bc.quarter,
    bc.month,
    bc.month_start_date,
    TO_CHAR(bc.date, 'YYYY-MM'),
    bc.day_of_month,
    bc.day_of_week,
    bc.day_name,
    bc.is_weekend,
    bc.is_business_day,
    bc.is_global_holiday,
    bc.holiday_name,
    bc.business_day_number_in_month,
    bc.business_days_in_month,
    bc.remaining_business_days_in_month,
    NOW()
FROM config.business_calendar bc
ORDER BY bc.date;

DO $$
DECLARE v INTEGER;
BEGIN
    SELECT COUNT(*) INTO v FROM gold.dim_tempo;
    RAISE NOTICE 'dim_tempo: % linhas', v;
END $$;

-- ---------------------------------------------------------------------------
-- 2. dim_agente — de config.agent_profile + silver.user_clean (enriquecimento)
-- ---------------------------------------------------------------------------
\echo '>> Carregando gold.dim_agente...'

TRUNCATE gold.dim_agente CASCADE;

INSERT INTO gold.dim_agente (
    agent_id, agent_name, agent_email, team_name, agent_level, seniority,
    agent_type, is_active, started_on, ended_on,
    crm_full_name, _loaded_at
)
SELECT
    ap.agent_id,
    ap.agent_name,
    COALESCE(ap.agent_email, uc.email),
    ap.team_name,
    ap.agent_level,
    ap.seniority,
    ap.agent_type,
    ap.is_active,
    ap.started_on,
    ap.ended_on,
    uc.full_name  AS crm_full_name,
    NOW()
FROM config.agent_profile ap
LEFT JOIN LATERAL (
    SELECT email, full_name
    FROM silver.user_clean
    WHERE LOWER(TRIM(full_name)) = LOWER(TRIM(ap.agent_name))
    ORDER BY is_disabled ASC, full_name
    LIMIT 1
) uc ON TRUE
ORDER BY ap.agent_id;

DO $$
DECLARE v INTEGER;
BEGIN
    SELECT COUNT(*) INTO v FROM gold.dim_agente;
    RAISE NOTICE 'dim_agente: % linhas', v;
END $$;

-- ---------------------------------------------------------------------------
-- 3. dim_ativo — de config.asset_catalog
-- ---------------------------------------------------------------------------
\echo '>> Carregando gold.dim_ativo...'

TRUNCATE gold.dim_ativo CASCADE;

INSERT INTO gold.dim_ativo (
    asset_id, sirix_symbol, normalized_symbol, display_name,
    asset_class, base_currency, quote_currency,
    is_major_asset, is_active, classification_status, _loaded_at
)
SELECT
    ac.asset_id,
    ac.sirix_symbol,
    ac.normalized_symbol,
    ac.display_name,
    ac.asset_class,
    ac.base_currency,
    ac.quote_currency,
    ac.is_major_asset,
    ac.is_active,
    ac.classification_status,
    NOW()
FROM config.asset_catalog ac
ORDER BY ac.asset_id;

DO $$
DECLARE v INTEGER;
BEGIN
    SELECT COUNT(*) INTO v FROM gold.dim_ativo;
    RAISE NOTICE 'dim_ativo: % linhas', v;
END $$;

-- ---------------------------------------------------------------------------
-- 4. dim_cliente — de silver.vw_account_bridge + resolução de agente
-- ---------------------------------------------------------------------------
\echo '>> Carregando gold.dim_cliente...'

TRUNCATE gold.dim_cliente CASCADE;

INSERT INTO gold.dim_cliente (
    crm_account_id, tp_account_id, sirix_login,
    cliente_nome, country, language_iso,
    lead_status_code, lead_status_text, lead_status_categoria,
    has_ftd,
    retention_owner_name, conversion_owner_name,
    agent_rule_used, agent_id_current, agente_sk_current,
    balance, equity, margin_level, last_activity_date,
    eh_habilitada, eh_readonly, eh_deletada,
    bridge_quality_status, _agente_quality, _loaded_at
)
SELECT
    b.crm_account_id,
    b.tp_account_id,
    b.sirix_login,
    b.cliente_nome,
    b.country,
    b.language_iso,
    b.lead_status_code,
    b.lead_status_text,
    b.lead_status_categoria,
    b.has_ftd,
    b.retention_owner_name,
    b.conversion_owner_name,
    'retention_owner'                           AS agent_rule_used,
    ap.agent_id                                 AS agent_id_current,
    da.agente_sk                                AS agente_sk_current,
    -- snapshot de balance: preferir sirix_account_clean, fallback tpaccount
    COALESCE(b.sirix_balance,  b.balance_usd)   AS balance,
    COALESCE(b.sirix_equity,   b.equity)        AS equity,
    COALESCE(b.sirix_margin_level, b.margin_level) AS margin_level,
    b.sirix_last_activity::date                 AS last_activity_date,
    b.sirix_eh_habilitada                       AS eh_habilitada,
    COALESCE(b.sirix_eh_readonly, b.eh_readonly) AS eh_readonly,
    b.eh_deletada,
    b.bridge_quality_status,
    CASE WHEN da.agente_sk IS NOT NULL THEN 'resolved' ELSE 'unresolved' END,
    NOW()
FROM silver.vw_account_bridge b
-- resolução de agente: normaliza retention_owner_name via config.agent_alias
LEFT JOIN config.agent_alias aa
    ON aa.normalized_alias = LOWER(TRIM(b.retention_owner_name))
    AND aa.source_system = 'CRM'
LEFT JOIN config.agent_profile ap
    ON ap.agent_id = aa.agent_id
LEFT JOIN gold.dim_agente da
    ON da.agent_id = ap.agent_id;

DO $$
DECLARE v_total INTEGER; v_resolved INTEGER; v_no_agent INTEGER;
BEGIN
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE _agente_quality = 'resolved'),
        COUNT(*) FILTER (WHERE agente_sk_current IS NULL)
    INTO v_total, v_resolved, v_no_agent
    FROM gold.dim_cliente;
    RAISE NOTICE 'dim_cliente: % linhas | % com agente resolvido | % sem agente', v_total, v_resolved, v_no_agent;
END $$;

COMMIT;
