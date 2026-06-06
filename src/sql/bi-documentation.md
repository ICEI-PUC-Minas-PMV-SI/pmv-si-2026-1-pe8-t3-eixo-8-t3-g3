# Documentacao BI - Modelo Semantico Power BI BrokerLab

Documento canonico novo para o modelo semantico do Power BI `BI - BrokerLab`.

## Visao geral do desenho

O modelo combina uma star schema `gold` para analises detalhadas com views semanticas ja agregadas para as abas executivas e operacionais do dashboard.

- Dimensoes principais: `gold dim_agente`, `gold dim_ativo`, `gold dim_cliente`, `gold dim_tempo`.
- Fatos principais: `gold fato_movimentacao_financeira`, `gold fato_operacao`, `gold fato_cliente_trade_dia`, `gold fato_meta_agente_mes`.
- Views de consumo: `gold vw_team_month_performance`, `gold vw_agent_month_performance`, `gold vw_agent_day_performance`, `gold vw_call_list_today`, `gold vw_data_quality_summary`, `gold vw_unresolved_agent_alias`, `gold vw_unresolved_client_bridge`.
- Bridge tecnica adicional: `silver vw_account_bridge`.
- Tabela de medidas: `Medidas`, sem colunas de negocio e com 85 medidas no total.

## Tabelas de negocio

Todas as tabelas abaixo estao em modo `Import`, com particao em estado `Ready`, carregadas via Power Query M a partir do PostgreSQL `192.168.5.149/db_brokerlab_reimport_test`.

| Tabela | Colunas | Origem |
|---|---:|---|
| `gold dim_agente` | 13 | `gold.dim_agente` |
| `gold dim_ativo` | 12 | `gold.dim_ativo` |
| `gold dim_cliente` | 26 | `gold.dim_cliente` |
| `gold dim_tempo` | 18 | `gold.dim_tempo` |
| `gold fato_cliente_trade_dia` | 13 | `gold.fato_cliente_trade_dia` |
| `gold fato_meta_agente_mes` | 13 | `gold.fato_meta_agente_mes` |
| `gold fato_movimentacao_financeira` | 26 | `gold.fato_movimentacao_financeira` |
| `gold fato_operacao` | 32 | `gold.fato_operacao` |
| `gold vw_agent_day_performance` | 17 | `gold.vw_agent_day_performance` |
| `gold vw_agent_month_performance` | 32 | `gold.vw_agent_month_performance` |
| `gold vw_call_list_today` | 27 | `gold.vw_call_list_today` |
| `gold vw_data_quality_summary` | 6 | `gold.vw_data_quality_summary` |
| `gold vw_team_month_performance` | 24 | `gold.vw_team_month_performance` |
| `gold vw_unresolved_agent_alias` | 3 | `gold.vw_unresolved_agent_alias` |
| `gold vw_unresolved_client_bridge` | 6 | `gold.vw_unresolved_client_bridge` |
| `silver vw_account_bridge` | 37 | `silver.vw_account_bridge` |

## Colunas por tabela

### `gold dim_agente`

`agente_sk` (int64), `agent_id` (int64), `agent_name` (string), `agent_email` (string), `team_name` (string), `agent_level` (string), `seniority` (string), `agent_type` (string), `is_active` (boolean), `started_on` (dateTime), `ended_on` (dateTime), `crm_full_name` (string), `_loaded_at` (dateTime).

### `gold dim_ativo`

`ativo_sk` (int64), `asset_id` (int64), `sirix_symbol` (string), `normalized_symbol` (string), `display_name` (string), `asset_class` (string), `base_currency` (string), `quote_currency` (string), `is_major_asset` (boolean), `is_active` (boolean), `classification_status` (string), `_loaded_at` (dateTime).

### `gold dim_cliente`

