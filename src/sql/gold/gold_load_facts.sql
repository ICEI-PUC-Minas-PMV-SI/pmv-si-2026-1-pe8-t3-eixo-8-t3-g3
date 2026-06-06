-- =============================================================================
-- gold_load_facts.sql — Carga dos 4 fatos gold
-- Criado: 2026-05-12
-- Depende de: gold_ddl.sql, gold_load_dimensions.sql executados
-- Ordem: fato_meta_agente_mes → fato_movimentacao_financeira → fato_operacao → fato_cliente_trade_dia
-- Estratégia inicial: full refresh (TRUNCATE + INSERT)
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. fato_meta_agente_mes
-- ---------------------------------------------------------------------------
\echo '>> Carregando gold.fato_meta_agente_mes...'

TRUNCATE gold.fato_meta_agente_mes CASCADE;

INSERT INTO gold.fato_meta_agente_mes (
    competence_month_sk, agente_sk, competence_month,
    target_deposit_month_usd, target_deposit_day_usd,
    target_trade_day, target_trade_month,
    target_unique_month, target_volume_month, target_volume_unit, business_days_in_month,
    source_type, _loaded_at
)
SELECT
    dt.tempo_sk                                                 AS competence_month_sk,
    da.agente_sk,
    t.competence_month,
    t.target_deposit_month_usd,
    ROUND(t.target_deposit_month_usd / NULLIF(cal.business_days_in_month, 0), 2)
                                                                AS target_deposit_day_usd,
    t.target_trade_day,
    COALESCE(t.target_trade_month, t.target_trade_day * cal.business_days_in_month)
                                                                AS target_trade_month,
    t.target_unique_month,
    t.target_volume_month,
    t.target_volume_unit,
    cal.business_days_in_month,
    t.source_type,
    NOW()
FROM config.agent_target_month t
JOIN gold.dim_agente da
    ON da.agent_id = t.agent_id
JOIN gold.dim_tempo dt
    ON dt.date = t.competence_month
JOIN (
    SELECT month_start_date, MAX(business_days_in_month) AS business_days_in_month
    FROM config.business_calendar
    GROUP BY month_start_date
) cal ON cal.month_start_date = t.competence_month
WHERE t.is_active = TRUE;

DO $$
DECLARE v INTEGER;
BEGIN
    SELECT COUNT(*) INTO v FROM gold.fato_meta_agente_mes;
    RAISE NOTICE 'fato_meta_agente_mes: % linhas', v;
END $$;

-- ---------------------------------------------------------------------------
-- 2. fato_movimentacao_financeira
-- Métrica oficial: deposit = approved_date (tempo_aprovacao_sk)
-- net_deposit = depósito - withdrawal aprovados
-- ---------------------------------------------------------------------------
\echo '>> Carregando gold.fato_movimentacao_financeira...'

TRUNCATE gold.fato_movimentacao_financeira CASCADE;

