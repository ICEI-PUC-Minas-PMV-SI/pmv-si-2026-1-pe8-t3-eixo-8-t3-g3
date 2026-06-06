-- =============================================================================
-- config_domain_template_ddl.sql
-- Rebuilds config/domain tables governed by local Excel templates.
-- Use with scripts/load_config_domain_templates.py.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS unaccent;

DROP SCHEMA IF EXISTS config CASCADE;
DROP SCHEMA IF EXISTS domain CASCADE;

CREATE SCHEMA config;
CREATE SCHEMA domain;
CREATE SCHEMA IF NOT EXISTS config_import;

COMMENT ON SCHEMA config IS 'Business configuration loaded from governed templates.';
COMMENT ON SCHEMA domain IS 'Canonical domain lookups loaded from governed templates and stable technical rules.';
COMMENT ON SCHEMA config_import IS 'Audit area for local/SharePoint configuration-template loads.';

CREATE TABLE IF NOT EXISTS config_import.load_batch (
    load_batch_id BIGSERIAL PRIMARY KEY,
    source_kind   VARCHAR(30) NOT NULL DEFAULT 'local_excel',
    template_dir  TEXT NOT NULL,
    executed_by   TEXT,
    started_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at  TIMESTAMP,
    status        VARCHAR(30) NOT NULL DEFAULT 'started',
    notes         TEXT
);

