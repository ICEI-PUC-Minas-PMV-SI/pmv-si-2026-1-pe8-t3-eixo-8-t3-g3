-- =============================================================================
-- gold_ddl.sql — Schema gold: star schema para consumo Power BI
-- Criado: 2026-05-12
-- Depende de: config_ddl.sql + seeds executados
-- Ordem de criação: dim_tempo → dim_agente → dim_ativo → dim_cliente → fatos
-- =============================================================================

BEGIN;

DROP SCHEMA IF EXISTS gold CASCADE;
CREATE SCHEMA gold;
COMMENT ON SCHEMA gold IS 'Camada Gold: star schema modelado para Power BI (dims + fatos + views semânticas).';

-- ---------------------------------------------------------------------------
-- gold.dim_tempo — dimensão tempo (fonte: config.business_calendar)
-- ---------------------------------------------------------------------------
CREATE TABLE gold.dim_tempo (
    tempo_sk                        INTEGER     PRIMARY KEY,  -- YYYYMMDD
    date                            DATE        NOT NULL UNIQUE,
    year                            SMALLINT    NOT NULL,
    quarter                         SMALLINT    NOT NULL,
    month                           SMALLINT    NOT NULL,
    month_start_date                DATE        NOT NULL,
    year_month                      VARCHAR(7)  NOT NULL,   -- ex: '2026-03'
    day_of_month                    SMALLINT    NOT NULL,
    day_of_week                     SMALLINT    NOT NULL,   -- 1=Seg, 7=Dom (ISO)
    day_name                        VARCHAR(20) NOT NULL,
    is_weekend                      BOOLEAN     NOT NULL,
    is_business_day                 BOOLEAN     NOT NULL,
    is_global_holiday               BOOLEAN     NOT NULL DEFAULT FALSE,
    holiday_name                    VARCHAR(200),
    business_day_number_in_month    SMALLINT,
    business_days_in_month          SMALLINT    NOT NULL,
    remaining_business_days_in_month SMALLINT,
    _loaded_at                      TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_gold_tempo_date    ON gold.dim_tempo(date);
CREATE INDEX idx_gold_tempo_month   ON gold.dim_tempo(month_start_date);
CREATE INDEX idx_gold_tempo_bday    ON gold.dim_tempo(is_business_day) WHERE is_business_day = TRUE;

COMMENT ON TABLE gold.dim_tempo IS 'Dimensão tempo 2020-2035. Fonte: config.business_calendar.';

-- ---------------------------------------------------------------------------
-- gold.dim_agente — dimensão agente canônico (SCD Type 1 inicial)
-- ---------------------------------------------------------------------------
CREATE TABLE gold.dim_agente (
    agente_sk       BIGSERIAL   PRIMARY KEY,
    agent_id        BIGINT      NOT NULL UNIQUE,  -- FK lógica → config.agent_profile
    agent_name      VARCHAR(200) NOT NULL,
    agent_email     VARCHAR(255),
    team_name       VARCHAR(100) NOT NULL,
    agent_level     VARCHAR(20),
    seniority       VARCHAR(50),
    agent_type      VARCHAR(30) NOT NULL DEFAULT 'individual',
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    started_on      DATE,
    ended_on        DATE,
    crm_full_name   VARCHAR(200),   -- full_name de silver.user_clean se encontrado
    _loaded_at      TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_gold_agente_name   ON gold.dim_agente(LOWER(agent_name));
CREATE INDEX idx_gold_agente_team   ON gold.dim_agente(team_name);
CREATE INDEX idx_gold_agente_level  ON gold.dim_agente(agent_level) WHERE agent_level IS NOT NULL;
CREATE INDEX idx_gold_agente_active ON gold.dim_agente(is_active) WHERE is_active = TRUE;

COMMENT ON TABLE gold.dim_agente IS 'Dimensão agente. Fonte: config.agent_profile + silver.user_clean.';
COMMENT ON COLUMN gold.dim_agente.agent_level IS 'Nível operacional do agente: trainee, inter ou pro. Fonte: config.agent_profile.agent_level.';

-- ---------------------------------------------------------------------------
-- gold.dim_ativo — dimensão ativo/símbolo (fonte: config.asset_catalog)
-- ---------------------------------------------------------------------------
CREATE TABLE gold.dim_ativo (
    ativo_sk                BIGSERIAL   PRIMARY KEY,
    asset_id                BIGINT      NOT NULL UNIQUE,
    sirix_symbol            VARCHAR(50) NOT NULL UNIQUE,
    normalized_symbol       VARCHAR(50) NOT NULL,
    display_name            VARCHAR(200),
    asset_class             VARCHAR(50) NOT NULL DEFAULT 'unknown',
    base_currency           VARCHAR(20),
    quote_currency          VARCHAR(20),
    is_major_asset          BOOLEAN     NOT NULL DEFAULT FALSE,
    is_active               BOOLEAN     NOT NULL DEFAULT TRUE,
    classification_status   VARCHAR(30) NOT NULL DEFAULT 'inferred',
    _loaded_at              TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_gold_ativo_class   ON gold.dim_ativo(asset_class);
CREATE INDEX idx_gold_ativo_major   ON gold.dim_ativo(is_major_asset) WHERE is_major_asset = TRUE;

COMMENT ON TABLE gold.dim_ativo IS 'Dimensão ativo. Fonte: config.asset_catalog.';

-- ---------------------------------------------------------------------------
-- gold.dim_cliente — dimensão cliente com agente resolvido
-- ---------------------------------------------------------------------------
CREATE TABLE gold.dim_cliente (
    cliente_sk              BIGSERIAL   PRIMARY KEY,
    crm_account_id          UUID        UNIQUE,         -- chave natural
    tp_account_id           UUID,
    sirix_login             BIGINT,
    cliente_nome            VARCHAR(200),
    country                 VARCHAR(50),
    language_iso            VARCHAR(5),
    lead_status_code        BIGINT,
    lead_status_text        VARCHAR(100),
    lead_status_categoria   VARCHAR(30),
    has_ftd                 BOOLEAN     NOT NULL DEFAULT FALSE,
    retention_owner_name    VARCHAR(100),               -- nome original do CRM
    conversion_owner_name   VARCHAR(100),               -- atributo histórico
    agent_rule_used         VARCHAR(50) NOT NULL DEFAULT 'retention_owner',
    agent_id_current        BIGINT,                     -- FK lógica → config.agent_profile
    agente_sk_current       BIGINT      REFERENCES gold.dim_agente(agente_sk),
    balance                 NUMERIC(15,2),
    equity                  NUMERIC(15,2),
    margin_level            NUMERIC(10,4),
    last_activity_date      DATE,
    eh_habilitada           BOOLEAN,
    eh_readonly             BOOLEAN,
    eh_deletada             BOOLEAN,
    bridge_quality_status   VARCHAR(30),
    _agente_quality         VARCHAR(50) NOT NULL DEFAULT 'unresolved',
    _loaded_at              TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_gold_cliente_agent  ON gold.dim_cliente(agente_sk_current);
CREATE INDEX idx_gold_cliente_login  ON gold.dim_cliente(sirix_login) WHERE sirix_login IS NOT NULL;
CREATE INDEX idx_gold_cliente_ftd    ON gold.dim_cliente(has_ftd) WHERE has_ftd = TRUE;
CREATE INDEX idx_gold_cliente_bridge ON gold.dim_cliente(bridge_quality_status);

COMMENT ON TABLE  gold.dim_cliente IS 'Dimensão cliente com agente resolvido por retention_owner. Fonte: silver.vw_account_bridge + config.agent_alias.';
COMMENT ON COLUMN gold.dim_cliente.agent_rule_used IS 'Regra usada para resolver agente: retention_owner (oficial MVP).';
COMMENT ON COLUMN gold.dim_cliente._agente_quality IS 'resolved=agente resolvido; unresolved=sem alias no config.';

-- ---------------------------------------------------------------------------
-- gold.fato_meta_agente_mes — metas mensais por agente
-- ---------------------------------------------------------------------------
CREATE TABLE gold.fato_meta_agente_mes (
    competence_month_sk         INTEGER NOT NULL REFERENCES gold.dim_tempo(tempo_sk),
    agente_sk                   BIGINT  NOT NULL REFERENCES gold.dim_agente(agente_sk),
    competence_month            DATE    NOT NULL,
    target_deposit_month_usd    NUMERIC(15,2) NOT NULL DEFAULT 0,
    target_deposit_day_usd      NUMERIC(15,2),  -- derivado: target_deposit_month / business_days
    target_trade_day            INTEGER NOT NULL DEFAULT 0,
    target_trade_month          INTEGER,        -- derivado: target_trade_day * business_days se NULL na config
    target_unique_month         INTEGER NOT NULL DEFAULT 0,
    target_volume_month         NUMERIC(20,4),
    target_volume_unit          VARCHAR(30),
    business_days_in_month      SMALLINT NOT NULL,
    source_type                 VARCHAR(50),
    _loaded_at                  TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (competence_month_sk, agente_sk)
);

COMMENT ON TABLE gold.fato_meta_agente_mes IS 'Grão: 1 linha por agente por mês. Fonte: config.agent_target_month.';

-- ---------------------------------------------------------------------------
-- gold.fato_movimentacao_financeira — transações financeiras aprovadas
-- ---------------------------------------------------------------------------
CREATE TABLE gold.fato_movimentacao_financeira (
    transaction_sk              BIGSERIAL   PRIMARY KEY,
    transaction_id              UUID        NOT NULL UNIQUE,
    tempo_aprovacao_sk          INTEGER     REFERENCES gold.dim_tempo(tempo_sk),
    tempo_criacao_sk            INTEGER     REFERENCES gold.dim_tempo(tempo_sk),
    cliente_sk                  BIGINT      REFERENCES gold.dim_cliente(cliente_sk),
    agente_sk                   BIGINT      REFERENCES gold.dim_agente(agente_sk),
    crm_account_id              UUID,       -- degenerate dimension
    tp_account_id               UUID,
    sirix_ticket                BIGINT,
    transaction_type_code       INTEGER     NOT NULL,
    transaction_type_categoria  VARCHAR(30),
    status_code                 BIGINT,
    eh_aprovada                 BOOLEAN     NOT NULL DEFAULT FALSE,
    eh_ftd                      BOOLEAN     NOT NULL DEFAULT FALSE,
    amount_original             NUMERIC(15,2),
    usd_value                   NUMERIC(15,2) NOT NULL DEFAULT 0,
    deposit_amount_usd          NUMERIC(15,2) NOT NULL DEFAULT 0,
    withdrawal_amount_usd       NUMERIC(15,2) NOT NULL DEFAULT 0,
    net_deposit_usd             NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency_iso                VARCHAR(3),
    payment_method_code         BIGINT,
    payment_method_name         VARCHAR(50),
    approved_on                 DATE,
    created_on                  TIMESTAMP,
    _agente_quality             VARCHAR(50) NOT NULL DEFAULT 'unresolved',
    _loaded_at                  TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_gold_fin_tempo_apr  ON gold.fato_movimentacao_financeira(tempo_aprovacao_sk);
CREATE INDEX idx_gold_fin_cliente    ON gold.fato_movimentacao_financeira(cliente_sk);
CREATE INDEX idx_gold_fin_agente     ON gold.fato_movimentacao_financeira(agente_sk);
CREATE INDEX idx_gold_fin_aprovada   ON gold.fato_movimentacao_financeira(eh_aprovada);
CREATE INDEX idx_gold_fin_ftd        ON gold.fato_movimentacao_financeira(eh_ftd) WHERE eh_ftd = TRUE;
CREATE INDEX idx_gold_fin_dep        ON gold.fato_movimentacao_financeira(deposit_amount_usd) WHERE deposit_amount_usd > 0;

COMMENT ON TABLE gold.fato_movimentacao_financeira IS 'Grão: 1 linha por transação financeira. Fonte: silver.transaction_clean.';

-- ---------------------------------------------------------------------------
-- gold.fato_operacao — operações de trading (todos CMD)
-- ---------------------------------------------------------------------------
CREATE TABLE gold.fato_operacao (
    operacao_sk         BIGSERIAL   PRIMARY KEY,
    ticket              BIGINT      NOT NULL UNIQUE,
    tempo_open_sk       INTEGER     REFERENCES gold.dim_tempo(tempo_sk),
    tempo_close_sk      INTEGER     REFERENCES gold.dim_tempo(tempo_sk),
    cliente_sk          BIGINT      REFERENCES gold.dim_cliente(cliente_sk),
    agente_sk           BIGINT      REFERENCES gold.dim_agente(agente_sk),
    ativo_sk            BIGINT      REFERENCES gold.dim_ativo(ativo_sk),
    sirix_login         BIGINT,
    cmd_code            INTEGER     NOT NULL,
    cmd_tipo            VARCHAR(20),
    eh_operacao_mercado BOOLEAN     NOT NULL DEFAULT FALSE,  -- CMD 0/1
    eh_pendente         BOOLEAN     NOT NULL DEFAULT FALSE,  -- CMD 2-5
    eh_financeiro_sirix BOOLEAN     NOT NULL DEFAULT FALSE,  -- CMD 6/7
    side                VARCHAR(10),
    side_sign           SMALLINT,
    symbol              VARCHAR(50),
    volume_raw          BIGINT,
    volume_lots         NUMERIC(20,4),
    open_time           TIMESTAMP,
    close_time          TIMESTAMP,
    eh_aberta           BOOLEAN     NOT NULL DEFAULT FALSE,
    open_price          NUMERIC(15,5),
    close_price         NUMERIC(15,5),
    profit_bruto        NUMERIC(15,2) NOT NULL DEFAULT 0,
    commission          NUMERIC(10,2) NOT NULL DEFAULT 0,
    swaps               NUMERIC(15,2) NOT NULL DEFAULT 0,
    profit_liquido      NUMERIC(15,2),
    duracao_segundos    BIGINT,
    _eh_suspeito        BOOLEAN     NOT NULL DEFAULT FALSE,
    _motivo_suspeito    TEXT,
    _agente_quality     VARCHAR(50) NOT NULL DEFAULT 'unresolved',
    _loaded_at          TIMESTAMP   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_gold_op_tempo_open  ON gold.fato_operacao(tempo_open_sk);
CREATE INDEX idx_gold_op_cliente     ON gold.fato_operacao(cliente_sk);
CREATE INDEX idx_gold_op_agente      ON gold.fato_operacao(agente_sk);
CREATE INDEX idx_gold_op_ativo       ON gold.fato_operacao(ativo_sk);
CREATE INDEX idx_gold_op_mercado     ON gold.fato_operacao(eh_operacao_mercado) WHERE eh_operacao_mercado = TRUE;
CREATE INDEX idx_gold_op_aberta      ON gold.fato_operacao(eh_aberta) WHERE eh_aberta = TRUE;
CREATE INDEX idx_gold_op_login       ON gold.fato_operacao(sirix_login);

COMMENT ON TABLE gold.fato_operacao IS 'Grão: 1 linha por ticket Sirix. Todos CMD 0-7. Fonte: silver.trade_clean.';

-- ---------------------------------------------------------------------------
-- gold.fato_cliente_trade_dia — clientes que operaram por dia
-- ---------------------------------------------------------------------------
CREATE TABLE gold.fato_cliente_trade_dia (
    tempo_sk            INTEGER NOT NULL REFERENCES gold.dim_tempo(tempo_sk),
    cliente_sk          BIGINT  NOT NULL REFERENCES gold.dim_cliente(cliente_sk),
    agente_sk           BIGINT  REFERENCES gold.dim_agente(agente_sk),
    sirix_login         BIGINT,
    qtd_trades_dia      INTEGER NOT NULL DEFAULT 0,
    qtd_ativos_dia      INTEGER NOT NULL DEFAULT 0,
    volume_lots_dia     NUMERIC(20,4),
    pnl_liquido_dia     NUMERIC(15,2),
    first_trade_ts      TIMESTAMP,
    last_trade_ts       TIMESTAMP,
    has_open_today      BOOLEAN NOT NULL DEFAULT TRUE,   -- abriu operação neste dia
    has_close_today     BOOLEAN NOT NULL DEFAULT FALSE,  -- fechou operação neste dia
    _loaded_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (tempo_sk, cliente_sk)
);

CREATE INDEX idx_gold_ctd_agente ON gold.fato_cliente_trade_dia(agente_sk);
CREATE INDEX idx_gold_ctd_login  ON gold.fato_cliente_trade_dia(sirix_login);

COMMENT ON TABLE gold.fato_cliente_trade_dia IS 'Grão: 1 linha por cliente por dia com abertura CMD 0/1. Base para call list e trading hoje. Fonte: gold.fato_operacao.';

COMMIT;