`cliente_sk` (int64), `crm_account_id` (string), `tp_account_id` (string), `sirix_login` (int64), `cliente_nome` (string), `country` (string), `language_iso` (string), `lead_status_code` (int64), `lead_status_text` (string), `lead_status_categoria` (string), `has_ftd` (boolean), `retention_owner_name` (string), `conversion_owner_name` (string), `agent_rule_used` (string), `agent_id_current` (int64), `agente_sk_current` (int64), `balance` (double), `equity` (double), `margin_level` (double), `last_activity_date` (dateTime), `eh_habilitada` (boolean), `eh_readonly` (boolean), `eh_deletada` (boolean), `bridge_quality_status` (string), `_agente_quality` (string), `_loaded_at` (dateTime).

### `gold dim_tempo`

`tempo_sk` (int64), `date` (dateTime), `year` (int64), `quarter` (int64), `month` (int64), `month_start_date` (dateTime), `year_month` (string), `day_of_month` (int64), `day_of_week` (int64), `day_name` (string), `is_weekend` (boolean), `is_business_day` (boolean), `is_global_holiday` (boolean), `holiday_name` (string), `business_day_number_in_month` (int64), `business_days_in_month` (int64), `remaining_business_days_in_month` (int64), `_loaded_at` (dateTime).

### `gold fato_cliente_trade_dia`

`tempo_sk` (int64), `cliente_sk` (int64), `agente_sk` (int64), `sirix_login` (int64), `qtd_trades_dia` (int64), `qtd_ativos_dia` (int64), `volume_lots_dia` (double), `pnl_liquido_dia` (double), `first_trade_ts` (dateTime), `last_trade_ts` (dateTime), `has_open_today` (boolean), `has_close_today` (boolean), `_loaded_at` (dateTime).

### `gold fato_meta_agente_mes`

`competence_month_sk` (int64), `agente_sk` (int64), `competence_month` (dateTime), `target_deposit_month_usd` (double), `target_deposit_day_usd` (double), `target_trade_day` (int64), `target_trade_month` (int64), `target_unique_month` (int64), `business_days_in_month` (int64), `source_type` (string), `_loaded_at` (dateTime), `target_volume_month` (double), `target_volume_unit` (string).

### `gold fato_movimentacao_financeira`

`transaction_sk` (int64), `transaction_id` (string), `tempo_aprovacao_sk` (int64), `tempo_criacao_sk` (int64), `cliente_sk` (int64), `agente_sk` (int64), `crm_account_id` (string), `tp_account_id` (string), `sirix_ticket` (int64), `transaction_type_code` (int64), `transaction_type_categoria` (string), `status_code` (int64), `eh_aprovada` (boolean), `eh_ftd` (boolean), `amount_original` (double), `usd_value` (double), `deposit_amount_usd` (double), `withdrawal_amount_usd` (double), `net_deposit_usd` (double), `currency_iso` (string), `payment_method_code` (int64), `payment_method_name` (string), `approved_on` (dateTime), `created_on` (dateTime), `_agente_quality` (string), `_loaded_at` (dateTime).

### `gold fato_operacao`

`operacao_sk` (int64), `ticket` (int64), `tempo_open_sk` (int64), `tempo_close_sk` (int64), `cliente_sk` (int64), `agente_sk` (int64), `ativo_sk` (int64), `sirix_login` (int64), `cmd_code` (int64), `cmd_tipo` (string), `eh_operacao_mercado` (boolean), `eh_pendente` (boolean), `eh_financeiro_sirix` (boolean), `side` (string), `side_sign` (int64), `symbol` (string), `volume_raw` (int64), `volume_lots` (double), `open_time` (dateTime), `close_time` (dateTime), `eh_aberta` (boolean), `open_price` (double), `close_price` (double), `profit_bruto` (double), `commission` (double), `swaps` (double), `profit_liquido` (double), `duracao_segundos` (int64), `_eh_suspeito` (boolean), `_motivo_suspeito` (string), `_agente_quality` (string), `_loaded_at` (dateTime).

### `gold vw_agent_day_performance`

