-- =====================================================================
-- BRONZE BOOTSTRAP INSERT — stg_raw → bronze
-- Estratégia: CAST explícito coluna a coluna, NULLIF para strings vazias,
--             MD5(ROW(...)::TEXT) como _hash_linha para auditoria.
-- Execução: psql -U postgres -d db_brokerlab -f bronze_bootstrap_insert.sql
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.safe_ts(v TEXT)
RETURNS TIMESTAMP
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT NULLIF(replace(NULLIF(btrim(v), ''), ',', '.'), '')::TIMESTAMP;
$$;

CREATE OR REPLACE FUNCTION pg_temp.safe_ts_null_epoch(v TEXT)
RETURNS TIMESTAMP
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT CASE
        WHEN NULLIF(btrim(v), '') IN ('1970-01-01 00:00:00', '1970-01-01 00:00:00,000') THEN NULL
        ELSE pg_temp.safe_ts(v)
    END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.safe_numeric(v TEXT)
RETURNS NUMERIC
LANGUAGE SQL
IMMUTABLE
AS $$
    SELECT NULLIF(replace(NULLIF(btrim(v), ''), ',', '.'), '')::NUMERIC;
$$;

-- ---------------------------------------------------------------------
-- 1. bronze.crm_account_base  (30.000 linhas)
-- ---------------------------------------------------------------------
INSERT INTO bronze.crm_account_base (
    accountid, buname, conversion_bu, conversion_owner, country,
    createdon, leadstatustext, lv_affiliate, lv_campaignid,
    lv_conversionownerid, lv_countryid, lv_firstname, lv_ftdexist,
    lv_language, lv_lastname, lv_leadstatus, lv_leadstatusreason,
    lv_maintpaccountid, lv_retentionownerid, lv_sourceid,
    modifiedon, name, lv_subaffiliate, ownerid, owningbusinessunit,
    parent, retention_bu, retention_owner,
    _origem, _hash_linha
)
SELECT
    NULLIF("AccountId", ''),
    NULLIF("BUName", ''),
    NULLIF("Conversion BU", ''),
    NULLIF("Conversion Owner", ''),
    NULLIF("Country", ''),
    pg_temp.safe_ts("CreatedOn"),
    NULLIF("LeadStatusText", ''),
    NULLIF("Lv_Affiliate", ''),
    NULLIF("Lv_campaignId", ''),
    NULLIF("lv_conversionownerid", ''),
    NULLIF("lv_countryid", ''),
    NULLIF("Lv_FirstName", ''),
    NULLIF("Lv_FTDExist", '')::BOOLEAN,
    NULLIF("Lv_Language", ''),
    NULLIF("Lv_LastName", ''),
    NULLIF("Lv_LeadStatus", '')::INTEGER,
    NULLIF("Lv_LeadStatusReason", '')::INTEGER,
    NULLIF("lv_maintpaccountid", ''),
    NULLIF("lv_retentionownerid", ''),
    NULLIF("lv_SourceID", '')::INTEGER,
    pg_temp.safe_ts("ModifiedOn"),
    NULLIF("Name", ''),
    NULLIF("Lv_SubAffiliate", ''),
    NULLIF("OwnerId", ''),
    NULLIF("OwningBusinessUnit", ''),
    NULLIF("Parent", ''),
    NULLIF("Retention BU", ''),
    NULLIF("Retention Owner", ''),
    'csv',
    MD5(CAST(ROW(
        "AccountId","BUName","Conversion BU","Conversion Owner","Country",
        "CreatedOn","LeadStatusText","Lv_Affiliate","Lv_campaignId",
        "lv_conversionownerid","lv_countryid","Lv_FirstName","Lv_FTDExist",
        "Lv_Language","Lv_LastName","Lv_LeadStatus","Lv_LeadStatusReason",
        "lv_maintpaccountid","lv_retentionownerid","lv_SourceID",
        "ModifiedOn","Name","Lv_SubAffiliate","OwnerId","OwningBusinessUnit",
        "Parent","Retention BU","Retention Owner"
    ) AS TEXT))
FROM stg_raw.crm_account_base;

