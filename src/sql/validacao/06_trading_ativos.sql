-- =============================================================================
-- 06_trading_ativos.sql — Aba 06 (Trading e Ativos)
-- Fonte PBI: fato_operacao, dim_ativo
-- Filtro obrigatório de trading: eh_operacao_mercado = TRUE (CMD 0/1).
-- Totais GERAIS (sem filtro de mês) — espelha os cards sem slicer no Power BI.
-- =============================================================================
\pset pager off
\echo '################ 06 — TRADING E ATIVOS ################'
\echo 'Filtro: eh_operacao_mercado = TRUE | PnL e volume = provisórios (lotes)'

-- ---------------------------------------------------------------------------
-- [06.1] Big Numbers de trading
--   DAX: Trading Market Operations, Trading Clients, Trading Active Assets,
--        Trading Volume Lots, Trading PnL/Gross Profit, Open Positions,
--        Open/Buy/Sell/Net Exposure Lots, Suspicious Operations.
-- ---------------------------------------------------------------------------
\echo '[06.1] Trading — totais gerais:'
SELECT
    COUNT(*)                                              AS market_operations,
    COUNT(DISTINCT cliente_sk)                            AS trading_clients,
    COUNT(DISTINCT ativo_sk)                              AS active_assets,
    ROUND(SUM(volume_lots), 4)                            AS volume_lots,
    ROUND(SUM(profit_liquido), 2)                         AS pnl_liquido_usd,
    ROUND(SUM(profit_bruto), 2)                           AS profit_bruto_usd,
    COUNT(*) FILTER (WHERE eh_aberta)                     AS open_positions,
    ROUND(SUM(volume_lots) FILTER (WHERE eh_aberta), 4)   AS open_volume_lots,
    ROUND(SUM(volume_lots) FILTER (WHERE side='Buy'), 4)  AS buy_volume_lots,
    ROUND(SUM(volume_lots) FILTER (WHERE side='Sell'), 4) AS sell_volume_lots,
    ROUND(SUM(volume_lots) FILTER (WHERE side='Buy')
        - SUM(volume_lots) FILTER (WHERE side='Sell'), 4) AS net_exposure_lots,
    COUNT(*) FILTER (WHERE _eh_suspeito)                  AS suspicious_operations
FROM gold.fato_operacao
WHERE eh_operacao_mercado = TRUE;

-- ---------------------------------------------------------------------------
-- [06.2] Ranking de ativos (operações, clientes, volume, PnL)
-- ---------------------------------------------------------------------------
\echo '[06.2] Ranking de ativos:'
SELECT
    COALESCE(da.display_name, da.sirix_symbol, fo.symbol) AS ativo,
    da.asset_class,
    COUNT(*)                              AS operacoes,
    COUNT(DISTINCT fo.cliente_sk)         AS clientes,
    ROUND(SUM(fo.volume_lots), 4)         AS volume_lots,
    ROUND(SUM(fo.profit_liquido), 2)      AS pnl_liquido_usd,
    COUNT(*) FILTER (WHERE fo.eh_aberta)  AS posicoes_abertas
FROM gold.fato_operacao fo
LEFT JOIN gold.dim_ativo da ON da.ativo_sk = fo.ativo_sk
WHERE fo.eh_operacao_mercado = TRUE
GROUP BY 1, 2
ORDER BY operacoes DESC
LIMIT 30;

-- ---------------------------------------------------------------------------
-- [06.3] Por classe de ativo (barras)
-- ---------------------------------------------------------------------------
\echo '[06.3] Por classe de ativo:'
SELECT
    COALESCE(da.asset_class, '(sem classe)') AS asset_class,
    COUNT(*)                                  AS operacoes,
    ROUND(SUM(fo.volume_lots), 4)             AS volume_lots
FROM gold.fato_operacao fo
LEFT JOIN gold.dim_ativo da ON da.ativo_sk = fo.ativo_sk
WHERE fo.eh_operacao_mercado = TRUE
GROUP BY 1
ORDER BY operacoes DESC;
