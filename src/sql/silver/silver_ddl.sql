BEGIN;

DROP SCHEMA IF EXISTS silver CASCADE;
CREATE SCHEMA silver;
COMMENT ON SCHEMA silver IS 'Camada Silver: dados limpos, validados, tipados, deduplicados. Pronto para BI ad-hoc.';

-- ---------------------------------------------------------------------
-- silver.account_clean — versão limpa de crm_account_base
-- ---------------------------------------------------------------------
CREATE TABLE silver.account_clean (
    account_id              UUID PRIMARY KEY,
    name                    VARCHAR(200) NOT NULL,
    first_name              VARCHAR(100),
    last_name               VARCHAR(100),
    country                 VARCHAR(50) NOT NULL,    -- normalizado (sem France2, sem 2-spaces)
    country_id              UUID,
    language_iso            VARCHAR(5),              -- ISO 639-1 (pt, it, tr, fr, en, ...)
    lead_status_code        BIGINT NOT NULL,
    lead_status_text        VARCHAR(100),
    lead_status_categoria   VARCHAR(30),             -- joined de domain.dom_lead_status
    eh_lead_terminal        BOOLEAN,
    lead_status_reason_code INTEGER,                  -- preservado para produção, mesmo NULL no dev
    bu_name                 VARCHAR(50),
    bu_parent               VARCHAR(50),
    owning_business_unit    UUID,
    conversion_bu           VARCHAR(50),
    conversion_owner_name   VARCHAR(100),            -- match com user_clean.fullname
    conversion_owner_key    VARCHAR(120),            -- lower/trim para alias em gold/config
    retention_bu            VARCHAR(50),
    retention_owner_name    VARCHAR(100),
    retention_owner_key     VARCHAR(120),            -- lower/trim para alias em gold/config
    has_retention_owner     BOOLEAN NOT NULL DEFAULT FALSE,
    main_tp_account_id      UUID,                    -- → tpaccount_clean.tpaccount_id
    affiliate_code          VARCHAR(50),
    subaffiliate_code       VARCHAR(255),            -- 100% NULL no dev; reservado para produção Dataverse
    campaign_id             VARCHAR(200),
    source_id               INTEGER,                 -- preservado para produção, mesmo NULL no dev
    owner_id                UUID,                    -- SystemUserId (não bate com user.activedirectoryguid)
    has_ftd                 BOOLEAN NOT NULL,        -- de lv_ftdexist
    created_on              TIMESTAMP NOT NULL,
    modified_on             TIMESTAMP NOT NULL,
    -- técnicas
    _silver_ts              TIMESTAMP NOT NULL DEFAULT NOW(),
    _eh_valido              BOOLEAN NOT NULL DEFAULT TRUE,
    _motivo_invalido        TEXT,
    _bronze_ingestao_ts     TIMESTAMP,
    _bronze_origem          VARCHAR(20),
    _bronze_hash_linha      VARCHAR(64)
);

CREATE INDEX idx_silver_acc_modifiedon ON silver.account_clean(modified_on);
CREATE INDEX idx_silver_acc_country ON silver.account_clean(country);
CREATE INDEX idx_silver_acc_ftd ON silver.account_clean(has_ftd) WHERE has_ftd = TRUE;
CREATE INDEX idx_silver_acc_maintp ON silver.account_clean(main_tp_account_id);
CREATE INDEX idx_silver_acc_convowner ON silver.account_clean(conversion_owner_name);
CREATE INDEX idx_silver_acc_retowner ON silver.account_clean(retention_owner_name);
CREATE INDEX idx_silver_acc_convowner_key ON silver.account_clean(conversion_owner_key);
CREATE INDEX idx_silver_acc_retowner_key ON silver.account_clean(retention_owner_key);

