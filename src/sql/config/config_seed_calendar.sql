-- >>> LEGADO (2026-06-02) ----------------------------------------------------
-- Substituído pela arquitetura config/domain via .xlsx. Fonte de verdade agora:
--   artefatos/config_templates/brokerlab_config_calendar.xlsx (aba holiday_exception)
--   -> scripts/load_config_domain_templates.py -> bd/config/config_domain_template_ddl.sql
-- Mantido como baseline histórico/fallback. NÃO executar junto com o loader .xlsx
-- (ambos populam config.business_calendar e conflitam).
-- Ver wiki/topics/plano-config-domain-xlsx.md.
-- ----------------------------------------------------------------------------
-- =============================================================================
-- config_seed_calendar.sql — Calendário de dias úteis 2020-2035
-- Criado: 2026-05-12
-- Depende de: config_ddl.sql executado
-- Regra: segunda a sexta, excluindo feriados globais cadastrados (Jan/01, Dez/25).
-- Para adicionar feriados: UPDATE config.business_calendar SET is_global_holiday=TRUE,
--   holiday_name='...' WHERE date = '...'; -- e recomputar is_business_day.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Etapa 1: gerar série de datas com campos básicos
-- ---------------------------------------------------------------------------
INSERT INTO config.business_calendar (
    date, date_sk, year, quarter, month, month_start_date,
    day_of_month, day_of_week, day_name,
    is_weekend, is_global_holiday, holiday_name, is_business_day,
    business_day_number_in_month, business_days_in_month,
    remaining_business_days_in_month
)
WITH

-- base: uma linha por data
serie AS (
    SELECT d::date AS dt
    FROM generate_series('2020-01-01'::date, '2035-12-31'::date, '1 day'::interval) d
),

-- feriados globais fixos: 01-01 e 25-12 de cada ano
-- Easter e outros feriados móveis devem ser adicionados manualmente após a carga
global_holidays AS (
    SELECT MAKE_DATE(y, 1,  1)  AS hdate, 'New Year''s Day'     AS hname
    FROM generate_series(2020, 2035) y
    UNION ALL
    SELECT MAKE_DATE(y, 12, 25), 'Christmas Day'
    FROM generate_series(2020, 2035) y
    UNION ALL
    SELECT MAKE_DATE(y, 12, 26), 'Boxing Day'
    FROM generate_series(2020, 2035) y
),

-- campos derivados por data
enriched AS (
    SELECT
        s.dt,
        TO_CHAR(s.dt, 'YYYYMMDD')::INTEGER                  AS date_sk,
        EXTRACT(YEAR    FROM s.dt)::SMALLINT                AS year,
        EXTRACT(QUARTER FROM s.dt)::SMALLINT                AS quarter,
        EXTRACT(MONTH   FROM s.dt)::SMALLINT                AS month,
        DATE_TRUNC('month', s.dt)::date                     AS month_start_date,
        EXTRACT(DAY     FROM s.dt)::SMALLINT                AS day_of_month,
        EXTRACT(ISODOW  FROM s.dt)::SMALLINT                AS day_of_week,  -- 1=Mon,7=Sun
        TO_CHAR(s.dt, 'Day')                                AS day_name,
        EXTRACT(ISODOW  FROM s.dt) IN (6,7)                 AS is_weekend,
        (g.hdate IS NOT NULL)                               AS is_global_holiday,
        g.hname                                             AS holiday_name
    FROM serie s
    LEFT JOIN global_holidays g ON g.hdate = s.dt
),

-- is_business_day
flagged AS (
    SELECT *,
        (NOT is_weekend AND NOT is_global_holiday) AS is_business_day
    FROM enriched
),

-- business_day ordinal dentro do mês (apenas para dias úteis)
ranked AS (
    SELECT *,
        CASE WHEN is_business_day
             THEN ROW_NUMBER() OVER (
                    PARTITION BY year, month
                    ORDER BY dt
                  )::SMALLINT
             ELSE NULL
        END AS business_day_number_in_month
    FROM flagged
),

-- total de dias úteis no mês (para todos os dias do mês)
month_totals AS (
    SELECT
        year, month,
        COUNT(*) FILTER (WHERE is_business_day)::SMALLINT AS business_days_in_month
    FROM ranked
    GROUP BY year, month
),

-- juntar tudo + calcular remaining
final AS (
    SELECT
        r.dt,
        r.date_sk,
        r.year,
        r.quarter,
        r.month,
        r.month_start_date,
        r.day_of_month,
        r.day_of_week,
        TRIM(r.day_name)        AS day_name,
        r.is_weekend,
        r.is_global_holiday,
        r.holiday_name,
        r.is_business_day,
        r.business_day_number_in_month,
        mt.business_days_in_month,
        CASE WHEN r.is_business_day
             THEN (mt.business_days_in_month - r.business_day_number_in_month)::SMALLINT
             ELSE NULL
        END AS remaining_business_days_in_month
    FROM ranked r
    JOIN month_totals mt ON mt.year = r.year AND mt.month = r.month
)

SELECT
    dt, date_sk, year, quarter, month, month_start_date,
    day_of_month, day_of_week, day_name,
    is_weekend, is_global_holiday, holiday_name, is_business_day,
    business_day_number_in_month, business_days_in_month,
    remaining_business_days_in_month
FROM final
ORDER BY dt;

-- ---------------------------------------------------------------------------
-- Verificação rápida após carga
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v_total  INTEGER;
    v_bdays  INTEGER;
    v_hdays  INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE is_business_day), COUNT(*) FILTER (WHERE is_global_holiday)
    INTO v_total, v_bdays, v_hdays
    FROM config.business_calendar;

    RAISE NOTICE 'business_calendar carregado: % datas | % dias úteis | % feriados globais',
        v_total, v_bdays, v_hdays;
END $$;

COMMIT;
