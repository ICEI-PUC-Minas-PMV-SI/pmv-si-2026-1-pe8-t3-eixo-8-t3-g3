-- =============================================================================
-- gold_views.sql — Views semânticas MVP para Power BI
-- Criado: 2026-05-12
-- Depende de: gold_ddl.sql, gold_load_facts.sql executados
-- Ordem: vw_agent_month_performance → vw_agent_day_performance →
--        vw_team_month_performance → vw_call_list_today →
--        vw_data_quality_summary → vw_unresolved_agent_alias →
--        vw_unresolved_client_bridge
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. gold.vw_agent_month_performance
-- Grão: 1 linha por agente por mês competência
-- Fonte: fato_movimentacao_financeira + fato_cliente_trade_dia + fato_meta_agente_mes
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_agent_month_performance AS
WITH

-- dias úteis do mês de referência (baseado em CURRENT_DATE)
today_cal AS (
    SELECT
        month_start_date,
        business_day_number_in_month    AS bday_number_today,
        business_days_in_month
    FROM config.business_calendar
    WHERE date = '2026-04-28' --CURRENT_DATE
),

-- base canônica agente x mês: qualquer mês com meta, financeiro ou trading
agent_month_base AS (
    SELECT agente_sk, competence_month
    FROM gold.fato_meta_agente_mes

    UNION

    SELECT
        agente_sk,
        DATE_TRUNC('month', approved_on)::date AS competence_month
    FROM gold.fato_movimentacao_financeira
    WHERE eh_aprovada = TRUE
      AND approved_on IS NOT NULL
      AND agente_sk IS NOT NULL

    UNION

    SELECT
        ctd.agente_sk,
        dt.month_start_date AS competence_month
    FROM gold.fato_cliente_trade_dia ctd
    JOIN gold.dim_tempo dt ON dt.tempo_sk = ctd.tempo_sk
    WHERE ctd.agente_sk IS NOT NULL
),

-- depósitos e withdrawals por agente/mês (aprovados)
fin AS (
    SELECT
        DATE_TRUNC('month', f.approved_on)::date    AS competence_month,
        f.agente_sk,
        SUM(f.deposit_amount_usd)                   AS deposit_month_usd,
        SUM(f.withdrawal_amount_usd)                AS withdrawal_month_usd,
        SUM(f.net_deposit_usd)                      AS net_deposit_month_usd,
        COUNT(DISTINCT CASE WHEN f.eh_ftd THEN f.cliente_sk END)    AS ftd_count_month,
        COUNT(DISTINCT CASE WHEN f.deposit_amount_usd > 0
                            THEN f.cliente_sk END)                   AS unique_deposit_month
    FROM gold.fato_movimentacao_financeira f
    WHERE f.eh_aprovada = TRUE
      AND f.approved_on IS NOT NULL
    GROUP BY 1, 2
),

-- clientes que operaram por agente/mês (CMD 0/1)
-- trading_client_days_month: soma de "cliente operou nesse dia" ao longo do mês
-- (grão fato_cliente_trade_dia = cliente x dia, COUNT(*) = soma diária correta para meta de trade)
-- unique_trading_month: distintos no mês — mantido apenas como métrica auxiliar
trading AS (
    SELECT
        dt.month_start_date                         AS competence_month,
        ctd.agente_sk,
        COUNT(*)                                    AS trading_client_days_month,
        COUNT(DISTINCT ctd.cliente_sk)              AS unique_trading_month,
        SUM(ctd.qtd_trades_dia)                     AS total_trades_month,
        SUM(ctd.volume_lots_dia)                    AS volume_lots_month,
        SUM(ctd.pnl_liquido_dia)                    AS pnl_month
    FROM gold.fato_cliente_trade_dia ctd
    JOIN gold.dim_tempo dt ON dt.tempo_sk = ctd.tempo_sk
    GROUP BY 1, 2
)