-- ---------------------------------------------------------------------
-- silver.user_clean — versão limpa de crm_user_base
-- (descarta as 30+ colunas 100% NULL e constantes)
-- ---------------------------------------------------------------------
CREATE TABLE silver.user_clean (
    active_directory_guid    UUID PRIMARY KEY,
    identity_id              INTEGER,
    business_unit_id         UUID NOT NULL,
    full_name                VARCHAR(200) NOT NULL,
    full_name_key            VARCHAR(220),           -- lower/trim para alias em config/gold
    first_name               VARCHAR(100),
    last_name                VARCHAR(100),
    email                    VARCHAR(255),           -- de domainname
    is_disabled              BOOLEAN NOT NULL,
    is_active                BOOLEAN,
    is_conversion_owner      BOOLEAN,
    is_retention_owner       BOOLEAN,
    is_business_unit_owner   BOOLEAN,
    can_create_tp_account    BOOLEAN,
    can_delete_tp_account    BOOLEAN,
    can_disable_enable_tp_account BOOLEAN,
    can_handle_transactions  BOOLEAN,
    can_use_custom_deposit   BOOLEAN,
    incoming_email_delivery_method INTEGER,
    lead_assignment_frequency INTEGER,
    created_on               TIMESTAMP NOT NULL,
    -- técnicas
    _silver_ts               TIMESTAMP NOT NULL DEFAULT NOW(),
    _eh_valido               BOOLEAN NOT NULL DEFAULT TRUE,
    _motivo_invalido         TEXT,
    _bronze_ingestao_ts      TIMESTAMP,
    _bronze_origem           VARCHAR(20),
    _bronze_hash_linha       VARCHAR(64)
);

CREATE INDEX idx_silver_user_fullname ON silver.user_clean(full_name);
CREATE INDEX idx_silver_user_fullname_key ON silver.user_clean(full_name_key);
CREATE INDEX idx_silver_user_buid ON silver.user_clean(business_unit_id);
CREATE INDEX idx_silver_user_active ON silver.user_clean(is_disabled) WHERE is_disabled = FALSE;

-- ---------------------------------------------------------------------
-- silver.tpaccount_clean — versão limpa de lv_tpaccountbase (A PONTE!)
-- ---------------------------------------------------------------------
CREATE TABLE silver.tpaccount_clean (
    tp_account_id              UUID PRIMARY KEY,
    sirix_login                BIGINT NOT NULL,        -- = lv_name, ponte com Sirix
    crm_account_id             UUID,                    -- → account_clean (96% match)
    sirix_group                VARCHAR(50),             -- de lv_tempname
    base_currency              VARCHAR(3) NOT NULL,     -- decodificado de lv_basecurrencyid (USD/EUR/TRY)
    base_currency_guid         UUID,
    leverage                   INTEGER,
    balance_usd                NUMERIC(20,8),
    balance_base               NUMERIC(20,8),
    equity                     NUMERIC(20,8),
    pnl_acumulado              NUMERIC(20,8),           -- de lv_pl
    margin_level               NUMERIC(15,4),
    margin_status              INTEGER,                  -- 1=normal, 2=margin call
    eh_margin_call             BOOLEAN,                  -- derivado: margin_status=2
    num_total_positions        INTEGER,
    num_open_positions         INTEGER,
    total_trading_amount_usd   NUMERIC(25,8),
    tp_type                    INTEGER,                  -- 0=regular, 1=especial
    eh_conta_especial          BOOLEAN,                  -- derivado: tp_type=1
    trading_type               INTEGER,                  -- ex: netting/hedging; constante no dev
    trade_server_hostname      INTEGER,                  -- identificador do servidor MT4
    trading_platform_id        UUID,
    owner_id                   UUID,                     -- SystemUserId
    owning_business_unit       UUID,
    eh_readonly                BOOLEAN,
    eh_online                  BOOLEAN,
    eh_logged_in_from_web      BOOLEAN,
    last_login                 TIMESTAMP,
    last_daily_ts              TIMESTAMP,
    last_bonus_ts              TIMESTAMP,
    last_bonus_date_ts         TIMESTAMP,
    eh_deletada                BOOLEAN NOT NULL DEFAULT FALSE,
    eh_desabilitada            BOOLEAN NOT NULL DEFAULT FALSE,
    state_code                 INTEGER,
    status_code                INTEGER,
    created_by                 UUID,
    modified_by                UUID,
    created_on                 TIMESTAMP NOT NULL,
    modified_on                TIMESTAMP NOT NULL,
    -- técnicas
    _silver_ts                 TIMESTAMP NOT NULL DEFAULT NOW(),
    _eh_valido                 BOOLEAN NOT NULL DEFAULT TRUE,
    _motivo_invalido           TEXT,
    _eh_suspeito               BOOLEAN NOT NULL DEFAULT FALSE,  -- outlier em total_trading_amount
    _motivo_suspeito           TEXT,
    _bronze_ingestao_ts        TIMESTAMP,
    _bronze_origem             VARCHAR(20),
    _bronze_hash_linha         VARCHAR(64)
);

