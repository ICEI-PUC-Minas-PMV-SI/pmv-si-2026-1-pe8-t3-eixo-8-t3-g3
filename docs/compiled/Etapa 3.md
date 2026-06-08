**Etapa 3 — Desenvolvimento da Solução de Sistema de Informação**

## SUMÁRIO

3. DESENVOLVIMENTO DA SOLUÇÃO BROKERLAB
   - 3.1 Visão geral da solução
   - 3.2 Arquitetura de dados: pipeline multicamadas (PostgreSQL)
   - 3.3 Integração entre sistemas: a bridge CRM↔Sirix
   - 3.4 Modelo semântico Gold: Star Schema
   - 3.5 Governança da configuração: templates XLSX e automação Python
   - 3.6 Dashboards implementados
   - 3.7 Mapeamento KIQs × solução implementada
   - 3.8 Escopo entregue versus roadmap técnico
4. ESPECIFICAÇÃO DE REQUISITOS INFORMACIONAIS
   - 4.1 KPIs implementados e regras de cálculo
   - 4.2 Requisitos informacionais e funcionais da solução
   - 4.3 Justificativa dos KPIs e relação com as decisões estratégicas
5. LEVANTAMENTO DE FONTES DE DADOS EXISTENTES
   - 5.1 Inventário de dados disponíveis
   - 5.2 Avaliação de qualidade, acessibilidade e prontidão dos dados
   - 5.3 Lacunas e dados remanescentes

---

## 3. DESENVOLVIMENTO DA SOLUÇÃO BROKERLAB

### 3.1 Visão geral da solução

O BrokerLab é um ambiente de Business Intelligence (BI) desenvolvido para a área de retenção de clientes da corretora GSRS S.A.S. O produto não se limita a um painel de visualização: constitui um pipeline de dados end-to-end, composto por três camadas interdependentes — camada de dados, camada de configuração governada e camada de visualização —, que juntas transformam dados operacionais brutos em indicadores gerenciais estruturados e auditáveis.

A camada de dados é implementada em um banco de dados PostgreSQL (db_brokerlab), estruturado em múltiplos schemas com papéis distintos e progressivos de tratamento. A camada de configuração é mantida via templates Microsoft Excel (.xlsx) carregados automaticamente por scripts Python, garantindo governança dos dados mestres sem intervenção técnica direta no banco. A camada de visualização é um relatório Microsoft Power BI, conectado às views semânticas da camada gold do banco de dados, com modelo Star Schema, medidas DAX organizadas em pastas temáticas e dashboards operacionais implementados.

A arquitetura geral do pipeline segue o fluxo representado a seguir:

```
stg_raw → bronze → silver → domain / config → gold → Power BI
```

*Figura 2 – Arquitetura geral do pipeline BrokerLab*  
*Fonte: Elaborado pelos autores (2026).*

### 3.2 Arquitetura de dados: pipeline multicamadas (PostgreSQL)

O banco de dados db_brokerlab organiza os dados em sete schemas com papéis progressivos e complementares. A separação em camadas garante rastreabilidade completa desde a ingestão até o consumo analítico, além de permitir reprocessamento seletivo sem perda de dados históricos.

**Tabela 3 – Schemas do banco de dados db_brokerlab**

| Schema | Papel | Descrição |
|--------|-------|-----------|
| stg_raw | Staging bruto | Ingestão TEXT-only dos CSVs e APIs-fonte. Espelho fiel dos dados de origem, sem qualquer transformação ou tipagem. Serve como zona de quarentena e ponto de reprocessamento. |
| bronze | Bronze tipada | Cópia tipada e auditada do stg_raw. Cada linha recebe `_ingestao_ts` (timestamp de ingestão), `_origem` (identificador da fonte) e `_hash_linha` (hash MD5 para detecção de duplicatas). Append-only: registros nunca são deletados. |
| silver | Silver limpa | Dados validados, normalizados, deduplicados e com derivados calculados. Inclui a view `vw_account_bridge`, que integra CRM e Sirix via entidade-pivô. Registros inválidos são marcados com `_eh_valido = FALSE` e `_motivo_invalido` documentado. |
| domain | Domínios canônicos | Tabelas de lookup para decodificação de códigos numéricos do CRM e do Sirix: lead status, tipo de transação (CMD), método de pagamento, moeda, entre outros. |
| config | Configuração governada | Dados de negócio controlados: cadastro de agentes e aliases, metas mensais por agente, calendário de dias úteis (2020–2035) e catálogo de ativos. Alimentado exclusivamente por templates XLSX via script Python. |
| config_import | Auditoria de carga | Registro de cada execução do script de carga: data/hora, arquivo processado, linhas inseridas e erros encontrados. |
| gold | Star Schema analítico | Modelo semântico otimizado para consumo no Power BI: 4 dimensões, 4 fatos e 7 views semânticas. Reconstruído integralmente a cada ciclo de recarga. |

*Fonte: Elaborado pelos autores (2026).*

**Fontes integradas ao pipeline:**

Duas fontes operacionais alimentam o pipeline. A primeira é o CRM Microsoft Dynamics 365, do qual são extraídas sete tabelas principais: `crm_account_base` (cadastro de clientes), `crm_user_base` (usuários e agentes), `lv_tpaccountbase` (contas de trading — entidade-pivô de integração), `lv_monetarytransactionbase` (transações financeiras aprovadas e pendentes) e tabelas auxiliares de domínio. A segunda é a plataforma Sirix, fornecida pela Leverate, da qual são extraídas `sirix_users_view` (contas de trading com saldos), `sirix_trades_view` (histórico completo de trades) e `sirix_daily_view` (snapshots diários de saldo e equity).

**Processo de recarga:**

O script Bash `reload_config_and_gold.sh` orquestra o ciclo completo de recarga: valida os templates XLSX, aplica as configurações nos schemas config e domain, reconstrói o schema gold (dimensões, fatos e views) e executa os checks de qualidade automatizados. A recarga é acionada manualmente conforme a disponibilidade de novos extratos das fontes.

