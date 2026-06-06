-- =====================================================================
-- SCHEMA BRONZE
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS bronze;
COMMENT ON SCHEMA bronze IS 'Camada Bronze: cópia fiel das fontes, append-only, auditável.';

-- ---------------------------------------------------------------------
-- bronze.crm_account_base
-- 30.000 linhas × 28 colunas — cadastro mestre de leads/clientes do CRM
-- ---------------------------------------------------------------------
CREATE TABLE bronze.crm_account_base (
    accountid               VARCHAR(36) NOT NULL,
    buname                  VARCHAR(50),
    conversion_bu           VARCHAR(50),
    conversion_owner        VARCHAR(100),
    country                 VARCHAR(50),
    createdon               TIMESTAMP,
    leadstatustext          VARCHAR(50),
    lv_affiliate            VARCHAR(50),
    lv_campaignid           VARCHAR(200),      -- fonte: até 152 chars observados
    lv_conversionownerid    VARCHAR(36),
    lv_countryid            VARCHAR(36),
    lv_firstname            VARCHAR(100),
    lv_ftdexist             BOOLEAN,
    lv_language             VARCHAR(10),
    lv_lastname             VARCHAR(100),
    lv_leadstatus           INTEGER,
    lv_leadstatusreason     INTEGER,         -- 100% NULL atualmente, manter
    lv_maintpaccountid      VARCHAR(36),     -- FK lógica → bronze.lv_tpaccountbase
    lv_retentionownerid     VARCHAR(36),
    lv_sourceid             INTEGER,         -- 100% NULL atualmente
    modifiedon              TIMESTAMP,       -- usado para extração incremental
    name                    VARCHAR(200),
    lv_subaffiliate         VARCHAR(255),
    ownerid                 VARCHAR(36),
    owningbusinessunit      VARCHAR(36),
    parent                  VARCHAR(50),
    retention_bu            VARCHAR(50),
    retention_owner         VARCHAR(100),
    -- colunas técnicas
    _ingestao_ts            TIMESTAMP NOT NULL DEFAULT NOW(),
    _origem                 VARCHAR(20) NOT NULL DEFAULT 'csv',
    _hash_linha             VARCHAR(64)
);

CREATE INDEX idx_bronze_acc_modifiedon ON bronze.crm_account_base(modifiedon);
CREATE INDEX idx_bronze_acc_accountid ON bronze.crm_account_base(accountid);
CREATE INDEX idx_bronze_acc_maintp ON bronze.crm_account_base(lv_maintpaccountid);

-- ---------------------------------------------------------------------
-- bronze.crm_user_base
-- 216 linhas × ~30 colunas relevantes (descartamos as 30+ sempre-NULL no bronze)
-- ⚠️ EXCLUI lv_password no extractor
-- ---------------------------------------------------------------------
CREATE TABLE bronze.crm_user_base (
    activedirectoryguid          VARCHAR(36) NOT NULL,
    identityid                   INTEGER,
    businessunitid               VARCHAR(36),
    fullname                     VARCHAR(200),
    firstname                    VARCHAR(100),
    lastname                     VARCHAR(100),
    domainname                   VARCHAR(255),
    createdby                    VARCHAR(36),
    createdon                    TIMESTAMP,
    isdisabled                   BOOLEAN,
    lv_isactive                  VARCHAR(10),
    lv_isconversionowner         VARCHAR(10),
    lv_isretentionowner          VARCHAR(10),
    lv_isbusinessunitowner       VARCHAR(10),
    lv_cancreatetpaccount        VARCHAR(10),
    lv_candeletetpaccount        VARCHAR(10),
    lv_candisableenabletpaccount VARCHAR(10),
    lv_canhandletransactions     VARCHAR(10),
    lv_canusecustomdeposit       VARCHAR(10),
    isactivedirectoryuser        BOOLEAN,
    invitestatuscode             INTEGER,
    incomingemaildeliverymethod  INTEGER,
    lv_leadassignmentfrequency   INTEGER,
    -- técnicas
    _ingestao_ts                 TIMESTAMP NOT NULL DEFAULT NOW(),
    _origem                      VARCHAR(20) NOT NULL DEFAULT 'csv',
    _hash_linha                  VARCHAR(64)
);