CREATE INDEX idx_silver_tp_login ON silver.tpaccount_clean(sirix_login);
CREATE INDEX idx_silver_tp_crm ON silver.tpaccount_clean(crm_account_id);
CREATE INDEX idx_silver_tp_modifiedon ON silver.tpaccount_clean(modified_on);
CREATE INDEX idx_silver_tp_currency ON silver.tpaccount_clean(base_currency);
CREATE INDEX idx_silver_tp_marginstatus ON silver.tpaccount_clean(eh_margin_call) WHERE eh_margin_call = TRUE;

-- ---------------------------------------------------------------------
-- silver.transaction_clean — versão limpa de lv_monetarytransactionbase
-- (descarta as 44 colunas 100% NULL)
-- ---------------------------------------------------------------------
CREATE TABLE silver.transaction_clean (
    transaction_id              UUID PRIMARY KEY,
    transaction_name            VARCHAR(80),              -- de lv_name (Deposit, Withdrawal, ...)
    transaction_type_code       INTEGER NOT NULL,         -- lv_type
    transaction_type_name       VARCHAR(80),              -- joined de domain.dom_transaction_type
    internal_type_code          INTEGER,                  -- lv_internaltype; sem lookup na domain
    transaction_type_categoria  VARCHAR(30),              -- joined de domain.dom_transaction_type
    sinal_financeiro            CHAR(1),                  -- '+', '-', '0'
    eh_deposito                 BOOLEAN NOT NULL DEFAULT FALSE,
    eh_withdrawal               BOOLEAN NOT NULL DEFAULT FALSE,
    eh_bonus                    BOOLEAN NOT NULL DEFAULT FALSE,
    eh_credit                   BOOLEAN NOT NULL DEFAULT FALSE,
    eh_debit                    BOOLEAN NOT NULL DEFAULT FALSE,
    eh_reversal                 BOOLEAN NOT NULL DEFAULT FALSE,
    signed_usd_value            NUMERIC(15,2),            -- usd_value aplicado ao sinal financeiro do domain
    crm_account_id              UUID,                     -- → account_clean (45% match na amostra)
    tp_account_id               UUID NOT NULL,            -- → tpaccount_clean (100% match)
    sirix_ticket                BIGINT,                   -- → trade_clean.ticket
    opposite_ticket             BIGINT,                   -- reconciliação de estornos/cancelamentos
    amount_original             NUMERIC(15,2) NOT NULL,
    usd_value                   NUMERIC(15,2) NOT NULL,
    net_deposit_usd             NUMERIC(15,2),            -- com sinal
    currency_iso                VARCHAR(3),               -- decodificada
    exchange_rate               NUMERIC(15,10),
    eh_ftd                      BOOLEAN NOT NULL DEFAULT FALSE,
    status_code                 BIGINT NOT NULL,
    status_descricao            VARCHAR(50),
    status_eh_aprovado          BOOLEAN,                  -- classificação do domain; comparar com flag fonte
    eh_aprovada                 BOOLEAN NOT NULL,         -- lv_transactionapproved
    eh_aprovacao_gerencial      BOOLEAN,
    eh_aprovacao_automatica     BOOLEAN,
    eh_atualiza_tp_ao_aprovar   BOOLEAN,
    eh_paga                     BOOLEAN,
    approved_on                 TIMESTAMP,
    approved_date               DATE,
    platform_updated_on         TIMESTAMP,
    expires_on                  TIMESTAMP,
    payment_method_code         BIGINT,
    payment_method_name         VARCHAR(50),              -- joined de dom_payment_method
    payment_method_is_official  BOOLEAN,
    transaction_comment         VARCHAR(255),
    internal_comment            VARCHAR(500),
    additional_info             TEXT,
    transaction_reference       VARCHAR(100),
    transaction_case_id         UUID,
    last_action_id              UUID,
    related_transaction_id      UUID,
    opposite_account_id         UUID,
    transfer_to_tp_account_id   UUID,
    transaction_owner           UUID,                     -- lv_mttransactionowner
    owner_id                    UUID,
    owning_business_unit        UUID,
    state_code                  INTEGER,
    status_reason_code          INTEGER,
    created_on                  TIMESTAMP NOT NULL,
    created_date                DATE,
    modified_on                 TIMESTAMP NOT NULL,
    modified_date               DATE,
    -- técnicas
    _silver_ts                  TIMESTAMP NOT NULL DEFAULT NOW(),
    _eh_valido                  BOOLEAN NOT NULL DEFAULT TRUE,
    _motivo_invalido            TEXT,
    _bronze_ingestao_ts         TIMESTAMP,
    _bronze_origem              VARCHAR(20),
    _bronze_hash_linha          VARCHAR(64)
);

