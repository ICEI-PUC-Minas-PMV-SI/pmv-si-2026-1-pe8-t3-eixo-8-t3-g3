-- >>> TRANSIÇÃO PARCIAL (2026-06-02) -----------------------------------------
-- Domínios TÉCNICOS estáveis permanecem aqui em SQL (autoritativo):
--   dom_cmd, dom_transaction_type, dom_transaction_status.
-- Domínios GOVERNADOS migram para .xlsx (não usar os inserts deste arquivo p/ eles):
--   dom_lead_status     <- brokerlab_domain_crm.xlsx
--   dom_payment_method  <- brokerlab_domain_finance.xlsx
--   dom_currency        <- brokerlab_domain_finance.xlsx
-- Fluxo-alvo: scripts/load_config_domain_templates.py -> bd/config/config_domain_template_ddl.sql.
-- Ver wiki/topics/plano-config-domain-xlsx.md e wiki/topics/domain-lookup-values.md.
-- ----------------------------------------------------------------------------
BEGIN;

DROP SCHEMA IF EXISTS domain CASCADE;
CREATE SCHEMA domain;

COMMENT ON SCHEMA domain IS 'Lookups canônicos para decodificar códigos CRM/Sirix usados pela silver/gold.';

-- Status de leads (42 valores) — fonte: §6.1 da documentação
CREATE TABLE domain.dom_lead_status (
    codigo              BIGINT PRIMARY KEY,
    descricao           VARCHAR(100) NOT NULL,
    categoria           VARCHAR(30) NOT NULL,  -- Novo, Em prospecção, Perdido, Inválido, Operacional
    eh_terminal         BOOLEAN NOT NULL       -- TRUE se status finaliza o lead
);

INSERT INTO domain.dom_lead_status (codigo, descricao, categoria, eh_terminal) VALUES
(1,         'New',                     'Novo',          FALSE),
(2,         'Not Interested',          'Perdido',       TRUE),
(3,         'Wrong Info',              'Inválido',      TRUE),
(4,         'No Answer',               'Em prospecção', FALSE),
(5,         'Interested',              'Em prospecção', FALSE),
(100000000, 'New1',                    'Novo',          FALSE),
(100000002, 'Callback',                'Em prospecção', FALSE),
(100000003, 'Callback - Reshuffle',    'Em prospecção', FALSE),
(100000004, 'Calling',                 'Em prospecção', FALSE),
(100000008, 'Doesn''t Have Money',     'Perdido',       TRUE),
(100000009, 'Duplicate',               'Inválido',      TRUE),
(100000010, 'Fake Details',            'Inválido',      TRUE),
(100000011, 'Cross Lead',              'Em prospecção', FALSE),
(100000012, 'Hung up the phone',       'Em prospecção', FALSE),
(100000013, 'Invalid Country',         'Inválido',      TRUE),
(100000014, 'Low Potential',           'Em prospecção', FALSE),
(100000015, 'Low Potential - Callback','Em prospecção', FALSE),
(100000016, 'Never answered',          'Em prospecção', FALSE),
(100000017, 'No Answer 1',             'Em prospecção', FALSE),
(100000018, 'No Answer 2',             'Em prospecção', FALSE),
(100000019, 'No Answer 3',             'Em prospecção', FALSE),
(100000020, 'No Answer 4',             'Em prospecção', FALSE),
(100000021, 'No Answer 5',             'Em prospecção', FALSE),
(100000022, 'No Interested - No Money','Perdido',       TRUE),
(100000023, 'No line',                 'Inválido',      TRUE),
(100000025, 'Not Workable',            'Perdido',       TRUE),
(100000026, 'PSP Failure',             'Operacional',   FALSE),
(100000027, 'Reassign',                'Operacional',   FALSE),
(100000030, 'Refer',                   'Operacional',   FALSE),
(100000031, 'Reshuffle',               'Operacional',   FALSE),
(100000032, 'Test',                    'Inválido',      TRUE),
(100000033, 'Under Age',               'Inválido',      TRUE),
(100000034, 'Voicemail',               'Em prospecção', FALSE),
(100000036, 'Wrong Campaign',          'Inválido',      TRUE),
(100000037, 'Wrong Language',          'Inválido',      TRUE),
(100000038, 'Wrong Number',            'Inválido',      TRUE),
(100000039, 'Wrong Person',            'Inválido',      TRUE),
(100000040, 'Telemarketing',           'Em prospecção', FALSE),
(100000041, 'Busy- Can''t talk',       'Em prospecção', FALSE),
(100000042, 'Call Again',              'Em prospecção', FALSE),
(100000043, 'Talk In Progress',        'Em prospecção', FALSE),
(100000044, 'Low Money',               'Em prospecção', FALSE),
(100000045, 'Medium Potential CB',     'Em prospecção', FALSE),
(100000046, 'Asked Info',              'Em prospecção', FALSE);