-- ---------------------------------------------------------------------
-- 2. bronze.crm_user_base  (216 linhas)
--    EXCLUI: lv_password (dado sensível — nunca sai de stg_raw)
-- ---------------------------------------------------------------------
INSERT INTO bronze.crm_user_base (
    activedirectoryguid, identityid, businessunitid, fullname,
    firstname, lastname, domainname, createdby, createdon,
    isdisabled, lv_isactive, lv_isconversionowner, lv_isretentionowner,
    lv_isbusinessunitowner, lv_cancreatetpaccount, lv_candeletetpaccount,
    lv_candisableenabletpaccount, lv_canhandletransactions,
    lv_canusecustomdeposit, isactivedirectoryuser, invitestatuscode,
    incomingemaildeliverymethod, lv_leadassignmentfrequency,
    _origem, _hash_linha
)
SELECT
    NULLIF("ActiveDirectoryGuid", ''),
    NULLIF("IdentityId", '')::INTEGER,
    NULLIF("BusinessUnitId", ''),
    NULLIF("FullName", ''),
    NULLIF("FirstName", ''),
    NULLIF("LastName", ''),
    NULLIF("DomainName", ''),
    NULLIF("CreatedBy", ''),
    pg_temp.safe_ts("CreatedOn"),
    NULLIF("IsDisabled", '')::BOOLEAN,
    NULLIF("Lv_IsActive", ''),
    NULLIF("Lv_IsConversionOwner", ''),
    NULLIF("Lv_IsRetentionOwner", ''),
    NULLIF("lv_IsBusinessUnitOwner", ''),
    NULLIF("Lv_CanCreateTPAccount", ''),
    NULLIF("Lv_CanDeleteTPAccount", ''),
    NULLIF("Lv_candisableenableTPaccount", ''),
    NULLIF("Lv_CanHandleTransactions", ''),
    NULLIF("Lv_CanUseCustomDeposit", ''),
    NULLIF("IsActiveDirectoryUser", '')::BOOLEAN,
    NULLIF("InviteStatusCode", '')::INTEGER,
    NULLIF("IncomingEmailDeliveryMethod", '')::INTEGER,
    NULLIF("lv_LeadAssignmentFrequency", '')::INTEGER,
    'csv',
    MD5(CAST(ROW(
        "ActiveDirectoryGuid","IdentityId","BusinessUnitId","FullName",
        "FirstName","LastName","DomainName","CreatedBy","CreatedOn",
        "IsDisabled","Lv_IsActive","Lv_IsConversionOwner","Lv_IsRetentionOwner",
        "lv_IsBusinessUnitOwner","Lv_CanCreateTPAccount","Lv_CanDeleteTPAccount",
        "Lv_candisableenableTPaccount","Lv_CanHandleTransactions","Lv_CanUseCustomDeposit",
        "IsActiveDirectoryUser","InviteStatusCode","IncomingEmailDeliveryMethod",
        "lv_LeadAssignmentFrequency"
    ) AS TEXT))
FROM stg_raw.crm_user_base;

