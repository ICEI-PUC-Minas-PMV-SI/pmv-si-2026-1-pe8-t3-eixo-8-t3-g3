BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.safe_uuid(value TEXT)
RETURNS UUID
LANGUAGE plpgsql
AS $$
BEGIN
    IF value IS NULL OR btrim(value) = '' THEN
        RETURN NULL;
    END IF;

    IF value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        RETURN value::UUID;
    END IF;

    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION pg_temp.bool_from_text(value TEXT)
RETURNS BOOLEAN
LANGUAGE sql
AS $$
    SELECT CASE
        WHEN value IS NULL THEN NULL
        WHEN lower(btrim(value)) IN ('true', 't', '1', 'yes', 'y') THEN TRUE
        WHEN lower(btrim(value)) IN ('false', 'f', '0', 'no', 'n') THEN FALSE
        ELSE NULL
    END;
$$;

-- Nota: silver.daily_snapshot_clean fora do TRUNCATE — materialização DIFERIDA
-- (ver bloco no fim do arquivo). A tabela permanece vazia até existir consumidor em gold.
TRUNCATE TABLE
    silver.trade_clean,
    silver.sirix_account_clean,
    silver.transaction_clean,
    silver.tpaccount_clean,
    silver.user_clean,
    silver.account_clean
RESTART IDENTITY;

INSERT INTO silver.account_clean (
    account_id,
    name,
    first_name,
    last_name,
    country,
    country_id,
    language_iso,
    lead_status_code,
    lead_status_text,
    lead_status_categoria,
    eh_lead_terminal,
    lead_status_reason_code,
    bu_name,
    bu_parent,
    owning_business_unit,
    conversion_bu,
    conversion_owner_name,
    conversion_owner_key,
    retention_bu,
    retention_owner_name,
    retention_owner_key,
    has_retention_owner,
    main_tp_account_id,
    affiliate_code,
    subaffiliate_code,
    campaign_id,
    source_id,
    owner_id,
    has_ftd,
    created_on,
    modified_on,
    _eh_valido,
    _motivo_invalido,
    _bronze_ingestao_ts,
    _bronze_origem,
    _bronze_hash_linha
)
SELECT
    pg_temp.safe_uuid(b.accountid) AS account_id,
    left(btrim(COALESCE(b.name, 'Unknown')), 200) AS name,
    left(NULLIF(btrim(b.lv_firstname), ''), 100) AS first_name,
    left(NULLIF(btrim(b.lv_lastname), ''), 100) AS last_name,
    left(COALESCE(NULLIF(btrim(regexp_replace(b.country, '[0-9]+$', '')), ''), 'Unknown'), 50) AS country,
    pg_temp.safe_uuid(b.lv_countryid) AS country_id,
    left(lower(NULLIF(btrim(b.lv_language), '')), 5) AS language_iso,
    b.lv_leadstatus::BIGINT AS lead_status_code,
    left(NULLIF(btrim(b.leadstatustext), ''), 100) AS lead_status_text,
    d.categoria AS lead_status_categoria,
    d.eh_terminal AS eh_lead_terminal,
    b.lv_leadstatusreason AS lead_status_reason_code,
    left(NULLIF(btrim(b.buname), ''), 50) AS bu_name,
    left(NULLIF(btrim(b.parent), ''), 50) AS bu_parent,
    pg_temp.safe_uuid(b.owningbusinessunit) AS owning_business_unit,
    left(NULLIF(btrim(b.conversion_bu), ''), 50) AS conversion_bu,
    left(NULLIF(btrim(b.conversion_owner), ''), 100) AS conversion_owner_name,
    left(lower(NULLIF(btrim(b.conversion_owner), '')), 120) AS conversion_owner_key,
    left(NULLIF(btrim(b.retention_bu), ''), 50) AS retention_bu,
    left(NULLIF(btrim(b.retention_owner), ''), 100) AS retention_owner_name,
    left(lower(NULLIF(btrim(b.retention_owner), '')), 120) AS retention_owner_key,
    NULLIF(btrim(b.retention_owner), '') IS NOT NULL AS has_retention_owner,
    pg_temp.safe_uuid(b.lv_maintpaccountid) AS main_tp_account_id,
    left(NULLIF(btrim(b.lv_affiliate), ''), 50) AS affiliate_code,
    left(NULLIF(btrim(b.lv_subaffiliate), ''), 255) AS subaffiliate_code,
    left(NULLIF(btrim(b.lv_campaignid), ''), 200) AS campaign_id,
    b.lv_sourceid AS source_id,
    pg_temp.safe_uuid(b.ownerid) AS owner_id,
    COALESCE(b.lv_ftdexist, FALSE) AS has_ftd,
    b.createdon AS created_on,
    b.modifiedon AS modified_on,
    pg_temp.safe_uuid(b.accountid) IS NOT NULL AS _eh_valido,
    CASE
        WHEN pg_temp.safe_uuid(b.accountid) IS NULL THEN 'account_id inválido'
        WHEN d.codigo IS NULL THEN 'lead_status sem domain'
        ELSE NULL
    END AS _motivo_invalido,
    b._ingestao_ts,
    b._origem,
    b._hash_linha