`ref_date` (dateTime), `year_month` (string), `is_business_day` (boolean), `business_day_number_in_month` (int64), `business_days_in_month` (int64), `agente_sk` (int64), `agent_name` (string), `team_name` (string), `deposit_day` (double), `withdrawal_day` (double), `net_deposit_day` (double), `net_deposit_acumulado_mes` (double), `target_deposit_day_usd` (double), `target_trade_day` (int64), `clientes_operaram_dia` (int64), `total_trades_dia` (int64), `agent_level` (string).

### `gold vw_agent_month_performance`

`agente_sk` (int64), `agent_name` (string), `team_name` (string), `is_active` (boolean), `competence_month` (dateTime), `year_month` (string), `deposit_month_usd` (double), `withdrawal_month_usd` (double), `net_deposit_month_usd` (double), `ftd_count_month` (int64), `unique_deposit_month` (int64), `target_deposit_month_usd` (double), `target_deposit_day_usd` (double), `target_trade_day` (int64), `target_trade_month` (int64), `target_unique_month` (int64), `business_days_in_month` (int64), `target_pct_deposit` (double), `run_rate_usd` (double), `gap_meta_usd` (double), `unique_trading_month` (int64), `total_trades_month` (int64), `volume_lots_month` (double), `pnl_month` (double), `target_pct_trade` (double), `meta_source_type` (string), `target_pct_unique` (double), `trading_client_days_month` (int64), `agent_level` (string), `target_volume_month` (double), `target_volume_unit` (string), `target_pct_volume` (double).

### `gold vw_call_list_today`

`agente_sk` (int64), `agent_name` (string), `team_name` (string), `cliente_sk` (int64), `cliente_nome` (string), `crm_account_id` (string), `tp_account_id` (string), `sirix_login` (int64), `country` (string), `lead_status_text` (string), `has_ftd` (boolean), `balance` (double), `equity` (double), `margin_level` (double), `last_activity_date` (dateTime), `last_deposit_date` (dateTime), `last_deposit_amount_usd` (double), `last_trade_date` (dateTime), `traded_today` (boolean), `is_pending_today` (boolean), `eh_habilitada` (boolean), `eh_readonly` (boolean), `eh_deletada` (boolean), `bridge_quality_status` (string), `_agente_quality` (string), `priority_label` (string), `agent_level` (string).

### `gold vw_data_quality_summary`

`check_name` (string), `categoria` (string), `status` (string), `valor_atual` (string), `threshold` (string), `detalhes` (string).

### `gold vw_team_month_performance`

`team_name` (string), `competence_month` (dateTime), `year_month` (string), `deposit_month_usd` (double), `withdrawal_month_usd` (double), `net_deposit_month_usd` (double), `target_deposit_month_usd` (double), `ftd_count_month` (double), `unique_deposit_month` (double), `unique_trading_month` (double), `total_trades_month` (double), `volume_lots_month` (double), `pnl_month` (double), `target_trade_month` (int64), `target_pct_deposit` (double), `run_rate_usd` (double), `gap_meta_usd` (double), `agentes_ativos` (int64), `target_unique_month` (int64), `target_pct_trade` (double), `target_pct_unique` (double), `trading_client_days_month` (double), `target_volume_month` (double), `target_pct_volume` (double).

### `gold vw_unresolved_agent_alias`

`retention_owner_name` (string), `normalized_key` (string), `clientes_afetados` (int64).

### `gold vw_unresolved_client_bridge`

`tabela` (string), `chave` (string), `crm_account_id` (string), `tp_account_id` (string), `sirix_login` (string), `_agente_quality` (string).

### `silver vw_account_bridge`