CREATE INDEX idx_bronze_user_adguid ON bronze.crm_user_base(activedirectoryguid);
CREATE INDEX idx_bronze_user_fullname ON bronze.crm_user_base(fullname);
CREATE INDEX idx_bronze_user_buid ON bronze.crm_user_base(businessunitid);

-- ---------------------------------------------------------------------
-- bronze.lv_tpaccountbase
-- 65.492 linhas × ~50 colunas relevantes — A PONTE CRM ↔ Sirix
-- ⚠️ EXCLUI lv_password
-- ---------------------------------------------------------------------
CREATE TABLE bronze.lv_tpaccountbase (
    lv_tpaccountid              VARCHAR(36) NOT NULL,
    lv_name                     BIGINT NOT NULL,         -- = LOGIN do Sirix
    lv_accountid                VARCHAR(36),             -- FK → crm_account_base
    lv_tempname                 VARCHAR(50),
    lv_basecurrencyid           VARCHAR(36),
    lv_leverage                 INTEGER,
    lv_balanceusd               NUMERIC(20,8),
    lv_balancebasecurrency      NUMERIC(20,8),
    lv_equity                   NUMERIC(20,8),
    lv_pl                       NUMERIC(20,8),
    lv_marginlevel              NUMERIC(15,4),
    lv_marginstatus             INTEGER,
    lv_numberofallpositions     INTEGER,
    lv_numberofopenedpositions  INTEGER,
    lv_totaltradingamount       NUMERIC(25,8),
    lv_type                     INTEGER,
    lv_tradingtype              INTEGER,
    lv_tradeserverhostname      INTEGER,
    lv_tradingplatformid        VARCHAR(36),
    ownerid                     VARCHAR(36),
    owningbusinessunit          VARCHAR(36),
    lv_platformreadonly         BOOLEAN,
    lv_isonline                 BOOLEAN,
    lv_isloggedinfromweb        BOOLEAN,
    lv_lastlogin                TIMESTAMP,
    lv_lastdailydate            TIMESTAMP,
    lv_dateoflastbonus          TIMESTAMP,
    lv_dateoflastbonus_date     TIMESTAMP,
    lv_deletedfromtradingplatform   BOOLEAN,
    lv_disabledonthetradingplatform BOOLEAN,
    createdon                   TIMESTAMP,
    modifiedon                  TIMESTAMP,
    createdby                   VARCHAR(36),
    modifiedby                  VARCHAR(36),
    statecode                   INTEGER,
    statuscode                  INTEGER,
    owneridtype                 INTEGER,
    -- técnicas
    _ingestao_ts                TIMESTAMP NOT NULL DEFAULT NOW(),
    _origem                     VARCHAR(20) NOT NULL DEFAULT 'csv',
    _hash_linha                 VARCHAR(64)
);

CREATE INDEX idx_bronze_tp_lv_name ON bronze.lv_tpaccountbase(lv_name);
CREATE INDEX idx_bronze_tp_accountid ON bronze.lv_tpaccountbase(lv_accountid);
CREATE INDEX idx_bronze_tp_modifiedon ON bronze.lv_tpaccountbase(modifiedon);
CREATE INDEX idx_bronze_tp_pk ON bronze.lv_tpaccountbase(lv_tpaccountid);

