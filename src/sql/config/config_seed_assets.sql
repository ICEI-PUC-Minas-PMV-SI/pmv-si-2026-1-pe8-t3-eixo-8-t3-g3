-- >>> LEGADO (2026-06-02) ----------------------------------------------------
-- Substituído pela arquitetura config/domain via .xlsx. Fonte de verdade agora:
--   artefatos/config_templates/brokerlab_config_assets.xlsx
--   -> scripts/load_config_domain_templates.py -> bd/config/config_domain_template_ddl.sql
-- Mantido como baseline histórico/fallback. NÃO executar junto com o loader .xlsx
-- (ambos populam config.asset_catalog e conflitam).
-- Ver wiki/topics/plano-config-domain-xlsx.md.
-- ----------------------------------------------------------------------------
-- =============================================================================
-- config_seed_assets.sql — Catálogo inicial de ativos a partir de silver.trade_clean
-- Criado: 2026-05-12
-- Depende de: config_ddl.sql executado, silver populada
-- Regra de classificação: inferred via regex (classification_status='inferred').
--   Atualizar manualmente para 'manual' ou 'validated' após revisão.
-- ZEROING é símbolo técnico de ajuste do Sirix, marcado como unknown/inativo.
-- =============================================================================

BEGIN;

INSERT INTO config.asset_catalog (
    sirix_symbol, normalized_symbol, display_name,
    asset_class, base_currency, quote_currency,
    is_major_asset, is_active, classification_status,
    created_at, updated_at, notes
)
SELECT
    t.symbol_key                                        AS sirix_symbol,
    LOWER(TRIM(t.symbol_key))                           AS normalized_symbol,
    NULL                                                AS display_name,

    CASE
        -- Crypto: sufixo USD/USDT/BTC + prefixo cripto conhecido
        WHEN t.symbol_key ~ '^(BTC|ETH|LTC|XRP|ADA|BNB|SOL|DOT|LINK|EOS|DASH|AAVE|ETC|ATOM|CHZ|FIL|TRX|NEO|VET|XDG|XTZ|ZEROING)' THEN 'crypto'

        -- Metais preciosos: XAU, XAG, XPT, XPD
        WHEN t.symbol_key ~ '^(XAUUSD|XAGUSD|XAUEUR|XAGEUR|XPTUSD|XPDUSD)' THEN 'commodity'

        -- Energia: petróleo, gás, derivados
        WHEN t.symbol_key ~ '(BRENT|OIL|NGAS|WTI|RBOB|HOIL|UK_OIL|US_OIL)' THEN 'energy'

        -- Commodities agrícolas e metais industriais
        WHEN t.symbol_key ~ '(COFFEE|COCOA|WHEAT|SBEAN|SUG|COPP|ALUMINUM|COTTON|AGRIC)' THEN 'commodity'

        -- Índices: nomes conhecidos de índices globais + prefixos/sufixos típicos
        WHEN t.symbol_key ~ '^(FRA40|GER40|FTSE100|NIKKEI225|NQ100|SPX500|BIST30|AEX|IBEX|SPMIB|WS30|USNDX|RUSS|TOPIX|VIX|NK|FRA|UK100|JPN225)' THEN 'index'
        WHEN t.symbol_key ~ '(-DEC|-NOV|-JAN|-FEB|-MAR|-APR|-MAY|-JUN|-JUL|-AUG|-SEP|-OCT)' THEN 'index'  -- futuros de índice com vencimento

        -- Forex: pares de moedas ISO4217 (6 chars = 3+3, ou padrão conhecido)
        WHEN t.symbol_key ~ '^(EUR|GBP|AUD|NZD|CAD|CHF|USD|JPY|TRY|SEK|NOK|DKK|CZK|HUF|PLN|CNH|MXN|ZAR|RUB|HKD|SGD|ILS|BRL)' AND
             LENGTH(REGEXP_REPLACE(t.symbol_key, '[^A-Za-z]', '', 'g')) = 6 THEN 'forex'
        -- Pares USD explícitos extras (ex: USDBRL, USDTRY)
        WHEN t.symbol_key ~ '^USD(BRL|TRY|CNH|MXN|ZAR|RUB|HKD|SGD|ILS|CZK|HUF|PLN|NOK|SEK|DKK)' THEN 'forex'

        -- Ações: o que sobrar com símbolo de empresa conhecida
        ELSE 'stock'
    END                                                 AS asset_class,

    -- base_currency inferida para forex/metais
    CASE
        WHEN t.symbol_key ~ '^XAU' THEN 'XAU'
        WHEN t.symbol_key ~ '^XAG' THEN 'XAG'
        WHEN t.symbol_key ~ '^XPT' THEN 'XPT'
        WHEN t.symbol_key ~ '^XPD' THEN 'XPD'
        WHEN LENGTH(REGEXP_REPLACE(t.symbol_key, '[^A-Za-z]', '', 'g')) = 6 AND
             t.symbol_key ~ '^(EUR|GBP|AUD|NZD|CAD|CHF|USD|JPY|TRY|SEK|NOK|DKK|CZK|HUF|PLN|CNH|MXN|ZAR|RUB|HKD|SGD|ILS|BRL)'
             THEN UPPER(SUBSTRING(REGEXP_REPLACE(t.symbol_key, '[^A-Za-z]', '', 'g'), 1, 3))
        ELSE NULL
    END                                                 AS base_currency,

    CASE
        WHEN t.symbol_key ~ '(USDUSDT|USD\.|USD$)' OR t.symbol_key ~ 'USD$' THEN 'USD'
        WHEN LENGTH(REGEXP_REPLACE(t.symbol_key, '[^A-Za-z]', '', 'g')) = 6 AND
             t.symbol_key ~ '^(EUR|GBP|AUD|NZD|CAD|CHF|USD|JPY|TRY|SEK|NOK|DKK|CZK|HUF|PLN|CNH|MXN|ZAR|RUB|HKD|SGD|ILS|BRL)'
             THEN UPPER(SUBSTRING(REGEXP_REPLACE(t.symbol_key, '[^A-Za-z]', '', 'g'), 4, 3))
        WHEN t.symbol_key ~ 'USD' THEN 'USD'
        ELSE NULL
    END                                                 AS quote_currency,

    -- is_major_asset: pares forex major + metais preciosos principais + índices/ações mais conhecidos
    CASE WHEN t.symbol_key IN (
        'EURUSD','GBPUSD','USDJPY','USDCHF','AUDUSD','NZDUSD','USDCAD',
        'XAUUSD','XAGUSD','BTCUSD.','ETHUSD.',
        'SPX500.','NQ100.','GER40.','FTSE100.','NIKKEI225.',
        'US_OIL.','BRENTOIL.',
        'NVDIA.','APPLE','AMAZON.','GOOGLE.','MSFT','TSLA.','NETFLIX.'
    ) THEN TRUE ELSE FALSE END                          AS is_major_asset,

    TRUE                                                AS is_active,
    'inferred'                                          AS classification_status,
    NOW(), NOW(),

    CASE WHEN t.symbol_key = 'ZEROING' THEN 'Símbolo técnico de ajuste Sirix — sem valor analítico' ELSE NULL END AS notes

FROM (
    SELECT DISTINCT symbol_key
    FROM silver.trade_clean
    WHERE eh_operacao_mercado = TRUE
      AND symbol_key IS NOT NULL
) t
ORDER BY t.symbol_key;

-- Símbolo técnico ZEROING: marcar como inativo
UPDATE config.asset_catalog
SET is_active = FALSE, asset_class = 'unknown',
    notes = 'Símbolo técnico de ajuste Sirix — sem valor analítico'
WHERE sirix_symbol = 'ZEROING';

-- Verificação rápida
DO $$
DECLARE v_total INTEGER; v_classes TEXT;
BEGIN
    SELECT COUNT(*) INTO v_total FROM config.asset_catalog;
    SELECT STRING_AGG(asset_class || '=' || cnt::text, ', ' ORDER BY cnt DESC)
    INTO v_classes
    FROM (SELECT asset_class, COUNT(*) AS cnt FROM config.asset_catalog GROUP BY 1) x;
    RAISE NOTICE 'asset_catalog carregado: % símbolos | %', v_total, v_classes;
END $$;

COMMIT;