`crm_account_id` (string), `cliente_nome` (string), `country` (string), `language_iso` (string), `has_ftd` (boolean), `lead_status_code` (int64), `lead_status_text` (string), `lead_status_categoria` (string), `bu_name` (string), `conversion_owner_name` (string), `conversion_owner_key` (string), `retention_owner_name` (string), `retention_owner_key` (string), `main_tp_account_id` (string), `tp_account_id` (string), `sirix_login` (int64), `sirix_group` (string), `base_currency` (string), `leverage` (int64), `balance_usd` (double), `equity` (double), `pnl_acumulado` (double), `margin_level` (double), `margin_status` (int64), `eh_readonly` (boolean), `eh_deletada` (boolean), `eh_desabilitada` (boolean), `num_open_positions` (int64), `sirix_balance` (double), `sirix_equity` (double), `sirix_margin_level` (double), `sirix_eh_habilitada` (boolean), `sirix_eh_readonly` (boolean), `sirix_last_activity` (dateTime), `has_tp_match` (boolean), `has_sirix_match` (boolean), `bridge_quality_status` (string).

## Relacionamentos de negocio

Todos os relacionamentos abaixo usam cardinalidade many-to-one e filtro unidirecional.

| Nome | Status | De | Para |
|---|---|---|---|
| `7dc6ebb7-15f7-4c9a-a66c-22e66fc92447` | Ativo | `gold fato_cliente_trade_dia[cliente_sk]` | `gold dim_cliente[cliente_sk]` |
| `8dc643ee-6cd1-4a26-a415-aaf325aeaf34` | Ativo | `gold fato_cliente_trade_dia[tempo_sk]` | `gold dim_tempo[tempo_sk]` |
| `09290171-073f-48ce-ab85-b76a2cabd25f` | Ativo | `gold fato_meta_agente_mes[competence_month_sk]` | `gold dim_tempo[tempo_sk]` |
| `d6d19976-37b3-4316-8f78-c7acc654f6f8` | Ativo | `gold fato_operacao[ativo_sk]` | `gold dim_ativo[ativo_sk]` |
| `40219556-a3e9-4810-bbe2-ffac1ae51e6c` | Ativo | `gold fato_operacao[cliente_sk]` | `gold dim_cliente[cliente_sk]` |
| `280d4cd5-ce95-4226-8b4c-4b4cc5755d7c` | Ativo | `gold fato_operacao[tempo_close_sk]` | `gold dim_tempo[tempo_sk]` |
| `5c8ec823-1794-4b18-babe-4cea2b157c15` | Inativo | `gold fato_operacao[tempo_open_sk]` | `gold dim_tempo[tempo_sk]` |
| `b7513318-e891-4793-a9f6-be5e8fff6323` | Ativo | `gold fato_movimentacao_financeira[cliente_sk]` | `gold dim_cliente[cliente_sk]` |
| `7db8f08c-03c7-4148-a210-bfdba9a15338` | Ativo | `gold fato_movimentacao_financeira[tempo_aprovacao_sk]` | `gold dim_tempo[tempo_sk]` |
| `7be2af50-df9c-4494-bee3-432547e73626` | Inativo | `gold fato_movimentacao_financeira[tempo_criacao_sk]` | `gold dim_tempo[tempo_sk]` |
| `rel_fato_fin_agente` | Ativo | `gold fato_movimentacao_financeira[agente_sk]` | `gold dim_agente[agente_sk]` |
| `rel_fato_operacao_agente` | Ativo | `gold fato_operacao[agente_sk]` | `gold dim_agente[agente_sk]` |
| `rel_fato_trade_dia_agente` | Ativo | `gold fato_cliente_trade_dia[agente_sk]` | `gold dim_agente[agente_sk]` |
| `rel_fato_meta_agente` | Ativo | `gold fato_meta_agente_mes[agente_sk]` | `gold dim_agente[agente_sk]` |
| `2855fb35-960c-f86d-2ddd-d72ca4281c78` | Ativo | `gold vw_team_month_performance[competence_month]` | `gold dim_tempo[date]` |
| `2cb7586e-79ff-0943-98a5-8e95be98380e` | Ativo | `gold vw_agent_month_performance[competence_month]` | `gold dim_tempo[date]` |
| `50d0b617-3804-ddf7-a893-09b177f61fd7` | Ativo | `gold vw_agent_day_performance[ref_date]` | `gold dim_tempo[date]` |
| `d6df5a82-ff24-5499-a470-a03ba9b2fab6` | Ativo | `gold vw_call_list_today[agente_sk]` | `gold dim_agente[agente_sk]` |
| `69f4a42d-4b1b-425d-9e80-bad3dd8bdb9c` | Ativo | `gold vw_agent_day_performance[agente_sk]` | `gold dim_agente[agente_sk]` |
| `3f0e3aea-9116-18c5-625a-fe86692338ec` | Ativo | `gold vw_agent_month_performance[agente_sk]` | `gold dim_agente[agente_sk]` |