-- ---------------------------------------------------------------------
-- 3. bronze.lv_tpaccountbase  (65.492 linhas)
--    EXCLUI: lv_password (dado sensível)
-- ---------------------------------------------------------------------
INSERT INTO bronze.lv_tpaccountbase (
    lv_tpaccountid, lv_name, lv_accountid, lv_tempname,
    lv_basecurrencyid, lv_leverage, lv_balanceusd, lv_balancebasecurrency,
    lv_equity, lv_pl, lv_marginlevel, lv_marginstatus,
    lv_numberofallpositions, lv_numberofopenedpositions, lv_totaltradingamount,
    lv_type, lv_tradingtype, lv_tradeserverhostname, lv_tradingplatformid,
    ownerid, owningbusinessunit, lv_platformreadonly, lv_isonline,
    lv_isloggedinfromweb, lv_lastlogin, lv_lastdailydate,
    lv_dateoflastbonus, lv_dateoflastbonus_date,
    lv_deletedfromtradingplatform, lv_disabledonthetradingplatform,
    createdon, modifiedon, createdby, modifiedby,
    statecode, statuscode, owneridtype,
    _origem, _hash_linha
)
SELECT
    NULLIF("Lv_tpaccountId", ''),
    NULLIF("Lv_name", '')::BIGINT,
    NULLIF("lv_accountid", ''),
    NULLIF("Lv_TempName", ''),
    NULLIF("lv_basecurrencyid", ''),
    NULLIF("Lv_leverage", '')::INTEGER,
    pg_temp.safe_numeric("lv_balanceusd")::NUMERIC(20,8),
    pg_temp.safe_numeric("lv_BalanceBaseCurrency")::NUMERIC(20,8),
    pg_temp.safe_numeric("lv_equity")::NUMERIC(20,8),
    pg_temp.safe_numeric("lv_pl")::NUMERIC(20,8),
    pg_temp.safe_numeric("lv_marginlevel")::NUMERIC(15,4),
    NULLIF("lv_MarginStatus", '')::INTEGER,
    NULLIF("lv_numberofallpositions", '')::INTEGER,
    NULLIF("lv_numberofopenedpositions", '')::INTEGER,
    pg_temp.safe_numeric("lv_totaltradingamount")::NUMERIC(25,8),
    NULLIF("lv_Type", '')::INTEGER,
    NULLIF("lv_tradingtype", '')::INTEGER,
    NULLIF("lv_tradeserverhostname", '')::INTEGER,
    NULLIF("lv_tradingplatformid", ''),
    NULLIF("OwnerId", ''),
    NULLIF("OwningBusinessUnit", ''),
    NULLIF("lv_platformreadonly", '')::BOOLEAN,
    NULLIF("lv_isonline", '')::BOOLEAN,
    NULLIF("lv_isloggedinfromweb", '')::BOOLEAN,
    pg_temp.safe_ts("Lv_LastLogin"),
    pg_temp.safe_ts("lv_LastDailyDate"),
    pg_temp.safe_ts("lv_DateofLastBonus"),
    pg_temp.safe_ts("lv_DateofLastBonus_Date"),
    NULLIF("Lv_Deletedfromtradingplatform", '')::BOOLEAN,
    NULLIF("Lv_disabledonthetradingplatform", '')::BOOLEAN,
    pg_temp.safe_ts("CreatedOn"),
    pg_temp.safe_ts("ModifiedOn"),
    NULLIF("CreatedBy", ''),
    NULLIF("ModifiedBy", ''),
    NULLIF("statecode", '')::INTEGER,
    NULLIF("statuscode", '')::INTEGER,
    NULLIF("OwnerIdType", '')::INTEGER,
    'csv',
    MD5(CAST(ROW(
        "Lv_tpaccountId","Lv_name","lv_accountid","Lv_TempName",
        "lv_basecurrencyid","Lv_leverage","lv_balanceusd","lv_BalanceBaseCurrency",
        "lv_equity","lv_pl","lv_marginlevel","lv_MarginStatus",
        "lv_numberofallpositions","lv_numberofopenedpositions","lv_totaltradingamount",
        "lv_Type","lv_tradingtype","lv_tradeserverhostname","lv_tradingplatformid",
        "OwnerId","OwningBusinessUnit","lv_platformreadonly","lv_isonline",
        "lv_isloggedinfromweb","Lv_LastLogin","lv_LastDailyDate",
        "lv_DateofLastBonus","lv_DateofLastBonus_Date",
        "Lv_Deletedfromtradingplatform","Lv_disabledonthetradingplatform",
        "CreatedOn","ModifiedOn","CreatedBy","ModifiedBy",
        "statecode","statuscode","OwnerIdType"
    ) AS TEXT))
FROM stg_raw.lv_tpaccountbase;