CREATE TABLE IF NOT EXISTS config_import.validation_error (
    validation_error_id BIGSERIAL PRIMARY KEY,
    load_batch_id       BIGINT REFERENCES config_import.load_batch(load_batch_id),
    severity            VARCHAR(20) NOT NULL,
    source_file         TEXT,
    sheet_name          TEXT,
    row_number          INTEGER,
    field_name          TEXT,
    message             TEXT NOT NULL,
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE domain.dom_lead_status (
    codigo      BIGINT PRIMARY KEY,
    descricao   VARCHAR(100) NOT NULL,
    categoria   VARCHAR(30) NOT NULL,
    eh_terminal BOOLEAN NOT NULL,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    source_file VARCHAR(255),
    reviewed_by VARCHAR(200),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    notes       TEXT,
    CONSTRAINT chk_lead_categoria CHECK (
        categoria IN ('Novo','Em prospecção','Perdido','Inválido','Operacional')
    )
);

CREATE TABLE domain.dom_cmd (
    codigo        INTEGER PRIMARY KEY,
    tipo          VARCHAR(20) NOT NULL,
    descricao     VARCHAR(100) NOT NULL,
    eh_trade      BOOLEAN NOT NULL,
    eh_financeiro BOOLEAN NOT NULL,
    eh_pendente   BOOLEAN NOT NULL,
    sinal         CHAR(1)
);

CREATE TABLE domain.dom_transaction_type (
    codigo           INTEGER PRIMARY KEY,
    nome             VARCHAR(80) NOT NULL,
    categoria        VARCHAR(30) NOT NULL,
    sinal_financeiro CHAR(1) NOT NULL
);

CREATE TABLE domain.dom_transaction_status (
    codigo      BIGINT PRIMARY KEY,
    descricao   VARCHAR(50) NOT NULL,
    eh_aprovado BOOLEAN NOT NULL
);

CREATE TABLE domain.dom_payment_method (
    codigo          BIGINT PRIMARY KEY,
    nome_inferido   VARCHAR(100),
    payment_channel VARCHAR(50),
    eh_oficial      BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    source_file     VARCHAR(255),
    reviewed_by     VARCHAR(200),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    notes           TEXT
);

CREATE TABLE domain.dom_currency (
    currency_guid VARCHAR(36) PRIMARY KEY,
    iso_code      VARCHAR(3) NOT NULL,
    nome          VARCHAR(50) NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    source_file   VARCHAR(255),
    updated_at    TIMESTAMP NOT NULL DEFAULT NOW(),
    notes         TEXT
);

INSERT INTO domain.dom_cmd VALUES
(0, 'OP_BUY',        'Compra a mercado (long)',                       TRUE,  FALSE, FALSE, '+'),
(1, 'OP_SELL',       'Venda a mercado (short)',                       TRUE,  FALSE, FALSE, '-'),
(2, 'OP_BUY_LIMIT',  'Ordem de compra pendente abaixo do mercado',    TRUE,  FALSE, TRUE,  '+'),
(3, 'OP_SELL_LIMIT', 'Ordem de venda pendente acima do mercado',      TRUE,  FALSE, TRUE,  '-'),
(4, 'OP_BUY_STOP',   'Ordem de compra pendente acima do mercado',     TRUE,  FALSE, TRUE,  '+'),
(5, 'OP_SELL_STOP',  'Ordem de venda pendente abaixo do mercado',     TRUE,  FALSE, TRUE,  '-'),
(6, 'OP_BALANCE',    'Movimentação de saldo (depósito/saque/taxa)',   FALSE, TRUE,  FALSE, '0'),
(7, 'OP_CREDIT',     'Crédito/bônus (concessão ou estorno)',          FALSE, TRUE,  FALSE, '0');

INSERT INTO domain.dom_transaction_type VALUES
(1,  'Deposit',                                             'Entrada',           '+'),
(2,  'Deposit Cancelled',                                   'Reversão',          '0'),
(5,  'Bonus',                                               'Bônus',             '+'),
(6,  'Bonus Cancelled',                                     'Reversão',          '0'),
(9,  'Withdrawal',                                          'Saída',             '-'),
(10, 'Withdrawal Cancelled',                                'Reversão',          '0'),
(13, 'Transfer Between Trading Platform Accounts',          'Transferência',     '0'),
(14, 'Transfer Between Trading Platform Accounts Cancelled', 'Reversão',          '0'),
(15, 'Credit',                                              'Crédito ajuste',    '+'),
(16, 'Credit Cancelled',                                    'Reversão',          '0'),
(17, 'Debit',                                               'Débito ajuste',     '-'),
(19, 'Inactivity Fee',                                      'Taxa',              '-');

INSERT INTO domain.dom_transaction_status VALUES
(100000000, 'Solicitada / Criada',     FALSE),
(100000001, 'Em análise / Pendente',   FALSE),
(100000002, 'Rejeitada',               FALSE),
(100000003, 'Aprovada / Concluída',    TRUE);

CREATE TABLE config.agent_profile (
    agent_id    BIGSERIAL PRIMARY KEY,
    agent_key   VARCHAR(100) NOT NULL UNIQUE,
    agent_name  VARCHAR(200) NOT NULL,
    agent_email VARCHAR(255),
    team_name   VARCHAR(100) NOT NULL,
    agent_level VARCHAR(20),
    seniority   VARCHAR(50),
    agent_type  VARCHAR(30) NOT NULL DEFAULT 'individual',
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    started_on  DATE,
    ended_on    DATE,
    source      VARCHAR(50) NOT NULL DEFAULT 'template',
    source_file VARCHAR(255),
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    notes       TEXT,
    CONSTRAINT chk_agent_type CHECK (agent_type IN ('individual','pool','system')),
    CONSTRAINT chk_agent_level CHECK (agent_level IN ('trainee','inter','pro') OR agent_level IS NULL),
    CONSTRAINT chk_seniority CHECK (seniority IN ('iniciante','intermediario','senior','manager') OR seniority IS NULL)
);

CREATE UNIQUE INDEX idx_cfg_agent_name_active
    ON config.agent_profile (LOWER(TRIM(agent_name)))
    WHERE is_active = TRUE AND agent_type = 'individual';

CREATE TABLE config.agent_alias (
    agent_alias_id   BIGSERIAL PRIMARY KEY,
    agent_id         BIGINT NOT NULL REFERENCES config.agent_profile(agent_id),
    source_system    VARCHAR(50) NOT NULL,
    alias_name       VARCHAR(200) NOT NULL,
    normalized_alias VARCHAR(200) NOT NULL,
    is_primary       BOOLEAN NOT NULL DEFAULT FALSE,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    source_file      VARCHAR(255),
    created_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    notes            TEXT,
    CONSTRAINT uq_agent_alias_normalized UNIQUE (normalized_alias, source_system)
);

CREATE TABLE config.business_calendar (
    date                             DATE PRIMARY KEY,
    date_sk                          INTEGER NOT NULL UNIQUE,
    year                             SMALLINT NOT NULL,
    quarter                          SMALLINT NOT NULL,
    month                            SMALLINT NOT NULL,
    month_start_date                 DATE NOT NULL,
    day_of_month                     SMALLINT NOT NULL,
    day_of_week                      SMALLINT NOT NULL,
    day_name                         VARCHAR(20) NOT NULL,
    is_weekend                       BOOLEAN NOT NULL,
    is_global_holiday                BOOLEAN NOT NULL DEFAULT FALSE,
    holiday_name                     VARCHAR(200),
    is_business_day                  BOOLEAN NOT NULL,
    business_day_number_in_month     SMALLINT,
    business_days_in_month           SMALLINT NOT NULL,
    remaining_business_days_in_month SMALLINT,
    source_file                      VARCHAR(255),
    notes                            TEXT
);

CREATE TABLE config.agent_target_month (
    target_month_id          BIGSERIAL PRIMARY KEY,
    competence_month         DATE NOT NULL,
    agent_id                 BIGINT NOT NULL REFERENCES config.agent_profile(agent_id),
    target_deposit_month_usd NUMERIC(15,2) NOT NULL DEFAULT 0,
    target_trade_day         INTEGER NOT NULL DEFAULT 0,
    target_trade_month       INTEGER,
    target_unique_month      INTEGER NOT NULL DEFAULT 0,
    target_volume_month      NUMERIC(20,4),
    target_volume_unit       VARCHAR(30),
    source_type              VARCHAR(50) NOT NULL DEFAULT 'template',
    source_file              VARCHAR(255),
    approved_by              VARCHAR(200),
    is_active                BOOLEAN NOT NULL DEFAULT TRUE,
    created_at               TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by               VARCHAR(200),
    notes                    TEXT,
    CONSTRAINT chk_competence_month CHECK (EXTRACT(DAY FROM competence_month) = 1),
    CONSTRAINT chk_target_positive CHECK (
        target_deposit_month_usd >= 0 AND
        target_trade_day >= 0 AND
        target_unique_month >= 0
    )
);

CREATE UNIQUE INDEX idx_cfg_target_active
    ON config.agent_target_month (competence_month, agent_id)
    WHERE is_active = TRUE;

CREATE TABLE config.asset_catalog (
    asset_id              BIGSERIAL PRIMARY KEY,
    sirix_symbol          VARCHAR(50) NOT NULL UNIQUE,
    normalized_symbol     VARCHAR(50) NOT NULL,
    display_name          VARCHAR(200),
    asset_class           VARCHAR(50) NOT NULL DEFAULT 'unknown',
    base_currency         VARCHAR(20),
    quote_currency        VARCHAR(20),
    contract_size         NUMERIC(20,8),
    tick_size             NUMERIC(20,8),
    tick_value            NUMERIC(20,8),
    volume_multiplier     NUMERIC(20,8),
    provider              VARCHAR(50),
    provider_symbol       VARCHAR(100),
    is_major_asset        BOOLEAN NOT NULL DEFAULT FALSE,
    is_active             BOOLEAN NOT NULL DEFAULT TRUE,
    classification_status VARCHAR(30) NOT NULL DEFAULT 'inferred',
    source_file           VARCHAR(255),
    created_at            TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMP NOT NULL DEFAULT NOW(),
    notes                 TEXT,
    CONSTRAINT chk_asset_class CHECK (
        asset_class IN ('forex','commodity','energy','index','stock','crypto','unknown'
    )),
    CONSTRAINT chk_class_status CHECK (
        classification_status IN ('inferred','manual','validated')
    )
);

COMMIT;