CREATE INDEX idx_silver_tx_tp ON silver.transaction_clean(tp_account_id);
CREATE INDEX idx_silver_tx_account ON silver.transaction_clean(crm_account_id);
CREATE INDEX idx_silver_tx_ticket ON silver.transaction_clean(sirix_ticket);
CREATE INDEX idx_silver_tx_opposite_ticket ON silver.transaction_clean(opposite_ticket) WHERE opposite_ticket IS NOT NULL;
CREATE INDEX idx_silver_tx_approved ON silver.transaction_clean(eh_aprovada);
CREATE INDEX idx_silver_tx_ftd ON silver.transaction_clean(eh_ftd) WHERE eh_ftd = TRUE;
CREATE INDEX idx_silver_tx_createdon ON silver.transaction_clean(created_on);
CREATE INDEX idx_silver_tx_approvedon ON silver.transaction_clean(approved_on);
CREATE INDEX idx_silver_tx_platform_updated ON silver.transaction_clean(platform_updated_on) WHERE platform_updated_on IS NOT NULL;
CREATE INDEX idx_silver_tx_type ON silver.transaction_clean(transaction_type_code);
CREATE INDEX idx_silver_tx_approved_date ON silver.transaction_clean(approved_date);
CREATE INDEX idx_silver_tx_deposito ON silver.transaction_clean(eh_deposito) WHERE eh_deposito = TRUE;
CREATE INDEX idx_silver_tx_withdrawal ON silver.transaction_clean(eh_withdrawal) WHERE eh_withdrawal = TRUE;
CREATE INDEX idx_silver_tx_related ON silver.transaction_clean(related_transaction_id) WHERE related_transaction_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- silver.sirix_account_clean — versão limpa de sirix_users_view
-- ---------------------------------------------------------------------
CREATE TABLE silver.sirix_account_clean (
    login                BIGINT PRIMARY KEY,
    name                 VARCHAR(200),
    sirix_group          VARCHAR(50),
    balance              NUMERIC(15,2) NOT NULL,
    equity               NUMERIC(15,2) NOT NULL,
    margin               NUMERIC(15,2) NOT NULL,
    margin_free          NUMERIC(15,2) NOT NULL,
    margin_level         NUMERIC(15,4),
    credit               NUMERIC(15,2),
    prev_balance         NUMERIC(15,2),
    prev_month_balance   NUMERIC(15,2),
    currency             VARCHAR(3) NOT NULL,
    leverage             INTEGER NOT NULL,
    agent_login          INTEGER,                 -- referência a IB; sem FK até modelagem gold
    interest_rate        INTEGER,
    taxes                INTEGER,
    send_reports         BOOLEAN,
    enable_change_pass   BOOLEAN,
    eh_habilitada        BOOLEAN NOT NULL,         -- enable = 1
    eh_readonly          BOOLEAN NOT NULL,
    last_activity_date   TIMESTAMP,
    last_activity_date_only DATE,
    modify_time          TIMESTAMP NOT NULL,
    modify_date          DATE,
    reg_date             TIMESTAMP NOT NULL,
    reg_date_only        DATE,
    -- técnicas
    _silver_ts           TIMESTAMP NOT NULL DEFAULT NOW(),
    _eh_valido           BOOLEAN NOT NULL DEFAULT TRUE,
    _motivo_invalido     TEXT,
    _bronze_ingestao_ts  TIMESTAMP,
    _bronze_origem       VARCHAR(20),
    _bronze_hash_linha   VARCHAR(64)
);