FROM bronze.crm_account_base b
LEFT JOIN domain.dom_lead_status d
    ON b.lv_leadstatus = d.codigo;

INSERT INTO silver.user_clean (
    active_directory_guid,
    identity_id,
    business_unit_id,
    full_name,
    full_name_key,
    first_name,
    last_name,
    email,
    is_disabled,
    is_active,
    is_conversion_owner,
    is_retention_owner,
    is_business_unit_owner,
    can_create_tp_account,
    can_delete_tp_account,
    can_disable_enable_tp_account,
    can_handle_transactions,
    can_use_custom_deposit,
    incoming_email_delivery_method,
    lead_assignment_frequency,
    created_on,
    _eh_valido,
    _motivo_invalido,
    _bronze_ingestao_ts,
    _bronze_origem,
    _bronze_hash_linha
)
SELECT
    pg_temp.safe_uuid(b.activedirectoryguid),
    b.identityid,
    pg_temp.safe_uuid(b.businessunitid),
    left(btrim(COALESCE(b.fullname, 'Unknown')), 200),
    left(lower(NULLIF(btrim(b.fullname), '')), 220),
    left(NULLIF(btrim(b.firstname), ''), 100),
    left(NULLIF(btrim(b.lastname), ''), 100),
    left(NULLIF(btrim(b.domainname), ''), 255),
    COALESCE(b.isdisabled, FALSE),
    pg_temp.bool_from_text(b.lv_isactive),
    pg_temp.bool_from_text(b.lv_isconversionowner),
    pg_temp.bool_from_text(b.lv_isretentionowner),
    pg_temp.bool_from_text(b.lv_isbusinessunitowner),
    pg_temp.bool_from_text(b.lv_cancreatetpaccount),
    pg_temp.bool_from_text(b.lv_candeletetpaccount),
    pg_temp.bool_from_text(b.lv_candisableenabletpaccount),
    pg_temp.bool_from_text(b.lv_canhandletransactions),
    pg_temp.bool_from_text(b.lv_canusecustomdeposit),
    b.incomingemaildeliverymethod,
    b.lv_leadassignmentfrequency,
    b.createdon,
    pg_temp.safe_uuid(b.activedirectoryguid) IS NOT NULL,
    CASE
        WHEN pg_temp.safe_uuid(b.activedirectoryguid) IS NULL THEN 'active_directory_guid inválido'
        WHEN pg_temp.safe_uuid(b.businessunitid) IS NULL THEN 'business_unit_id inválido'
        ELSE NULL
    END,
    b._ingestao_ts,
    b._origem,
    b._hash_linha
FROM bronze.crm_user_base b;

