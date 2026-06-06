-- >>> LEGADO (2026-06-02) ----------------------------------------------------
-- Substituído pela arquitetura config/domain via .xlsx. Fonte de verdade agora:
--   artefatos/config_templates/brokerlab_config_targets.xlsx
--   -> scripts/load_config_domain_templates.py -> bd/config/config_domain_template_ddl.sql
-- Mantido como baseline histórico/fallback. NÃO executar junto com o loader .xlsx
-- (ambos populam config.agent_target_month e conflitam).
-- Ver wiki/topics/plano-config-domain-xlsx.md.
-- ----------------------------------------------------------------------------
-- =============================================================================
-- config_seed_targets.sql — Metas reais por agente/mês (Política 2026)
-- Atualizado: 2026-05-26
-- Depende de: config_ddl.sql, config_seed_agents.sql, config_seed_calendar.sql
--
-- Targets por nível (validados pelo cliente em 2026-05-26):
--   Nível   | deposit_month | trade_day | unique_day
--   --------|---------------|-----------|----------
--   pro     |    60.000 USD |        22 |        16
--   inter   |    40.000 USD |        22 |        16
--   trainee |    20.000 USD |        10 |         6
--   NULL    |    50.000 USD |         5 |        10  ← default para agentes sem nível definido
--
-- target_unique_month = unique_day × business_days_in_month (varia por mês)
-- target_trade_month  = NULL → derivado em gold como trade_day × business_days_in_month
--
-- Meses cobertos: 2025-03 a 2026-05 (alinhado com silver.transaction_clean)
-- ATENÇÃO: agentes sem agent_level recebem defaults genéricos. Atualizar agent_profile
--          com o nível correto para que os targets sejam recalculados.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Desativar todos os registros anteriores (MVP defaults e versões antigas)
-- ---------------------------------------------------------------------------
UPDATE config.agent_target_month
SET    is_active = FALSE
WHERE  is_active = TRUE;

-- ---------------------------------------------------------------------------
-- 2. Inserir targets reais por nível, com unique calculado pelo calendário
-- ---------------------------------------------------------------------------
INSERT INTO config.agent_target_month (
    competence_month,
    agent_id,
    target_deposit_month_usd,
    target_trade_day,
    target_trade_month,
    target_unique_month,
    source_type,
    is_active,
    notes
)
SELECT
    m.competence_month,
    ap.agent_id,

    -- Meta de depósito líquido mensal
    CASE ap.agent_level
        WHEN 'pro'     THEN 60000.00
        WHEN 'inter'   THEN 40000.00
        WHEN 'trainee' THEN 20000.00
        ELSE                50000.00   -- default para agentes sem nível
    END                                             AS target_deposit_month_usd,

    -- Meta diária de clientes operando (1º trade do cliente no dia)
    CASE ap.agent_level
        WHEN 'pro'     THEN 22
        WHEN 'inter'   THEN 22
        WHEN 'trainee' THEN 10
        ELSE                 5         -- default
    END                                             AS target_trade_day,

    NULL                                            AS target_trade_month,  -- derivado em gold

    -- Meta mensal de unique = taxa diária × dias úteis do mês
    CASE ap.agent_level
        WHEN 'pro'     THEN 16 * cal.business_days_in_month
        WHEN 'inter'   THEN 16 * cal.business_days_in_month
        WHEN 'trainee' THEN  6 * cal.business_days_in_month
        ELSE                10         -- default fixo para sem nível
    END                                             AS target_unique_month,

    CASE
        WHEN ap.agent_level IS NOT NULL THEN 'manual'
        ELSE                                 'manual_default'
    END                                             AS source_type,

    TRUE                                            AS is_active,

    CASE ap.agent_level
        WHEN 'pro'     THEN 'Política 2026 — PRO: deposit=60k, trade=22/dia, unique=16×dias_uteis'
        WHEN 'inter'   THEN 'Política 2026 — INTER: deposit=40k, trade=22/dia, unique=16×dias_uteis'
        WHEN 'trainee' THEN 'Política 2026 — TRAINEE: deposit=20k, trade=10/dia, unique=6×dias_uteis'
        ELSE                'Default MVP — agente sem nível definido em agent_profile'
    END                                             AS notes

FROM
    -- Meses com dados em silver.transaction_clean (2025-03 a 2026-05)
    (VALUES
        ('2025-03-01'::date),
        ('2025-04-01'::date),
        ('2025-08-01'::date),
        ('2025-09-01'::date),
        ('2025-10-01'::date),
        ('2025-11-01'::date),
        ('2025-12-01'::date),
        ('2026-01-01'::date),
        ('2026-02-01'::date),
        ('2026-03-01'::date),
        ('2026-04-01'::date),
        ('2026-05-01'::date)
    ) AS m(competence_month)

    CROSS JOIN (
        SELECT agent_id, agent_level
        FROM   config.agent_profile
        WHERE  agent_type = 'individual'
        AND    is_active  = TRUE
    ) ap

    -- Dias úteis do mês: basta 1 linha por mês (business_days_in_month é fixo por mês)
    JOIN (
        SELECT DISTINCT month_start_date, business_days_in_month
        FROM   config.business_calendar
    ) cal ON cal.month_start_date = m.competence_month;

-- ---------------------------------------------------------------------------
-- 3. Verificação pós-carga
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v_total   INTEGER;
    v_agents  INTEGER;
    v_months  INTEGER;
    v_leveled INTEGER;
BEGIN
    SELECT
        COUNT(*),
        COUNT(DISTINCT agent_id),
        COUNT(DISTINCT competence_month),
        COUNT(*) FILTER (WHERE source_type = 'manual')
    INTO v_total, v_agents, v_months, v_leveled
    FROM config.agent_target_month
    WHERE is_active = TRUE;

    RAISE NOTICE '=== agent_target_month recarregado ===';
    RAISE NOTICE '  Total linhas ativas : %', v_total;
    RAISE NOTICE '  Agentes             : %', v_agents;
    RAISE NOTICE '  Meses               : %', v_months;
    RAISE NOTICE '  Com nível real      : % | Sem nível (default): %', v_leveled, v_total - v_leveled;
    RAISE NOTICE '======================================';
END $$;

COMMIT;