CREATE INDEX idx_silver_sa_modify ON silver.sirix_account_clean(modify_time);
CREATE INDEX idx_silver_sa_currency ON silver.sirix_account_clean(currency);
CREATE INDEX idx_silver_sa_enabled ON silver.sirix_account_clean(eh_habilitada);

-- ---------------------------------------------------------------------
-- silver.trade_clean — versão limpa de sirix_trades_view
-- (mantém todos os CMD — separação trade/movimentação acontece em gold)
-- ---------------------------------------------------------------------
CREATE TABLE silver.trade_clean (
    ticket                BIGINT PRIMARY KEY,
    sirix_login           BIGINT NOT NULL,            -- = account_id (LOGIN duplicado descartado)
    cmd_code              INTEGER NOT NULL,
    cmd_tipo              VARCHAR(20),                -- OP_BUY, OP_SELL, ...
    eh_trade              BOOLEAN NOT NULL,           -- joined de dom_cmd
    eh_operacao_mercado   BOOLEAN NOT NULL,           -- TRUE apenas para CMD 0/1
    eh_financeiro         BOOLEAN NOT NULL,
    eh_pendente           BOOLEAN NOT NULL,
    sinal                 CHAR(1),                    -- '+', '-', '0'
    side                  VARCHAR(10),                -- Buy, Sell, Other
    side_sign             SMALLINT,                   -- Buy=1, Sell=-1, outros=0
    broker_id             VARCHAR(36),                -- ID textual do broker Sirix; não é UUID canônico
    account_id            BIGINT,                     -- duplicado do LOGIN na fonte; preservado para reconciliação
    symbol                VARCHAR(20),                -- NULL para CMD 6/7
    symbol_key            VARCHAR(30),                -- upper/trim para dim_ativo
    volume                BIGINT NOT NULL,            -- volume bruto da plataforma
    volume_lots           NUMERIC(20,8),              -- lote fracionário usado no MVP
    open_time             TIMESTAMP,                  -- NULL se = 1970-01-01 (ordens nunca executadas)
    open_date             DATE,
    close_time            TIMESTAMP,                  -- NULL se ordem ainda aberta
    close_date            DATE,
    eh_aberta             BOOLEAN NOT NULL,           -- derivado: eh_trade AND close_time IS NULL
    open_price            NUMERIC(15,5),
    close_price           NUMERIC(15,5),
    open_position_id      BIGINT,                     -- se preenchido, é evento de fechamento
    profit_bruto          NUMERIC(15,2) NOT NULL,     -- PROFIT do Sirix
    commission            NUMERIC(10,2) NOT NULL,
    commission_agent      INTEGER,
    swaps                 NUMERIC(15,2) NOT NULL,
    taxes                 INTEGER,
    profit_liquido        NUMERIC(15,2),              -- DERIVADO: profit_bruto - ABS(commission) + swaps (validar fórmula)
    sl                    NUMERIC(15,5),              -- NULL se 0
    tp                    NUMERIC(15,5),              -- NULL se 0
    expiration            TIMESTAMP,
    duracao_segundos      BIGINT,                     -- DERIVADO: EXTRACT(EPOCH FROM close_time - open_time)
    modify_time           TIMESTAMP NOT NULL,
    modify_date           DATE,
    sirix_comment         VARCHAR(255),
    movimentacao_tipo     VARCHAR(30),                -- DERIVADO de comment quando eh_financeiro: 'Deposito', 'Saque', 'Bonus', ...
    conv_rate1            NUMERIC(15,5),
    conv_rate2            NUMERIC(15,5),
    margin_rate           INTEGER,
    digits                INTEGER,
    internal_id           INTEGER,
    -- técnicas
    _silver_ts            TIMESTAMP NOT NULL DEFAULT NOW(),
    _eh_valido            BOOLEAN NOT NULL DEFAULT TRUE,
    _motivo_invalido      TEXT,
    _eh_suspeito          BOOLEAN NOT NULL DEFAULT FALSE,  -- outliers em PROFIT/VOLUME
    _motivo_suspeito      TEXT,
    _bronze_ingestao_ts   TIMESTAMP,
    _bronze_origem        VARCHAR(20),
    _bronze_hash_linha    VARCHAR(64)
);