### 3.3 Integração entre sistemas: a bridge CRM↔Sirix

O principal desafio técnico do projeto foi a integração entre dois sistemas com universos de dados distintos e sem chave de junção explícita: o CRM Microsoft Dynamics 365, que gerencia o relacionamento com o cliente, e a plataforma Sirix (Leverate), que registra as operações de trading. Um mesmo investidor possui identidades diferentes nos dois sistemas — um `crm_account_id` no CRM e um `sirix_login` na plataforma de trading — sem campo de junção direto entre eles.

A solução foi identificar a tabela `lv_tpaccountbase` do CRM como entidade-pivô: nela, o campo `lv_name` corresponde ao `sirix_login` do usuário na plataforma Sirix. Essa chave une `crm_account_id` (identidade no CRM) ao `sirix_login` (identidade no Sirix), permitindo rastrear, para um mesmo investidor, tanto seu histórico de transações financeiras quanto suas operações de trading.

**Monitoramento de qualidade da bridge:**

A efetividade da integração é monitorada por campos específicos na camada silver e propagados ao gold:

- `bridge_quality_status`: classifica a qualidade do vínculo como `full_match` (ambos os sistemas resolvidos), `partial_match` (apenas um lado) ou `no_match` (nenhum vínculo encontrado);
- `has_tp_match` e `has_sirix_match`: flags booleanas que indicam individualmente se o lado CRM e o lado Sirix foram resolvidos;
- `_agente_quality`: campo presente em `fato_movimentacao_financeira`, `fato_operacao` e `dim_cliente`, indicando a qualidade da resolução do agente responsável para cada registro.

Os clientes sem bridge completa resolvida são listados na view `gold.vw_unresolved_client_bridge`, e os aliases de agentes sem correspondência são identificados em `gold.vw_unresolved_agent_alias`, ambas monitoradas pela view `gold.vw_data_quality_summary` com classificações OK, WARN e INFO.

### 3.4 Modelo semântico Gold: Star Schema

A camada gold implementa um modelo Star Schema com quatro dimensões, quatro tabelas fato e sete views semânticas. Esse modelo é a camada de abstração entre o banco de dados PostgreSQL e o Power BI, garantindo que as medidas DAX operem sobre dados já agregados, tipados e com relacionamentos predefinidos.

**Tabela 4 – Dimensões do Star Schema Gold**

| Tabela | Colunas | Descrição |
|--------|---------|-----------|
| gold.dim_tempo | 18 | Dimensão calendário. Cobre datas de 2020 a 2035. Campos-chave: `tempo_sk` (YYYYMMDD), `date`, `year_month`, `is_business_day`, `business_day_number_in_month`, `business_days_in_month`, `remaining_business_days_in_month`. Fonte: `config.business_calendar`. |
| gold.dim_agente | 13 | Dimensão agente. Campos-chave: `agente_sk`, `agent_name`, `team_name`, `agent_level`, `seniority`, `is_active`, `started_on`. Fonte: `config.agent_profile` + `silver.user_clean`. |
| gold.dim_ativo | 12 | Dimensão ativo financeiro. Campos-chave: `ativo_sk`, `sirix_symbol`, `normalized_symbol`, `asset_class`, `is_major_asset`. Fonte: `config.asset_catalog`. |
| gold.dim_cliente | 26 | Dimensão cliente. Campos-chave: `cliente_sk`, `crm_account_id`, `sirix_login`, `lead_status_text`, `has_ftd`, `agente_sk_current`, `balance`, `equity`, `margin_level`, `bridge_quality_status`, `_agente_quality`. Fonte: `silver.vw_account_bridge`. |

*Fonte: Elaborado pelos autores (2026).*

**Tabela 5 – Fatos do Star Schema Gold**

| Tabela | Colunas | Descrição |
|--------|---------|-----------|
| gold.fato_movimentacao_financeira | 26 | Registra cada transação financeira aprovada ou pendente. Campos-chave: `transaction_id`, `tempo_aprovacao_sk`, `cliente_sk`, `agente_sk`, `eh_aprovada`, `eh_ftd`, `deposit_amount_usd`, `withdrawal_amount_usd`, `net_deposit_usd`, `payment_method_name`. Fonte: `silver.transaction_clean`. |
| gold.fato_operacao | 32 | Registra cada ticket de trading do Sirix. Campos-chave: `ticket`, `cliente_sk`, `agente_sk`, `ativo_sk`, `cmd_tipo`, `eh_operacao_mercado`, `volume_lots`, `open_time`, `close_time`, `profit_liquido`, `_eh_suspeito`. Fonte: `silver.trade_clean`. |
| gold.fato_cliente_trade_dia | 13 | Agrega, por cliente e por dia, a atividade de trading: `qtd_trades_dia`, `volume_lots_dia`, `pnl_liquido_dia`, `first_trade_ts`, `has_open_today`, `has_close_today`. Alimenta diretamente os indicadores de meta de trade e a call list. Fonte: agregação de `fato_operacao`. |
| gold.fato_meta_agente_mes | 13 | Registra as metas mensais configuradas por agente: `target_deposit_month_usd`, `target_deposit_day_usd`, `target_trade_day`, `target_trade_month`, `target_unique_month`, `business_days_in_month`. Fonte: `config.agent_target_month`. |

*Fonte: Elaborado pelos autores (2026).*

**Tabela 6 – Views semânticas da camada Gold**

