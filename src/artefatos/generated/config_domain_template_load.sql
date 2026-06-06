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

BEGIN;
INSERT INTO config_import.load_batch (source_kind, template_dir, executed_by, completed_at, status, notes)
VALUES ('local_excel', '/Users/arthurnariz/Developer/tcc-dashboard-brokerlab/artefatos/config_templates', 'arthurnariz', NOW(), 'completed', 'Loaded by scripts/load_config_domain_templates.py');

INSERT INTO domain.dom_lead_status (codigo, descricao, categoria, eh_terminal, is_active, source_file, reviewed_by, notes) VALUES
(100000031, 'Reshuffle', 'Operacional', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Categoria provisoria mantida por ser operacional; revisar com cliente se entra no funil ou fica separado.'),
(100000041, 'Busy- Can''t talk', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000011, 'Cross Lead', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000015, 'Low Potential - Callback', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000022, 'No Interested - No Money', 'Perdido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente perdido/final.'),
(100000016, 'Never answered', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000027, 'Reassign', 'Operacional', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Categoria provisoria mantida por ser operacional; revisar com cliente se entra no funil ou fica separado.'),
(100000037, 'Wrong Language', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000030, 'Refer', 'Operacional', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Categoria provisoria mantida por ser operacional; revisar com cliente se entra no funil ou fica separado.'),
(100000002, 'Callback', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000034, 'Voicemail', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000032, 'Test', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000046, 'Asked Info', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000039, 'Wrong Person', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000013, 'Invalid Country', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(5, 'Interested', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(4, 'No Answer', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000012, 'Hung up the phone', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000036, 'Wrong Campaign', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000043, 'Talk In Progress', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000018, 'No Answer 2', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000019, 'No Answer 3', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000025, 'Not Workable', 'Perdido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente perdido/final.'),
(100000009, 'Duplicate', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000040, 'Telemarketing', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000045, 'Medium Potential CB', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000023, 'No line', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000026, 'PSP Failure', 'Operacional', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Categoria provisoria mantida por ser operacional; revisar com cliente se entra no funil ou fica separado.'),
(100000042, 'Call Again', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(1, 'New', 'Novo', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente novo.'),
(100000000, 'New1', 'Novo', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente novo.'),
(100000017, 'No Answer 1', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000008, 'Doesn''t Have Money', 'Perdido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente perdido/final.'),
(100000010, 'Fake Details', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000020, 'No Answer 4', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000004, 'Calling', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(2, 'Not Interested', 'Perdido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente perdido/final.'),
(100000038, 'Wrong Number', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000003, 'Callback - Reshuffle', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(3, 'Wrong Info', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000033, 'Under Age', 'Inválido', TRUE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente invalido/final.'),
(100000044, 'Low Money', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000014, 'Low Potential', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.'),
(100000021, 'No Answer 5', 'Em prospecção', FALSE, TRUE, 'brokerlab_domain_crm.xlsx', NULL, 'Classificacao provisoria mantida por ser claramente status de follow-up/prospeccao.');
INSERT INTO domain.dom_payment_method (codigo, nome_inferido, payment_channel, eh_oficial, is_active, source_file, reviewed_by, notes) VALUES
(100000013, 'Custom 13', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(100000006, 'Custom 6', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(100000019, 'Custom 19', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(13, 'Crypto?', 'crypto', FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Nome inferido mantido por ser obvio; confirmar oficial com cliente/CRM.'),
(100000015, 'Custom 15', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(100000014, 'Custom 14', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(100000011, 'Custom 11', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(1, 'Wire Transfer', 'wire', FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Nome inferido mantido por ser obvio; confirmar oficial com cliente/CRM.'),
(100000020, 'Custom 20', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(100000005, 'Boleto?', 'boleto', FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Nome inferido mantido por ser obvio; confirmar oficial com cliente/CRM.'),
(100000010, 'Custom 10', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(100000012, 'Custom 12', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(100000002, 'PIX', 'instant', FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Nome inferido mantido por ser obvio; confirmar oficial com cliente/CRM.'),
(100000017, 'Custom 17', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(100000000, 'Custom 1', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(100000004, 'Custom 4', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(2, 'Credit Card', 'card', FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Nome inferido mantido por ser obvio; confirmar oficial com cliente/CRM.'),
(100000016, 'Custom 16', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.'),
(3, 'Desconhecido 3', NULL, FALSE, TRUE, 'brokerlab_domain_finance.xlsx', NULL, 'Sem confirmacao. Deixar em branco e revisar posteriormente com cliente/CRM.');
INSERT INTO domain.dom_currency (currency_guid, iso_code, nome, is_active, source_file, notes) VALUES
('1DC17FC1-AF04-F011-9699-005056B16E94', 'EUR', 'Euro', TRUE, 'brokerlab_domain_finance.xlsx', NULL),
('27BEAC42-6BF5-F011-9133-005056B1FEFC', 'TRY', 'Lira Turca', TRUE, 'brokerlab_domain_finance.xlsx', NULL),
('BDB50AD4-A204-F011-9135-005056B1E25D', 'USD', 'Dólar Americano', TRUE, 'brokerlab_domain_finance.xlsx', NULL);
INSERT INTO config.agent_profile (agent_key, agent_name, agent_email, team_name, agent_level, seniority, agent_type, is_active, started_on, ended_on, source_file, notes) VALUES
('alessio_ferri', 'Alessio Ferri', NULL, 'Italy', 'inter', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Fake'),
('angelo_costa', 'Angelo Costa', NULL, 'Italy', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('arthur_moreau', 'Arthur Moreau', NULL, 'Brazil', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('beatriz_mariano', 'Beatriz Mariano', NULL, 'Brazil', 'pro', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('benjamin_castelli', 'Benjamin Castelli', NULL, 'Europe', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('brian_lima', 'Brian Lima', NULL, 'Brazil', 'pro', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('caio_beltrao', 'Caio Beltrão', NULL, 'Brazil', 'pro', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('can_sezgin', 'Can Sezgin', NULL, 'Turkey', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('charles_miller', 'Charles Miller', NULL, 'Retention', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('charlie_kanthawong', 'Charlie Kanthawong', NULL, 'Brazil', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('daniel_hutin', 'Daniel Hutin', NULL, 'France', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('daniela_academy', 'Daniela Academy', NULL, 'Brazil', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('ece_aydin', 'Ece Aydin', NULL, 'Turkey', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('eric_laurent', 'Eric Laurent', NULL, 'France', 'pro', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Fake'),
('fatih_tufekci', 'Fatih Tufekci', NULL, 'Turkey', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('felix_schneider', 'Felix Schneider', NULL, 'Brazil', 'trainee', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('gerard_chaulet', 'Gerard Chaulet', NULL, 'France', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('ilker_meric', 'Ilker Meric', NULL, 'Turkey', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('james_lago', 'James Lago', NULL, 'Retention', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('julien_pinelli', 'Julien Pinelli', NULL, 'France', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('kaan_yilmaz', 'Kaan Yilmaz', NULL, 'Turkey', 'trainee', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Fake'),
('katherine_escobar', 'Katherine Escobar', NULL, 'Retention', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('kevin_liu', 'Kevin Liu', NULL, 'Asia', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('lorenzo_masi', 'Lorenzo Masi', NULL, 'Italy', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('lucas_leoni', 'Lucas Leoni', NULL, 'Italy', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('magnus_schulz', 'Magnus Schulz', NULL, 'Europe', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('massimo_abate', 'Massimo Abate', NULL, 'Italy', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('mel_salazar', 'Mel Salazar', NULL, 'Brazil', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('mickael_vian', 'Mickael Vian', NULL, 'France', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('miguel_santoro', 'Miguel Santoro', NULL, 'Brazil', 'inter', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('pierre_beltran', 'Pierre Beltran', NULL, 'France', 'inter', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('pool', 'Pool', NULL, 'Pool', NULL, NULL, 'pool', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('rafaela_miranda', 'Rafaela Miranda', NULL, 'Brazil', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('refund', 'REFUND', NULL, 'System', NULL, NULL, 'system', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('richard_bremont', 'Richard Bremont', NULL, 'France', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('samuel_davis', 'Samuel Davis', NULL, 'Brazil', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('santiago_jeronimo', 'Santiago Jeronimo', NULL, 'Brazil', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('stephane_augier', 'Stephane Augier', NULL, 'France', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('test_deposit', 'TEST DEPOSIT', NULL, 'System', NULL, NULL, 'system', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('tommaso_soleri', 'Tommaso Soleri', NULL, 'Italy', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', NULL),
('atena_moraes', 'Atena Moraes', NULL, 'Brazil', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('ricardo_campos', 'Ricardo Campos', NULL, 'Brazil', NULL, NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Reconstruido conforme regra da sessao: ativo Brazil quando veio do arquivo do cliente ou tinha level conhecido.'),
('romana', 'Romana', NULL, 'Brazil', 'pro', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Level conhecido; nome completo pendente de validacao do cliente.'),
('antoni', 'Antoni', NULL, 'Brazil', 'pro', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Level conhecido; nome completo pendente de validacao do cliente.'),
('maia', 'Maia Fernandes', NULL, 'Brazil', 'trainee', NULL, 'individual', TRUE, NULL, NULL, 'brokerlab_config_agents.xlsx', 'Nome completo Maia Fernandes observado no arquivo do cliente; level trainee mantido.');
INSERT INTO config.agent_alias (agent_id, source_system, alias_name, normalized_alias, is_primary, is_active, source_file, notes)
SELECT ap.agent_id, 'CRM', 'Samuel Davis', LOWER(TRIM(unaccent('Samuel Davis'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'samuel_davis'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Inactive Italy Clients', LOWER(TRIM(unaccent('Inactive Italy Clients'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Inactive France Clients', LOWER(TRIM(unaccent('Inactive France Clients'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'James Lago', LOWER(TRIM(unaccent('James Lago'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'james_lago'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Alessio Ferri', LOWER(TRIM(unaccent('Alessio Ferri'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'alessio_ferri'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Angelo Costa', LOWER(TRIM(unaccent('Angelo Costa'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'angelo_costa'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Beatriz Mariano', LOWER(TRIM(unaccent('Beatriz Mariano'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'beatriz_mariano'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Brian Lima', LOWER(TRIM(unaccent('Brian Lima'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'brian_lima'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Mickael Vian', LOWER(TRIM(unaccent('Mickael Vian'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'mickael_vian'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Felix Schneider', LOWER(TRIM(unaccent('Felix Schneider'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'felix_schneider'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Caio Beltrao', LOWER(TRIM(unaccent('Caio Beltrao'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'caio_beltrao'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Julien Pinelli', LOWER(TRIM(unaccent('Julien Pinelli'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'julien_pinelli'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Miguel Santoro', LOWER(TRIM(unaccent('Miguel Santoro'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'miguel_santoro'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Massimo Abate', LOWER(TRIM(unaccent('Massimo Abate'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'massimo_abate'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Charles Miller', LOWER(TRIM(unaccent('Charles Miller'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'charles_miller'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Arthur Moreau', LOWER(TRIM(unaccent('Arthur Moreau'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'arthur_moreau'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Richard Bremont', LOWER(TRIM(unaccent('Richard Bremont'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'richard_bremont'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Eric Laurent', LOWER(TRIM(unaccent('Eric Laurent'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'eric_laurent'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Ece Aydin', LOWER(TRIM(unaccent('Ece Aydin'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'ece_aydin'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Europe Retention ITA', LOWER(TRIM(unaccent('Europe Retention ITA'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Kaan Yilmaz', LOWER(TRIM(unaccent('Kaan Yilmaz'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'kaan_yilmaz'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Katherine Escobar', LOWER(TRIM(unaccent('Katherine Escobar'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'katherine_escobar'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Rafaela Miranda', LOWER(TRIM(unaccent('Rafaela Miranda'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'rafaela_miranda'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Ilker Meric', LOWER(TRIM(unaccent('Ilker Meric'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'ilker_meric'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Stephane Augier', LOWER(TRIM(unaccent('Stephane Augier'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'stephane_augier'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Lucas Leoni', LOWER(TRIM(unaccent('Lucas Leoni'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'lucas_leoni'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Europe Retention FR', LOWER(TRIM(unaccent('Europe Retention FR'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Magnus Schulz', LOWER(TRIM(unaccent('Magnus Schulz'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'magnus_schulz'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Daniel Hutin', LOWER(TRIM(unaccent('Daniel Hutin'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'daniel_hutin'
UNION ALL
SELECT ap.agent_id, 'CRM', 'xBenjamin Castelli', LOWER(TRIM(unaccent('xBenjamin Castelli'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'benjamin_castelli'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Gerard Chaulet', LOWER(TRIM(unaccent('Gerard Chaulet'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'gerard_chaulet'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Asia Ret MS', LOWER(TRIM(unaccent('Asia Ret MS'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Kevin Liu', LOWER(TRIM(unaccent('Kevin Liu'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'kevin_liu'
UNION ALL
SELECT ap.agent_id, 'CRM', 'xTommaso Soleri', LOWER(TRIM(unaccent('xTommaso Soleri'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'tommaso_soleri'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Brazil Retention PT', LOWER(TRIM(unaccent('Brazil Retention PT'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Asia Ret ZH', LOWER(TRIM(unaccent('Asia Ret ZH'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'REFUND REFUND', LOWER(TRIM(unaccent('REFUND REFUND'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'refund'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Asia Ret EN', LOWER(TRIM(unaccent('Asia Ret EN'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'xDaniela Academy', LOWER(TRIM(unaccent('xDaniela Academy'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'daniela_academy'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Brazil Conversion PT', LOWER(TRIM(unaccent('Brazil Conversion PT'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Pierre Beltran', LOWER(TRIM(unaccent('Pierre Beltran'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pierre_beltran'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Santiago Jeronimo', LOWER(TRIM(unaccent('Santiago Jeronimo'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'santiago_jeronimo'
UNION ALL
SELECT ap.agent_id, 'CRM', 'TEST DEPOSIT TEST', LOWER(TRIM(unaccent('TEST DEPOSIT TEST'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'test_deposit'
UNION ALL
SELECT ap.agent_id, 'CRM', 'XCan Sezgin', LOWER(TRIM(unaccent('XCan Sezgin'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'can_sezgin'
UNION ALL
SELECT ap.agent_id, 'CRM', 'AcademiesGroup Brazil Conversion Owner', LOWER(TRIM(unaccent('AcademiesGroup Brazil Conversion Owner'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'pool'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Charlie Kanthawong', LOWER(TRIM(unaccent('Charlie Kanthawong'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'charlie_kanthawong'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Fatih Tufekci', LOWER(TRIM(unaccent('Fatih Tufekci'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'fatih_tufekci'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Lorenzo Masi', LOWER(TRIM(unaccent('Lorenzo Masi'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'lorenzo_masi'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Mel Salazar', LOWER(TRIM(unaccent('Mel Salazar'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', NULL FROM config.agent_profile ap WHERE ap.agent_key = 'mel_salazar'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Atena Moraes', LOWER(TRIM(unaccent('Atena Moraes'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'atena_moraes'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Ricardo Campos', LOWER(TRIM(unaccent('Ricardo Campos'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'ricardo_campos'
UNION ALL
SELECT ap.agent_id, 'MANUAL', 'Romana', LOWER(TRIM(unaccent('Romana'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'romana'
UNION ALL
SELECT ap.agent_id, 'MANUAL', 'Antoni', LOWER(TRIM(unaccent('Antoni'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'antoni'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Maia Fernandes', LOWER(TRIM(unaccent('Maia Fernandes'))), TRUE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias canonico reconstruido conforme regra da sessao.' FROM config.agent_profile ap WHERE ap.agent_key = 'maia'
UNION ALL
SELECT ap.agent_id, 'MANUAL', 'Maia', LOWER(TRIM(unaccent('Maia'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias curto mantido para compatibilidade.' FROM config.agent_profile ap WHERE ap.agent_key = 'maia'
UNION ALL
SELECT ap.agent_id, 'CRM', 'Atena Morais', LOWER(TRIM(unaccent('Atena Morais'))), FALSE, TRUE, 'brokerlab_config_agents.xlsx', 'Alias alternativo observado no DASHBOARD PRINCIPAL (1).xlsx.' FROM config.agent_profile ap WHERE ap.agent_key = 'atena_moraes';

CREATE TEMP TABLE base_calendar AS
SELECT
    d::date AS date,
    TO_CHAR(d, 'YYYYMMDD')::integer AS date_sk,
    EXTRACT(YEAR FROM d)::smallint AS year,
    EXTRACT(QUARTER FROM d)::smallint AS quarter,
    EXTRACT(MONTH FROM d)::smallint AS month,
    DATE_TRUNC('month', d)::date AS month_start_date,
    EXTRACT(DAY FROM d)::smallint AS day_of_month,
    EXTRACT(ISODOW FROM d)::smallint AS day_of_week,
    TO_CHAR(d, 'FMDay') AS day_name,
    (EXTRACT(ISODOW FROM d) IN (6,7)) AS is_weekend,
    (
        TO_CHAR(d, 'MM-DD') IN ('01-01','12-25','12-26')
    ) AS is_global_holiday,
    CASE TO_CHAR(d, 'MM-DD')
        WHEN '01-01' THEN 'New Year'
        WHEN '12-25' THEN 'Christmas'
        WHEN '12-26' THEN 'Boxing Day'
        ELSE NULL
    END AS holiday_name,
    NOT (EXTRACT(ISODOW FROM d) IN (6,7) OR TO_CHAR(d, 'MM-DD') IN ('01-01','12-25','12-26')) AS is_business_day,
    NULL::varchar(255) AS source_file,
    NULL::text AS notes
FROM generate_series('2020-01-01'::date, '2035-12-31'::date, '1 day') d;

UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2020-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2020-04-10';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2020-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2020-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2020-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2020-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2021-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2021-04-02';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2021-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2021-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2021-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2021-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2022-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2022-04-15';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2022-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2022-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2022-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2022-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2023-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2023-04-07';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2023-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2023-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2023-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2023-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2024-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2024-03-29';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2024-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2024-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2024-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2024-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2025-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2025-04-18';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2025-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2025-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2025-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2025-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2026-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2026-04-03';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2026-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2026-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2026-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2026-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2027-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2027-03-26';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2027-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2027-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2027-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2027-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2028-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2028-04-14';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2028-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2028-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2028-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2028-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2029-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2029-03-30';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2029-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2029-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2029-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2029-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2030-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2030-04-19';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2030-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2030-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2030-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2030-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2031-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2031-04-11';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2031-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2031-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2031-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2031-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2032-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2032-03-26';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2032-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2032-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2032-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2032-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2033-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2033-04-15';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2033-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2033-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2033-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2033-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2034-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2034-04-07';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2034-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2034-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2034-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2034-12-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Confraternização Universal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2035-01-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Sexta-feira Santa', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2035-03-23';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia do Trabalho', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2035-05-01';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Dia da Revolução de 25 de Maio', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2035-05-25';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Revolução Constitucionalista de 1932', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2035-07-09';
UPDATE base_calendar SET is_global_holiday = TRUE, holiday_name = 'Natal', is_business_day = is_business_day, source_file = 'brokerlab_config_calendar.xlsx', notes = NULL WHERE date = '2035-12-25';

INSERT INTO config.business_calendar (
    date, date_sk, year, quarter, month, month_start_date, day_of_month, day_of_week,
    day_name, is_weekend, is_global_holiday, holiday_name, is_business_day,
    business_day_number_in_month, business_days_in_month, remaining_business_days_in_month,
    source_file, notes
)
SELECT
    date,
    date_sk,
    year,
    quarter,
    month,
    month_start_date,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend,
    is_global_holiday,
    holiday_name,
    is_business_day,
    CASE WHEN is_business_day THEN business_day_seq ELSE NULL END AS business_day_number_in_month,
    business_days_in_month,
    CASE WHEN is_business_day THEN business_days_in_month - business_day_seq ELSE NULL END AS remaining_business_days_in_month,
    source_file,
    notes
FROM (
    SELECT
        b.*,
        COUNT(*) FILTER (WHERE is_business_day) OVER (
            PARTITION BY month_start_date ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )::smallint AS business_day_seq,
        COUNT(*) FILTER (WHERE is_business_day) OVER (
            PARTITION BY month_start_date
        )::smallint AS business_days_in_month
    FROM base_calendar b
) x
ORDER BY date;

DROP TABLE base_calendar;

INSERT INTO config.asset_catalog (sirix_symbol, normalized_symbol, display_name, asset_class, base_currency, quote_currency, contract_size, tick_size, tick_value, volume_multiplier, provider, provider_symbol, is_major_asset, is_active, classification_status, source_file, notes) VALUES
('AGRIC', 'agric', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ALUMINUM', 'aluminum', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COCOA-JUL26', 'cocoa-jul26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COCOA-MAY26', 'cocoa-may26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COFFEE-DEC25', 'coffee-dec25', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COFFEE-JUL26', 'coffee-jul26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COFFEE-MAR26', 'coffee-mar26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COFFEE-MAY26', 'coffee-may26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COPP-DEC25', 'copp-dec25', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COPP-MAR26', 'copp-mar26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COPP-MAY26', 'copp-may26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COPPER', 'copper', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SBEAN-JAN26', 'sbean-jan26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SBEAN-MAR26', 'sbean-mar26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SBEAN-MAY26', 'sbean-may26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SBEAN-NOV25', 'sbean-nov25', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SUG11-JUL26', 'sug11-jul26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SUG11-MAR26', 'sug11-mar26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SUG11-MAY26', 'sug11-may26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('WHEAT-DEC25', 'wheat-dec25', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('WHEAT-MAR26', 'wheat-mar26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('WHEAT-MAY26', 'wheat-may26', NULL, 'commodity', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XAGEUR', 'xageur', NULL, 'commodity', 'XAG', NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XAGUSD', 'xagusd', 'Silver', 'commodity', 'XAG', 'USD', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('XAUEUR', 'xaueur', NULL, 'commodity', 'XAU', NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XAUUSD', 'xauusd', 'Gold', 'commodity', 'XAU', 'USD', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('XPDUSD', 'xpdusd', NULL, 'commodity', 'XPD', 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XPTUSD', 'xptusd', NULL, 'commodity', 'XPT', 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AAVEUSD.', 'aaveusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ADABTC.', 'adabtc.', NULL, 'crypto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ADAEUR.', 'adaeur.', NULL, 'crypto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ADAUSD.', 'adausd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ATOMUSD', 'atomusd', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BNBUSDT.', 'bnbusdt.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BTCEUR.', 'btceur.', NULL, 'crypto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BTCUSD.', 'btcusd.', 'Bitcoin', 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('CHZUSD.', 'chzusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('DASH', 'dash', NULL, 'crypto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('DASHEUR', 'dasheur', NULL, 'crypto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('DASHUSD', 'dashusd', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('DOTUSD.', 'dotusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EOSUSD.', 'eosusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ETCEUR.', 'etceur.', NULL, 'crypto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ETCUSD.', 'etcusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ETHUSD.', 'ethusd.', 'Ethereum', 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('FILUSD.', 'filusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('LINKBTC.', 'linkbtc.', NULL, 'crypto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('LINKUSD', 'linkusd', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('LTCEUR.', 'ltceur.', NULL, 'crypto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('LTCUSD.', 'ltcusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NEOBTC.', 'neobtc.', NULL, 'crypto', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NEOUSD.', 'neousd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SOLUSD.', 'solusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TRXUSD.', 'trxusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VETUSD.', 'vetusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XDGUSD.', 'xdgusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XRPUSD.', 'xrpusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XTZUSD.', 'xtzusd.', NULL, 'crypto', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BRENT-JUL26', 'brent-jul26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BRENT-JUN26', 'brent-jun26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BRENT-MAR26', 'brent-mar26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BRENT-MAY26', 'brent-may26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BRENTOIL.', 'brentoil.', 'Brent Oil', 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('HOIL-APR26', 'hoil-apr26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('HOIL-DEC25', 'hoil-dec25', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('HOIL-FEB26', 'hoil-feb26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('HOIL-JAN26', 'hoil-jan26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('HOIL-JUN26', 'hoil-jun26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('HOIL-MAR26', 'hoil-mar26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('HOIL-MAY26', 'hoil-may26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NGAS-APR26', 'ngas-apr26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NGAS-JUN26', 'ngas-jun26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NGAS-MAY26', 'ngas-may26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('RBOB-APR26', 'rbob-apr26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('RBOB-DEC25', 'rbob-dec25', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('RBOB-FEB26', 'rbob-feb26', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('UK_OIL.', 'uk_oil.', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('US_OIL.', 'us_oil.', NULL, 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('WTI.', 'wti.', 'WTI Crude Oil', 'energy', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('AUDCAD', 'audcad', NULL, 'forex', 'AUD', 'CAD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AUDCHF', 'audchf', NULL, 'forex', 'AUD', 'CHF', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AUDJPY', 'audjpy', NULL, 'forex', 'AUD', 'JPY', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AUDNZD', 'audnzd', NULL, 'forex', 'AUD', 'NZD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AUDUSD', 'audusd', 'AUD/USD', 'forex', 'AUD', 'USD', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('CADCHF', 'cadchf', NULL, 'forex', 'CAD', 'CHF', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CADJPY', 'cadjpy', NULL, 'forex', 'CAD', 'JPY', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CHFJPY', 'chfjpy', NULL, 'forex', 'CHF', 'JPY', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURAUD', 'euraud', NULL, 'forex', 'EUR', 'AUD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURCAD', 'eurcad', NULL, 'forex', 'EUR', 'CAD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURCHF', 'eurchf', NULL, 'forex', 'EUR', 'CHF', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURCZK', 'eurczk', NULL, 'forex', 'EUR', 'CZK', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURDKK', 'eurdkk', NULL, 'forex', 'EUR', 'DKK', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURGBP', 'eurgbp', NULL, 'forex', 'EUR', 'GBP', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURHUF', 'eurhuf', NULL, 'forex', 'EUR', 'HUF', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURILS', 'eurils', NULL, 'forex', 'EUR', 'ILS', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURJPY', 'eurjpy', NULL, 'forex', 'EUR', 'JPY', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURNOK', 'eurnok', NULL, 'forex', 'EUR', 'NOK', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURNZD', 'eurnzd', NULL, 'forex', 'EUR', 'NZD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURPLN', 'eurpln', NULL, 'forex', 'EUR', 'PLN', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURTRY', 'eurtry', NULL, 'forex', 'EUR', 'TRY', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EURUSD', 'eurusd', 'EUR/USD', 'forex', 'EUR', 'USD', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('GBPAUD', 'gbpaud', NULL, 'forex', 'GBP', 'AUD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GBPCAD', 'gbpcad', NULL, 'forex', 'GBP', 'CAD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GBPCHF', 'gbpchf', NULL, 'forex', 'GBP', 'CHF', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GBPJPY', 'gbpjpy', NULL, 'forex', 'GBP', 'JPY', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GBPNZD', 'gbpnzd', NULL, 'forex', 'GBP', 'NZD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GBPUSD', 'gbpusd', 'GBP/USD', 'forex', 'GBP', 'USD', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('GBPZAR', 'gbpzar', NULL, 'forex', 'GBP', 'ZAR', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NZDCAD', 'nzdcad', NULL, 'forex', 'NZD', 'CAD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NZDCHF', 'nzdchf', NULL, 'forex', 'NZD', 'CHF', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NZDJPY', 'nzdjpy', NULL, 'forex', 'NZD', 'JPY', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NZDUSD', 'nzdusd', 'NZD/USD', 'forex', 'NZD', 'USD', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('USDBRL', 'usdbrl', NULL, 'forex', 'USD', 'BRL', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDCAD', 'usdcad', 'USD/CAD', 'forex', 'USD', 'CAD', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('USDCHF', 'usdchf', 'USD/CHF', 'forex', 'USD', 'CHF', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('USDCNH', 'usdcnh', NULL, 'forex', 'USD', 'CNH', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDCZK', 'usdczk', NULL, 'forex', 'USD', 'CZK', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDDKK', 'usddkk', NULL, 'forex', 'USD', 'DKK', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDHKD', 'usdhkd', NULL, 'forex', 'USD', 'HKD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDHUF', 'usdhuf', NULL, 'forex', 'USD', 'HUF', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDILS', 'usdils', NULL, 'forex', 'USD', 'ILS', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDJPY', 'usdjpy', 'USD/JPY', 'forex', 'USD', 'JPY', NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('USDMXN', 'usdmxn', NULL, 'forex', 'USD', 'MXN', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDNOK', 'usdnok', NULL, 'forex', 'USD', 'NOK', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDPLN', 'usdpln', NULL, 'forex', 'USD', 'PLN', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDRUB', 'usdrub', NULL, 'forex', 'USD', 'RUB', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDSEK', 'usdsek', NULL, 'forex', 'USD', 'SEK', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDSGD', 'usdsgd', NULL, 'forex', 'USD', 'SGD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDTRY', 'usdtry', NULL, 'forex', 'USD', 'TRY', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USDZAR', 'usdzar', NULL, 'forex', 'USD', 'ZAR', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ZARJPY', 'zarjpy', NULL, 'forex', 'ZAR', 'JPY', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AEX-APR26', 'aex-apr26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AEX-DEC25', 'aex-dec25', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AEX-FEB26', 'aex-feb26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AEX-JAN26', 'aex-jan26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AEX-MAR26', 'aex-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AEX-MAY26', 'aex-may26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AEX-NOV25', 'aex-nov25', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BIST30', 'bist30', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CAC-APR26', 'cac-apr26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CL-APR26', 'cl-apr26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CL-FEB26', 'cl-feb26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CORN-MAY26', 'corn-may26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COTT2-JUL26', 'cott2-jul26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COTT2-MAY26', 'cott2-may26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('FRA40.', 'fra40.', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('FTSE100.', 'ftse100.', 'FTSE 100', 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('GER40.', 'ger40.', 'DAX 40', 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('HANG-MAR26', 'hang-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('IBEX-JAN26', 'ibex-jan26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('IBEX-MAR26', 'ibex-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('IBEX-MAY26', 'ibex-may26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NIKKEI225.', 'nikkei225.', 'Nikkei 225', 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('NK-DEC25', 'nk-dec25', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NK-JUN26', 'nk-jun26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NK-MAR26', 'nk-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NQ100.', 'nq100.', 'Nasdaq 100', 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('PLAT-APR26', 'plat-apr26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PLAT-JUL26', 'plat-jul26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('RICE-MAY26', 'rice-may26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('RUSS-DEC25', 'russ-dec25', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('RUSS-JUN26', 'russ-jun26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('RUSS-MAR26', 'russ-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SPMIB-DEC25', 'spmib-dec25', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SPMIB-JUN26', 'spmib-jun26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SPMIB-MAR26', 'spmib-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SPX500.', 'spx500.', 'S&P 500', 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', 'Display name preenchido por ser ativo obvio/principal.'),
('TOPIX-DEC25', 'topix-dec25', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TOPIX-JUN26', 'topix-jun26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TOPIX-MAR26', 'topix-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('USNDX-MAR26', 'usndx-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VIX-APR26', 'vix-apr26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VIX-DEC25', 'vix-dec25', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VIX-FEB26', 'vix-feb26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VIX-JAN26', 'vix-jan26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VIX-MAR26', 'vix-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VIX-MAY26', 'vix-may26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VIX-NOV25', 'vix-nov25', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('WS30.', 'ws30.', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XINHUA50-MAR26', 'xinhua50-mar26', NULL, 'index', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AAL', 'aal', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ABB', 'abb', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ABBOT', 'abbot', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ABNB', 'abnb', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ACCOR', 'accor', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ACKERMANS', 'ackermans', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ADBE', 'adbe', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ADIDAS', 'adidas', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AGEAS', 'ageas', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AGHOL-IST', 'aghol-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AIR', 'air', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AIRBUS', 'airbus', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AIRBUS-XET', 'airbus-xet', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AKFGY-IST', 'akfgy-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ALCOA', 'alcoa', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ALIBABA', 'alibaba', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ALKIM-IST', 'alkim-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ALLI', 'alli', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ALSTOM', 'alstom', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ALTGR', 'altgr', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AMAZON.', 'amazon.', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AMD', 'amd', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AMEX', 'amex', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AMGEN', 'amgen', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ANELE-IST', 'anele-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('APPLE', 'apple', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('APTUSD.', 'aptusd.', NULL, 'stock', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ARENA-IST', 'arena-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ASELS-IST', 'asels-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ATEKS-IST', 'ateks-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ATSYH-IST', 'atsyh-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AVGO', 'avgo', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AXA', 'axa', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('AZN-LON', 'azn-lon', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BAHKM-IST', 'bahkm-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BAIDU', 'baidu', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BAKAB-IST', 'bakab-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BASGZ-IST', 'basgz-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BAYER', 'bayer', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BBRY', 'bbry', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BBVA', 'bbva', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BCHEUR.', 'bcheur.', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BCHUSD.', 'bchusd.', NULL, 'stock', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BFREN-IST', 'bfren-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BIMAS-IST', 'bimas-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BJKAS-IST', 'bjkas-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BMW', 'bmw', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BNTX', 'bntx', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BOA', 'boa', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BOEING', 'boeing', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BRKVY-IST', 'brkvy-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BUCIM-IST', 'bucim-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BUD', 'bud', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BURCE-IST', 'burce-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BURVA-IST', 'burva-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('BYND', 'bynd', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CAP', 'cap', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CATER', 'cater', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CELHA-IST', 'celha-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CGC', 'cgc', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CHEVRON', 'chevron', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CISCO', 'cisco', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('CITI', 'citi', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COIN', 'coin', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('COKE', 'coke', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('DAIM', 'daim', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('DISNEY', 'disney', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('DJXX50', 'djxx50', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('DOGUB-IST', 'dogub-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EA', 'ea', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EBAY', 'ebay', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EGGUB-IST', 'eggub-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EGPRO-IST', 'egpro-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EMKEL-IST', 'emkel-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ENDAE-IST', 'endae-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EUPWR-IST', 'eupwr-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('EXXM', 'exxm', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('FACEBOOK', 'facebook', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('FENER-IST', 'fener-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('FERRARI', 'ferrari', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('FVRR', 'fvrr', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GARAN-ISE', 'garan-ise', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GAUTRY', 'gautry', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GAUUSD', 'gauusd', NULL, 'stock', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GEREL-IST', 'gerel-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GESAN-IST', 'gesan-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GM', 'gm', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GOOGLE.', 'google.', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GPRO', 'gpro', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GS', 'gs', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GSRAY-IST', 'gsray-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('GZNMI-IST', 'gznmi-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('HOG', 'hog', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('HOOD', 'hood', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('HOROZ-IST', 'horoz-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('IBM', 'ibm', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('IHLAS-IST', 'ihlas-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('INTEL', 'intel', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('INTESA', 'intesa', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('IOTUSD.', 'iotusd.', NULL, 'stock', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('JPM', 'jpm', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('KAPLM-IST', 'kaplm-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('KLRHO-IST', 'klrho-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('KONTR-IST', 'kontr-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('KOZAA-IST', 'kozaa-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('KRDMA-IST', 'krdma-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('KTSKR-IST', 'ktskr-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('LMT', 'lmt', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('LUFTHANSA', 'lufthansa', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('LVMH', 'lvmh', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('MANAS-IST', 'manas-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('MCARD', 'mcard', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('MCDON', 'mcdon', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('MELI', 'meli', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('METRO', 'metro', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('MICRON', 'micron', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('MORSTAN', 'morstan', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('MRNA', 'mrna', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('MSFT', 'msft', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NETFLIX.', 'netflix.', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NIKE', 'nike', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NIO', 'nio', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NOKIA', 'nokia', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NTGAZ-IST', 'ntgaz-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NUHCM-IST', 'nuhcm-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NVAX', 'nvax', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('NVIDIA.', 'nvidia.', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ORACLE', 'oracle', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('OZATD-IST', 'ozatd-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PAYPAL', 'paypal', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PDBC', 'pdbc', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PETKM-ISE', 'petkm-ise', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PETR4', 'petr4', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PFIZER', 'pfizer', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PG', 'pg', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PKENT-IST', 'pkent-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('POLHO-IST', 'polho-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PRKME-IST', 'prkme-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('PRZMA-IST', 'przma-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('REPSOL', 'repsol', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('RODRG-IST', 'rodrg-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SASA-IST', 'sasa-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SCHNEIDER', 'schneider', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SMCI', 'smci', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SONY', 'sony', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('SPOT', 'spot', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('STARBUCKS', 'starbucks', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TCELL-IST', 'tcell-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TOTAL', 'total', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TOYOTA', 'toyota', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TSLA.', 'tsla.', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, TRUE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TSM', 'tsm', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TSPOR-IST', 'tspor-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('TUPRS', 'tuprs', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('UBER', 'uber', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('UFUK-IST', 'ufuk-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('UNIUSD.', 'uniusd.', NULL, 'stock', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VAKBN-IST', 'vakbn-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VESTL', 'vestl', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VISA', 'visa', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VOWGEN', 'vowgen', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('VUG', 'vug', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('WMART.', 'wmart.', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XEMBTC.', 'xembtc.', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XLMUSD.', 'xlmusd.', NULL, 'stock', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('XNGUSD.', 'xngusd.', NULL, 'stock', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ZECUSD.', 'zecusd.', NULL, 'stock', NULL, 'USD', NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ZINC', 'zinc', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ZOREN-IST', 'zoren-ist', NULL, 'stock', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, TRUE, 'inferred', 'brokerlab_config_assets.xlsx', NULL),
('ZEROING', 'zeroing', NULL, 'unknown', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, FALSE, FALSE, 'manual', 'brokerlab_config_assets.xlsx', 'Simbolo tecnico de ajuste Sirix. Sem valor analitico.');
INSERT INTO config.agent_target_month (competence_month, agent_id, target_deposit_month_usd, target_trade_day, target_trade_month, target_unique_month, target_volume_month, target_volume_unit, source_type, source_file, approved_by, is_active, created_by, notes)
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'samuel_davis'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'james_lago'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'alessio_ferri'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'angelo_costa'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026.' FROM config.agent_profile ap WHERE ap.agent_key = 'beatriz_mariano'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 40000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026.' FROM config.agent_profile ap WHERE ap.agent_key = 'brian_lima'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'mickael_vian'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 20000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026.' FROM config.agent_profile ap WHERE ap.agent_key = 'felix_schneider'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 40000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026.' FROM config.agent_profile ap WHERE ap.agent_key = 'caio_beltrao'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'julien_pinelli'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026.' FROM config.agent_profile ap WHERE ap.agent_key = 'miguel_santoro'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'massimo_abate'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'charles_miller'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026.' FROM config.agent_profile ap WHERE ap.agent_key = 'arthur_moreau'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'richard_bremont'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'eric_laurent'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 50000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'ece_aydin'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'kaan_yilmaz'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'katherine_escobar'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 40000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026.' FROM config.agent_profile ap WHERE ap.agent_key = 'rafaela_miranda'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'ilker_meric'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'stephane_augier'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'lucas_leoni'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'magnus_schulz'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'daniel_hutin'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'benjamin_castelli'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'gerard_chaulet'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'kevin_liu'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'tommaso_soleri'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'daniela_academy'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'pierre_beltran'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'santiago_jeronimo'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'can_sezgin'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'charlie_kanthawong'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'fatih_tufekci'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'lorenzo_masi'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'valor fake' FROM config.agent_profile ap WHERE ap.agent_key = 'mel_salazar'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 30000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026. O dashboard escreve Atena Morais; agent_key mantido conforme template de agentes.' FROM config.agent_profile ap WHERE ap.agent_key = 'atena_moraes'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 20000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026.' FROM config.agent_profile ap WHERE ap.agent_key = 'ricardo_campos'
UNION ALL
SELECT '2026-04-01'::date, ap.agent_id, 1000, 0, NULL::integer, 0, NULL::numeric, NULL, 'template', 'brokerlab_config_targets.xlsx', NULL, TRUE, 'arthurnariz', 'Preenchido a partir do arquivo do cliente DASHBOARD PRINCIPAL (1).xlsx - abril/2026.' FROM config.agent_profile ap WHERE ap.agent_key = 'pool';
COMMIT;