Observacoes:

- `gold fato_operacao[tempo_close_sk]` esta ativo; `tempo_open_sk` esta inativo.
- `gold fato_movimentacao_financeira[tempo_aprovacao_sk]` esta ativo; `tempo_criacao_sk` esta inativo.
- As views de performance e call list tambem se relacionam diretamente com `gold dim_tempo` e/ou `gold dim_agente`.

## Medidas DAX documentadas

### Pasta `Team Month`

#### `Team Month Deposit USD`

Formato: `\$#,0.00;(\$#,0.00);\$#,0.00`

```DAX
SUM ( 'gold vw_team_month_performance'[deposit_month_usd] )
```

#### `Team Month Withdrawal USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_team_month_performance'[withdrawal_month_usd] )
```

#### `Team Month Net Deposit USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_team_month_performance'[net_deposit_month_usd] )
```

#### `Team Month Target Deposit USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_team_month_performance'[target_deposit_month_usd] )
```

#### `Team Month Target Deposit %`

Formato: `0.00%`

```DAX
DIVIDE ( [Team Month Net Deposit USD], [Team Month Target Deposit USD] )
```

#### `Team Month Run Rate USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_team_month_performance'[run_rate_usd] )
```

#### `Team Month Gap Run Rate USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
[Team Month Net Deposit USD] - [Team Month Run Rate USD]
```

#### `Team Month Gap Meta USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
[Team Month Target Deposit USD] - [Team Month Net Deposit USD]
```

#### `Team Month Unique Deposit QTD`

Formato: `0`

```DAX
SUM ( 'gold vw_team_month_performance'[unique_deposit_month] )
```

#### `Team Month Target Unique QTD`

Formato: `0`

```DAX
SUM ( 'gold vw_team_month_performance'[target_unique_month] )
```

#### `Team Month Target Unique %`

Formato: `0.00%`

```DAX
DIVIDE ( [Team Month Unique Deposit QTD], [Team Month Target Unique QTD] )
```

#### `Team Month Unique Trading QTD`

Formato: `0`

```DAX
SUM ( 'gold vw_team_month_performance'[unique_trading_month] )
```

#### `Team Month Target Trade QTD`

Formato: `0`

```DAX
SUM ( 'gold vw_team_month_performance'[target_trade_month] )
```

#### `Team Month Target Trade %`

Formato: `0.00%`

```DAX
DIVIDE ( [Team Month Trading Client Days QTD], [Team Month Target Trade QTD] )
```

#### `Team Month Total Trades QTD`

Formato: `0`

```DAX
SUM ( 'gold vw_team_month_performance'[total_trades_month] )
```

#### `Status Meta`

```DAX
SWITCH (
    TRUE (),
    [Team Month Target Deposit %] >= 1, "Meta atingida",
    [Team Month Target Deposit %] >= 0.7, FORMAT([Team Month Target Deposit %],"Percent") & " da Meta",
    "Abaixo da Meta"
)
```

#### `Team Month Trading Client Days QTD`

Formato: `0`

```DAX
SUM ( 'gold vw_team_month_performance'[trading_client_days_month] )
```

### Pasta `Call List`

#### `Call List Carteira Clientes QTD`

Formato: `#,0`

```DAX
COUNTROWS ( 'gold vw_call_list_today' )
```