| View | Colunas | Descrição e uso |
|------|---------|-----------------|
| gold.vw_team_month_performance | 24 | Performance consolidada do piso (equipe) por mês: net deposit, meta, run rate, gap, unique depositors, trading client days, total trades, volume e PnL. Alimenta a Aba 01 do dashboard. |
| gold.vw_agent_month_performance | 32 | Performance individual por agente e mês: todos os KPIs mensais incluindo `target_pct_deposit`, `run_rate_usd`, `gap_meta_usd`, `unique_deposit_month`, `trading_client_days_month`. Alimenta as Abas 01 e 02. |
| gold.vw_agent_day_performance | 17 | Performance diária por agente: `deposit_day`, `withdrawal_day`, `net_deposit_day`, `net_deposit_acumulado_mes`, `target_deposit_day_usd`, `clientes_operaram_dia`. Alimenta o gráfico de evolução diária nas Abas 01 e 02. |
| gold.vw_call_list_today | 27 | Lista operacional do dia: um registro por cliente da carteira, com `traded_today`, `is_pending_today`, `priority_label`, `balance`, `equity`, `last_deposit_date`, `lead_status_text`. Alimenta a Aba 03 e a tabela de pendentes da Aba 02. |
| gold.vw_data_quality_summary | 6 | Checks automáticos de qualidade do pipeline classificados por status (OK/WARN/INFO): aliases sem match, bridge não resolvida, trades suspeitos, registros sem agente atribuído. |
| gold.vw_unresolved_agent_alias | 3 | Lista de `retention_owner_name` do CRM sem correspondência na tabela de aliases de agentes, com contagem de clientes afetados. |
| gold.vw_unresolved_client_bridge | 6 | Lista de clientes sem bridge CRM↔Sirix completamente resolvida, com indicação do lado faltante (`has_tp_match`, `has_sirix_match`). |

*Fonte: Elaborado pelos autores (2026).*

**Tabela 7 – Relacionamentos do modelo Power BI**

| De (tabela[campo]) | Para (tabela[campo]) | Status |
|--------------------|----------------------|--------|
| fato_movimentacao_financeira[tempo_aprovacao_sk] | dim_tempo[tempo_sk] | Ativo |
| fato_movimentacao_financeira[tempo_criacao_sk] | dim_tempo[tempo_sk] | Inativo |
| fato_movimentacao_financeira[cliente_sk] | dim_cliente[cliente_sk] | Ativo |
| fato_movimentacao_financeira[agente_sk] | dim_agente[agente_sk] | Ativo |
| fato_operacao[tempo_close_sk] | dim_tempo[tempo_sk] | Ativo |
| fato_operacao[tempo_open_sk] | dim_tempo[tempo_sk] | Inativo |
| fato_operacao[cliente_sk] | dim_cliente[cliente_sk] | Ativo |
| fato_operacao[agente_sk] | dim_agente[agente_sk] | Ativo |
| fato_operacao[ativo_sk] | dim_ativo[ativo_sk] | Ativo |
| fato_cliente_trade_dia[tempo_sk] | dim_tempo[tempo_sk] | Ativo |
| fato_cliente_trade_dia[cliente_sk] | dim_cliente[cliente_sk] | Ativo |
| fato_cliente_trade_dia[agente_sk] | dim_agente[agente_sk] | Ativo |
| fato_meta_agente_mes[competence_month_sk] | dim_tempo[tempo_sk] | Ativo |
| fato_meta_agente_mes[agente_sk] | dim_agente[agente_sk] | Ativo |
| vw_team_month_performance[competence_month] | dim_tempo[date] | Ativo |
| vw_agent_month_performance[competence_month] | dim_tempo[date] | Ativo |
| vw_agent_day_performance[ref_date] | dim_tempo[date] | Ativo |
| vw_agent_day_performance[agente_sk] | dim_agente[agente_sk] | Ativo |
| vw_call_list_today[agente_sk] | dim_agente[agente_sk] | Ativo |

*Fonte: Documentação técnica do modelo Power BI (bi-documentation.md, 2026). Relacionamentos usam cardinalidade many-to-one e filtro unidirecional. Relacionamentos inativos existem no modelo mas não propagam filtros por padrão (`tempo_open_sk` e `tempo_criacao_sk` substituídos pelos equivalentes ativos).*

### 3.5 Governança da configuração: templates XLSX e automação Python

Um dos componentes técnicos de maior relevância prática do projeto é o mecanismo de governança dos dados de configuração. Dados mestres como cadastro de agentes, metas mensais, catálogo de ativos e calendário de dias úteis precisam ser atualizados periodicamente pela gestão, sem que isso exija intervenção técnica direta no banco de dados.

A solução adotada utiliza quatro templates de configuração e dois templates de domínio, todos em formato Microsoft Excel (.xlsx), processados pelo script Python `load_config_domain_templates.py`, que valida os dados, gera SQL parametrizado e aplica as atualizações no PostgreSQL. Os templates de configuração gerenciam dados de negócio atualizados pela gestão; os templates de domínio mantêm os lookups canônicos de códigos dos sistemas-fonte. O processo completo é orquestrado pelo script Bash `reload_config_and_gold.sh`.

**Tabela 8 – Templates XLSX de configuração e domínio**

| Template | Tipo | Conteúdo |
|----------|------|----------|
| brokerlab_config_agents.xlsx | Configuração | Cadastro de agentes: nome, e-mail, equipe, nível (trainee/inter/pro), seniority, status ativo/inativo e lista de aliases — variações do nome do agente encontradas no campo retention_owner do CRM, necessárias para o mapeamento da bridge. |
| brokerlab_config_targets.xlsx | Configuração | Metas mensais por agente: `target_deposit_month_usd`, `target_trade_day`, `target_trade_month`, `target_unique_month` e `target_volume_month`. Cada linha representa um agente × mês de competência. Histórico de metas disponível para análises retroativas. |
| brokerlab_config_assets.xlsx | Configuração | Catálogo de ativos negociáveis: `sirix_symbol`, `normalized_symbol`, `display_name`, `asset_class` (forex, commodity, index, crypto), `base_currency`, `quote_currency`, `is_major_asset`. |
| brokerlab_config_calendar.xlsx | Configuração | Calendário de dias úteis de 2020 a 2035 com feriados: `is_business_day`, `is_global_holiday`, `holiday_name`. Usado no cálculo de `target_deposit_day_usd` (meta ÷ dias úteis do mês) e do run rate. |
| brokerlab_domain_crm.xlsx | Domínio | Lookups canônicos dos códigos do CRM Dynamics 365: lead status, tipos de transação financeira, métodos de pagamento e demais enumerações numéricas do sistema. Alimenta o schema domain. |
| brokerlab_domain_finance.xlsx | Domínio | Lookups canônicos de domínios financeiros: moedas, classificações de transação e demais tabelas de decodificação do pipeline. Alimenta o schema domain. |