-- ---------------------------------------------------------------------
-- bronze.lv_monetarytransactionbase
-- 10.032 linhas × ~50 colunas relevantes (das 109 da fonte)
-- ---------------------------------------------------------------------
CREATE TABLE bronze.lv_monetarytransactionbase (
    lv_monetarytransactionid              VARCHAR(36) NOT NULL,
    lv_name                               VARCHAR(100),     -- fonte: até 52 chars observados
    lv_type                               INTEGER,
    lv_internaltype                       INTEGER,
    lv_accountid                          VARCHAR(36),
    lv_tpaccountid                        VARCHAR(36),
    lv_tradingplatformtransactionid       BIGINT,
    lv_tradingplatformoppositetransactionid BIGINT,
    lv_amount                             NUMERIC(15,2),
    lv_usdvalue                           NUMERIC(15,2),
    lv_netdepositusdvalue                 NUMERIC(15,2),
    transactioncurrencyid                 VARCHAR(36),
    exchangerate                          NUMERIC(15,10),
    lv_firsttimedeposit                   BOOLEAN,
    lv_internaltransactionstatus          INTEGER,
    lv_transactionapproved                BOOLEAN,
    lv_managementapproval                 BOOLEAN,
    lv_autoapproval                       BOOLEAN,
    lv_approvedon                         TIMESTAMP,
    lv_updatetpon                         TIMESTAMP,
    lv_updatetponapprove                  BOOLEAN,
    lv_paid                               BOOLEAN,
    lv_expiraydate                        TIMESTAMP,
    lv_methodofpayment                    INTEGER,
    lv_cardacquirerreference              VARCHAR(50),
    lv_cardissuingbank                    VARCHAR(100),
    lv_cardholdername                     VARCHAR(100),
    lv_comment                            VARCHAR(255),
    lv_internalcomment                    VARCHAR(500),
    lv_additionalinfo                     TEXT,
    lv_transactioncaseid                  VARCHAR(36),
    lv_transactionreference               VARCHAR(100),
    lv_lastactionid                       VARCHAR(36),
    lv_relatedtransactionid               VARCHAR(36),
    lv_oppositeaccountid                  VARCHAR(36),
    lv_transfertotpaccount                VARCHAR(36),
    lv_mttransactionowner                 VARCHAR(36),
    ownerid                               VARCHAR(36),
    owningbusinessunit                    VARCHAR(36),
    createdon                             TIMESTAMP,
    modifiedon                            TIMESTAMP,
    createdby                             VARCHAR(36),
    modifiedby                            VARCHAR(36),
    statecode                             INTEGER,
    statuscode                            INTEGER,
    -- técnicas
    _ingestao_ts                          TIMESTAMP NOT NULL DEFAULT NOW(),
    _origem                               VARCHAR(20) NOT NULL DEFAULT 'csv',
    _hash_linha                           VARCHAR(64)
);

CREATE INDEX idx_bronze_mt_pk ON bronze.lv_monetarytransactionbase(lv_monetarytransactionid);
CREATE INDEX idx_bronze_mt_tpaccount ON bronze.lv_monetarytransactionbase(lv_tpaccountid);
CREATE INDEX idx_bronze_mt_account ON bronze.lv_monetarytransactionbase(lv_accountid);
CREATE INDEX idx_bronze_mt_ticket ON bronze.lv_monetarytransactionbase(lv_tradingplatformtransactionid);
CREATE INDEX idx_bronze_mt_modifiedon ON bronze.lv_monetarytransactionbase(modifiedon);
CREATE INDEX idx_bronze_mt_ftd ON bronze.lv_monetarytransactionbase(lv_firsttimedeposit) WHERE lv_firsttimedeposit = TRUE;

-- ---------------------------------------------------------------------
-- bronze.sirix_users_view
-- 30.000 linhas × ~25 colunas relevantes (das 36 da fonte)
-- ---------------------------------------------------------------------
CREATE TABLE bronze.sirix_users_view (
    login                BIGINT NOT NULL,
    name                 VARCHAR(200),
    "group"              VARCHAR(50),
    balance              NUMERIC(15,2),
    equity               NUMERIC(15,2),
    margin               NUMERIC(15,2),
    margin_free          NUMERIC(15,2),
    margin_level         NUMERIC(15,4),
    credit               NUMERIC(15,2),
    prevbalance          NUMERIC(15,2),
    prevmonthbalance     INTEGER,
    currency             VARCHAR(3),
    leverage             INTEGER,
    enable               SMALLINT,
    enable_change_pass   SMALLINT,
    enable_readonly      SMALLINT,
    lastdate             TIMESTAMP,
    modify_time          TIMESTAMP,
    regdate              TIMESTAMP,
    agent_account        INTEGER,
    interestrate         INTEGER,
    send_reports         SMALLINT,
    taxes                INTEGER,
    "timestamp"          INTEGER,
    user_color           INTEGER,
    -- técnicas
    _ingestao_ts         TIMESTAMP NOT NULL DEFAULT NOW(),
    _origem              VARCHAR(20) NOT NULL DEFAULT 'csv',
    _hash_linha          VARCHAR(64)
);

CREATE INDEX idx_bronze_su_login ON bronze.sirix_users_view(login);
CREATE INDEX idx_bronze_su_modify ON bronze.sirix_users_view(modify_time);
CREATE INDEX idx_bronze_su_group ON bronze.sirix_users_view("group");

