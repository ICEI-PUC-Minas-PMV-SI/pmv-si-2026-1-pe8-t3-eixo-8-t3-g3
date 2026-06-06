# DER — db_brokerlab

Banco: PostgreSQL · db: `db_brokerlab` · schemas ativos: `stg_raw`, `domain`, `bronze`, `silver`, `config`, `config_import`, `gold`
---

## Diagrama Completo (Mermaid)

```mermaid
erDiagram

    %% ================================================================
    %% STG_RAW — ingestão TEXT-only, espelho dos sistemas-fonte
    %% ================================================================

    STG_crm_account_base {
        TEXT AccountId PK
        TEXT lv_maintpaccountid "FK lógica → STG_lv_tpaccountbase"
        TEXT OwnerId            "FK lógica → STG_crm_user_base"
        TEXT Lv_LeadStatus
        TEXT Lv_FTDExist
        TEXT Country
        TEXT CreatedOn
        TEXT ModifiedOn
    }

    STG_crm_user_base {
        TEXT ActiveDirectoryGuid PK
        TEXT BusinessUnitId
        TEXT FullName
        TEXT DomainName
        TEXT Lv_IsRetentionOwner
        TEXT Lv_IsConversionOwner
        TEXT CreatedOn
        TEXT ModifiedOn
    }

    STG_lv_tpaccountbase {
        TEXT Lv_tpaccountId PK
        TEXT lv_accountid   "FK lógica → STG_crm_account_base"
        TEXT lv_name        "= Sirix LOGIN"
        TEXT OwnerId        "FK lógica → STG_crm_user_base"
        TEXT lv_basecurrencyid
        TEXT lv_balanceusd
        TEXT lv_equity
        TEXT statecode
        TEXT CreatedOn
        TEXT ModifiedOn
    }

    STG_lv_monetarytransactionbase {
        TEXT Lv_monetarytransactionId PK
        TEXT lv_accountid             "FK lógica → STG_crm_account_base"
        TEXT lv_tpaccountid           "FK lógica → STG_lv_tpaccountbase"
        TEXT lv_TradingPlatformTransactionId "FK lógica → STG_sirix_trades_view"
        TEXT Lv_Type
        TEXT Lv_Amount
        TEXT lv_netDepositusdvalue
        TEXT Lv_Status
        TEXT Lv_ApprovedOn
        TEXT CreatedOn
    }

    STG_sirix_users_view {
        TEXT LOGIN PK
        TEXT NAME
        TEXT GROUP
        TEXT BALANCE
        TEXT EQUITY
        TEXT CURRENCY
        TEXT LEVERAGE
        TEXT REGDATE
        TEXT MODIFY_TIME
    }

    STG_sirix_trades_view {
        TEXT TICKET  PK
        TEXT LOGIN   "FK lógica → STG_sirix_users_view"
        TEXT CMD
        TEXT SYMBOL
        TEXT VOLUME
        TEXT OPEN_TIME
        TEXT CLOSE_TIME
        TEXT PROFIT
        TEXT COMMISSION
        TEXT SWAPS
    }

    STG_sirix_daily_view {
        TEXT TIME  PK
        TEXT LOGIN PK "FK lógica → STG_sirix_users_view"
        TEXT BALANCE
        TEXT EQUITY
        TEXT PROFIT
        TEXT PROFIT_CLOSED
        TEXT GROUP
    }

    %% Relações lógicas dentro de stg_raw (sem FKs físicas — tudo TEXT)
    STG_crm_account_base   }o--o{ STG_lv_tpaccountbase          : "AccountId = lv_accountid"
    STG_crm_account_base   }o--o| STG_crm_user_base             : "OwnerId = ActiveDirectoryGuid"
    STG_lv_tpaccountbase   }o--o{ STG_lv_monetarytransactionbase : "Lv_tpaccountId = lv_tpaccountid"
    STG_sirix_users_view   ||--o{ STG_sirix_trades_view          : "LOGIN"
    STG_sirix_users_view   ||--o{ STG_sirix_daily_view           : "LOGIN"


    %% ================================================================
    %% DOMAIN — lookups canônicos para decodificar códigos CRM/Sirix
    %% ================================================================

    DOM_lead_status {
        BIGINT  codigo      PK
        VARCHAR descricao
        VARCHAR categoria       "Novo|Em prospecção|Perdido|Inválido|Operacional"
        BOOLEAN eh_terminal
    }

    DOM_cmd {
        INTEGER codigo      PK
        VARCHAR tipo            "OP_BUY|OP_SELL|OP_BALANCE|..."
        VARCHAR descricao
        BOOLEAN eh_trade
        BOOLEAN eh_financeiro   "TRUE para CMD 6 e 7"
        BOOLEAN eh_pendente
        CHAR    sinal           "+|-|0"
    }

    DOM_transaction_type {
        INTEGER codigo           PK
        VARCHAR nome
        VARCHAR categoria        "Entrada|Saída|Bônus|Reversão|Transferência|Taxa"
        CHAR    sinal_financeiro "+|-|0"
    }

    DOM_transaction_status {
        BIGINT  codigo      PK
        VARCHAR descricao
        BOOLEAN eh_aprovado
    }

    DOM_payment_method {
        BIGINT  codigo       PK
        VARCHAR nome_inferido
        BOOLEAN eh_oficial
    }

    DOM_currency {
        VARCHAR currency_guid PK
        VARCHAR iso_code      "USD|EUR|TRY"
        VARCHAR nome
    }


    %% ================================================================
    %% BRONZE — cópia fiel tipada, append-only, auditável
    %% ================================================================

    BRZ_crm_account_base {
        VARCHAR  accountid              PK
        VARCHAR  lv_maintpaccountid     "FK lógica → BRZ_lv_tpaccountbase"
        VARCHAR  lv_conversionownerid   "FK lógica → BRZ_crm_user_base"
        VARCHAR  lv_retentionownerid    "FK lógica → BRZ_crm_user_base"
        INTEGER  lv_leadstatus
        BOOLEAN  lv_ftdexist
        VARCHAR  country
        TIMESTAMP createdon
        TIMESTAMP modifiedon
        TIMESTAMP _ingestao_ts
        VARCHAR  _origem
        VARCHAR  _hash_linha
    }

    BRZ_crm_user_base {
        VARCHAR  activedirectoryguid PK
        INTEGER  identityid
        VARCHAR  businessunitid
        VARCHAR  fullname
        VARCHAR  domainname
        BOOLEAN  isdisabled
        VARCHAR  lv_isactive
        VARCHAR  lv_isretentionowner
        VARCHAR  lv_isconversionowner
        TIMESTAMP _ingestao_ts
        VARCHAR  _origem
    }

    BRZ_lv_tpaccountbase {
        VARCHAR  lv_tpaccountid    PK
        BIGINT   lv_name           "= Sirix LOGIN — ponte CRM↔Sirix"
        VARCHAR  lv_accountid      "FK lógica → BRZ_crm_account_base"
        VARCHAR  ownerid           "FK lógica → BRZ_crm_user_base"
        VARCHAR  lv_basecurrencyid "FK lógica → DOM_currency"
        INTEGER  lv_leverage
        NUMERIC  lv_balanceusd
        NUMERIC  lv_equity
        INTEGER  statecode
        TIMESTAMP createdon
        TIMESTAMP modifiedon
        TIMESTAMP _ingestao_ts
    }

    BRZ_lv_monetarytransactionbase {
        VARCHAR  lv_monetarytransactionid PK
        VARCHAR  lv_tpaccountid           "FK lógica → BRZ_lv_tpaccountbase"
        VARCHAR  lv_accountid             "FK lógica → BRZ_crm_account_base"
        BIGINT   lv_tradingplatformtransactionid "FK lógica → BRZ_sirix_trades_view"
        INTEGER  lv_type
        NUMERIC  lv_amount
        NUMERIC  lv_usdvalue
        NUMERIC  lv_netdepositusdvalue
        BOOLEAN  lv_firsttimedeposit
        BOOLEAN  lv_transactionapproved
        TIMESTAMP lv_approvedon
        TIMESTAMP createdon
        TIMESTAMP modifiedon
        TIMESTAMP _ingestao_ts
    }

    BRZ_sirix_users_view {
        BIGINT   login           PK
        VARCHAR  name
        VARCHAR  group
        NUMERIC  balance
        NUMERIC  equity
        VARCHAR  currency
        INTEGER  leverage
        TIMESTAMP lastdate
        TIMESTAMP regdate
        TIMESTAMP modify_time
        TIMESTAMP _ingestao_ts
    }

    BRZ_sirix_trades_view {
        BIGINT   ticket          PK
        BIGINT   login           "FK lógica → BRZ_sirix_users_view"
        BIGINT   account_id
        INTEGER  cmd             "FK lógica → DOM_cmd"
        VARCHAR  symbol
        BIGINT   volume
        NUMERIC  open_price
        NUMERIC  close_price
        TIMESTAMP open_time
        TIMESTAMP close_time
        NUMERIC  profit
        NUMERIC  commission
        NUMERIC  swaps
        TIMESTAMP modify_time
        TIMESTAMP _ingestao_ts
    }

    BRZ_sirix_daily_view {
        TIMESTAMP time           PK
        BIGINT    login          PK "FK lógica → BRZ_sirix_users_view"
        NUMERIC   balance
        NUMERIC   balance_prev
        NUMERIC   equity
        NUMERIC   profit
        NUMERIC   profit_closed
        VARCHAR   group
        TIMESTAMP modify_time
        TIMESTAMP _ingestao_ts
    }

    %% Relações lógicas Bronze (sem FKs físicas por design append-only)
    BRZ_crm_account_base   }o--o| BRZ_lv_tpaccountbase          : "accountid = lv_accountid"
    BRZ_lv_tpaccountbase   }o--o{ BRZ_lv_monetarytransactionbase : "lv_tpaccountid"
    BRZ_crm_account_base   }o--o{ BRZ_lv_monetarytransactionbase : "accountid = lv_accountid"
    BRZ_sirix_users_view   ||--o{ BRZ_sirix_trades_view          : "login"
    BRZ_sirix_users_view   ||--o{ BRZ_sirix_daily_view           : "login"


    %% ================================================================
    %% SILVER — dados limpos, tipados, deduplicados, prontos para BI
    %% ================================================================

    SLV_account_clean {
        UUID     account_id              PK
        BIGINT   lead_status_code        "FK → DOM_lead_status"
        VARCHAR  lead_status_categoria
        UUID     main_tp_account_id      "FK lógica → SLV_tpaccount_clean"
        VARCHAR  country
        VARCHAR  language_iso
        BOOLEAN  has_ftd
        VARCHAR  conversion_owner_name
        VARCHAR  conversion_owner_key    "lower/trim p/ alias"
        VARCHAR  retention_owner_name
        VARCHAR  retention_owner_key     "lower/trim p/ alias"
        BOOLEAN  has_retention_owner
        UUID     owner_id
        UUID     owning_business_unit
        TIMESTAMP created_on
        TIMESTAMP modified_on
        TIMESTAMP _silver_ts
        BOOLEAN  _eh_valido
    }

    SLV_user_clean {
        UUID     active_directory_guid   PK
        INTEGER  identity_id
        UUID     business_unit_id
        VARCHAR  full_name
        VARCHAR  full_name_key           "lower/trim p/ alias"
        VARCHAR  email                   "de domainname"
        BOOLEAN  is_disabled
        BOOLEAN  is_active
        BOOLEAN  is_retention_owner
        BOOLEAN  is_conversion_owner
        BOOLEAN  is_business_unit_owner
        TIMESTAMP created_on
        TIMESTAMP _silver_ts
    }

    SLV_tpaccount_clean {
        UUID     tp_account_id           PK
        BIGINT   sirix_login             "ponte CRM↔Sirix → SLV_sirix_account_clean"
        UUID     crm_account_id          "FK lógica → SLV_account_clean"
        VARCHAR  base_currency           "decodificado de DOM_currency"
        UUID     base_currency_guid      "FK lógica → DOM_currency"
        INTEGER  leverage
        NUMERIC  balance_usd
        NUMERIC  equity
        NUMERIC  pnl_acumulado
        INTEGER  margin_status
        BOOLEAN  eh_margin_call
        BOOLEAN  eh_conta_especial
        BOOLEAN  eh_readonly
        BOOLEAN  eh_online
        BOOLEAN  eh_deletada
        BOOLEAN  eh_desabilitada
        TIMESTAMP last_login
        TIMESTAMP created_on
        TIMESTAMP modified_on
        TIMESTAMP _silver_ts
        BOOLEAN  _eh_valido
        BOOLEAN  _eh_suspeito
    }

    SLV_transaction_clean {
        UUID     transaction_id          PK
        UUID     tp_account_id           "FK lógica → SLV_tpaccount_clean"
        UUID     crm_account_id          "FK lógica → SLV_account_clean"
        BIGINT   sirix_ticket            "FK lógica → SLV_trade_clean"
        INTEGER  transaction_type_code   "FK → DOM_transaction_type"
        VARCHAR  transaction_type_categoria
        CHAR     sinal_financeiro
        BIGINT   status_code             "FK → DOM_transaction_status"
        BOOLEAN  status_eh_aprovado
        BIGINT   payment_method_code     "FK → DOM_payment_method"
        VARCHAR  currency_iso
        NUMERIC  amount_original
        NUMERIC  usd_value
        NUMERIC  net_deposit_usd
        BOOLEAN  eh_aprovada
        BOOLEAN  eh_ftd
        BOOLEAN  eh_deposito
        BOOLEAN  eh_withdrawal
        DATE     approved_date
        TIMESTAMP approved_on
        TIMESTAMP created_on
        TIMESTAMP _silver_ts
        BOOLEAN  _eh_valido
    }

    SLV_sirix_account_clean {
        BIGINT   login           PK
        VARCHAR  sirix_group
        NUMERIC  balance
        NUMERIC  equity
        NUMERIC  margin
        VARCHAR  currency
        INTEGER  leverage
        BOOLEAN  eh_habilitada
        BOOLEAN  eh_readonly
        INTEGER  agent_login     "referência a IB/introdutor"
        TIMESTAMP last_activity_date
        DATE     last_activity_date_only
        TIMESTAMP reg_date
        TIMESTAMP modify_time
        TIMESTAMP _silver_ts
        BOOLEAN  _eh_valido
    }

    SLV_trade_clean {
        BIGINT   ticket           PK
        BIGINT   sirix_login      "FK lógica → SLV_sirix_account_clean"
        INTEGER  cmd_code         "FK → DOM_cmd"
        VARCHAR  cmd_tipo
        BOOLEAN  eh_trade
        BOOLEAN  eh_operacao_mercado  "CMD 0/1"
        BOOLEAN  eh_financeiro
        BOOLEAN  eh_pendente
        VARCHAR  side             "Buy|Sell|Other"
        SMALLINT side_sign        "1|-1|0"
        VARCHAR  symbol
        VARCHAR  symbol_key       "upper/trim p/ dim_ativo"
        BIGINT   volume
        NUMERIC  volume_lots
        NUMERIC  open_price
        NUMERIC  close_price
        TIMESTAMP open_time
        TIMESTAMP close_time
        BOOLEAN  eh_aberta
        BIGINT   open_position_id "evento de fechamento"
        NUMERIC  profit_bruto
        NUMERIC  commission
        NUMERIC  swaps
        NUMERIC  profit_liquido
        BIGINT   duracao_segundos
        TIMESTAMP modify_time
        TIMESTAMP _silver_ts
        BOOLEAN  _eh_valido
        BOOLEAN  _eh_suspeito
    }

    SLV_daily_snapshot_clean {
        DATE     snapshot_date     PK
        BIGINT   sirix_login       PK "FK lógica → SLV_sirix_account_clean"
        TIMESTAMP snapshot_ts
        NUMERIC  balance
        NUMERIC  balance_prev
        NUMERIC  equity
        NUMERIC  margin
        NUMERIC  margin_free
        NUMERIC  credit
        NUMERIC  profit_aberto
        NUMERIC  profit_realizado
        NUMERIC  fluxo_dia         "DERIVADO: balance - balance_prev"
        NUMERIC  deposit_raw
        NUMERIC  bank
        VARCHAR  sirix_group
        TIMESTAMP modify_time
        DATE     modify_date
        TIMESTAMP _silver_ts
        BOOLEAN  _eh_valido
        TEXT     _motivo_invalido
        TIMESTAMP _bronze_ingestao_ts
        VARCHAR  _bronze_origem
        VARCHAR  _bronze_hash_linha
    }

    %% Relações Silver (FKs lógicas, sem constraint física por design)
    DOM_lead_status          ||--o{ SLV_account_clean       : "lead_status_code"
    DOM_cmd                  ||--o{ SLV_trade_clean         : "cmd_code"
    DOM_transaction_type     ||--o{ SLV_transaction_clean   : "transaction_type_code"
    DOM_transaction_status   ||--o{ SLV_transaction_clean   : "status_code"
    DOM_payment_method       ||--o{ SLV_transaction_clean   : "payment_method_code"
    DOM_currency             ||--o{ SLV_tpaccount_clean     : "base_currency_guid"

    SLV_account_clean        ||--o{ SLV_tpaccount_clean     : "account_id = crm_account_id"
    SLV_tpaccount_clean      }o--|| SLV_sirix_account_clean : "sirix_login = login"
    SLV_tpaccount_clean      ||--o{ SLV_transaction_clean   : "tp_account_id"
    SLV_account_clean        ||--o{ SLV_transaction_clean   : "account_id = crm_account_id"
    SLV_sirix_account_clean  ||--o{ SLV_trade_clean         : "login = sirix_login"
    SLV_sirix_account_clean  ||--o{ SLV_daily_snapshot_clean: "login = sirix_login"
    SLV_trade_clean          ||--o{ SLV_transaction_clean   : "ticket = sirix_ticket"


    %% ================================================================
    %% CONFIG — dados de negócio controlados manualmente
    %% ================================================================

    CFG_agent_profile {
        BIGSERIAL agent_id       PK
        VARCHAR   agent_key      UNIQUE
        VARCHAR   agent_name
        VARCHAR   agent_email
        VARCHAR   team_name
        VARCHAR   agent_level    "trainee|inter|pro"
        VARCHAR   seniority      "iniciante|intermediario|senior|manager"
        VARCHAR   agent_type     "individual|pool|system"
        BOOLEAN   is_active
        DATE      started_on
        DATE      ended_on
        VARCHAR   source         "template|manual|crm|excel"
        VARCHAR   source_file
        TIMESTAMP created_at
        TIMESTAMP updated_at
        TEXT      notes
    }

    CFG_agent_alias {
        BIGSERIAL agent_alias_id  PK
        BIGINT    agent_id        "FK → CFG_agent_profile"
        VARCHAR   source_system   "CRM|Excel|Manual|Template"
        VARCHAR   alias_name
        VARCHAR   normalized_alias UNIQUE "lower(trim(unaccent))"
        BOOLEAN   is_primary
        BOOLEAN   is_active
        VARCHAR   source_file
        TIMESTAMP created_at
        TEXT      notes
    }

    CFG_business_calendar {
        DATE     date              PK
        INTEGER  date_sk           UNIQUE "YYYYMMDD"
        SMALLINT year
        SMALLINT quarter
        SMALLINT month
        DATE     month_start_date
        SMALLINT day_of_month
        SMALLINT day_of_week       "1=Seg .. 7=Dom (ISO)"
        VARCHAR  day_name
        BOOLEAN  is_weekend
        BOOLEAN  is_global_holiday
        VARCHAR  holiday_name
        BOOLEAN  is_business_day
        SMALLINT business_day_number_in_month
        SMALLINT business_days_in_month
        SMALLINT remaining_business_days_in_month
        VARCHAR  source_file
        TEXT     notes
    }

    CFG_agent_target_month {
        BIGSERIAL target_month_id          PK
        DATE      competence_month         "sempre dia 1 do mês"
        BIGINT    agent_id                 "FK → CFG_agent_profile"
        NUMERIC   target_deposit_month_usd
        INTEGER   target_trade_day
        INTEGER   target_trade_month       "derivado se NULL"
        INTEGER   target_unique_month
        NUMERIC   target_volume_month
        VARCHAR   target_volume_unit
        VARCHAR   source_type
        VARCHAR   source_file
        VARCHAR   approved_by
        BOOLEAN   is_active
        TIMESTAMP created_at
        VARCHAR   created_by
        TEXT      notes
    }

    CFG_asset_catalog {
        BIGSERIAL asset_id             PK
        VARCHAR   sirix_symbol         UNIQUE
        VARCHAR   normalized_symbol
        VARCHAR   display_name
        VARCHAR   asset_class          "forex|commodity|energy|index|stock|crypto|unknown"
        VARCHAR   base_currency
        VARCHAR   quote_currency
        NUMERIC   contract_size
        NUMERIC   tick_size
        NUMERIC   tick_value
        NUMERIC   volume_multiplier
        VARCHAR   provider
        VARCHAR   provider_symbol
        BOOLEAN   is_major_asset
        BOOLEAN   is_active
        VARCHAR   classification_status "inferred|manual|validated"
        VARCHAR   source_file
        TIMESTAMP created_at
        TIMESTAMP updated_at
        TEXT      notes
    }

    CFG_agent_profile    ||--o{ CFG_agent_alias        : "agent_id"
    CFG_agent_profile    ||--o{ CFG_agent_target_month : "agent_id"

    CFGI_load_batch {
        BIGSERIAL load_batch_id PK
        VARCHAR   source_kind
        TEXT      template_dir
        TEXT      executed_by
        TIMESTAMP started_at
        TIMESTAMP completed_at
        VARCHAR   status
        TEXT      notes
    }

    CFGI_validation_error {
        BIGSERIAL validation_error_id PK
        BIGINT    load_batch_id       "FK → CFGI_load_batch"
        VARCHAR   severity
        TEXT      source_file
        TEXT      sheet_name
        INTEGER   row_number
        TEXT      field_name
        TEXT      message
        TIMESTAMP created_at
    }

    CFGI_load_batch ||--o{ CFGI_validation_error : "load_batch_id"


    %% ================================================================
    %% GOLD — Star Schema para consumo Power BI
    %% ================================================================

    GLD_dim_tempo {
        INTEGER  tempo_sk                        PK "YYYYMMDD"
        DATE     date                            UNIQUE
        SMALLINT year
        SMALLINT quarter
        SMALLINT month
        DATE     month_start_date
        VARCHAR  year_month                      "ex: 2026-03"
        SMALLINT day_of_month
        SMALLINT day_of_week
        VARCHAR  day_name
        BOOLEAN  is_weekend
        BOOLEAN  is_business_day
        BOOLEAN  is_global_holiday
        VARCHAR  holiday_name
        SMALLINT business_day_number_in_month
        SMALLINT business_days_in_month
        SMALLINT remaining_business_days_in_month
        TIMESTAMP _loaded_at
    }

    GLD_dim_agente {
        BIGSERIAL agente_sk      PK
        BIGINT    agent_id       UNIQUE "FK lógica → CFG_agent_profile"
        VARCHAR   agent_name
        VARCHAR   agent_email
        VARCHAR   team_name
        VARCHAR   agent_level    "trainee|inter|pro"
        VARCHAR   seniority
        VARCHAR   agent_type     "individual|pool|system"
        BOOLEAN   is_active
        DATE      started_on
        DATE      ended_on
        VARCHAR   crm_full_name  "de SLV_user_clean"
        TIMESTAMP _loaded_at
    }

    GLD_dim_ativo {
        BIGSERIAL ativo_sk              PK
        BIGINT    asset_id              UNIQUE "FK lógica → CFG_asset_catalog"
        VARCHAR   sirix_symbol          UNIQUE
        VARCHAR   normalized_symbol
        VARCHAR   display_name
        VARCHAR   asset_class
        VARCHAR   base_currency
        VARCHAR   quote_currency
        BOOLEAN   is_major_asset
        BOOLEAN   is_active
        VARCHAR   classification_status
        TIMESTAMP _loaded_at
    }

    GLD_dim_cliente {
        BIGSERIAL cliente_sk             PK
        UUID      crm_account_id         UNIQUE "FK lógica → SLV_account_clean"
        UUID      tp_account_id          "FK lógica → SLV_tpaccount_clean"
        BIGINT    sirix_login            "FK lógica → SLV_sirix_account_clean"
        BIGINT    agente_sk_current      "FK → GLD_dim_agente"
        BIGINT    agent_id_current       "FK lógica → CFG_agent_profile"
        VARCHAR   cliente_nome
        VARCHAR   country
        VARCHAR   language_iso
        BIGINT    lead_status_code
        VARCHAR   lead_status_text
        VARCHAR   lead_status_categoria
        BOOLEAN   has_ftd
        VARCHAR   retention_owner_name
        VARCHAR   conversion_owner_name
        VARCHAR   agent_rule_used        "retention_owner (MVP)"
        NUMERIC   balance
        NUMERIC   equity
        NUMERIC   margin_level
        DATE      last_activity_date
        BOOLEAN   eh_habilitada
        BOOLEAN   eh_deletada
        VARCHAR   bridge_quality_status  "ok|sem_tp|tp_nao_encontrada|..."
        VARCHAR   _agente_quality        "resolved|unresolved"
        TIMESTAMP _loaded_at
    }

    GLD_fato_meta_agente_mes {
        INTEGER  competence_month_sk      PK "FK → GLD_dim_tempo"
        BIGINT   agente_sk                PK "FK → GLD_dim_agente"
        DATE     competence_month
        NUMERIC  target_deposit_month_usd
        NUMERIC  target_deposit_day_usd   "DERIVADO"
        INTEGER  target_trade_day
        INTEGER  target_trade_month       "DERIVADO se NULL na config"
        INTEGER  target_unique_month
        SMALLINT business_days_in_month
        VARCHAR  source_type
        TIMESTAMP _loaded_at
    }

    GLD_fato_movimentacao_financeira {
        BIGSERIAL transaction_sk           PK
        UUID      transaction_id           UNIQUE "FK lógica → SLV_transaction_clean"
        INTEGER   tempo_aprovacao_sk       "FK → GLD_dim_tempo"
        INTEGER   tempo_criacao_sk         "FK → GLD_dim_tempo"
        BIGINT    cliente_sk               "FK → GLD_dim_cliente"
        BIGINT    agente_sk                "FK → GLD_dim_agente"
        UUID      crm_account_id           "dim degenerada"
        UUID      tp_account_id            "dim degenerada"
        BIGINT    sirix_ticket
        INTEGER   transaction_type_code
        VARCHAR   transaction_type_categoria
        BIGINT    status_code
        BOOLEAN   eh_aprovada
        BOOLEAN   eh_ftd
        NUMERIC   amount_original
        NUMERIC   usd_value
        NUMERIC   deposit_amount_usd
        NUMERIC   withdrawal_amount_usd
        NUMERIC   net_deposit_usd
        VARCHAR   currency_iso
        BIGINT    payment_method_code
        VARCHAR   payment_method_name
        DATE      approved_on
        TIMESTAMP created_on
        VARCHAR   _agente_quality
        TIMESTAMP _loaded_at
    }

    GLD_fato_operacao {
        BIGSERIAL operacao_sk            PK
        BIGINT    ticket                 UNIQUE "FK lógica → SLV_trade_clean"
        INTEGER   tempo_open_sk          "FK → GLD_dim_tempo"
        INTEGER   tempo_close_sk         "FK → GLD_dim_tempo"
        BIGINT    cliente_sk             "FK → GLD_dim_cliente"
        BIGINT    agente_sk              "FK → GLD_dim_agente"
        BIGINT    ativo_sk               "FK → GLD_dim_ativo"
        BIGINT    sirix_login
        INTEGER   cmd_code
        VARCHAR   cmd_tipo
        BOOLEAN   eh_operacao_mercado    "CMD 0/1"
        BOOLEAN   eh_pendente            "CMD 2-5"
        BOOLEAN   eh_financeiro_sirix    "CMD 6/7"
        VARCHAR   side
        SMALLINT  side_sign
        VARCHAR   symbol
        BIGINT    volume_raw
        NUMERIC   volume_lots
        TIMESTAMP open_time
        TIMESTAMP close_time
        BOOLEAN   eh_aberta
        NUMERIC   open_price
        NUMERIC   close_price
        NUMERIC   profit_bruto
        NUMERIC   commission
        NUMERIC   swaps
        NUMERIC   profit_liquido
        BIGINT    duracao_segundos
        BOOLEAN   _eh_suspeito
        VARCHAR   _agente_quality
        TIMESTAMP _loaded_at
    }

    GLD_fato_cliente_trade_dia {
        INTEGER  tempo_sk           PK "FK → GLD_dim_tempo"
        BIGINT   cliente_sk         PK "FK → GLD_dim_cliente"
        BIGINT   agente_sk          "FK → GLD_dim_agente"
        BIGINT   sirix_login
        INTEGER  qtd_trades_dia     "CMD 0/1 fechados"
        INTEGER  qtd_ativos_dia
        NUMERIC  volume_lots_dia
        NUMERIC  pnl_liquido_dia
        TIMESTAMP first_trade_ts
        TIMESTAMP last_trade_ts
        BOOLEAN  has_open_today
        BOOLEAN  has_close_today
        TIMESTAMP _loaded_at
    }

    %% ── Gold: dimensão agente → cliente ──
    GLD_dim_agente   ||--o{ GLD_dim_cliente : "agente_sk_current"

    %% ── Gold: fato_meta_agente_mes ──
    GLD_dim_tempo    ||--o{ GLD_fato_meta_agente_mes : "competence_month_sk"
    GLD_dim_agente   ||--o{ GLD_fato_meta_agente_mes : "agente_sk"

    %% ── Gold: fato_movimentacao_financeira ──
    GLD_dim_tempo    ||--o{ GLD_fato_movimentacao_financeira : "tempo_aprovacao_sk"
    GLD_dim_cliente  ||--o{ GLD_fato_movimentacao_financeira : "cliente_sk"
    GLD_dim_agente   ||--o{ GLD_fato_movimentacao_financeira : "agente_sk"

    %% ── Gold: fato_operacao ──
    GLD_dim_tempo    ||--o{ GLD_fato_operacao : "tempo_open_sk"
    GLD_dim_cliente  ||--o{ GLD_fato_operacao : "cliente_sk"
    GLD_dim_agente   ||--o{ GLD_fato_operacao : "agente_sk"
    GLD_dim_ativo    ||--o{ GLD_fato_operacao : "ativo_sk"

    %% ── Gold: fato_cliente_trade_dia ──
    GLD_dim_tempo    ||--o{ GLD_fato_cliente_trade_dia : "tempo_sk"
    GLD_dim_cliente  ||--o{ GLD_fato_cliente_trade_dia : "cliente_sk"
    GLD_dim_agente   ||--o{ GLD_fato_cliente_trade_dia : "agente_sk"

    %% ── Config → Gold (feeds lógicos) ──
    CFG_business_calendar  ||--|| GLD_dim_tempo   : "date_sk = tempo_sk"
    CFG_agent_profile      ||--|| GLD_dim_agente  : "agent_id"
    CFG_asset_catalog      ||--|| GLD_dim_ativo   : "asset_id"
    CFG_agent_alias        }o--|| GLD_dim_cliente  : "resolve retention_owner → agente_sk"
    CFG_agent_target_month ||--|| GLD_fato_meta_agente_mes : "feeds"
```