SELECT
    da.agente_sk,
    da.agent_name,
    da.team_name,
    da.agent_level,
    da.is_active,

    -- mês de competência
    amb.competence_month,
    TO_CHAR(amb.competence_month, 'YYYY-MM') AS year_month,

    -- financeiro
    COALESCE(fin.deposit_month_usd,     0)  AS deposit_month_usd,
    COALESCE(fin.withdrawal_month_usd,  0)  AS withdrawal_month_usd,
    COALESCE(fin.net_deposit_month_usd, 0)  AS net_deposit_month_usd,
    COALESCE(fin.ftd_count_month,       0)  AS ftd_count_month,
    COALESCE(fin.unique_deposit_month,  0)  AS unique_deposit_month,

    -- metas
    COALESCE(meta.target_deposit_month_usd, 0)  AS target_deposit_month_usd,
    COALESCE(meta.target_deposit_day_usd,   0)  AS target_deposit_day_usd,
    COALESCE(meta.target_trade_day,         0)  AS target_trade_day,
    COALESCE(meta.target_trade_month,       0)  AS target_trade_month,
    COALESCE(meta.target_unique_month,      0)  AS target_unique_month,
    meta.target_volume_month                     AS target_volume_month,
    meta.target_volume_unit                      AS target_volume_unit,
    COALESCE(meta.business_days_in_month,   0)  AS business_days_in_month,

    -- target %
    CASE WHEN COALESCE(meta.target_deposit_month_usd, 0) > 0
         THEN ROUND(COALESCE(fin.net_deposit_month_usd, 0)
                  / meta.target_deposit_month_usd, 2)
         ELSE NULL
    END                                         AS target_pct_deposit,

    -- run rate (extrapola realizado até hoje pelo ritmo diário)
    -- fórmula: realizado * dias_uteis_mes / dias_uteis_ate_hoje
    CASE
        WHEN amb.competence_month = tc.month_start_date
             AND COALESCE(tc.bday_number_today, 0) > 0
        THEN ROUND(COALESCE(fin.net_deposit_month_usd, 0)
                 * COALESCE(meta.business_days_in_month, tc.business_days_in_month)::NUMERIC
                 / tc.bday_number_today, 2)
        ELSE NULL
    END                                         AS run_rate_usd,

    -- gap meta (meta - realizado)
    COALESCE(meta.target_deposit_month_usd, 0)
        - COALESCE(fin.net_deposit_month_usd, 0)
                                                AS gap_meta_usd,

    -- trading
    -- trading_client_days_month: realizado do acelerador de trade (soma de cliente-dia no mês)
    COALESCE(trading.trading_client_days_month, 0) AS trading_client_days_month,
    -- unique_trading_month: distintos no mês (métrica auxiliar — NÃO usar para Target Trade %)
    COALESCE(trading.unique_trading_month, 0)   AS unique_trading_month,
    COALESCE(trading.total_trades_month,   0)   AS total_trades_month,
    COALESCE(trading.volume_lots_month,    0)   AS volume_lots_month,
    COALESCE(trading.pnl_month,            0)   AS pnl_month,

    -- target % trade: realizado = trading_client_days_month (soma cliente-dia)
    --                 meta      = target_trade_day × business_days_in_month
    CASE WHEN COALESCE(meta.target_trade_month, 0) > 0
         THEN ROUND(COALESCE(trading.trading_client_days_month, 0) * 100.0
                  / meta.target_trade_month, 2)
         ELSE NULL
    END                                         AS target_pct_trade,

    CASE WHEN COALESCE(meta.target_volume_month, 0) > 0
              AND LOWER(COALESCE(meta.target_volume_unit, '')) = 'lots'
         THEN ROUND(COALESCE(trading.volume_lots_month, 0) * 100.0
                  / meta.target_volume_month, 2)
         ELSE NULL
    END                                         AS target_pct_volume,

    meta.source_type                            AS meta_source_type,

    -- target % unique oficial (clientes distintos com depósito aprovado no mês)
    CASE WHEN COALESCE(meta.target_unique_month, 0) > 0
         THEN ROUND(COALESCE(fin.unique_deposit_month, 0) * 100.0
                  / meta.target_unique_month, 2)
         ELSE NULL
    END                                         AS target_pct_unique

FROM agent_month_base amb
JOIN gold.dim_agente da
    ON da.agente_sk = amb.agente_sk
CROSS JOIN today_cal tc
LEFT JOIN fin
    ON fin.agente_sk = amb.agente_sk
    AND fin.competence_month = amb.competence_month
LEFT JOIN trading
    ON trading.agente_sk = amb.agente_sk
    AND trading.competence_month = amb.competence_month