INSERT INTO silver.tpaccount_clean (
    tp_account_id,
    sirix_login,
    crm_account_id,
    sirix_group,
    base_currency,
    base_currency_guid,
    leverage,
    balance_usd,
    balance_base,
    equity,
    pnl_acumulado,
    margin_level,
    margin_status,
    eh_margin_call,
    num_total_positions,
    num_open_positions,
    total_trading_amount_usd,
    tp_type,
    eh_conta_especial,
    trading_type,
    trade_server_hostname,
    trading_platform_id,
    owner_id,
    owning_business_unit,
    eh_readonly,
    eh_online,
    eh_logged_in_from_web,
    last_login,
    last_daily_ts,
    last_bonus_ts,
    last_bonus_date_ts,
    eh_deletada,
    eh_desabilitada,
    state_code,
    status_code,
    created_by,
    modified_by,
    created_on,
    modified_on,
    _eh_valido,
    _motivo_invalido,
    _eh_suspeito,
    _motivo_suspeito,
    _bronze_ingestao_ts,
    _bronze_origem,
    _bronze_hash_linha
)
SELECT
    pg_temp.safe_uuid(b.lv_tpaccountid),
    b.lv_name,
    pg_temp.safe_uuid(b.lv_accountid),
    left(NULLIF(btrim(b.lv_tempname), ''), 50),
    COALESCE(d.iso_code, 'UNK'),
    pg_temp.safe_uuid(b.lv_basecurrencyid),
    b.lv_leverage,
    b.lv_balanceusd,
    b.lv_balancebasecurrency,
    b.lv_equity,
    b.lv_pl,
    b.lv_marginlevel,
    b.lv_marginstatus,
    b.lv_marginstatus = 2,
    b.lv_numberofallpositions,
    b.lv_numberofopenedpositions,
    b.lv_totaltradingamount,
    b.lv_type,
    b.lv_type = 1,
    b.lv_tradingtype,
    b.lv_tradeserverhostname,
    pg_temp.safe_uuid(b.lv_tradingplatformid),
    pg_temp.safe_uuid(b.ownerid),
    pg_temp.safe_uuid(b.owningbusinessunit),
    COALESCE(b.lv_platformreadonly, FALSE),
    COALESCE(b.lv_isonline, FALSE),
    COALESCE(b.lv_isloggedinfromweb, FALSE),
    b.lv_lastlogin,
    b.lv_lastdailydate,
    b.lv_dateoflastbonus,
    b.lv_dateoflastbonus_date,
    COALESCE(b.lv_deletedfromtradingplatform, FALSE),
    COALESCE(b.lv_disabledonthetradingplatform, FALSE),
    b.statecode,
    b.statuscode,
    pg_temp.safe_uuid(b.createdby),
    pg_temp.safe_uuid(b.modifiedby),
    b.createdon,
    b.modifiedon,
    pg_temp.safe_uuid(b.lv_tpaccountid) IS NOT NULL,
    CASE
        WHEN pg_temp.safe_uuid(b.lv_tpaccountid) IS NULL THEN 'tp_account_id inválido'
        WHEN d.currency_guid IS NULL THEN 'base_currency sem domain'
        ELSE NULL
    END,
    COALESCE(ABS(b.lv_totaltradingamount), 0) > 1000000000,
    CASE WHEN COALESCE(ABS(b.lv_totaltradingamount), 0) > 1000000000 THEN 'total_trading_amount extremo' END,
    b._ingestao_ts,
    b._origem,
    b._hash_linha
FROM bronze.lv_tpaccountbase b
LEFT JOIN domain.dom_currency d
    ON upper(b.lv_basecurrencyid) = upper(d.currency_guid);