CREATE INDEX idx_silver_trade_login ON silver.trade_clean(sirix_login);
CREATE INDEX idx_silver_trade_opentime ON silver.trade_clean(open_time);
CREATE INDEX idx_silver_trade_closetime ON silver.trade_clean(close_time);
CREATE INDEX idx_silver_trade_cmd ON silver.trade_clean(cmd_code);
CREATE INDEX idx_silver_trade_aberta ON silver.trade_clean(eh_aberta) WHERE eh_aberta = TRUE;
CREATE INDEX idx_silver_trade_symbol ON silver.trade_clean(symbol) WHERE symbol IS NOT NULL;
CREATE INDEX idx_silver_trade_symbol_key ON silver.trade_clean(symbol_key) WHERE symbol_key IS NOT NULL;
CREATE INDEX idx_silver_trade_openposid ON silver.trade_clean(open_position_id) WHERE open_position_id IS NOT NULL;
CREATE INDEX idx_silver_trade_market ON silver.trade_clean(eh_operacao_mercado) WHERE eh_operacao_mercado = TRUE;
CREATE INDEX idx_silver_trade_open_date ON silver.trade_clean(open_date);

-- ---------------------------------------------------------------------
-- silver.daily_snapshot_clean — versão limpa de sirix_daily_view
-- NOTA (2026-06-02): estrutura mantida, porém a CARGA está DIFERIDA — a tabela
-- fica vazia. A série diária de equity (4,7M linhas) não é consumida por gold
-- hoje; ver bloco DIFERIDO em silver_bootstrap_insert.sql e wiki/topics/camada-silver.md.
-- Quando o consumidor em gold existir, reativar a carga e criar o índice
-- adequado (provável (sirix_login, snapshot_date) para curva por conta).
-- ---------------------------------------------------------------------
CREATE TABLE silver.daily_snapshot_clean (
    snapshot_date        DATE NOT NULL,           -- de TIME, truncado para data
    snapshot_ts          TIMESTAMP NOT NULL,      -- TIME original (sempre 23:59:59)
    sirix_login          BIGINT NOT NULL,
    balance              NUMERIC(15,2) NOT NULL,
    balance_prev         NUMERIC(15,2) NOT NULL,
    equity               NUMERIC(15,2) NOT NULL,
    margin               NUMERIC(15,2) NOT NULL,
    margin_free          NUMERIC(15,2) NOT NULL,
    credit               NUMERIC(15,2),
    profit_aberto        NUMERIC(15,2),           -- de PROFIT (posições abertas a mercado)
    profit_realizado     NUMERIC(15,2),           -- de PROFIT_CLOSED
    fluxo_dia            NUMERIC(15,2),           -- DERIVADO: balance - balance_prev
    deposit_raw          NUMERIC(15,2),           -- campo da fonte daily; PRD pode conter centavos
    bank                 NUMERIC(15,2),           -- NULL no dev; preservar para produção
    sirix_group          VARCHAR(50),
    modify_time          TIMESTAMP,
    modify_date          DATE,
    -- técnicas
    _silver_ts           TIMESTAMP NOT NULL DEFAULT NOW(),
    _eh_valido           BOOLEAN NOT NULL DEFAULT TRUE,
    _motivo_invalido     TEXT,
    _bronze_ingestao_ts  TIMESTAMP,
    _bronze_origem       VARCHAR(20),
    _bronze_hash_linha   VARCHAR(64),
    PRIMARY KEY (snapshot_date, sirix_login)
);