---

## Glossário de Schemas

| Schema | Papel | Linhas aprox. |
|--------|-------|---------------|
| `stg_raw` | Ingestão TEXT-only dos CSVs/APIs fonte | 5.006.418 |
| `domain` | Lookups canônicos CRM/Sirix (códigos → descrições) | 90 |
| `bronze` | Cópia tipada, append-only, com colunas de auditoria | 5.006.418 |
| `silver` | Dados limpos, deduplicados, derivados calculados | 5.006.418 |
| `config` | Dados de negócio controlados manualmente (agentes, metas, calendário, ativos) | ~6 k |
| `config_import` | Auditoria e erros de carga dos templates `.xlsx` | 7 batches / 0 erros |
| `gold` | Star schema para Power BI (4 dims + 4 fatos + 7 views semânticas) | 179.515 |

---

## Entidade-Pivô: `lv_tpaccountbase`

A tabela **`lv_tpaccountbase`** (CRM) é a ponte entre os dois sistemas-fonte:

```
CRM Account  ──→  lv_tpaccountbase  ──→  Sirix Users
(crm_account_id)   (lv_accountid /      (sirix_login =
                    lv_name = LOGIN)      lv_name)
```

Sem ela não é possível associar um cliente CRM às suas operações no Sirix.

---

## Star Schema Gold (resumo visual)

