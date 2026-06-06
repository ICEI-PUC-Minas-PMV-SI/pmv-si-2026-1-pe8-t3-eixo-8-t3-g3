-- >>> LEGADO (2026-06-02) ----------------------------------------------------
-- Substituído pela arquitetura config/domain via .xlsx. Fonte de verdade agora:
--   artefatos/config_templates/brokerlab_config_agents.xlsx
--   -> scripts/load_config_domain_templates.py -> bd/config/config_domain_template_ddl.sql
-- Mantido como baseline histórico/fallback. NÃO executar junto com o loader .xlsx
-- (ambos populam config.agent_profile/agent_alias e conflitam).
-- Ver wiki/topics/plano-config-domain-xlsx.md.
-- ----------------------------------------------------------------------------
-- =============================================================================
-- config_seed_agents.sql — Carga inicial de agentes e aliases
-- Criado: 2026-05-12
-- Depende de: config_ddl.sql executado
-- Fonte: analytics/plano_11 + silver.account_clean (retention_owner_name)
-- =============================================================================
-- ATENÇÃO: team_name inferido por origem/nome. Confirmar com gestor antes do uso oficial.
-- agents marcados agent_type='pool' representam filas regionais → mapeados ao agente Pool.
-- agents com prefixo x/X são inativos no CRM.
-- REFUND REFUND e TEST DEPOSIT TEST → agente system (sem dados analíticos).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. agent_profile
-- ---------------------------------------------------------------------------

-- Agentes individuais ativos (32)
-- agent_level: trainee / inter / pro (Política 2026). NULL = nível não definido para este agente.
-- Níveis confirmados pelo cliente em 2026-05-26:
--   PRO   → Beatriz Mariano, Brian Lima, Caio Beltrao  (+ Romana e Antoni — confirmar nome completo)
--   INTER → Miguel Santoro, Pierre Beltran
--   TRAINEE → Felix Schneider  (+ Maia — confirmar nome completo)
INSERT INTO config.agent_profile
    (agent_name, team_name, agent_level, agent_type, is_active, source, notes)