-- ---------------------------------------------------------------------
-- 4. bronze.lv_monetarytransactionbase  (10.032 linhas)
-- ---------------------------------------------------------------------
INSERT INTO bronze.lv_monetarytransactionbase (
    lv_monetarytransactionid, lv_name, lv_type, lv_internaltype,
    lv_accountid, lv_tpaccountid,
    lv_tradingplatformtransactionid, lv_tradingplatformoppositetransactionid,
    lv_amount, lv_usdvalue, lv_netdepositusdvalue,
    transactioncurrencyid, exchangerate,
    lv_firsttimedeposit, lv_internaltransactionstatus,
    lv_transactionapproved, lv_managementapproval, lv_autoapproval,
    lv_approvedon, lv_updatetpon, lv_updatetponapprove,
    lv_paid, lv_expiraydate, lv_methodofpayment,
    lv_cardacquirerreference, lv_cardissuingbank, lv_cardholdername,
    lv_comment, lv_internalcomment, lv_additionalinfo,
    lv_transactioncaseid, lv_transactionreference,
    lv_lastactionid, lv_relatedtransactionid,
    lv_oppositeaccountid, lv_transfertotpaccount, lv_mttransactionowner,
    ownerid, owningbusinessunit,
    createdon, modifiedon, createdby, modifiedby,
    statecode, statuscode,
    _origem, _hash_linha
)
SELECT
    NULLIF("Lv_monetarytransactionId", ''),
    NULLIF("Lv_name", ''),
    NULLIF("Lv_Type", '')::INTEGER,
    NULLIF("Lv_InternalType", '')::INTEGER,
    NULLIF("lv_accountid", ''),
    NULLIF("lv_tpaccountid", ''),
    NULLIF("lv_TradingPlatformTransactionId", '')::BIGINT,
    NULLIF("lv_TradingPlatformOppositeTransactionId", '')::BIGINT,
    pg_temp.safe_numeric("Lv_Amount")::NUMERIC(15,2),
    pg_temp.safe_numeric("Lv_USDValue")::NUMERIC(15,2),
    pg_temp.safe_numeric("lv_NetDepositUSDValue")::NUMERIC(15,2),
    NULLIF("TransactionCurrencyId", ''),
    pg_temp.safe_numeric("ExchangeRate")::NUMERIC(15,10),
    NULLIF("Lv_FirstTimeDeposit", '')::BOOLEAN,
    NULLIF("lv_internaltransactionstatus", '')::INTEGER,
    NULLIF("Lv_TransactionApproved", '')::BOOLEAN,
    NULLIF("Lv_ManagementApproval", '')::BOOLEAN,
    NULLIF("lv_AutoApproval", '')::BOOLEAN,
    pg_temp.safe_ts("Lv_ApprovedOn"),
    pg_temp.safe_ts("Lv_UpdateTPon"),
    NULLIF("Lv_UpdateTPOnApprove", '')::BOOLEAN,
    NULLIF("Lv_Paid", '')::BOOLEAN,
    pg_temp.safe_ts("Lv_ExpirayDate"),
    NULLIF("Lv_MethodofPayment", '')::INTEGER,
    NULLIF("Lv_CardAcquirerReference", ''),
    NULLIF("Lv_CardIssuingBank", ''),
    NULLIF("Lv_CardHolderName", ''),
    NULLIF("Lv_Comment", ''),
    NULLIF("Lv_internalcomment", ''),
    NULLIF("lv_AdditionalInfo", ''),
    NULLIF("lv_transactioncaseid", ''),
    NULLIF("Lv_TransactionReference", ''),
    NULLIF("lv_lastactionid", ''),
    NULLIF("lv_relatedtransactionid", ''),
    NULLIF("lv_oppositeaccountid", ''),
    NULLIF("lv_transfertotpaccount", ''),
    NULLIF("lv_MTTransactionOwner", ''),
    NULLIF("OwnerId", ''),
    NULLIF("OwningBusinessUnit", ''),
    pg_temp.safe_ts("CreatedOn"),
    pg_temp.safe_ts("ModifiedOn"),
    NULLIF("CreatedBy", ''),
    NULLIF("ModifiedBy", ''),
    NULLIF("statecode", '')::INTEGER,
    NULLIF("statuscode", '')::INTEGER,
    'csv',
    MD5(CAST(ROW(
        "Lv_monetarytransactionId","Lv_name","Lv_Type","Lv_InternalType",
        "lv_accountid","lv_tpaccountid",
        "lv_TradingPlatformTransactionId","lv_TradingPlatformOppositeTransactionId",
        "Lv_Amount","Lv_USDValue","lv_NetDepositUSDValue",
        "TransactionCurrencyId","ExchangeRate",
        "Lv_FirstTimeDeposit","lv_internaltransactionstatus",
        "Lv_TransactionApproved","Lv_ManagementApproval","lv_AutoApproval",
        "Lv_ApprovedOn","Lv_UpdateTPon","Lv_UpdateTPOnApprove",
        "Lv_Paid","Lv_ExpirayDate","Lv_MethodofPayment",
        "Lv_CardAcquirerReference","Lv_CardIssuingBank","Lv_CardHolderName",
        "Lv_Comment","Lv_internalcomment","lv_AdditionalInfo",
        "lv_transactioncaseid","Lv_TransactionReference",
        "lv_lastactionid","lv_relatedtransactionid",
        "lv_oppositeaccountid","lv_transfertotpaccount","lv_MTTransactionOwner",
        "OwnerId","OwningBusinessUnit",
        "CreatedOn","ModifiedOn","CreatedBy","ModifiedBy",
        "statecode","statuscode"
    ) AS TEXT))