#### `Call List Clientes Operaram Hoje QTD`

Formato: `#,0`

```DAX
CALCULATE ( COUNTROWS ( 'gold vw_call_list_today' ), 'gold vw_call_list_today'[traded_today] = TRUE ())
```

#### `Call List Clientes Pendentes Hoje QTD`

Formato: `#,0`

```DAX
CALCULATE ( COUNTROWS ( 'gold vw_call_list_today' ), 'gold vw_call_list_today'[is_pending_today] = TRUE ())
```

#### `Call List  Carteira Operando Hoje %`

Formato: `0.00%;-0.00%;0.00%`

```DAX
DIVIDE ( [Call List Clientes Operaram Hoje QTD], [Call List Carteira Clientes QTD], 0 )
```

#### `Call List Carteira Operando Hoje %`

Formato: `0.00%;-0.00%;0.00%`

```DAX
DIVIDE ( [Call List Clientes Operaram Hoje QTD], [Call List Carteira Clientes QTD] )
```

#### `Call List Balance USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_call_list_today'[balance] )
```

#### `Call List Equity USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_call_list_today'[equity] )
```

#### `Call List Last Deposit USD`

Formato: `\$#,0.00;(\$#,0.00);\$#,0.00`

```DAX
SUM ( 'gold vw_call_list_today'[last_deposit_amount_usd] )
```

#### `Call List Clientes c Saldo QTD`

Formato: `#,0`

```DAX
CALCULATE ( [Call List Carteira Clientes QTD], OR('gold vw_call_list_today'[balance]>0,'gold vw_call_list_today'[equity]>0))
```

#### `Call List Clientes Pendentes Alta Prioridade QTD`

Formato: `0`

```DAX
CALCULATE ( [Call List Carteira Clientes QTD], 'gold vw_call_list_today'[is_pending_today]=TRUE() && 'gold vw_call_list_today'[priority_label]="Alta")
```

#### `Call List Carteira Pendente Hoje %`

Formato: `0.00%;-0.00%;0.00%`

```DAX
DIVIDE ( [Call List Clientes Pendentes Hoje QTD], [Call List Carteira Clientes QTD] )
```

### Pasta `Agent Month`

#### `Agent Month Rank Net Deposit`

Formato: `#,0`

```DAX
RANKX ( ALLSELECTED ( 'gold dim_agente'[agent_name] ), [Agent Month Net Deposit USD], , DESC, DENSE )
```

#### `Agent Month Net Deposit USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_month_performance'[net_deposit_month_usd] )
```

#### `Agent Month Target USD`

Formato: `\$#,0.###############;(\$#,0.###############);\$#,0.###############`

```DAX
SUM('gold vw_agent_month_performance'[target_deposit_month_usd])
```

#### `Agent Month Target %`

Formato: `0%;-0%;0%`

```DAX
SUM('gold vw_agent_month_performance'[target_pct_deposit])
```

#### `Agent Month Trades QTD`

Formato: `0`

```DAX
SUM('gold vw_agent_month_performance'[total_trades_month])
```

#### `Agent Month Unique Deposit QTD`

Formato: `#,0`

```DAX
SUM ( 'gold vw_agent_month_performance'[unique_deposit_month] )
```

#### `Agent Month Unique Trades QTD`

Formato: `0`

```DAX
SUM('gold vw_agent_month_performance'[unique_trading_month])
```

#### `Agent Month Deposit USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_month_performance'[deposit_month_usd] )
```

#### `Agent Month Withdrawal USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_month_performance'[withdrawal_month_usd] )
```

#### `Agent Month Target Deposit USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_month_performance'[target_deposit_month_usd] )
```

#### `Agent Month Target Deposit %`

Formato: `0.00%;-0.00%;0.00%`

```DAX
DIVIDE ( [Agent Month Net Deposit USD], [Agent Month Target Deposit USD] )
```

#### `Agent Month Run Rate USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_month_performance'[run_rate_usd] )
```

#### `Agent Month Gap Run Rate USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
[Agent Month Net Deposit USD] - [Agent Month Run Rate USD]
```

#### `Agent Month Gap Meta USD`

Formato: `\$#,0.00;(\$#,0.00);\$#,0.00`