*Fonte: Elaborado pelos autores (2026).*

**Fluxo de processamento:**

- O script Python lê cada planilha, valida tipos, nomes de colunas e integridade referencial (ex.: agente citado no targets deve existir no agents);
- Gera o arquivo SQL `config_domain_template_load.sql` com os comandos de INSERT/UPDATE parametrizados e registros de auditoria;
- O script Bash executa esse SQL no banco, reconstrói o schema gold na sequência (dimensões → fatos → views) e executa `gold_checks.sql` para validação automática;
- Erros de validação são registrados em `config_import` com timestamp, identificação do arquivo e descrição do problema, sem interromper o pipeline para outros templates.

### 3.6 Dashboards implementados

O relatório Power BI 'BI - BrokerLab' contém cinco páginas no total, conforme evidenciado pelos prints disponíveis no repositório (00 - Analítico, 01 - Página Inicial, 02 - Visão Executiva, 03 - Performance por Agente, 04 - Call List). As páginas 00 e 01 existem no arquivo, mas não possuem especificação técnica detalhada no repositório. As três abas operacionais com especificação técnica completa — referenciadas neste documento como Aba 01, Aba 02 e Aba 03 conforme a nomenclatura interna das especificações — correspondem às páginas de Visão Executiva, Performance por Agente e Call List do arquivo Power BI. O modelo semântico possui medidas DAX organizadas em pastas temáticas (Team Month, Agent Month, Agent Day, Call List, HTML Content), com fórmulas documentadas individualmente em `bi-documentation.md`.

#### 3.6.1 Aba 01 — Visão Executiva do Piso

Primeira tela do gestor e da diretoria. Responde se o piso está batendo a meta mensal, se está acima ou abaixo do run rate esperado, como está a evolução diária e quais agentes puxam o resultado.

**Tabela 9 – KPIs e visuais da Aba 01**

| Área | Medidas/campos principais | Uso |
|------|--------------------------|-----|
| Cards superiores (8) | Team Month Net Deposit USD, Team Month Target Deposit %, Team Month Withdrawal USD, Team Month Deposit USD, Team Month Run Rate USD, Team Month Gap Run Rate USD, Call List Clientes Operaram Hoje QTD, Call List Clientes Pendentes Hoje QTD | Visão instantânea dos principais KPIs do piso no mês selecionado. |
| Gauge HTML de meta | Team Month Target Deposit % (arco) / Team Month Net Deposit USD (realizado) / Team Month Target Deposit USD (meta) / Status Meta (classificação textual) | Arco animado com gradiente vermelho/amarelo/verde. Medida: Gauge HTML. |
| Gráfico evolução diária | Agent Day Net Deposit USD (colunas) / Agent Day Target Deposit USD (linha tracejada) | Evolução dia a dia do net deposit versus meta diária no mês selecionado. |
| Resumo operacional | Team Month Net Deposit USD, Team Month Target Deposit %, Team Month Target Deposit USD, Team Month Gap Meta USD, Team Month Run Rate USD, Team Month Gap Run Rate USD | Bloco compacto com seis KPIs consolidados do piso. |
| Ranking de agentes | agent_name, agent_level, Agent Month Rank Net Deposit (troféu), Agent Month Net Deposit USD, Agent Month Target Deposit %, Agent Month Trades QTD, Agent Month Unique Trades QTD | Tabela ordenada por net deposit mensal. Troféus para rank 1, 2 e 3 (medida Rank Chart com ImageUrl). |
| Filtros gold | dim_tempo[year_month] (mês), team_name, agent_name, agent_level, country, lead_status_text, has_ftd, priority_label, traded_today, is_pending_today | Filtros persistentes que propagam para todas as views da aba via relacionamentos. |

*Fonte: Especificação técnica 01-visao-executiva-piso.md (2026).*

#### 3.6.2 Aba 02 — Performance por Agente

Tela de acompanhamento individual para gestor e agente. Responde se o agente selecionado está performando no mês e quais clientes da sua carteira precisam de ação no dia.

**Tabela 10 – KPIs e visuais da Aba 02**

| Área | Medidas/campos principais | Uso |
|------|--------------------------|-----|
| Card Performance Agente | agent_name, agent_level, is_active, Agent Month Rank Net Deposit, Agent Day Net Deposit USD, Agent Month Target Deposit %, Call List Carteira Operando Hoje % | Visão consolidada do status do agente: rank, resultado hoje e atingimento da meta. |
| Card Net Deposit | Agent Month Net Deposit USD, Agent Day Net Deposit USD, Agent Day Deposit USD, Agent Day Withdrawal USD, Agent Day Net Deposit Acumulado USD | Net deposit mensal e diário com sparkline do acumulado mensal por data. |
| Cards superiores (3) | Agent Month Run Rate USD, Agent Month Total Trades QTD, Agent Month Unique Deposit QTD | KPIs de ritmo, atividade de trading e unique depositors do mês. |
| Gráfico evolução diária | Agent Day Net Deposit USD (colunas) / Agent Day Target Deposit USD (linha) por gold vw_agent_day_performance[ref_date] | Evolução diária do agente selecionado com tooltip de deposit, withdrawal e trades. |
| Card Atingimento da Meta | Agent Month Target Donut HTML (rosca HTML, verde ≥100%, âmbar 70–99%, vermelho <70%), Agent Month Net Deposit USD, Agent Month Target Deposit USD, Agent Month Gap Meta USD, Agent Month Status Meta TXT | Rosca HTML centralizada com valor percentual real, mesmo quando acima de 100%. |
| Card Carteira de Clientes | Call List Carteira Clientes QTD, Call List Clientes Operaram Hoje QTD, Call List Clientes Pendentes Hoje QTD, Call List Carteira Operando Hoje % | Status operacional diário da carteira do agente com barra de percentual. |
| Tabela Clientes Pendentes Hoje | gold vw_call_list_today filtrado por is_pending_today = TRUE: cliente_nome, lead_status_text, balance, equity, last_deposit_date, last_deposit_amount_usd, priority_label | Lista acionável de clientes da carteira que ainda não operaram no dia. |