VALUES
    ('Alessio Ferri',      'Italy',     NULL,       'individual', TRUE, 'crm', NULL),
    ('Angelo Costa',       'Italy',     NULL,       'individual', TRUE, 'crm', NULL),
    ('Arthur Moreau',      'France',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Beatriz Mariano',    'Brazil',    'pro',      'individual', TRUE, 'crm', NULL),
    ('Brian Lima',         'Brazil',    'pro',      'individual', TRUE, 'crm', NULL),
    ('Caio Beltrao',       'Brazil',    'pro',      'individual', TRUE, 'crm', NULL),
    ('Charles Miller',     'Retention', NULL,       'individual', TRUE, 'crm', NULL),
    ('Charlie Kanthawong', 'Asia',      NULL,       'individual', TRUE, 'crm', NULL),
    ('Daniel Hutin',       'France',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Ece Aydin',          'Turkey',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Eric Laurent',       'France',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Fatih Tufekci',      'Turkey',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Felix Schneider',    'Europe',    'trainee',  'individual', TRUE, 'crm', NULL),
    ('Gerard Chaulet',     'France',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Ilker Meric',        'Turkey',    NULL,       'individual', TRUE, 'crm', NULL),
    ('James Lago',         'Retention', NULL,       'individual', TRUE, 'crm', NULL),
    ('Julien Pinelli',     'France',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Kaan Yilmaz',        'Turkey',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Katherine Escobar',  'Retention', NULL,       'individual', TRUE, 'crm', NULL),
    ('Kevin Liu',          'Asia',      NULL,       'individual', TRUE, 'crm', NULL),
    ('Lorenzo Masi',       'Italy',     NULL,       'individual', TRUE, 'crm', NULL),
    ('Lucas Leoni',        'Italy',     NULL,       'individual', TRUE, 'crm', NULL),
    ('Magnus Schulz',      'Europe',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Massimo Abate',      'Italy',     NULL,       'individual', TRUE, 'crm', NULL),
    ('Mel Salazar',        'Brazil',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Mickael Vian',       'France',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Miguel Santoro',     'Retention', 'inter',    'individual', TRUE, 'crm', NULL),
    ('Pierre Beltran',     'France',    'inter',    'individual', TRUE, 'crm', NULL),
    ('Rafaela Miranda',    'Brazil',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Richard Bremont',    'France',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Santiago Jeronimo',  'Brazil',    NULL,       'individual', TRUE, 'crm', NULL),
    ('Stephane Augier',    'France',    NULL,       'individual', TRUE, 'crm', NULL);

-- ---------------------------------------------------------------------------
-- Agentes com nível confirmado mas nome completo pendente (2026-05-26)
-- TODO: substituir primeiro nome pelo nome completo quando o cliente confirmar,
--       e adicionar o alias correspondente na seção de agent_alias abaixo.
-- ---------------------------------------------------------------------------
INSERT INTO config.agent_profile
    (agent_name, team_name, agent_level, agent_type, is_active, source, notes)
VALUES
    ('Romana', 'Brazil', 'pro',     'individual', TRUE, 'manual', 'TODO: confirmar sobrenome completo — PRO confirmado em 2026-05-26'),
    ('Antoni', 'Brazil', 'pro',     'individual', TRUE, 'manual', 'TODO: confirmar sobrenome completo — PRO confirmado em 2026-05-26'),
    ('Maia',   'Brazil', 'trainee', 'individual', TRUE, 'manual', 'TODO: confirmar sobrenome completo — TRAINEE confirmado em 2026-05-26');

-- Agentes individuais inativos (prefixo x/X no CRM — 4)
INSERT INTO config.agent_profile
    (agent_name, team_name, agent_type, is_active, source, notes)
VALUES
    ('Benjamin Castelli', 'Europe', 'individual', FALSE, 'crm', 'Inativo no CRM (prefixo xBenjamin Castelli)'),
    ('Can Sezgin',        'Turkey', 'individual', FALSE, 'crm', 'Inativo no CRM (prefixo XCan Sezgin)'),
    ('Daniela Academy',   'Brazil', 'individual', FALSE, 'crm', 'Inativo no CRM (prefixo xDaniela Academy)'),
    ('Tommaso Soleri',    'Italy',  'individual', FALSE, 'crm', 'Inativo no CRM (prefixo xTommaso Soleri)');

-- Agente Pool — grupo especial para filas regionais e clientes não atribuídos individualmente (1)
INSERT INTO config.agent_profile
    (agent_name, team_name, agent_type, is_active, source, notes)
VALUES
    ('Pool', 'Pool', 'pool', TRUE, 'manual',
     'Agente virtual para filas regionais e clientes sem atribuição individual. Ver: AcademiesGroup, Asia Ret, Brazil Conversion, Europe Retention, Inactive queues.');

-- Agentes sistema — entradas técnicas sem papel analítico (2)
INSERT INTO config.agent_profile
    (agent_name, team_name, agent_type, is_active, source, notes)
VALUES
    ('REFUND',      'System', 'system', FALSE, 'crm', 'Entrada técnica CRM: REFUND REFUND. Sem dados analíticos.'),
    ('TEST DEPOSIT','System', 'system', FALSE, 'crm', 'Entrada técnica CRM: TEST DEPOSIT TEST. Sem dados analíticos.');

-- ---------------------------------------------------------------------------
-- 2. agent_alias  — mapeamento CRM retention_owner_name → agent_id
-- Todos os 48 valores distintos de silver.account_clean.retention_owner_name
-- ---------------------------------------------------------------------------

-- Agentes individuais ativos
INSERT INTO config.agent_alias (agent_id, source_system, alias_name, normalized_alias, is_primary)
SELECT ap.agent_id, 'CRM', v.alias_name, LOWER(TRIM(v.alias_name)), TRUE
FROM (VALUES
    ('Alessio Ferri',      'Alessio Ferri'),
    ('Angelo Costa',       'Angelo Costa'),
    ('Arthur Moreau',      'Arthur Moreau'),
    ('Beatriz Mariano',    'Beatriz Mariano'),
    ('Brian Lima',         'Brian Lima'),
    ('Caio Beltrao',       'Caio Beltrao'),
    ('Charles Miller',     'Charles Miller'),
    ('Charlie Kanthawong', 'Charlie Kanthawong'),
    ('Daniel Hutin',       'Daniel Hutin'),
    ('Ece Aydin',          'Ece Aydin'),
    ('Eric Laurent',       'Eric Laurent'),
    ('Fatih Tufekci',      'Fatih Tufekci'),
    ('Felix Schneider',    'Felix Schneider'),
    ('Gerard Chaulet',     'Gerard Chaulet'),
    ('Ilker Meric',        'Ilker Meric'),
    ('James Lago',         'James Lago'),
    ('Julien Pinelli',     'Julien Pinelli'),
    ('Kaan Yilmaz',        'Kaan Yilmaz'),
    ('Katherine Escobar',  'Katherine Escobar'),
    ('Kevin Liu',          'Kevin Liu'),
    ('Lorenzo Masi',       'Lorenzo Masi'),
    ('Lucas Leoni',        'Lucas Leoni'),
    ('Magnus Schulz',      'Magnus Schulz'),
    ('Massimo Abate',      'Massimo Abate'),
    ('Mel Salazar',        'Mel Salazar'),
    ('Mickael Vian',       'Mickael Vian'),
    ('Miguel Santoro',     'Miguel Santoro'),
    ('Pierre Beltran',     'Pierre Beltran'),
    ('Rafaela Miranda',    'Rafaela Miranda'),
    ('Richard Bremont',    'Richard Bremont'),
    ('Santiago Jeronimo',  'Santiago Jeronimo'),
    ('Stephane Augier',    'Stephane Augier')
) AS v(agent_name, alias_name)
JOIN config.agent_profile ap ON LOWER(TRIM(ap.agent_name)) = LOWER(TRIM(v.agent_name));

-- Agentes inativos (alias CRM → nome canônico sem prefixo x/X)
INSERT INTO config.agent_alias (agent_id, source_system, alias_name, normalized_alias, is_primary)
SELECT ap.agent_id, 'CRM', v.crm_name, LOWER(TRIM(v.crm_name)), TRUE
FROM (VALUES
    ('Benjamin Castelli', 'xBenjamin Castelli'),
    ('Can Sezgin',        'XCan Sezgin'),
    ('Daniela Academy',   'xDaniela Academy'),
    ('Tommaso Soleri',    'xTommaso Soleri')
) AS v(canonical, crm_name)
JOIN config.agent_profile ap ON LOWER(TRIM(ap.agent_name)) = LOWER(TRIM(v.canonical));

-- Pool — filas regionais do CRM (8 grupos) mapeadas ao agente Pool
INSERT INTO config.agent_alias (agent_id, source_system, alias_name, normalized_alias, is_primary)
SELECT ap.agent_id, 'CRM', v.alias_name, LOWER(TRIM(v.alias_name)), FALSE
FROM (VALUES
    ('AcademiesGroup Brazil Conversion Owner'),
    ('Asia Ret EN'),
    ('Asia Ret MS'),
    ('Asia Ret ZH'),
    ('Brazil Conversion PT'),
    ('Brazil Retention PT'),
    ('Europe Retention FR'),
    ('Europe Retention ITA'),
    ('Inactive France Clients'),
    ('Inactive Italy Clients')
) AS v(alias_name)
JOIN config.agent_profile ap ON ap.agent_name = 'Pool';

-- Sistema — entradas técnicas
INSERT INTO config.agent_alias (agent_id, source_system, alias_name, normalized_alias, is_primary)
SELECT ap.agent_id, 'CRM', v.crm_name, LOWER(TRIM(v.crm_name)), FALSE
FROM (VALUES
    ('REFUND',       'REFUND REFUND'),
    ('TEST DEPOSIT', 'TEST DEPOSIT TEST')
) AS v(canonical, crm_name)
JOIN config.agent_profile ap ON LOWER(TRIM(ap.agent_name)) = LOWER(TRIM(v.canonical));

COMMIT;