-- CMD (tipo de operação MT4) — fonte: §6.2 da documentação
CREATE TABLE domain.dom_cmd (
    codigo          INTEGER PRIMARY KEY,
    tipo            VARCHAR(20) NOT NULL,        -- OP_BUY, OP_SELL, ...
    descricao       VARCHAR(100) NOT NULL,
    eh_trade        BOOLEAN NOT NULL,            -- TRUE para CMD 0-5
    eh_financeiro   BOOLEAN NOT NULL,            -- TRUE para CMD 6,7
    eh_pendente     BOOLEAN NOT NULL,            -- TRUE para CMD 2,3,4,5
    sinal           CHAR(1)                       -- '+', '-', '0'
);

INSERT INTO domain.dom_cmd VALUES
(0, 'OP_BUY',        'Compra a mercado (long)',                       TRUE,  FALSE, FALSE, '+'),
(1, 'OP_SELL',       'Venda a mercado (short)',                       TRUE,  FALSE, FALSE, '-'),
(2, 'OP_BUY_LIMIT',  'Ordem de compra pendente abaixo do mercado',    TRUE,  FALSE, TRUE,  '+'),
(3, 'OP_SELL_LIMIT', 'Ordem de venda pendente acima do mercado',      TRUE,  FALSE, TRUE,  '-'),
(4, 'OP_BUY_STOP',   'Ordem de compra pendente acima do mercado',     TRUE,  FALSE, TRUE,  '+'),
(5, 'OP_SELL_STOP',  'Ordem de venda pendente abaixo do mercado',     TRUE,  FALSE, TRUE,  '-'),
(6, 'OP_BALANCE',    'Movimentação de saldo (depósito/saque/taxa)',   FALSE, TRUE,  FALSE, '0'),
(7, 'OP_CREDIT',     'Crédito/bônus (concessão ou estorno)',          FALSE, TRUE,  FALSE, '0');

-- Tipo de transação monetária — fonte: §6.6
CREATE TABLE domain.dom_transaction_type (
    codigo           INTEGER PRIMARY KEY,
    nome             VARCHAR(80) NOT NULL,
    categoria        VARCHAR(30) NOT NULL,     -- Entrada, Saída, Bônus, Reversão, Transferência, Taxa, Crédito ajuste, Débito ajuste
    sinal_financeiro CHAR(1) NOT NULL          -- '+', '-', '0'
);

INSERT INTO domain.dom_transaction_type VALUES
(1,  'Deposit',                                            'Entrada',           '+'),
(2,  'Deposit Cancelled',                                  'Reversão',          '0'),
(5,  'Bonus',                                              'Bônus',             '+'),
(6,  'Bonus Cancelled',                                    'Reversão',          '0'),
(9,  'Withdrawal',                                         'Saída',             '-'),
(10, 'Withdrawal Cancelled',                               'Reversão',          '0'),
(13, 'Transfer Between Trading Platform Accounts',         'Transferência',     '0'),
(14, 'Transfer Between Trading Platform Accounts Cancelled','Reversão',         '0'),
(15, 'Credit',                                             'Crédito ajuste',    '+'),
(16, 'Credit Cancelled',                                   'Reversão',          '0'),
(17, 'Debit',                                              'Débito ajuste',     '-'),
(19, 'Inactivity Fee',                                     'Taxa',              '-');