LEFT JOIN gold.fato_meta_agente_mes meta
    ON meta.agente_sk = amb.agente_sk
    AND meta.competence_month = amb.competence_month
WHERE da.agent_type = 'individual';

COMMENT ON VIEW gold.vw_agent_month_performance IS 'Grão: agente x mês. KPIs financeiros, metas, run rate, trading. Base para Power BI.';

-- ---------------------------------------------------------------------------
-- 2. gold.vw_agent_day_performance
-- Grão: 1 linha por agente por dia
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_agent_day_performance AS
WITH

fin_dia AS (
    SELECT
        f.approved_on::date     AS ref_date,
        f.agente_sk,
        SUM(f.deposit_amount_usd)       AS deposit_day,
        SUM(f.withdrawal_amount_usd)    AS withdrawal_day,
        SUM(f.net_deposit_usd)          AS net_deposit_day
    FROM gold.fato_movimentacao_financeira f
    WHERE f.eh_aprovada = TRUE AND f.approved_on IS NOT NULL
    GROUP BY 1, 2
),

-- acumulado mês até o dia
fin_acumulado AS (
    SELECT
        f.approved_on::date     AS ref_date,
        f.agente_sk,
        DATE_TRUNC('month', f.approved_on)::date    AS competence_month,
        SUM(SUM(f.net_deposit_usd)) OVER (
            PARTITION BY f.agente_sk, DATE_TRUNC('month', f.approved_on)
            ORDER BY f.approved_on::date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                       AS net_deposit_acumulado_mes
    FROM gold.fato_movimentacao_financeira f
    WHERE f.eh_aprovada = TRUE AND f.approved_on IS NOT NULL
    GROUP BY 1, 2, 3
),

trade_dia AS (
    SELECT
        dt.date                 AS ref_date,
        ctd.agente_sk,
        COUNT(DISTINCT ctd.cliente_sk)  AS clientes_operaram_dia,
        SUM(ctd.qtd_trades_dia)         AS total_trades_dia
    FROM gold.fato_cliente_trade_dia ctd
    JOIN gold.dim_tempo dt ON dt.tempo_sk = ctd.tempo_sk
    GROUP BY 1, 2
)

SELECT
    dt.date                     AS ref_date,
    dt.year_month,
    dt.is_business_day,
    dt.business_day_number_in_month,
    dt.business_days_in_month,
    da.agente_sk,
    da.agent_name,
    da.team_name,
    da.agent_level,

    COALESCE(fd.deposit_day,    0)  AS deposit_day,
    COALESCE(fd.withdrawal_day, 0)  AS withdrawal_day,
    COALESCE(fd.net_deposit_day,0)  AS net_deposit_day,

    COALESCE(fa.net_deposit_acumulado_mes, 0)   AS net_deposit_acumulado_mes,

    meta.target_deposit_day_usd                 AS target_deposit_day_usd,
    meta.target_trade_day                       AS target_trade_day,

    COALESCE(td.clientes_operaram_dia, 0)       AS clientes_operaram_dia,
    COALESCE(td.total_trades_dia,      0)       AS total_trades_dia

FROM gold.dim_tempo dt
CROSS JOIN gold.dim_agente da
LEFT JOIN fin_dia fd
    ON fd.ref_date = dt.date AND fd.agente_sk = da.agente_sk
LEFT JOIN fin_acumulado fa
    ON fa.ref_date = dt.date AND fa.agente_sk = da.agente_sk
LEFT JOIN trade_dia td
    ON td.ref_date = dt.date AND td.agente_sk = da.agente_sk
LEFT JOIN gold.fato_meta_agente_mes meta
    ON meta.agente_sk        = da.agente_sk
    AND meta.competence_month = dt.month_start_date
WHERE da.agent_type = 'individual'
  AND dt.is_business_day = TRUE
  AND (fd.deposit_day IS NOT NULL OR td.clientes_operaram_dia IS NOT NULL);  -- apenas dias com dados

COMMENT ON VIEW gold.vw_agent_day_performance IS 'Grão: agente x dia. Financeiro e trading diários com acumulado mês.';

-- ---------------------------------------------------------------------------
-- 3. gold.vw_team_month_performance
-- Grão: 1 linha por equipe por mês (agrega vw_agent_month_performance)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_team_month_performance AS
SELECT
    v.team_name,
    v.competence_month,
    v.year_month,
    SUM(v.deposit_month_usd)            AS deposit_month_usd,
    SUM(v.withdrawal_month_usd)         AS withdrawal_month_usd,
    SUM(v.net_deposit_month_usd)        AS net_deposit_month_usd,
    SUM(v.target_deposit_month_usd)     AS target_deposit_month_usd,
    SUM(v.ftd_count_month)              AS ftd_count_month,
    SUM(v.unique_deposit_month)         AS unique_deposit_month,
    SUM(v.trading_client_days_month)    AS trading_client_days_month,
    SUM(v.unique_trading_month)         AS unique_trading_month,
    SUM(v.total_trades_month)           AS total_trades_month,
    SUM(v.volume_lots_month)            AS volume_lots_month,
    SUM(v.target_volume_month)          AS target_volume_month,
    SUM(v.pnl_month)                    AS pnl_month,
    SUM(v.target_trade_month)           AS target_trade_month,
    CASE WHEN SUM(v.target_deposit_month_usd) > 0
         THEN ROUND(SUM(v.net_deposit_month_usd) / SUM(v.target_deposit_month_usd), 2)
         ELSE NULL
    END                                 AS target_pct_deposit,
    SUM(v.run_rate_usd)                 AS run_rate_usd,
    SUM(v.gap_meta_usd)                 AS gap_meta_usd,
    COUNT(DISTINCT v.agente_sk) FILTER (WHERE v.is_active = TRUE)
                                        AS agentes_ativos,
    SUM(v.target_unique_month)          AS target_unique_month,
    CASE WHEN SUM(v.target_trade_month) > 0
         THEN ROUND(SUM(v.trading_client_days_month) * 100.0 / SUM(v.target_trade_month), 2)
         ELSE NULL
    END                                 AS target_pct_trade,
    CASE WHEN SUM(v.target_volume_month) > 0
         THEN ROUND(SUM(v.volume_lots_month) * 100.0 / SUM(v.target_volume_month), 2)
         ELSE NULL
    END                                 AS target_pct_volume,
    CASE WHEN SUM(v.target_unique_month) > 0
         THEN ROUND(SUM(v.unique_deposit_month) * 100.0 / SUM(v.target_unique_month), 2)
         ELSE NULL
    END                                 AS target_pct_unique
FROM gold.vw_agent_month_performance v
WHERE v.competence_month IS NOT NULL
GROUP BY v.team_name, v.competence_month, v.year_month;

COMMENT ON VIEW gold.vw_team_month_performance IS 'Grão: equipe x mês. Agregação de vw_agent_month_performance.';

-- ---------------------------------------------------------------------------
-- 4. gold.vw_call_list_today
-- Grão: 1 linha por cliente (carteira do agente no dia atual)
-- Regra MVP: carteira = todos os clientes com retention_owner atribuído
-- Operou hoje = abriu CMD 0/1 com open_date = CURRENT_DATE
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_call_list_today AS
WITH

today_sk AS (
    SELECT 
    --TO_CHAR(CURRENT_DATE, 'YYYYMMDD')::INTEGER AS sk
    20260428 AS sk
),

-- operações hoje
operou_hoje AS (
    SELECT DISTINCT ctd.cliente_sk
    FROM gold.fato_cliente_trade_dia ctd
    CROSS JOIN today_sk ts
    WHERE ctd.tempo_sk = ts.sk
),

-- último trade de cada cliente
ultimo_trade AS (
    SELECT
        ctd.cliente_sk,
        MAX(dt.date)    AS last_trade_date
    FROM gold.fato_cliente_trade_dia ctd
    JOIN gold.dim_tempo dt ON dt.tempo_sk = ctd.tempo_sk
    GROUP BY ctd.cliente_sk
),

-- último depósito de cada cliente
ultimo_deposito AS (
    SELECT DISTINCT ON (f.cliente_sk)
        f.cliente_sk,
        f.approved_on   AS last_deposit_date,
        f.deposit_amount_usd AS last_deposit_amount_usd
    FROM gold.fato_movimentacao_financeira f
    WHERE f.deposit_amount_usd > 0
    ORDER BY f.cliente_sk, f.approved_on DESC NULLS LAST
)

SELECT
    da.agente_sk,
    da.agent_name,
    da.team_name,
    da.agent_level,

    dc.cliente_sk,
    dc.cliente_nome,
    dc.crm_account_id,
    dc.tp_account_id,
    dc.sirix_login,
    dc.country,
    dc.lead_status_text,
    dc.has_ftd,

    -- snapshot financeiro
    dc.balance,
    dc.equity,
    dc.margin_level,
    dc.last_activity_date,

    -- último depósito
    ud.last_deposit_date,
    ud.last_deposit_amount_usd,

    -- último trade
    ut.last_trade_date,

    -- operou hoje (abriu operação de mercado hoje)
    CASE WHEN oh.cliente_sk IS NOT NULL THEN TRUE ELSE FALSE END    AS traded_today,

    -- pendente: está na carteira e NÃO operou hoje
    CASE WHEN oh.cliente_sk IS NULL THEN TRUE ELSE FALSE END        AS is_pending_today,

    -- flags técnicas (atributos — não usados como filtro de elegibilidade no MVP)
    dc.eh_habilitada,
    dc.eh_readonly,
    dc.eh_deletada,
    dc.bridge_quality_status,
    dc._agente_quality,

    -- prioridade provisória (critério: balance)
    CASE
        WHEN dc.balance > 10000 THEN 'Alta'
        WHEN dc.balance > 1000  THEN 'Média'
        ELSE 'Baixa'
    END                                                             AS priority_label

FROM gold.dim_cliente dc
JOIN gold.dim_agente da
    ON da.agente_sk = dc.agente_sk_current
    AND da.agent_type = 'individual'
    AND da.is_active = TRUE
LEFT JOIN operou_hoje oh
    ON oh.cliente_sk = dc.cliente_sk
LEFT JOIN ultimo_trade ut
    ON ut.cliente_sk = dc.cliente_sk
LEFT JOIN ultimo_deposito ud
    ON ud.cliente_sk = dc.cliente_sk;

COMMENT ON VIEW gold.vw_call_list_today IS 'Grão: cliente x hoje. Carteira do retention owner com flag operou/pendente. Sem filtro de bloqueio no MVP.';

-- ---------------------------------------------------------------------------
-- 5. gold.vw_data_quality_summary
-- Grão: 1 linha por check de qualidade
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_data_quality_summary AS
SELECT check_name, categoria, status, valor_atual, threshold, detalhes
FROM (
    VALUES

    ('trades_sem_cliente',       'Gold',   CASE WHEN (SELECT COUNT(*) FROM gold.fato_operacao WHERE cliente_sk IS NULL) = 0 THEN 'OK' ELSE 'WARN' END,
        (SELECT COUNT(*) FROM gold.fato_operacao WHERE cliente_sk IS NULL)::text,
        '0', 'fato_operacao sem cliente_sk'),

    ('trades_sem_agente',        'Gold',   CASE WHEN (SELECT COUNT(*) FROM gold.fato_operacao WHERE agente_sk IS NULL) = 0 THEN 'OK' ELSE 'WARN' END,
        (SELECT COUNT(*) FROM gold.fato_operacao WHERE agente_sk IS NULL)::text,
        '0', 'fato_operacao sem agente_sk'),

    ('tx_sem_cliente',           'Gold',   CASE WHEN (SELECT COUNT(*) FROM gold.fato_movimentacao_financeira WHERE cliente_sk IS NULL) = 0 THEN 'OK' ELSE 'WARN' END,
        (SELECT COUNT(*) FROM gold.fato_movimentacao_financeira WHERE cliente_sk IS NULL)::text,
        '0', 'fato_movimentacao sem cliente_sk'),

    ('operacoes_sem_ativo',      'Gold',   CASE WHEN (SELECT COUNT(*) FROM gold.fato_operacao WHERE eh_operacao_mercado AND ativo_sk IS NULL) = 0 THEN 'OK' ELSE 'WARN' END,
        (SELECT COUNT(*) FROM gold.fato_operacao WHERE eh_operacao_mercado AND ativo_sk IS NULL)::text,
        '0', 'CMD 0/1 sem ativo_sk'),

    ('clientes_agente_unresolved','Gold',  CASE WHEN (SELECT COUNT(*) * 100.0 / NULLIF(COUNT(*),0) FROM gold.dim_cliente WHERE _agente_quality != 'resolved') < 15 THEN 'OK' ELSE 'WARN' END,
        ROUND((SELECT COUNT(*) * 100.0 / NULLIF((SELECT COUNT(*) FROM gold.dim_cliente),0) FROM gold.dim_cliente WHERE _agente_quality != 'resolved'), 2)::text || '%',
        '<15%', '% clientes sem agente resolvido'),

    ('aliases_sem_match',        'Config', CASE WHEN (SELECT COUNT(DISTINCT ac.retention_owner_name) FROM silver.account_clean ac WHERE ac.retention_owner_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM config.agent_alias aa WHERE aa.normalized_alias = LOWER(TRIM(ac.retention_owner_name)) AND aa.source_system = 'CRM')) = 0 THEN 'OK' ELSE 'WARN' END,
        (SELECT COUNT(DISTINCT ac.retention_owner_name) FROM silver.account_clean ac WHERE ac.retention_owner_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM config.agent_alias aa WHERE aa.normalized_alias = LOWER(TRIM(ac.retention_owner_name)) AND aa.source_system = 'CRM'))::text,
        '0', 'retention_owner sem alias CRM'),

    ('metodos_pagamento_nao_oficiais','Config', 'INFO',
        (SELECT COUNT(*)::text FROM silver.transaction_clean WHERE payment_method_is_official = FALSE),
        NULL, 'Transações com método de pagamento nao-oficial (nomes inferidos)'),

    ('ativos_unknown',           'Config', 'INFO',
        (SELECT COUNT(*)::text FROM config.asset_catalog WHERE asset_class = 'unknown' AND is_active),
        NULL, 'Ativos com classificação unknown — revisar manualmente'),

    ('metas_default_mvp',        'Config', 'INFO',
        (SELECT COUNT(*)::text FROM config.agent_target_month WHERE source_type = 'manual_default' AND is_active),
        NULL, 'Metas MVP com valores default — substituir pelos valores reais')

) AS t(check_name, categoria, status, valor_atual, threshold, detalhes);