INSERT INTO silver.transaction_clean (
    transaction_id,
    transaction_name,
    transaction_type_code,
    transaction_type_name,
    internal_type_code,
    transaction_type_categoria,
    sinal_financeiro,
    eh_deposito,
    eh_withdrawal,
    eh_bonus,
    eh_credit,
    eh_debit,
    eh_reversal,
    signed_usd_value,
    crm_account_id,
    tp_account_id,
    sirix_ticket,
    opposite_ticket,
    amount_original,
    usd_value,
    net_deposit_usd,
    currency_iso,
    exchange_rate,
    eh_ftd,
    status_code,
    status_descricao,
    status_eh_aprovado,
    eh_aprovada,
    eh_aprovacao_gerencial,
    eh_aprovacao_automatica,
    eh_atualiza_tp_ao_aprovar,
    eh_paga,
    approved_on,
    approved_date,
    platform_updated_on,
    expires_on,
    payment_method_code,
    payment_method_name,
    payment_method_is_official,
    transaction_comment,
    internal_comment,
    additional_info,
    transaction_reference,
    transaction_case_id,
    last_action_id,
    related_transaction_id,
    opposite_account_id,
    transfer_to_tp_account_id,
    transaction_owner,
    owner_id,
    owning_business_unit,
    state_code,
    status_reason_code,
    created_on,
    created_date,
    modified_on,
    modified_date,
    _eh_valido,
    _motivo_invalido,
    _bronze_ingestao_ts,
    _bronze_origem,
    _bronze_hash_linha
)
SELECT
    pg_temp.safe_uuid(b.lv_monetarytransactionid),
    left(NULLIF(btrim(b.lv_name), ''), 80),
    b.lv_type,
    dtt.nome,
    b.lv_internaltype,
    dtt.categoria,
    dtt.sinal_financeiro,
    b.lv_type = 1,
    b.lv_type = 9,
    b.lv_type IN (5, 6),
    b.lv_type IN (15, 16),
    b.lv_type = 17,
    dtt.categoria = 'Reversão',
    CASE dtt.sinal_financeiro
        WHEN '-' THEN -1 * b.lv_usdvalue
        WHEN '+' THEN b.lv_usdvalue
        ELSE 0
    END,
    pg_temp.safe_uuid(b.lv_accountid),
    pg_temp.safe_uuid(b.lv_tpaccountid),
    b.lv_tradingplatformtransactionid,
    b.lv_tradingplatformoppositetransactionid,
    b.lv_amount,
    b.lv_usdvalue,
    b.lv_netdepositusdvalue,
    dc.iso_code,
    b.exchangerate,
    COALESCE(b.lv_firsttimedeposit, FALSE),
    b.lv_internaltransactionstatus,
    dts.descricao,
    dts.eh_aprovado,
    COALESCE(b.lv_transactionapproved, FALSE),
    b.lv_managementapproval,
    b.lv_autoapproval,
    b.lv_updatetponapprove,
    b.lv_paid,
    b.lv_approvedon,
    DATE(b.lv_approvedon),
    b.lv_updatetpon,
    b.lv_expiraydate,
    b.lv_methodofpayment,
    dpm.nome_inferido,
    dpm.eh_oficial,
    left(NULLIF(btrim(b.lv_comment), ''), 255),
    left(NULLIF(btrim(b.lv_internalcomment), ''), 500),
    b.lv_additionalinfo,
    left(NULLIF(btrim(b.lv_transactionreference), ''), 100),
    pg_temp.safe_uuid(b.lv_transactioncaseid),
    pg_temp.safe_uuid(b.lv_lastactionid),
    pg_temp.safe_uuid(b.lv_relatedtransactionid),
    pg_temp.safe_uuid(b.lv_oppositeaccountid),
    pg_temp.safe_uuid(b.lv_transfertotpaccount),
    pg_temp.safe_uuid(b.lv_mttransactionowner),
    pg_temp.safe_uuid(b.ownerid),
    pg_temp.safe_uuid(b.owningbusinessunit),
    b.statecode,
    b.statuscode,
    b.createdon,
    DATE(b.createdon),
    b.modifiedon,
    DATE(b.modifiedon),
    pg_temp.safe_uuid(b.lv_monetarytransactionid) IS NOT NULL,
    CASE
        WHEN pg_temp.safe_uuid(b.lv_monetarytransactionid) IS NULL THEN 'transaction_id inválido'
        WHEN pg_temp.safe_uuid(b.lv_tpaccountid) IS NULL THEN 'tp_account_id inválido'
        WHEN dtt.codigo IS NULL THEN 'transaction_type sem domain'
        WHEN dts.codigo IS NULL THEN 'status sem domain'
        ELSE NULL
    END,
    b._ingestao_ts,
    b._origem,
    b._hash_linha
FROM bronze.lv_monetarytransactionbase b
LEFT JOIN domain.dom_transaction_type dtt
    ON b.lv_type = dtt.codigo
LEFT JOIN domain.dom_transaction_status dts
    ON b.lv_internaltransactionstatus = dts.codigo
LEFT JOIN domain.dom_payment_method dpm
    ON b.lv_methodofpayment = dpm.codigo
LEFT JOIN domain.dom_currency dc
    ON upper(b.transactioncurrencyid) = upper(dc.currency_guid);