*Fonte: Especificação técnica 02-performance-por-agente.md (2026).*

#### 3.6.3 Aba 03 — Call List Operacional

Tela operacional usada durante o dia por supervisores e agentes para separar quem já operou de quem ainda está pendente e priorizar clientes com maior potencial de ação. O campo `priority_label` (Alta/Média/Baixa), utilizado como critério de ordenação e filtro nesta aba, é baseado no valor de balance do cliente e está marcado no repositório como provisório — não representa uma regra de score oficial validada pela gestão da empresa.

**Tabela 11 – KPIs e visuais da Aba 03**

| Área | Medidas/campos principais | Uso |
|------|--------------------------|-----|
| 7 KPI cards (linha superior) | Call List Carteira Clientes QTD / Call List Clientes Operaram Hoje QTD / Call List Clientes Pendentes Hoje QTD / Call List Clientes Pendentes Alta Prioridade QTD / Call List Clientes c Saldo QTD / Call List Balance USD / Call List Equity USD | Visão agregada de toda a carteira filtrada. Valores reais de abril/2026 registrados na documentação: carteira de 1.849 clientes, 220 operaram, 1.629 pendentes. |
| Tabela esquerda — Operaram Hoje | gold vw_call_list_today filtrado por traded_today = TRUE: cliente_nome, agent_name, balance, equity, last_deposit_amount_usd, priority_label. Header: Call List Coverage Bar HTML (% operaram, cor dinâmica) | Lista dos clientes que já abriram posição no dia, ordenados por maior balance. |
| Tabela direita — Pendentes Hoje | gold vw_call_list_today filtrado por is_pending_today = TRUE: mesmas colunas da tabela esquerda. Header: Call List Coverage Bar HTML (% pendentes, cor dinâmica) | Lista dos clientes que ainda não operaram, ordenados por prioridade Alta e maior balance. |
| Rodapé — 3 visuais HTML | Call List Pendentes por Agente HTML (top 6 agentes, barras horizontais) / Call List Por Prioridade HTML (Alta/Média/Baixa com dots e barras) / Call List Lead Status HTML (top 5 lead statuses dos pendentes) | Visuais analíticos de concentração de pendências por agente, prioridade e perfil. |
| Filtros | priority_label (pills Alta/Média/Baixa), agent_name (dropdown) | Filtros operacionais da aba para segmentação rápida durante o dia. |

*Fonte: Especificação técnica 03-operacao-diaria-call-list.md (2026).*

A lógica de carteira implementada segue a regra: carteira = clientes atribuídos ao Retention Owner; operaram hoje = clientes da carteira com operação CMD 0/1 aberta no dia de referência; pendentes hoje = carteira menos operaram hoje.

### 3.7 Mapeamento KIQs × solução implementada

A tabela a seguir cruza cada KIQ definida no Plano de IC com o dashboard, a view Gold e as medidas DAX principais que a respondem diretamente.

**Tabela 12 – Mapeamento KIQs × dashboards × views × medidas DAX**

| KIQ | Dashboard | View Gold | Medidas DAX principais |
|-----|-----------|-----------|------------------------|
| KIQ 1 — Meta de depósito líquido (piso e agente) | Aba 01 (piso) / Aba 02 (agente) | vw_team_month_performance / vw_agent_month_performance / vw_agent_day_performance | Team Month Net Deposit USD / Team Month Target Deposit % / Team Month Run Rate USD / Team Month Gap Meta USD / Agent Month Target Deposit % / Agent Month Run Rate USD / Agent Day Net Deposit USD |
| KIQ 2 — Meta de unique depositors | Aba 01 (ranking) / Aba 02 (card superior) | vw_agent_month_performance / vw_team_month_performance / fato_meta_agente_mes | Agent Month Unique Deposit QTD / Agent Month Target Unique QTD / Agent Month Target Unique % / Team Month Unique Deposit QTD |
| KIQ 3 — Meta de trade / call list do dia | Aba 02 (tabela pendentes) / Aba 03 (tabelas e rodapé) | vw_call_list_today / fato_cliente_trade_dia / vw_agent_month_performance | Agent Month Trading Client Days QTD / Agent Month Target Trade % / Call List Clientes Operaram Hoje QTD / Call List Clientes Pendentes Hoje QTD / Call List Coverage Bar HTML |
| KIQ 4 — Evolução diária do agente | Aba 01 (gráfico combinado) / Aba 02 (gráfico combinado) | vw_agent_day_performance | Agent Day Net Deposit USD (colunas) / Agent Day Target Deposit USD (linha) / Agent Day Net Deposit Acumulado USD / Agent Day Clientes Operaram QTD |
| KIQ 5 — Priorização da carteira | Aba 02 (tabela pendentes) / Aba 03 (tabela direita + rodapé) | vw_call_list_today | Campos: balance, equity, margin_level / last_deposit_date, last_deposit_amount_usd / lead_status_text, priority_label / Call List Pendentes por Agente HTML / Call List Por Prioridade HTML / Call List Lead Status HTML |
| KIQ 6 — Produtividade de contato (telefonia) | Não implementada | Não implementada | Não implementada (evolução futura — ver Seção 3.8) |

*Fonte: Elaborado pelos autores com base em bi-documentation.md e specs de dashboard (2026).*

### 3.8 Escopo entregue versus roadmap técnico

Esta seção distingue formalmente as funcionalidades entregues neste projeto das que compõem o roadmap técnico documentado — desenvolvimentos futuros previstos, mas não implementados como parte da solução atual.

