-- >>> LEGADO (2026-06-02) ----------------------------------------------------
-- Substituído pela arquitetura config/domain via .xlsx. Feriados agora vêm da aba
--   holiday_exception de artefatos/config_templates/brokerlab_config_calendar.xlsx
--   -> scripts/load_config_domain_templates.py -> bd/config/config_domain_template_ddl.sql
-- Mantido como baseline histórico/fallback. NÃO executar junto com o loader .xlsx.
-- Ver wiki/topics/plano-config-domain-xlsx.md.
-- ----------------------------------------------------------------------------
-- =============================================================================
-- config_update_holidays.sql — Atualiza feriados do calendário conforme lista
-- do cliente (BrokerLab)
-- Criado: 2026-05-18
-- Depende de: config_seed_calendar.sql já executado
--
-- Feriados a adicionar/manter:
--   01/Jan  — Confraternização Universal (já existia)
--   Sexta-feira Santa — feriado móvel, calculado via algoritmo de Gauss
--   01/Mai  — Dia do Trabalho (NOVO)
--   25/Mai  — Dia da Revolução de 25 de Maio (NOVO)
--   09/Jul  — Revolução Constitucionalista de 1932 (NOVO)
--   25/Dez  — Natal (já existia)
--
-- ATENÇÃO: remove Boxing Day (26/Dez) que estava no seed original mas não
-- está na lista do cliente.
--
-- Após marcar os feriados, recomputa:
--   is_business_day, business_day_number_in_month,
--   business_days_in_month, remaining_business_days_in_month
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Etapa 1: função auxiliar para calcular Páscoa (algoritmo Gregoriano)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.easter_sunday(p_year INT) RETURNS DATE AS $$
DECLARE
    a INT := p_year % 19;
    b INT := p_year / 100;
    c INT := p_year % 100;
    d INT := b / 4;
    e INT := b % 4;
    f INT := (b + 8) / 25;
    g INT := (b - f + 1) / 3;
    h INT := (19 * a + b - d - g + 15) % 30;
    i INT := c / 4;
    k INT := c % 4;
    l INT := (32 + 2 * e + 2 * i - h - k) % 7;
    m INT := (a + 11 * h + 22 * l) / 451;
    v_month INT := (h + l - 7 * m + 114) / 31;
    v_day   INT := ((h + l - 7 * m + 114) % 31) + 1;
BEGIN
    RETURN MAKE_DATE(p_year, v_month, v_day);
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Etapa 2: resetar todos os feriados existentes (recomeçar limpo)
-- is_business_day deve ser atualizado junto para satisfazer chk_business_day
-- ---------------------------------------------------------------------------
UPDATE config.business_calendar
SET is_global_holiday = FALSE,
    holiday_name      = NULL,
    is_business_day   = NOT is_weekend;  -- recalcula provisoriamente

-- ---------------------------------------------------------------------------
-- Etapa 3: marcar feriados fixos (todos os anos 2020-2035)
-- ---------------------------------------------------------------------------

-- 01 de Janeiro — Confraternização Universal
UPDATE config.business_calendar
SET is_global_holiday = TRUE,
    holiday_name      = 'Confraternização Universal',
    is_business_day   = FALSE
WHERE EXTRACT(MONTH FROM date) = 1
  AND EXTRACT(DAY   FROM date) = 1;

-- 01 de Maio — Dia do Trabalho
UPDATE config.business_calendar
SET is_global_holiday = TRUE,
    holiday_name      = 'Dia do Trabalho',
    is_business_day   = FALSE
WHERE EXTRACT(MONTH FROM date) = 5
  AND EXTRACT(DAY   FROM date) = 1;

-- 25 de Maio — Dia da Revolução de 25 de Maio
UPDATE config.business_calendar
SET is_global_holiday = TRUE,
    holiday_name      = 'Dia da Revolução de 25 de Maio',
    is_business_day   = FALSE
WHERE EXTRACT(MONTH FROM date) = 5
  AND EXTRACT(DAY   FROM date) = 25;

-- 09 de Julho — Revolução Constitucionalista de 1932
UPDATE config.business_calendar
SET is_global_holiday = TRUE,
    holiday_name      = 'Revolução Constitucionalista de 1932',
    is_business_day   = FALSE
WHERE EXTRACT(MONTH FROM date) = 7
  AND EXTRACT(DAY   FROM date) = 9;

-- 25 de Dezembro — Natal
UPDATE config.business_calendar
SET is_global_holiday = TRUE,
    holiday_name      = 'Natal',
    is_business_day   = FALSE
WHERE EXTRACT(MONTH FROM date) = 12
  AND EXTRACT(DAY   FROM date) = 25;

-- ---------------------------------------------------------------------------
-- Etapa 4: marcar Sexta-feira Santa (feriado móvel: Páscoa − 2 dias)
-- ---------------------------------------------------------------------------
UPDATE config.business_calendar bc
SET is_global_holiday = TRUE,
    holiday_name      = 'Sexta-feira Santa',
    is_business_day   = FALSE
FROM (
    SELECT pg_temp.easter_sunday(y) - INTERVAL '2 days' AS gf_date
    FROM generate_series(2020, 2035) y
) gf
WHERE bc.date = gf.gf_date::date;

-- ---------------------------------------------------------------------------
-- Etapa 5 (removida — is_business_day já foi mantido consistente acima)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Etapa 6: recomputar campos de contagem de dias úteis por mês
-- ---------------------------------------------------------------------------
WITH
-- ordinal do dia útil dentro do mês + total por mês em uma única passagem
computed AS (
    SELECT
        date,
        is_business_day,
        CASE WHEN is_business_day
             THEN ROW_NUMBER() OVER (
                    PARTITION BY year, month
                    ORDER BY date
                  )::SMALLINT
             ELSE NULL
        END AS bday_num,
        COUNT(*) FILTER (WHERE is_business_day)
            OVER (PARTITION BY year, month)::SMALLINT AS bdays_total
    FROM config.business_calendar
)
UPDATE config.business_calendar bc
SET
    business_day_number_in_month       = c.bday_num,
    business_days_in_month             = c.bdays_total,
    remaining_business_days_in_month   =
        CASE WHEN c.is_business_day
             THEN (c.bdays_total - c.bday_num)::SMALLINT
             ELSE NULL
        END
FROM computed c
WHERE bc.date = c.date;

-- ---------------------------------------------------------------------------
-- Verificação
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    v_total  INTEGER;
    v_bdays  INTEGER;
    v_hdays  INTEGER;
BEGIN
    SELECT COUNT(*),
           COUNT(*) FILTER (WHERE is_business_day),
           COUNT(*) FILTER (WHERE is_global_holiday)
    INTO v_total, v_bdays, v_hdays
    FROM config.business_calendar;

    RAISE NOTICE 'business_calendar atualizado: % datas | % dias úteis | % feriados',
        v_total, v_bdays, v_hdays;
END $$;

-- Amostra dos feriados cadastrados (um por ano)
SELECT
    EXTRACT(YEAR FROM date)::INT AS ano,
    TO_CHAR(date, 'DD/MM')      AS data,
    holiday_name
FROM config.business_calendar
WHERE is_global_holiday = TRUE
ORDER BY ano, date
LIMIT 50;

COMMIT;