-- ---------------------------------------------------------------------
-- bronze.sirix_trades_view
-- 30.000 linhas × 28 colunas — eventos (trades + movimentações CMD 6/7)
-- ---------------------------------------------------------------------
CREATE TABLE bronze.sirix_trades_view (
    ticket               BIGINT NOT NULL,
    account_id           BIGINT,
    login                BIGINT,
    broker_id            VARCHAR(36),
    cmd                  INTEGER,
    symbol               VARCHAR(20),
    volume               BIGINT,
    open_time            TIMESTAMP,
    close_time           TIMESTAMP,
    open_price           NUMERIC(15,5),
    close_price          NUMERIC(15,5),
    open_position_id     BIGINT,
    profit               NUMERIC(15,2),
    commission           NUMERIC(10,2),
    commission_agent     INTEGER,
    swaps                NUMERIC(15,2),
    taxes                INTEGER,
    sl                   NUMERIC(15,5),
    tp                   NUMERIC(15,5),
    expiration           TIMESTAMP,
    modify_time          TIMESTAMP,
    "comment"            VARCHAR(255),
    conv_rate1           NUMERIC(15,5),
    conv_rate2           NUMERIC(15,5),
    margin_rate          INTEGER,
    digits               INTEGER,
    internal_id          INTEGER,
    "timestamp"          INTEGER,
    -- técnicas
    _ingestao_ts         TIMESTAMP NOT NULL DEFAULT NOW(),
    _origem              VARCHAR(20) NOT NULL DEFAULT 'csv',
    _hash_linha          VARCHAR(64)
);

CREATE INDEX idx_bronze_trades_ticket ON bronze.sirix_trades_view(ticket);
CREATE INDEX idx_bronze_trades_login ON bronze.sirix_trades_view(login);
CREATE INDEX idx_bronze_trades_cmd ON bronze.sirix_trades_view(cmd);
CREATE INDEX idx_bronze_trades_opentime ON bronze.sirix_trades_view(open_time);
CREATE INDEX idx_bronze_trades_modify ON bronze.sirix_trades_view(modify_time);
CREATE INDEX idx_bronze_trades_openposid ON bronze.sirix_trades_view(open_position_id);

-- ---------------------------------------------------------------------
-- bronze.sirix_daily_view
-- 30.000 linhas × 14 colunas — snapshots EOD por conta × dia
-- ---------------------------------------------------------------------
CREATE TABLE bronze.sirix_daily_view (
    "time"           TIMESTAMP NOT NULL,
    login            BIGINT NOT NULL,
    balance          NUMERIC(15,2),
    balance_prev     NUMERIC(15,2),
    equity           NUMERIC(15,2),
    margin           NUMERIC(15,2),
    margin_free      NUMERIC(15,2),
    credit           NUMERIC(15,2),
    deposit          NUMERIC(15,2),   -- PRD pode conter centavos com vírgula decimal
    profit           NUMERIC(15,2),
    profit_closed    NUMERIC(15,2),
    "group"          VARCHAR(50),
    modify_time      TIMESTAMP,
    bank             NUMERIC(15,2),   -- 100% NULL atualmente
    -- técnicas
    _ingestao_ts     TIMESTAMP NOT NULL DEFAULT NOW(),
    _origem          VARCHAR(20) NOT NULL DEFAULT 'csv',
    _hash_linha      VARCHAR(64)
);

-- Índices REMOVIDOS (2026-06-02): bronze.sirix_daily_view é pass-through, lido
-- apenas por um full-scan INSERT em silver; gold nunca lê bronze. Os 3 índices
-- (~296 MB) não serviam a nenhuma query do pipeline e só custavam manutenção ao
-- inserir 4,7M linhas. idx_bronze_daily_time ainda era redundante (prefixo do PK).
-- Quando a curva de equity em gold for construída, criar o índice correto na hora
-- (provável (login, "time") para curva por conta). Ver wiki/topics/camada-silver.md.
-- CREATE INDEX idx_bronze_daily_pk ON bronze.sirix_daily_view("time", login);
-- CREATE INDEX idx_bronze_daily_login ON bronze.sirix_daily_view(login);
-- CREATE INDEX idx_bronze_daily_time ON bronze.sirix_daily_view("time");