> **Nota técnica sobre data de referência:** as views `vw_agent_month_performance` e `vw_call_list_today` utilizam, no código do repositório, a data de referência fixa `'2026-04-28'` (em substituição a `CURRENT_DATE`), correspondente ao período de homologação do projeto. Para operação em produção, essa data deve ser substituída por `CURRENT_DATE` no script `gold_views.sql` antes de cada implantação.

**Tabela 13 – Escopo entregue versus roadmap técnico**

| Componente | Escopo entregue | Roadmap / backlog |
|------------|-----------------|-------------------|
| Pipeline de dados | Pipeline multicamadas completo: stg_raw, bronze, silver, domain, config, gold. DDLs, scripts de carga e validação implementados. | — |
| Integração CRM↔Sirix | Bridge via lv_tpaccountbase implementada e monitorada com campos de qualidade (bridge_quality_status, has_tp_match, has_sirix_match). | — |
| Star Schema Gold | 4 dimensões, 4 fatos e 7 views semânticas implementados. 19 relacionamentos ativos e 2 inativos no modelo Power BI. | — |
| Governança de configuração | 6 templates XLSX (4 de configuração + 2 de domínio) + script Python de validação e carga + script Bash de recarga completa do pipeline. | — |
| Dashboard — Aba 01 | Visão Executiva do Piso: gauge HTML, evolução diária, ranking de agentes, 8 KPI cards, filtros interativos. | — |
| Dashboard — Aba 02 | Performance por Agente: donut HTML, evolução diária individual, carteira, tabela de pendentes, 6 áreas implementadas. | — |
| Dashboard — Aba 03 | Call List Operacional: 7 KPI cards, duas tabelas lado a lado, 3 visuais HTML no rodapé, coverage bars. | — |
| Medidas DAX | Medidas DAX documentadas em bi-documentation.md, organizadas em 5 pastas: Team Month, Agent Month, Agent Day, Call List, HTML Content. | — |
| Monitoramento de qualidade | vw_data_quality_summary com checks OK/WARN/INFO; vw_unresolved_agent_alias; vw_unresolved_client_bridge. | — |
| Abas 04–09 do Power BI | — | SQLs de validação documentados e prontos para conferência (src/sql/validacao/), mas as abas não foram implementadas no Power BI: Rankings (04), Financeiro (05), Trading/Ativos (06), Qualidade (07), Comissão (08), Drill Cliente (09). |
| Cálculo de comissões | — | Rascunho técnico documentado em 08_comissao_score.sql, marcado explicitamente como 'SIMULAÇÃO — cálculo NÃO oficial'. A view gold.vw_agent_commission ainda é draft. Sem meta oficial de trade/unique validada. Não disponível como funcionalidade do dashboard. |
| Alertas automáticos | — | Objetivo de médio prazo (6–12 meses) documentado no PETI (Etapa 4). Nenhum artefato de implementação existe no repositório. |
| Integração de telefonia | — | Objetivo de médio prazo. Depende de disponibilização de logs estruturados (Voiso/Microsip) com chave de integração ao agente do CRM. |
| Análises preditivas | — | Objetivo de longo prazo (1–2 anos) documentado no PETI. Sem qualquer artefato de implementação. |

*Fonte: Elaborado pelos autores com base no repositório do projeto (2026).*

---

## 4. ESPECIFICAÇÃO DE REQUISITOS INFORMACIONAIS

Esta seção traduz as KIQs em requisitos de informação e indicadores-chave (KPIs) gerados pela solução BrokerLab, com distinção entre os requisitos implementados e os planejados para evolução futura.

### 4.1 KPIs implementados e regras de cálculo

**Tabela 14 – KPIs implementados na solução BrokerLab**