COMMENT ON VIEW gold.vw_data_quality_summary IS 'Checks de qualidade consolidados. Expor como página oculta no Power BI.';

-- ---------------------------------------------------------------------------
-- 6. gold.vw_unresolved_agent_alias
-- Lista retention_owner_name sem match em config.agent_alias
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_unresolved_agent_alias AS
SELECT
    ac.retention_owner_name,
    LOWER(TRIM(ac.retention_owner_name)) AS normalized_key,
    COUNT(*)                             AS clientes_afetados
FROM silver.account_clean ac
WHERE ac.retention_owner_name IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM config.agent_alias aa
    WHERE aa.normalized_alias = LOWER(TRIM(ac.retention_owner_name))
      AND aa.source_system = 'CRM'
  )
GROUP BY ac.retention_owner_name
ORDER BY clientes_afetados DESC;

COMMENT ON VIEW gold.vw_unresolved_agent_alias IS 'Owners no CRM sem alias configurado — clientes não terão agente resolvido.';

-- ---------------------------------------------------------------------------
-- 7. gold.vw_unresolved_client_bridge
-- Lista transações e operações sem cliente resolvido
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW gold.vw_unresolved_client_bridge AS
SELECT 'fato_movimentacao_financeira' AS tabela,
       f.transaction_id::text         AS chave,
       f.crm_account_id::text         AS crm_account_id,
       f.tp_account_id::text          AS tp_account_id,
       NULL::text                     AS sirix_login,
       f._agente_quality
FROM gold.fato_movimentacao_financeira f
WHERE f.cliente_sk IS NULL

UNION ALL

SELECT 'fato_operacao',
       fo.ticket::text,
       NULL,
       NULL,
       fo.sirix_login::text,
       fo._agente_quality
FROM gold.fato_operacao fo
WHERE fo.cliente_sk IS NULL;

COMMENT ON VIEW gold.vw_unresolved_client_bridge IS 'Transações e operações sem cliente_sk resolvido — expor na página de qualidade.';

COMMIT;