FROM stg_raw.lv_monetarytransactionbase;

-- ---------------------------------------------------------------------
-- 5. bronze.sirix_users_view  (30.000 linhas)
-- ---------------------------------------------------------------------
INSERT INTO bronze.sirix_users_view (
    login, name, "group",
    balance, equity, margin, margin_free, margin_level,
    credit, prevbalance, prevmonthbalance,
    currency, leverage,
    enable, enable_change_pass, enable_readonly,
    lastdate, modify_time, regdate,
    agent_account, interestrate, send_reports,
    taxes, "timestamp", user_color,
    _origem, _hash_linha
)
SELECT
    NULLIF("LOGIN", '')::BIGINT,
    NULLIF("NAME", ''),
    NULLIF("GROUP", ''),
    pg_temp.safe_numeric("BALANCE")::NUMERIC(15,2),
    pg_temp.safe_numeric("EQUITY")::NUMERIC(15,2),
    pg_temp.safe_numeric("MARGIN")::NUMERIC(15,2),
    pg_temp.safe_numeric("MARGIN_FREE")::NUMERIC(15,2),
    pg_temp.safe_numeric("MARGIN_LEVEL")::NUMERIC(15,4),
    pg_temp.safe_numeric("CREDIT")::NUMERIC(15,2),
    pg_temp.safe_numeric("PREVBALANCE")::NUMERIC(15,2),
    NULLIF("PREVMONTHBALANCE", '')::INTEGER,
    NULLIF("CURRENCY", ''),
    NULLIF("LEVERAGE", '')::INTEGER,
    NULLIF("ENABLE", '')::SMALLINT,
    NULLIF("ENABLE_CHANGE_PASS", '')::SMALLINT,
    NULLIF("ENABLE_READONLY", '')::SMALLINT,
    pg_temp.safe_ts("LASTDATE"),
    pg_temp.safe_ts("MODIFY_TIME"),
    pg_temp.safe_ts("REGDATE"),
    NULLIF("AGENT_ACCOUNT", '')::INTEGER,
    NULLIF("INTERESTRATE", '')::INTEGER,
    NULLIF("SEND_REPORTS", '')::SMALLINT,
    NULLIF("TAXES", '')::INTEGER,
    NULLIF("TIMESTAMP", '')::INTEGER,
    NULLIF("USER_COLOR", '')::INTEGER,
    'csv',
    MD5(CAST(ROW(
        "LOGIN","NAME","GROUP","BALANCE","EQUITY","MARGIN","MARGIN_FREE",
        "MARGIN_LEVEL","CREDIT","PREVBALANCE","PREVMONTHBALANCE","CURRENCY",
        "LEVERAGE","ENABLE","ENABLE_CHANGE_PASS","ENABLE_READONLY",
        "LASTDATE","MODIFY_TIME","REGDATE","AGENT_ACCOUNT","INTERESTRATE",
        "SEND_REPORTS","TAXES","TIMESTAMP","USER_COLOR"
    ) AS TEXT))
FROM stg_raw.sirix_users_view;