INSERT INTO gold.fato_movimentacao_financeira (
    transaction_id,
    tempo_aprovacao_sk, tempo_criacao_sk,
    cliente_sk, agente_sk,
    crm_account_id, tp_account_id, sirix_ticket,
    transaction_type_code, transaction_type_categoria,
    status_code, eh_aprovada, eh_ftd,
    amount_original, usd_value,
    deposit_amount_usd, withdrawal_amount_usd, net_deposit_usd,
    currency_iso, payment_method_code, payment_method_name,
    approved_on, created_on,
    _agente_quality, _loaded_at
)
SELECT
    tr.transaction_id,

    -- tempo de aprovação (métrica principal)
    CASE WHEN tr.approved_date IS NOT NULL
         THEN TO_CHAR(tr.approved_date, 'YYYYMMDD')::INTEGER
         ELSE NULL
    END                                                         AS tempo_aprovacao_sk,

    -- tempo de criação
    CASE WHEN tr.created_date IS NOT NULL
         THEN TO_CHAR(tr.created_date, 'YYYYMMDD')::INTEGER
         ELSE NULL
    END                                                         AS tempo_criacao_sk,

    dc.cliente_sk,
    COALESCE(dc.agente_sk_current, (SELECT agente_sk FROM gold.dim_agente WHERE agent_name = 'Pool' LIMIT 1))
                                                                AS agente_sk,
    tr.crm_account_id,
    tr.tp_account_id,
    tr.sirix_ticket,
    tr.transaction_type_code,
    tr.transaction_type_categoria,
    tr.status_code,
    tr.eh_aprovada,
    tr.eh_ftd,
    tr.amount_original,
    tr.usd_value,

    -- deposit_amount_usd: apenas depósitos aprovados
    CASE WHEN tr.eh_deposito AND tr.eh_aprovada THEN tr.usd_value ELSE 0 END,

    -- withdrawal_amount_usd: apenas withdrawals aprovados
    CASE WHEN tr.eh_withdrawal AND tr.eh_aprovada THEN tr.usd_value ELSE 0 END,

    -- net_deposit: depósito - withdrawal (ambos aprovados)
    CASE
        WHEN tr.eh_deposito  AND tr.eh_aprovada THEN  tr.usd_value
        WHEN tr.eh_withdrawal AND tr.eh_aprovada THEN -tr.usd_value
        ELSE 0
    END,

    tr.currency_iso,
    tr.payment_method_code,
    tr.payment_method_name,
    tr.approved_date,
    tr.created_on,

    CASE WHEN dc.agente_sk_current IS NOT NULL THEN 'resolved' ELSE 'current_owner_fallback' END,
    NOW()

FROM silver.transaction_clean tr
LEFT JOIN gold.dim_cliente dc
    ON dc.crm_account_id = tr.crm_account_id;

DO $$
DECLARE v_total INTEGER; v_dep NUMERIC; v_wit NUMERIC;
BEGIN
    SELECT COUNT(*), SUM(deposit_amount_usd), SUM(withdrawal_amount_usd)
    INTO v_total, v_dep, v_wit
    FROM gold.fato_movimentacao_financeira;
    RAISE NOTICE 'fato_movimentacao_financeira: % linhas | Deposito USD %.2f | Withdrawal USD %.2f', v_total, COALESCE(v_dep,0), COALESCE(v_wit,0);
END $$;

-- ---------------------------------------------------------------------------
-- 3. fato_operacao
-- ---------------------------------------------------------------------------
\echo '>> Carregando gold.fato_operacao...'

TRUNCATE gold.fato_operacao CASCADE;

INSERT INTO gold.fato_operacao (
    ticket, tempo_open_sk, tempo_close_sk,
    cliente_sk, agente_sk, ativo_sk,
    sirix_login, cmd_code, cmd_tipo,
    eh_operacao_mercado, eh_pendente, eh_financeiro_sirix,
    side, side_sign, symbol, volume_raw, volume_lots,
    open_time, close_time, eh_aberta,
    open_price, close_price,
    profit_bruto, commission, swaps, profit_liquido,
    duracao_segundos,
    _eh_suspeito, _motivo_suspeito, _agente_quality, _loaded_at
)
SELECT
    tc.ticket,

    -- surrogate de data de abertura
    CASE WHEN tc.open_date IS NOT NULL
         THEN TO_CHAR(tc.open_date, 'YYYYMMDD')::INTEGER
         ELSE NULL
    END                                                         AS tempo_open_sk,

    -- surrogate de data de fechamento
    CASE WHEN tc.close_date IS NOT NULL
         THEN TO_CHAR(tc.close_date, 'YYYYMMDD')::INTEGER
         ELSE NULL
    END                                                         AS tempo_close_sk,

    dc.cliente_sk,
    COALESCE(dc.agente_sk_current,
             (SELECT agente_sk FROM gold.dim_agente WHERE agent_name = 'Pool' LIMIT 1))
                                                                AS agente_sk,
    dav.ativo_sk,

    tc.sirix_login,
    tc.cmd_code,
    tc.cmd_tipo,
    tc.eh_operacao_mercado,
    tc.eh_pendente,
    tc.eh_financeiro,
    tc.side,
    tc.side_sign,
    tc.symbol,
    tc.volume                                                   AS volume_raw,
    tc.volume_lots,
    tc.open_time,
    tc.close_time,
    tc.eh_aberta,
    tc.open_price,
    tc.close_price,
    tc.profit_bruto,
    tc.commission,
    tc.swaps,
    tc.profit_liquido,
    tc.duracao_segundos,
    tc._eh_suspeito,
    tc._motivo_suspeito,
    CASE WHEN dc.agente_sk_current IS NOT NULL THEN 'resolved' ELSE 'current_owner_fallback' END,
    NOW()