INSERT INTO silver.sirix_account_clean (
    login,
    name,
    sirix_group,
    balance,
    equity,
    margin,
    margin_free,
    margin_level,
    credit,
    prev_balance,
    prev_month_balance,
    currency,
    leverage,
    agent_login,
    interest_rate,
    taxes,
    send_reports,
    enable_change_pass,
    eh_habilitada,
    eh_readonly,
    last_activity_date,
    last_activity_date_only,
    modify_time,
    modify_date,
    reg_date,
    reg_date_only,
    _eh_valido,
    _motivo_invalido,
    _bronze_ingestao_ts,
    _bronze_origem,
    _bronze_hash_linha
)
SELECT
    b.login,
    left(NULLIF(btrim(b.name), ''), 200),
    left(NULLIF(btrim(b."group"), ''), 50),
    b.balance,
    b.equity,
    b.margin,
    b.margin_free,
    b.margin_level,
    b.credit,
    b.prevbalance,
    b.prevmonthbalance::NUMERIC(15,2),
    left(COALESCE(NULLIF(btrim(b.currency), ''), 'UNK'), 3),
    b.leverage,
    b.agent_account,
    b.interestrate,
    b.taxes,
    b.send_reports = 1,
    b.enable_change_pass = 1,
    b.enable = 1,
    b.enable_readonly = 1,
    b.lastdate,
    DATE(b.lastdate),
    b.modify_time,
    DATE(b.modify_time),
    b.regdate,
    DATE(b.regdate),
    b.login IS NOT NULL,
    CASE WHEN b.login IS NULL THEN 'login nulo' END,
    b._ingestao_ts,
    b._origem,
    b._hash_linha
FROM bronze.sirix_users_view b;

INSERT INTO silver.trade_clean (
    ticket,
    sirix_login,
    cmd_code,
    cmd_tipo,
    eh_trade,
    eh_operacao_mercado,
    eh_financeiro,
    eh_pendente,
    sinal,
    side,
    side_sign,
    broker_id,
    account_id,
    symbol,
    symbol_key,
    volume,
    volume_lots,
    open_time,
    open_date,
    close_time,
    close_date,
    eh_aberta,
    open_price,
    close_price,
    open_position_id,
    profit_bruto,
    commission,
    commission_agent,
    swaps,
    taxes,
    profit_liquido,
    sl,
    tp,
    expiration,
    duracao_segundos,
    modify_time,
    modify_date,
    sirix_comment,
    movimentacao_tipo,
    conv_rate1,
    conv_rate2,
    margin_rate,
    digits,
    internal_id,
    _eh_valido,
    _motivo_invalido,
    _eh_suspeito,
    _motivo_suspeito,
    _bronze_ingestao_ts,
    _bronze_origem,
    _bronze_hash_linha
)
WITH normalized AS (
    SELECT
        b.*,
        CASE WHEN b.open_time IS NULL OR DATE(b.open_time) = DATE '1970-01-01' THEN NULL ELSE b.open_time END AS open_time_norm,
        CASE WHEN b.close_time IS NULL OR DATE(b.close_time) = DATE '1970-01-01' THEN NULL ELSE b.close_time END AS close_time_norm,
        CASE WHEN b.expiration IS NULL OR DATE(b.expiration) = DATE '1970-01-01' THEN NULL ELSE b.expiration END AS expiration_norm
    FROM bronze.sirix_trades_view b
)
SELECT
    b.ticket,
    b.login,
    b.cmd,
    d.tipo,
    COALESCE(d.eh_trade, FALSE),
    b.cmd IN (0, 1),
    COALESCE(d.eh_financeiro, FALSE),
    COALESCE(d.eh_pendente, FALSE),
    d.sinal,
    CASE WHEN b.cmd = 0 THEN 'Buy' WHEN b.cmd = 1 THEN 'Sell' ELSE 'Other' END,
    CASE WHEN b.cmd = 0 THEN 1 WHEN b.cmd = 1 THEN -1 ELSE 0 END,
    left(NULLIF(btrim(b.broker_id), ''), 36),
    b.account_id,
    left(NULLIF(btrim(b.symbol), ''), 20),
    left(upper(NULLIF(btrim(b.symbol), '')), 30),
    b.volume,
    b.volume::NUMERIC(20,8) / 100.0,
    b.open_time_norm,
    DATE(b.open_time_norm),
    b.close_time_norm,
    DATE(b.close_time_norm),
    b.cmd IN (0, 1) AND b.close_time_norm IS NULL,
    b.open_price,
    b.close_price,
    b.open_position_id,
    b.profit,
    b.commission,
    b.commission_agent,
    b.swaps,
    b.taxes,
    b.profit - ABS(b.commission) + b.swaps,
    NULLIF(b.sl, 0),
    NULLIF(b.tp, 0),
    b.expiration_norm,
    CASE
        WHEN b.open_time_norm IS NOT NULL AND b.close_time_norm IS NOT NULL
        THEN EXTRACT(EPOCH FROM (b.close_time_norm - b.open_time_norm))::BIGINT
        ELSE NULL
    END,
    b.modify_time,
    DATE(b.modify_time),
    left(NULLIF(btrim(b."comment"), ''), 255),
    CASE
        WHEN b.cmd = 6 AND b."comment" ILIKE '%deposit%' THEN 'Deposito'
        WHEN b.cmd = 6 AND b."comment" ILIKE '%withdraw%' THEN 'Saque'
        WHEN b.cmd = 7 THEN 'Credito'
        WHEN b.cmd IN (6, 7) THEN 'Financeiro'
        ELSE NULL
    END,
    b.conv_rate1,
    b.conv_rate2,
    b.margin_rate,
    b.digits,
    b.internal_id,
    b.ticket IS NOT NULL AND d.codigo IS NOT NULL,
    CASE
        WHEN b.ticket IS NULL THEN 'ticket nulo'
        WHEN d.codigo IS NULL THEN 'cmd sem domain'
        WHEN b.login IS NULL THEN 'login nulo'
        WHEN b.cmd IN (0, 1) AND NULLIF(btrim(b.symbol), '') IS NULL THEN 'operação de mercado sem symbol'
        ELSE NULL
    END,
    ABS(b.profit) > 10000000 OR b.volume > 100000000,
    CASE
        WHEN ABS(b.profit) > 10000000 THEN 'profit extremo'
        WHEN b.volume > 100000000 THEN 'volume extremo'
        ELSE NULL
    END,
    b._ingestao_ts,
    b._origem,
    b._hash_linha