| KPI | Definição | Regra de cálculo | Periodicidade | Tabela/view |
|-----|-----------|------------------|---------------|-------------|
| Depósito líquido (USD) | Resultado líquido de captação: depósitos aprovados menos withdrawals aprovados | `SUM(deposit_amount_usd) - SUM(withdrawal_amount_usd)` sobre transações com `eh_aprovada = TRUE` | Diária e mensal | vw_agent_day_performance / vw_agent_month_performance / vw_team_month_performance |
| Meta mensal de depósito líquido | Meta individual por agente/mês configurada via template | `target_deposit_month_usd`; objetivo diário = meta mensal ÷ dias úteis do mês | Mensal (acumulado diário) | fato_meta_agente_mes / vw_agent_month_performance |
| Atingimento da meta de depósito (%) | Percentual de atingimento da meta mensal de depósito | `DIVIDE([Agent Month Net Deposit USD], [Agent Month Target Deposit USD])` | Mensal | Medida DAX: Agent Month Target Deposit % |
| Run Rate (USD) | Projeção do realizado ao ritmo diário atual para o mês cheio | `net_deposit_acumulado × business_days_in_month ÷ business_day_number_today` | Mensal (mês corrente) | vw_agent_month_performance / vw_team_month_performance |
| Gap Meta (USD) | Valor faltante para atingir a meta | `[Agent Month Target Deposit USD] - [Agent Month Net Deposit USD]` | Mensal | Medida DAX: Agent Month Gap Meta USD |
| Gap Run Rate (USD) | Diferença entre realizado e run rate (negativo = abaixo do ritmo) | `[Agent Month Net Deposit USD] - [Agent Month Run Rate USD]` | Mensal | Medida DAX: Agent Month Gap Run Rate USD |
| Unique Depositors (mês) | Clientes distintos com pelo menos um depósito aprovado no mês | `COUNT DISTINCT cliente_sk` sobre fato_movimentacao_financeira com `deposit_amount_usd > 0` e `eh_aprovada = TRUE` | Mensal | vw_agent_month_performance — unique_deposit_month / Medida DAX: Agent Month Unique Deposit QTD |
| Meta de unique depositors | Meta mensal de unique por agente/mês configurada individualmente | `target_unique_month` da fato_meta_agente_mes | Mensal | Medida DAX: Agent Month Target Unique QTD |
| Atingimento de meta de unique (%) | % de atingimento da meta mensal de unique | `DIVIDE([Agent Month Unique Deposit QTD], [Agent Month Target Unique QTD])` | Mensal | Medida DAX: Agent Month Target Unique % |
| Trading Client Days (mês) | Soma acumulada de ocorrências cliente×dia com operação. Métrica oficial de acompanhamento da meta de trade | `COUNT(*)` sobre fato_cliente_trade_dia no mês | Mensal | vw_agent_month_performance — trading_client_days_month / Medida DAX: Agent Month Trading Client Days QTD |
| Unique Trading Month (métrica auxiliar) | Clientes distintos que realizaram ao menos uma operação no mês. Métrica informativa — **NÃO** deve ser usada como base da meta de trade (a base oficial é trading_client_days_month) | `COUNT DISTINCT cliente_sk` sobre fato_cliente_trade_dia no mês | Mensal | vw_agent_month_performance — unique_trading_month / Medida DAX: Agent Month Unique Trading QTD |
| Meta mensal de trade | Meta de trading client days por agente/mês | `target_trade_month` da fato_meta_agente_mes | Mensal | Medida DAX: Agent Month Target Trade QTD |
| Atingimento de meta de trade (%) | % de atingimento da meta mensal de trade | `DIVIDE([Agent Month Trading Client Days QTD], [Agent Month Target Trade QTD])` | Mensal | Medida DAX: Agent Month Target Trade % |
| Clientes que operaram hoje | Clientes da carteira com operação CMD 0/1 no dia | `CALCULATE(COUNTROWS(vw_call_list_today), traded_today = TRUE)` | Diária | Medida DAX: Call List Clientes Operaram Hoje QTD |
| Clientes pendentes hoje | Carteira menos clientes com `traded_today = TRUE` | `CALCULATE(COUNTROWS(vw_call_list_today), is_pending_today = TRUE)` | Diária | Medida DAX: Call List Clientes Pendentes Hoje QTD |
| Volume negociado (lots) | Volume total em lotes. KPI informativo complementar — sem meta oficial para a maioria dos agentes | `SUM(volume_lots_month)` — vw_agent_month_performance | Mensal | Medida DAX: Agent Month Volume Lots QTD |
| PnL líquido (USD) | Resultado financeiro líquido das operações da carteira | `SUM(profit_liquido)` — fato_operacao | Mensal | Medida DAX: Agent Month PnL USD |
| Status Meta — piso | Classificação textual do atingimento (piso) | SWITCH: >= 100% → "Meta atingida"; >= 70% → "XX% da Meta"; else → "Abaixo da Meta" (base: Team Month Target Deposit %) | Mensal | Medida DAX: Status Meta (pasta Team Month) |
| Status Meta — agente | Classificação textual do atingimento (agente individual) | SWITCH: >= 100% → "Meta atingida"; >= 70% → "XX% da Meta"; else → "Abaixo da Meta" (base: Agent Month Target Deposit %) | Mensal | Medida DAX: Agent Month Status Meta / Agent Month Status Meta TXT |

*Fonte: Elaborado pelos autores com base em bi-documentation.md (2026).*

**KPIs planejados — evolução futura (não implementados neste projeto):**

| KPI | Definição | Motivo de não implementação |
|-----|-----------|------------------------------|
| Tempo em chamada (por agente/dia) | Tempo total em chamadas de voz por agente | Dependência de logs estruturados de telefonia (Voiso/Microsip) não disponibilizados |
| Comissão calculada (USD) | Comissão por faixas de net deposit e aceleradores | Lógica documentada em rascunho (08_comissao_score.sql — 'SIMULAÇÃO, NÃO oficial'); sem validação da gestão; não disponível como funcionalidade do dashboard |

*Fonte: Elaborado pelos autores (2026).*

### 4.2 Requisitos informacionais e funcionais da solução (BI/sistema)

**R1 — Painel diário de performance por agente** *(implementado)*  
Exibe depósito líquido do dia, meta diária, acumulado do mês e comparativo vs. run rate. Disponível na Aba 02 — Performance por Agente.

**R2 — Painel mensal de metas por piso e por agente** *(implementado)*  
Exibe meta mensal total do piso e por agente, com evolução diária, atingimento percentual, run rate e gap. Disponível na Aba 01 — Visão Executiva do Piso.

**R2.1 — Calendário de dias úteis** *(implementado)*  
Calendário de negócios parametrizado em `config.business_calendar` (2020–2035) com `is_business_day`, `business_day_number_in_month` e `remaining_business_days_in_month`. Usado no cálculo automático do objetivo diário e do run rate.

**R3 — KPI de unique depositors mensal** *(implementado)*  
Exibe contagem de clientes distintos com depósito aprovado no mês por agente (COUNT DISTINCT, `eh_aprovada = TRUE`), com comparativo à meta configurada. Disponível nas Abas 01 e 02.

**R4 — Painel de trades (diário e mensal)** *(implementado)*  
Exibe clientes que operaram no dia por agente e acumulado mensal de trading client days (soma de ocorrências cliente×dia com operação), que é a métrica de acompanhamento da meta mensal de trade. Disponível nas Abas 01, 02 e 03.

**R5 — Lista acionável de clientes pendentes (call list)** *(implementado)*  
Gera a lista diária de clientes que ainda não operaram (`is_pending_today = TRUE`), por agente, com prioridade, saldo, equity, último depósito e lead status. Disponível na Aba 03 e na Aba 02.

**R6 — Cadastro de agentes, níveis e metas (com histórico)** *(implementado)*  
Mantido via templates `brokerlab_config_agents.xlsx` e `brokerlab_config_targets.xlsx`, carregados por script Python. Histórico mensal de metas em `config.agent_target_month` e `gold.fato_meta_agente_mes`. Suporta aliases de agentes para mapeamento CRM.

**R7 — Integração com telefonia (Voiso/Microsip)** *(não implementado — evolução futura)*  
Importação de logs de chamadas para KPI de produtividade de contato. Dependente de logs estruturados disponibilizados pela plataforma de telefonia. Objetivo de médio prazo documentado no PETI (Etapa 4).