```
                    ┌──────────────┐
                    │  dim_tempo   │
                    └──────┬───────┘
                           │ tempo_sk
         ┌─────────────────┼──────────────────────────┐
         │                 │                           │
 ┌───────▼──────┐  ┌───────▼────────────┐  ┌──────────▼───────────┐
 │fato_meta_    │  │fato_movimentacao_  │  │   fato_operacao      │
 │agente_mes    │  │financeira          │  │ (todos os tickets)   │
 └───────┬──────┘  └────────┬───────────┘  └──────────┬───────────┘
         │                  │                          │
    ┌────▼─────┐     ┌──────▼───────┐      ┌──────────▼──┐
    │dim_agente│     │  dim_cliente │      │  dim_ativo  │
    └──────────┘     └──────────────┘      └─────────────┘
                            │
              ┌─────────────▼────────────────┐
              │      fato_cliente_trade_dia  │
              │    (clientes × dia × agente) │
              └──────────────────────────────┘
```

---

## Rastreabilidade de Camadas

```
[Sirix MT4]          [CRM MS Dynamics]
     │                      │
     ▼                      ▼
 stg_raw   ─── ETL ───►  bronze   ─── transformações SQL ───►  silver
                                                                    │
                                                              domain (lookups)
                                                                    │
                                                             config (negócio)
                                                                    │
                                                               gold (BI)
                                                                    │
                                                                Power BI
```