CREATE INDEX idx_silver_daily_login ON silver.daily_snapshot_clean(sirix_login);
CREATE INDEX idx_silver_daily_date ON silver.daily_snapshot_clean(snapshot_date);

-- ---------------------------------------------------------------------
-- silver.vw_account_bridge — VIEW conveniente que une CRM + TP + Sirix
-- (mencionada na documentação das fontes)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW silver.vw_account_bridge AS
SELECT
    a.account_id              AS crm_account_id,
    a.name                    AS cliente_nome,
    a.country,
    a.language_iso,
    a.has_ftd,
    a.lead_status_code,
    a.lead_status_text,
    a.lead_status_categoria,
    a.bu_name,
    a.conversion_owner_name,
    a.conversion_owner_key,
    a.retention_owner_name,
    a.retention_owner_key,
    a.main_tp_account_id,
    t.tp_account_id,
    t.sirix_login,
    t.sirix_group,
    t.base_currency,
    t.leverage,
    t.balance_usd,
    t.equity,
    t.pnl_acumulado,
    t.margin_level,
    t.margin_status,
    t.eh_readonly,
    t.eh_deletada,
    t.eh_desabilitada,
    t.num_open_positions,
    s.balance                 AS sirix_balance,
    s.equity                  AS sirix_equity,
    s.margin_level            AS sirix_margin_level,
    s.eh_habilitada           AS sirix_eh_habilitada,
    s.eh_readonly             AS sirix_eh_readonly,
    s.last_activity_date      AS sirix_last_activity,
    (t.tp_account_id IS NOT NULL) AS has_tp_match,
    (s.login IS NOT NULL) AS has_sirix_match,
    CASE
        WHEN a.main_tp_account_id IS NULL THEN 'sem_tp_principal'
        WHEN t.tp_account_id IS NULL THEN 'tp_nao_encontrada'
        WHEN t.sirix_login IS NULL THEN 'sem_sirix_login'
        WHEN s.login IS NULL THEN 'sirix_nao_encontrado'
        ELSE 'ok'
    END AS bridge_quality_status
FROM silver.account_clean a
LEFT JOIN silver.tpaccount_clean t
    ON a.main_tp_account_id = t.tp_account_id
   AND t.eh_deletada = FALSE
LEFT JOIN silver.sirix_account_clean s
    ON t.sirix_login = s.login;

COMMIT;