-- Status interno de transação — fonte: §6.7
CREATE TABLE domain.dom_transaction_status (
    codigo      BIGINT PRIMARY KEY,
    descricao   VARCHAR(50) NOT NULL,
    eh_aprovado BOOLEAN NOT NULL
);

INSERT INTO domain.dom_transaction_status VALUES
(100000000, 'Solicitada / Criada',     FALSE),
(100000001, 'Em análise / Pendente',   FALSE),
(100000002, 'Rejeitada',               FALSE),
(100000003, 'Aprovada / Concluída',    TRUE);

-- Método de pagamento — fonte: §6.8 (descrições inferidas; atualizar quando o time CRM enviar a canônica)
CREATE TABLE domain.dom_payment_method (
    codigo         BIGINT PRIMARY KEY,
    nome_inferido  VARCHAR(50),
    eh_oficial     BOOLEAN NOT NULL DEFAULT FALSE  -- FALSE até confirmação do CRM
);

INSERT INTO domain.dom_payment_method VALUES
(1,         'Wire Transfer',  FALSE),
(2,         'Credit Card',    FALSE),
(3,         'Desconhecido 3', FALSE),
(13,        'Crypto?',        FALSE),
(100000000, 'Custom 1',       FALSE),
(100000002, 'PIX',            FALSE),
(100000004, 'Custom 4',       FALSE),
(100000005, 'Boleto?',        FALSE),
(100000006, 'Custom 6',       FALSE),
(100000010, 'Custom 10',      FALSE),
(100000011, 'Custom 11',      FALSE),
(100000012, 'Custom 12',      FALSE),
(100000013, 'Custom 13',      FALSE),
(100000014, 'Custom 14',      FALSE),
(100000015, 'Custom 15',      FALSE),
(100000016, 'Custom 16',      FALSE),
(100000017, 'Custom 17',      FALSE),
(100000019, 'Custom 19',      FALSE),
(100000020, 'Custom 20',      FALSE);

-- Moedas — fonte: §6.9
CREATE TABLE domain.dom_currency (
    currency_guid    VARCHAR(36) PRIMARY KEY,
    iso_code         VARCHAR(3) NOT NULL,
    nome             VARCHAR(30) NOT NULL
);

INSERT INTO domain.dom_currency VALUES
('BDB50AD4-A204-F011-9135-005056B1E25D', 'USD', 'Dólar Americano'),
('1DC17FC1-AF04-F011-9699-005056B16E94', 'EUR', 'Euro'),
('27BEAC42-6BF5-F011-9133-005056B1FEFC', 'TRY', 'Lira Turca');

COMMENT ON TABLE domain.dom_lead_status IS 'Status de lead do CRM. Usado em silver.account_clean.';
COMMENT ON TABLE domain.dom_cmd IS 'Tipos CMD do Sirix/MT4. Usado em silver.trade_clean.';
COMMENT ON TABLE domain.dom_transaction_type IS 'Tipos de transação monetária do CRM. Usado em silver.transaction_clean.';
COMMENT ON TABLE domain.dom_transaction_status IS 'Status interno de transação monetária do CRM. Usado em silver.transaction_clean.';
COMMENT ON TABLE domain.dom_payment_method IS 'Métodos de pagamento inferidos. Labels não oficiais até validação do CRM.';
COMMENT ON TABLE domain.dom_currency IS 'Moedas por GUID CRM. Usado em tpaccount/transaction.';

COMMIT;