```DAX
[Agent Month Target Deposit USD] - [Agent Month Net Deposit USD]
```

#### `Agent Month Target Unique QTD`

Formato: `#,0`

```DAX
SUM ( 'gold vw_agent_month_performance'[target_unique_month] )
```

#### `Agent Month Target Unique %`

Formato: `0.00%;-0.00%;0.00%`

```DAX
DIVIDE ( [Agent Month Unique Deposit QTD], [Agent Month Target Unique QTD] )
```

#### `Agent Month Trading Client Days QTD`

Formato: `#,0`

```DAX
SUM ( 'gold vw_agent_month_performance'[trading_client_days_month] )
```

#### `Agent Month Target Trade QTD`

Formato: `#,0`

```DAX
SUM ( 'gold vw_agent_month_performance'[target_trade_month] )
```

#### `Agent Month Target Trade %`

Formato: `0.00%;-0.00%;0.00%`

```DAX
DIVIDE ( [Agent Month Trading Client Days QTD], [Agent Month Target Trade QTD] )
```

#### `Agent Month Unique Trading QTD`

Formato: `#,0`

```DAX
SUM ( 'gold vw_agent_month_performance'[unique_trading_month] )
```

#### `Agent Month Total Trades QTD`

Formato: `#,0`

```DAX
SUM ( 'gold vw_agent_month_performance'[total_trades_month] )
```

#### `Agent Month Volume Lots QTD`

Formato: `#,0.00`

```DAX
SUM ( 'gold vw_agent_month_performance'[volume_lots_month] )
```

#### `Agent Month PnL USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_month_performance'[pnl_month] )
```

#### `Agent Month Status Meta TXT`

```DAX
SWITCH ( TRUE (), [Agent Month Target Deposit %] >= 1, "Meta atingida", [Agent Month Target Deposit %] >= 0.7, FORMAT ( [Agent Month Target Deposit %], "0.00%" ) & " da Meta", "Abaixo da Meta" )
```

#### `Agent Month Status Meta`

```DAX
SWITCH (
    TRUE (),
    [Agent Month Target Deposit %] >= 1, "Meta atingida",
    [Agent Month Target Deposit %] >= 0.7, FORMAT([Agent Month Target Deposit %],"Percent") & " da Meta",
    "Abaixo da Meta"
)
```

### Pasta `Agent Day`

#### `Agent Day Net Deposit USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_day_performance'[net_deposit_day] )
```

#### `Agent Day Target Deposit USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_day_performance'[target_deposit_day_usd] )
```

#### `Agent Day Target Deposit %`

Formato: `0.00%;-0.00%;0.00%`

```DAX
DIVIDE ( [Agent Day Net Deposit USD], [Agent Day Target Deposit USD] )
```

#### `Agent Day Withdrawal USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_day_performance'[withdrawal_day] )
```

#### `Agent Day Deposit USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
SUM ( 'gold vw_agent_day_performance'[deposit_day] )
```

#### `Agent Day Net Deposit Acumulado USD`

Formato: `$#,0.00;($#,0.00);$#,0.00`

```DAX
MAX ( 'gold vw_agent_day_performance'[net_deposit_acumulado_mes] )
```

#### `Agent Day Clientes Operaram QTD`

Formato: `#,0`

```DAX
SUM ( 'gold vw_agent_day_performance'[clientes_operaram_dia] )
```

#### `Agent Day Total Trades QTD`

Formato: `#,0`

```DAX
SUM ( 'gold vw_agent_day_performance'[total_trades_dia] )
```

#### `Agent Day Target Trade QTD`

Formato: `#,0`

```DAX
SUM ( 'gold vw_agent_day_performance'[target_trade_day] )
```