-- ---------------------------------------------------------------------
-- 6. bronze.sirix_trades_view  (30.000 linhas)
--    EXPIRATION: 100% '1970-01-01 00:00:00' na carga de dev → mapeado para NULL
--    OPEN_POSITION_ID: ausente em CMD 6/7 (balance ops) → NULLIF
-- ---------------------------------------------------------------------
INSERT INTO bronze.sirix_trades_view (
    ticket, account_id, login, broker_id, cmd, symbol, volume,
    open_time, close_time, open_price, close_price,
    open_position_id, profit, commission, commission_agent,
    swaps, taxes, sl, tp, expiration, modify_time,
    "comment", conv_rate1, conv_rate2,
    margin_rate, digits, internal_id, "timestamp",
    _origem, _hash_linha
)
SELECT
    NULLIF("TICKET", '')::BIGINT,
    NULLIF("account_id", '')::BIGINT,
    NULLIF("LOGIN", '')::BIGINT,
    NULLIF("broker_id", ''),
    NULLIF("CMD", '')::INTEGER,
    NULLIF("SYMBOL", ''),
    NULLIF("VOLUME", '')::BIGINT,
    pg_temp.safe_ts("OPEN_TIME"),
    pg_temp.safe_ts("CLOSE_TIME"),
    pg_temp.safe_numeric("OPEN_PRICE")::NUMERIC(15,5),
    pg_temp.safe_numeric("CLOSE_PRICE")::NUMERIC(15,5),
    NULLIF("OPEN_POSITION_ID", '')::BIGINT,
    pg_temp.safe_numeric("PROFIT")::NUMERIC(15,2),
    pg_temp.safe_numeric("COMMISSION")::NUMERIC(10,2),
    NULLIF("COMMISSION_AGENT", '')::INTEGER,
    pg_temp.safe_numeric("SWAPS")::NUMERIC(15,2),
    NULLIF("TAXES", '')::INTEGER,
    pg_temp.safe_numeric("SL")::NUMERIC(15,5),
    pg_temp.safe_numeric("TP")::NUMERIC(15,5),
    -- epoch Unix (1970-01-01) indica ausência de expiração em MT4 → NULL
    pg_temp.safe_ts_null_epoch("EXPIRATION"),
    pg_temp.safe_ts("MODIFY_TIME"),
    NULLIF("COMMENT", ''),
    pg_temp.safe_numeric("CONV_RATE1")::NUMERIC(15,5),
    pg_temp.safe_numeric("CONV_RATE2")::NUMERIC(15,5),
    NULLIF("MARGIN_RATE", '')::INTEGER,
    NULLIF("DIGITS", '')::INTEGER,
    NULLIF("INTERNAL_ID", '')::INTEGER,
    NULLIF("TIMESTAMP", '')::INTEGER,
    'csv',
    MD5(CAST(ROW(
        "TICKET","account_id","LOGIN","broker_id","CMD","SYMBOL","VOLUME",
        "OPEN_TIME","CLOSE_TIME","OPEN_PRICE","CLOSE_PRICE","OPEN_POSITION_ID",
        "PROFIT","COMMISSION","COMMISSION_AGENT","SWAPS","TAXES","SL","TP",
        "EXPIRATION","MODIFY_TIME","COMMENT","CONV_RATE1","CONV_RATE2",
        "MARGIN_RATE","DIGITS","INTERNAL_ID","TIMESTAMP"
    ) AS TEXT))
FROM stg_raw.sirix_trades_view;

-- ---------------------------------------------------------------------
-- 7. bronze.sirix_daily_view  (30.000 linhas)
--    BANK: ausente no layout oficial de PRD → reservado como NULL no bronze
-- ---------------------------------------------------------------------
INSERT INTO bronze.sirix_daily_view (
    "time", login, balance, balance_prev, equity,
    margin, margin_free, credit, deposit,
    profit, profit_closed, "group", modify_time, bank,
    _origem, _hash_linha
)
SELECT
    pg_temp.safe_ts("TIME"),
    NULLIF("LOGIN", '')::BIGINT,
    pg_temp.safe_numeric("BALANCE")::NUMERIC(15,2),
    pg_temp.safe_numeric("BALANCE_PREV")::NUMERIC(15,2),
    pg_temp.safe_numeric("EQUITY")::NUMERIC(15,2),
    pg_temp.safe_numeric("MARGIN")::NUMERIC(15,2),
    pg_temp.safe_numeric("MARGIN_FREE")::NUMERIC(15,2),
    pg_temp.safe_numeric("CREDIT")::NUMERIC(15,2),
    pg_temp.safe_numeric("DEPOSIT")::NUMERIC(15,2),
    pg_temp.safe_numeric("PROFIT")::NUMERIC(15,2),
    pg_temp.safe_numeric("PROFIT_CLOSED")::NUMERIC(15,2),
    NULLIF("GROUP", ''),
    pg_temp.safe_ts("MODIFY_TIME"),
    NULL::NUMERIC(15,2),
    'csv',
    MD5(CAST(ROW(
        "TIME","LOGIN","BALANCE","BALANCE_PREV","EQUITY",
        "MARGIN","MARGIN_FREE","CREDIT","DEPOSIT",
        "PROFIT","PROFIT_CLOSED","GROUP","MODIFY_TIME"
    ) AS TEXT))
FROM stg_raw.sirix_daily_view;

COMMIT;

-- ---------------------------------------------------------------------
-- VERIFICAÇÃO PÓS-CARGA
-- ---------------------------------------------------------------------
SELECT schemaname, relname, n_live_tup AS rows
FROM pg_stat_user_tables
WHERE schemaname = 'bronze'
ORDER BY relname;