FROM normalized b
LEFT JOIN domain.dom_cmd d
    ON b.cmd = d.codigo;

-- =============================================================================
-- DIFERIDO (2026-06-02): materialização de silver.daily_snapshot_clean adiada.
-- Motivo: a série diária de equity/saldo (4,7M linhas, ~1,1 GB) NÃO é consumida
-- por nenhum fato/view de gold (dim_cliente.balance/equity vêm de
-- sirix_account_clean/tpaccount, não do snapshot). stg_raw + bronze são mantidos
-- como histórico bruto. Reativar este bloco quando existir consumidor em gold
-- (ex.: gold.fato_equity_dia / curva de equity). Ver wiki/topics/camada-silver.md.
-- A tabela e seus índices continuam definidos em silver_ddl.sql (ficam vazios).
-- -----------------------------------------------------------------------------
-- INSERT INTO silver.daily_snapshot_clean (
--     snapshot_date,
--     snapshot_ts,
--     sirix_login,
--     balance,
--     balance_prev,
--     equity,
--     margin,
--     margin_free,
--     credit,
--     profit_aberto,
--     profit_realizado,
--     fluxo_dia,
--     deposit_raw,
--     bank,
--     sirix_group,
--     modify_time,
--     modify_date,
--     _eh_valido,
--     _motivo_invalido,
--     _bronze_ingestao_ts,
--     _bronze_origem,
--     _bronze_hash_linha
-- )
-- SELECT
--     DATE(b."time"),
--     b."time",
--     b.login,
--     b.balance,
--     b.balance_prev,
--     b.equity,
--     b.margin,
--     b.margin_free,
--     b.credit,
--     b.profit,
--     b.profit_closed,
--     b.balance - b.balance_prev,
--     b.deposit,
--     b.bank,
--     left(NULLIF(btrim(b."group"), ''), 50),
--     b.modify_time,
--     DATE(b.modify_time),
--     b."time" IS NOT NULL AND b.login IS NOT NULL,
--     CASE
--         WHEN b."time" IS NULL THEN 'snapshot_ts nulo'
--         WHEN b.login IS NULL THEN 'login nulo'
--         ELSE NULL
--     END,
--     b._ingestao_ts,
--     b._origem,
--     b._hash_linha
-- FROM bronze.sirix_daily_view b;
-- =============================================================================

COMMIT;