**R8 — Filtros e segmentações** *(implementado)*  
Filtros por mês, agente, equipe, nível, país, lead status, prioridade e status de operação disponíveis nas três abas do dashboard.

**R9 — Governança e rastreabilidade** *(parcialmente implementado)*  
Rastreabilidade na camada bronze (`_ingestao_ts`, `_origem`, `_hash_linha`) e monitoramento de qualidade via `vw_data_quality_summary`. Versionamento de dashboards a ser definido operacionalmente pela empresa.

### 4.3 Justificativa dos KPIs e relação com as decisões estratégicas

Os KPIs implementados refletem diretamente a lógica de gestão da área de retenção. O depósito líquido fornece a visão realista da captação ao descontar withdrawals; o run rate e o gap de meta permitem antecipar riscos de não atingimento ainda dentro do mês; o unique depositors mensura a capacidade do agente de manter clientes ativos realizando depósitos no mês; o trading client days acumula dia a dia os clientes que operaram e alimenta tanto a meta mensal de trade quanto a call list operacional; e o volume negociado e o PnL atuam como indicadores informativos complementares da intensidade de atividade da carteira, sem meta oficial vinculada. Juntos, esses indicadores permitem que a gestão tome decisões táticas diárias (priorização da call list, realocação de carteiras) e estratégicas mensais (ajuste de metas, avaliação de performance individual e do piso) com base em dados estruturados e auditáveis.

---

## 5. LEVANTAMENTO DE FONTES DE DADOS EXISTENTES

Esta seção apresenta o inventário das fontes de dados integradas pela solução BrokerLab, avaliando formato, acessibilidade, qualidade e status de implementação.

### 5.1 Inventário de dados disponíveis

**Tabela 15 – Inventário de fontes de dados integradas**

| Fonte / tabela | Origem | Ingestão | Tabela no BrokerLab | Uso principal |
|----------------|--------|----------|----------------------|---------------|
| crm_account_base | CRM Dynamics 365 | CSV → stg_raw → bronze → silver | silver.account_clean / gold.dim_cliente | Cadastro de clientes: nome, país, lead status, FTD, agente responsável |
| crm_user_base | CRM Dynamics 365 | CSV → stg_raw → bronze → silver | silver.user_clean / gold.dim_agente | Cadastro de usuários/agentes: nome, e-mail, perfil de acesso |
| lv_tpaccountbase | CRM Dynamics 365 | CSV → stg_raw → bronze → silver | silver.tpaccount_clean | Entidade-pivô CRM↔Sirix: conecta crm_account_id ao sirix_login; saldo, equity, margem |
| lv_monetarytransactionbase | CRM Dynamics 365 | CSV → stg_raw → bronze → silver | silver.transaction_clean / gold.fato_movimentacao_financeira | Transações financeiras: depósitos, withdrawals, aprovação, método, FTD |
| sirix_users_view | Sirix / Leverate | CSV/API → stg_raw → bronze → silver | silver.sirix_account_clean / gold.dim_cliente (enriquecimento) | Contas de trading: login, saldo, equity, leverage, grupo, última atividade |
| sirix_trades_view | Sirix / Leverate | CSV/API → stg_raw → bronze → silver | silver.trade_clean / gold.fato_operacao | Histórico de trades: ticket, CMD, símbolo, volume, open/close time, profit |
| sirix_daily_view | Sirix / Leverate | CSV/API → stg_raw → bronze → silver | silver.sirix_daily_clean | Snapshots diários de saldo/equity por conta Sirix |
| Templates XLSX de configuração | Controle interno do projeto | Excel → Python → PostgreSQL | config.*, domain.* | Agentes, aliases, metas mensais, catálogo de ativos, calendário de dias úteis |

*Fonte: Elaborado pelos autores (2026).*

### 5.2 Avaliação de qualidade, acessibilidade e prontidão dos dados

**Acessibilidade:**

Após a formalização do acesso às bases de dados do Sirix junto à Leverate, ambas as fontes principais estão integradas ao pipeline. A ingestão é realizada via extração para arquivos CSV e carregamento no schema stg_raw, seguido de transformações automatizadas pelas camadas bronze, silver e gold.

**Qualidade e rastreabilidade:**

Cada linha ingerida recebe `_ingestao_ts`, `_origem` e `_hash_linha`. A camada silver registra registros invalidados com `_eh_valido = FALSE` e `_motivo_invalido`. A view `gold.vw_data_quality_summary` centraliza checks automáticos com status OK, WARN e INFO.

**Casos de falha conhecidos e monitorados:**

- **Aliases de agentes:** nem todos os nomes de `retention_owner` no CRM possuem correspondência na `config.agent_alias`, monitorados via `gold.vw_unresolved_agent_alias`;
- **Bridge CRM↔Sirix parcial:** uma parcela dos clientes não possui o vínculo completo entre `crm_account_id` e `sirix_login`, monitorada via `gold.vw_unresolved_client_bridge` e o campo `bridge_quality_status`;
- **Operações suspeitas:** trades com padrão atípico são sinalizados com `_eh_suspeito = TRUE` na `fato_operacao`.

**Prontidão para uso analítico:**

Os dados transacionais e de trading estão disponíveis com histórico retroativo e regras de negócio aplicadas na camada gold. A dependência de planilhas manuais para controle de trades foi eliminada pela integração direta com a base Sirix.

### 5.3 Lacunas e dados remanescentes

As seguintes lacunas foram identificadas durante o projeto e permanecem como itens para evolução futura:

- **Dados de telefonia (Voiso/Microsip):** logs estruturados com duração de chamadas e identificador do agente. Necessários para o KPI de produtividade de contato (KIQ 6). Integração não implementada neste projeto.
- **Volume por chamada e correlação telefonia × resultados:** dependente da integração de telefonia descrita acima.
- **Cálculo oficial de comissões:** lógica documentada como rascunho técnico (`08_comissao_score.sql`), marcada explicitamente como simulação não oficial, sem validação da gestão e sem implementação no dashboard.

---