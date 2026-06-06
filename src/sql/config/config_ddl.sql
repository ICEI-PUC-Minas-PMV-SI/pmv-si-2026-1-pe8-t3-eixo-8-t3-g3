-- >>> LEGADO (2026-06-02) ----------------------------------------------------
-- DDL do modelo antigo de config (manutenção manual via seeds). A arquitetura-alvo
-- é bd/config/config_domain_template_ddl.sql (recria config/domain + config_import)
-- governada por artefatos/config_templates/*.xlsx via scripts/load_config_domain_templates.py.
-- Mantido como baseline histórico/fallback. Ver wiki/topics/plano-config-domain-xlsx.md.
-- ----------------------------------------------------------------------------
-- =============================================================================
-- config_ddl.sql — Schema config: dados de negócio controlados manualmente
-- Criado: 2026-05-12
-- Depende de: nada (schema independente)
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS unaccent;

DROP SCHEMA IF EXISTS config CASCADE;
CREATE SCHEMA config;
COMMENT ON SCHEMA config IS 'Dados de negócio controlados manualmente: agentes, metas, calendário, ativos.';

-- ---------------------------------------------------------------------------
-- config.agent_profile — agente canônico da corretora
-- ---------------------------------------------------------------------------
CREATE TABLE config.agent_profile (
    agent_id        BIGSERIAL       PRIMARY KEY,
    agent_name      VARCHAR(200)    NOT NULL,
    agent_email     VARCHAR(255),
    team_name       VARCHAR(100)    NOT NULL,
    agent_level     VARCHAR(20),                -- trainee / inter / pro  (Política 2026)
    seniority       VARCHAR(50),                -- iniciante / intermediario / senior / manager
    agent_type      VARCHAR(30)     NOT NULL DEFAULT 'individual',  -- individual / pool / system
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    started_on      DATE,
    ended_on        DATE,
    source          VARCHAR(50)     NOT NULL DEFAULT 'manual',  -- manual / crm / excel
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    notes           TEXT,
    CONSTRAINT chk_agent_type  CHECK (agent_type IN ('individual', 'pool', 'system')),
    CONSTRAINT chk_agent_level CHECK (agent_level IN ('trainee','inter','pro') OR agent_level IS NULL),
    CONSTRAINT chk_seniority   CHECK (seniority IN ('iniciante','intermediario','senior','manager') OR seniority IS NULL)
);

CREATE UNIQUE INDEX idx_cfg_agent_name_active
    ON config.agent_profile (LOWER(TRIM(agent_name)))
    WHERE is_active = TRUE AND agent_type = 'individual';

COMMENT ON TABLE  config.agent_profile IS '1 linha por agente canônico. Fonte de verdade para dim_agente.';
COMMENT ON COLUMN config.agent_profile.agent_type IS 'individual=agente real; pool=fila/grupo; system=entidade técnica (REFUND, TEST).';

-- ---------------------------------------------------------------------------
-- config.agent_alias — mapeamento nome-fonte → agente canônico
-- ---------------------------------------------------------------------------
CREATE TABLE config.agent_alias (
    agent_alias_id  BIGSERIAL   PRIMARY KEY,
    agent_id        BIGINT      NOT NULL REFERENCES config.agent_profile(agent_id),
    source_system   VARCHAR(50) NOT NULL,   -- CRM / Excel / Manual
    alias_name      VARCHAR(200) NOT NULL,
    normalized_alias VARCHAR(200) NOT NULL, -- lower(trim(unaccent(alias_name)))
    is_primary      BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP   NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_agent_alias_normalized UNIQUE (normalized_alias, source_system)
);

COMMENT ON TABLE config.agent_alias IS '1 linha por alias textual por sistema-fonte. Todo retention_owner_name deve ter entrada aqui.';

-- ---------------------------------------------------------------------------
-- config.business_calendar — calendário de dias úteis
-- ---------------------------------------------------------------------------
CREATE TABLE config.business_calendar (
    date                            DATE        PRIMARY KEY,
    date_sk                         INTEGER     NOT NULL UNIQUE,    -- YYYYMMDD
    year                            SMALLINT    NOT NULL,
    quarter                         SMALLINT    NOT NULL,
    month                           SMALLINT    NOT NULL,
    month_start_date                DATE        NOT NULL,
    day_of_month                    SMALLINT    NOT NULL,
    day_of_week                     SMALLINT    NOT NULL,   -- 1=Mon ... 7=Sun (ISO)
    day_name                        VARCHAR(20) NOT NULL,
    is_weekend                      BOOLEAN     NOT NULL,
    is_global_holiday               BOOLEAN     NOT NULL DEFAULT FALSE,
    holiday_name                    VARCHAR(200),
    is_business_day                 BOOLEAN     NOT NULL,
    business_day_number_in_month    SMALLINT,   -- NULL para fins de semana/feriados
    business_days_in_month          SMALLINT    NOT NULL,
    remaining_business_days_in_month SMALLINT,  -- NULL para fins de semana/feriados
    CONSTRAINT chk_business_day CHECK (
        is_business_day = (NOT is_weekend AND NOT is_global_holiday)
    )
);

COMMENT ON TABLE  config.business_calendar IS '1 linha por data (2020-2035). Fonte para dim_tempo e cálculo de run rate.';
COMMENT ON COLUMN config.business_calendar.day_of_week IS 'ISO: 1=Segunda, 7=Domingo.';
COMMENT ON COLUMN config.business_calendar.is_global_holiday IS 'Feriado global cadastrado. Cadastráveis via UPDATE.';

-- ---------------------------------------------------------------------------
-- config.agent_target_month — metas mensais por agente
-- ---------------------------------------------------------------------------
CREATE TABLE config.agent_target_month (
    target_month_id             BIGSERIAL       PRIMARY KEY,
    competence_month            DATE            NOT NULL,   -- sempre primeiro dia do mês
    agent_id                    BIGINT          NOT NULL REFERENCES config.agent_profile(agent_id),
    target_deposit_month_usd    NUMERIC(15,2)   NOT NULL DEFAULT 0,
    target_trade_day            INTEGER         NOT NULL DEFAULT 0,
    target_trade_month          INTEGER,                    -- derivado se NULL: target_trade_day * business_days_in_month
    target_unique_month         INTEGER         NOT NULL DEFAULT 0,
    target_volume_month         NUMERIC(20,4),              -- futuro (lotes)
    target_volume_unit          VARCHAR(30),                -- lots / contracts / notional_usd
    source_type                 VARCHAR(50)     NOT NULL DEFAULT 'manual_default',
    source_file                 VARCHAR(255),
    approved_by                 VARCHAR(200),
    is_active                   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMP       NOT NULL DEFAULT NOW(),
    created_by                  VARCHAR(200),
    notes                       TEXT,
    CONSTRAINT chk_competence_month CHECK (EXTRACT(DAY FROM competence_month) = 1),
    CONSTRAINT chk_target_positive  CHECK (
        target_deposit_month_usd >= 0 AND
        target_trade_day >= 0 AND
        target_unique_month >= 0
    )
);

CREATE UNIQUE INDEX idx_cfg_target_active
    ON config.agent_target_month (competence_month, agent_id)
    WHERE is_active = TRUE;

COMMENT ON TABLE  config.agent_target_month IS '1 linha ativa por agente por mês. Suporta versionamento (is_active=FALSE para histórico).';
COMMENT ON COLUMN config.agent_target_month.competence_month IS 'Primeiro dia do mês de competência (ex: 2026-01-01).';

-- ---------------------------------------------------------------------------
-- config.asset_catalog — catálogo de símbolos Sirix
-- ---------------------------------------------------------------------------
CREATE TABLE config.asset_catalog (
    asset_id                BIGSERIAL       PRIMARY KEY,
    sirix_symbol            VARCHAR(50)     NOT NULL UNIQUE,
    normalized_symbol       VARCHAR(50)     NOT NULL,
    display_name            VARCHAR(200),
    asset_class             VARCHAR(50)     NOT NULL DEFAULT 'unknown',
    base_currency           VARCHAR(20),
    quote_currency          VARCHAR(20),
    contract_size           NUMERIC(20,8),  -- futuro (lote × contract_size = volume financeiro)
    tick_size               NUMERIC(20,8),  -- futuro
    tick_value              NUMERIC(20,8),  -- futuro
    volume_multiplier       NUMERIC(20,8),  -- futuro
    provider                VARCHAR(50),    -- API futura (TradingView, etc.)
    provider_symbol         VARCHAR(100),   -- símbolo no provedor externo
    is_major_asset          BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    classification_status   VARCHAR(30)     NOT NULL DEFAULT 'inferred',
    created_at              TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP       NOT NULL DEFAULT NOW(),
    notes                   TEXT,
    CONSTRAINT chk_asset_class  CHECK (asset_class IN (
        'forex','commodity','energy','index','stock','crypto','unknown'
    )),
    CONSTRAINT chk_class_status CHECK (classification_status IN (
        'inferred','manual','validated'
    ))
);

COMMENT ON TABLE  config.asset_catalog IS '1 linha por símbolo Sirix negociável. Fonte para dim_ativo.';
COMMENT ON COLUMN config.asset_catalog.asset_class IS 'forex|commodity|energy|index|stock|crypto|unknown.';
COMMENT ON COLUMN config.asset_catalog.classification_status IS 'inferred=regex automático; manual=revisado; validated=confirmado com cliente.';

COMMIT;