FROM silver.trade_clean tc
LEFT JOIN gold.dim_cliente dc
    ON dc.sirix_login = tc.sirix_login
LEFT JOIN gold.dim_ativo dav
    ON dav.sirix_symbol = tc.symbol_key;

DO $$
DECLARE v_total INTEGER; v_market INTEGER; v_open INTEGER;
BEGIN
    SELECT COUNT(*), COUNT(*) FILTER (WHERE eh_operacao_mercado), COUNT(*) FILTER (WHERE eh_aberta)
    INTO v_total, v_market, v_open
    FROM gold.fato_operacao;
    RAISE NOTICE 'fato_operacao: % linhas | % mercado CMD0/1 | % abertas', v_total, v_market, v_open;
END $$;

-- ---------------------------------------------------------------------------
-- 4. fato_cliente_trade_dia — agrega de fato_operacao (apenas CMD 0/1, open_date)
-- ---------------------------------------------------------------------------
\echo '>> Carregando gold.fato_cliente_trade_dia...'

TRUNCATE gold.fato_cliente_trade_dia CASCADE;

INSERT INTO gold.fato_cliente_trade_dia (
    tempo_sk, cliente_sk, agente_sk, sirix_login,
    qtd_trades_dia, qtd_ativos_dia,
    volume_lots_dia, pnl_liquido_dia,
    first_trade_ts, last_trade_ts,
    has_open_today, has_close_today, _loaded_at
)
SELECT
    fo.tempo_open_sk                            AS tempo_sk,
    fo.cliente_sk,
    MAX(fo.agente_sk)                           AS agente_sk,
    MAX(fo.sirix_login)                         AS sirix_login,
    COUNT(*)                                    AS qtd_trades_dia,
    COUNT(DISTINCT fo.ativo_sk)                 AS qtd_ativos_dia,
    SUM(fo.volume_lots)                         AS volume_lots_dia,
    SUM(fo.profit_liquido)                      AS pnl_liquido_dia,
    MIN(fo.open_time)                           AS first_trade_ts,
    MAX(fo.open_time)                           AS last_trade_ts,
    TRUE                                        AS has_open_today,  -- todo o grupo abriu neste dia
    -- has_close_today: TRUE se algum ticket do cliente fechou neste mesmo dia
    BOOL_OR(fo.tempo_close_sk = fo.tempo_open_sk AND fo.close_time IS NOT NULL)
                                                AS has_close_today,
    NOW()
FROM gold.fato_operacao fo
WHERE fo.eh_operacao_mercado = TRUE    -- apenas CMD 0/1
  AND fo.tempo_open_sk IS NOT NULL
  AND fo.cliente_sk IS NOT NULL
GROUP BY fo.tempo_open_sk, fo.cliente_sk;

DO $$
DECLARE v INTEGER;
BEGIN
    SELECT COUNT(*) INTO v FROM gold.fato_cliente_trade_dia;
    RAISE NOTICE 'fato_cliente_trade_dia: % linhas (cliente x dia)', v;
END $$;

COMMIT;
