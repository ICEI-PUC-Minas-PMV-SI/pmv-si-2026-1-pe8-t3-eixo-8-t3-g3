# Etapa 2 — Plano de Inteligência Competitiva

## PONTIFÍCIA UNIVERSIDADE CATÓLICA DE MINAS GERAIS
Bacharelado em Sistemas de Informação
Arthur Andrade de Oliveira
Gabriel Vilhena Magri
Guilherme Pereira Carneiro
Ian Faria Chamone
Iyan Lucas Duarte Marques
Lucas Borges Silva
Raphaela Tamietto Rios
Trabalho de Conclusão de Curso
Etapa 2 — Plano de Inteligência Competitiva
Tese de Graduação apresentada ao curso de Sistemas de Informação, como parte dos requisitos
necessários à obtenção do título de Bacharel em Sistemas da Informação.
Orientadora: Dra. Simone Fernandes Queiroz
Área de concentração: Sistema de Informação
Belo Horizonte, 2026

## SUMÁRIO
# 1. ETAPA 1 – APRESENTAÇÃO DA EMPRESA, MERCADO, PROCESSOS E SISTEMAS
## 1.1 Apresentação da empresa
## 1.2 Análise de mercado
## 1.3 Análise de processos e sistemas
# 2. OBJETIVO E ESCOPO
## 2.1 Mapeamento das decisões estratégicas
## 2.2 Escolha da decisão-chave
## 2.3 Definição do KIT (Key Intelligence Topic)
## 2.4 Formulação das KIQs (Key Intelligence Questions)
## 2.5 Justificativa da relevância do KIT e das KIQs
# 3. MAPEAMENTO DE DADOS E IDENTIFICAÇÃO DAS NECESSIDADES DE INFORMAÇÃO
## 3.1 Observações técnicas (chaves, padronização e tipos de dados)
# 4. ESPECIFICAÇÃO DE REQUISITOS INFORMACIONAIS
## 4.1 KPIs implementados e regras de cálculo
## 4.2 Requisitos informacionais e funcionais da solução
## 4.3 Justificativa dos KPIs e relação com as decisões estratégicas
# 5. LEVANTAMENTO DE FONTES DE DADOS EXISTENTES
## 5.1 Inventário de dados disponíveis
## 5.2 Avaliação de qualidade, acessibilidade e prontidão dos dados
## 5.3 Lacunas e dados remanescentes
# 6. COMPLIANCE DE TI E SEGURANÇA DA INFORMAÇÃO
## 6.1 Normas e regulamentações aplicáveis
## 6.2 Políticas de proteção de dados e segurança da informação
## 6.3 Diretrizes para anonimização, controle de acesso e rastreabilidade
## 6.4 Procedimentos de auditoria e conformidade

# 1. ETAPA 1 – APRESENTAÇÃO DA EMPRESA, MERCADO, PROCESSOS E
## SISTEMAS
## 1.1 Apresentação da empresa
A empresa GSRS S.A.S., pertencente ao grupo internacional Cleverdemy, foi selecionada para o
desenvolvimento deste projeto. Trata-se de uma corretora internacional de investimentos fundada
há aproximadamente 20 anos, que atua no setor de serviços financeiros, especificamente no
segmento de intermediação no mercado de capitais. A organização oferece suporte à negociação
de ativos financeiros e ao relacionamento com investidores por meio de atendimento telefônico e
plataformas digitais de negociação. A empresa possui natureza privada, caracterizando-se como
uma organização internacional de capital fechado. Sua sede administrativa está localizada na Itália,
com operações distribuídas em diferentes países da Europa e da América Latina. Atualmente, a
empresa conta com cerca de 200 colaboradores em suas operações globais, sendo
aproximadamente 35 profissionais na unidade da Argentina, localizada na Ciudad Autónoma de
Buenos Aires, na região do Microcentro, responsável pelo atendimento exclusivo de investidores
brasileiros.
O modelo de funcionamento da corretora baseia-se na gestão de carteiras de investidores,
realizada por agentes comerciais responsáveis pelo acompanhamento da atividade das contas e
pela manutenção do relacionamento com os clientes. Esses profissionais monitoram indicadores
operacionais e comerciais, como número de clientes ativos, volume de operações realizadas,
valores depositados nas contas e desempenho das carteiras de investimento. A remuneração da
equipe está diretamente vinculada ao desempenho dessas carteiras, sendo baseada em metas
operacionais e indicadores de performance, o que torna a análise das informações geradas pelas
operações financeiras um elemento estratégico para a gestão da empresa.
Historicamente, a operação da empresa esteve concentrada principalmente em atividades
comerciais e operacionais. A unidade da Argentina identificou a necessidade de utilizar os dados
gerados pelas operações de forma mais estruturada para apoiar a tomada de decisão e melhorar o
acompanhamento da performance da equipe, especialmente na área de retenção de clientes. A
implementação da solução de BI BrokerLab, desenvolvida no âmbito deste projeto, atendeu
diretamente a essa necessidade, estruturando e organizando as informações operacionais por
meio de um ambiente analítico integrado. A iniciativa também despertou interesse em outras
unidades da empresa, como a operação localizada na França.
## 1.2 Análise de mercado
A empresa analisada atua no setor de serviços financeiros, especificamente no segmento de
intermediação no mercado de capitais por meio de corretoras de investimento. Esse tipo de
organização é responsável por intermediar a negociação de ativos financeiros entre investidores e
o mercado, oferecendo plataformas digitais de negociação e suporte operacional para a realização
de operações financeiras.
Nos últimos anos, o setor de corretagem passou por um processo de transformação impulsionado
pela digitalização dos serviços financeiros e pela expansão das plataformas de negociação online.
Nesse contexto, tornou-se comum que corretoras operem por meio de atendimento remoto e
plataformas tecnológicas, com equipes responsáveis por acompanhar o comportamento dos
investidores e estimular a atividade das contas de investimento.

O modelo de atuação baseia-se no relacionamento entre agentes comerciais e investidores, com
foco no acompanhamento das carteiras e na manutenção da atividade dos clientes dentro da
plataforma de negociação. O setor apresenta alta competitividade, com a presença de diversas
corretoras internacionais que oferecem serviços semelhantes de negociação online. Entre os
principais concorrentes encontram-se empresas como eToro, XM, AvaTrade e Interactive Brokers,
que competem principalmente por meio da oferta de tecnologia, variedade de ativos disponíveis
para negociação e qualidade das plataformas digitais.
Uma prática comum nesse mercado é o uso de sistemas de informação e análise de dados para
monitorar o comportamento dos investidores, acompanhar indicadores de desempenho e apoiar
estratégias comerciais. Corretoras que conseguem estruturar melhor seus dados e transformar
informações operacionais em indicadores estratégicos tendem a obter vantagens competitivas no
setor.
No caso da empresa analisada, a ausência de ferramentas estruturadas de acompanhamento de
indicadores dificultava o monitoramento da performance da equipe e da atividade das carteiras de
investidores. O desenvolvimento da solução BrokerLab, apresentada neste projeto, representa a
resposta direta a essa oportunidade de melhoria, substituindo controles manuais fragmentados por
um ambiente analítico integrado.
Tabela 1 – Matriz SWOT da empresa analisada
Ambiente
Elemento
Descrição
Interno
Forças
Estrutura comercial baseada em agentes especializados no relacionamento
com investidores; geração contínua de dados operacionais relevantes;
proximidade com o comportamento da carteira de clientes; existência de
sistemas operacionais já utilizados na rotina da empresa.
Interno
Fraquezas
Ausência de ambiente analítico integrado (estado anterior ao projeto);
dependência de planilhas eletrônicas para consolidação de indicadores
(estado anterior); baixa automação na geração de relatórios; dificuldade de
visualização consolidada do desempenho individual e da equipe.
Externo
Oportunidades
Crescimento do mercado de investimentos digitais; ampliação do uso de
ferramentas de Business Intelligence no setor financeiro; possibilidade de
integrar dados operacionais com notícias e indicadores de mercado; expansão
da cultura orientada a dados nas organizações.
Externo
Ameaças
Forte concorrência entre corretoras e fintechs; rápida evolução tecnológica do
setor; exigências regulatórias que podem demandar adaptações sistêmicas;
maior exigência dos investidores quanto à qualidade das plataformas e
agilidade das informações.
Fonte: Elaborado pelos autores (2026).
## 1.3 Análise de processos e sistemas
A análise dos processos da empresa foi realizada com o objetivo de compreender os fluxos de
trabalho e de informação relacionados às atividades de acompanhamento e retenção de
investidores — contexto que fundamentou o escopo da solução desenvolvida.
O processo de retenção inicia-se após a transferência do investidor pelo setor responsável pela
habilitação de contas. Nessa etapa inicial, o cliente já realizou um depósito inicial de valor reduzido,
utilizado apenas para ativação e abertura da conta na plataforma. Ao ser encaminhado para a área
de retenção, o investidor passa a ser classificado internamente como FTD (First Time Deposit),

termo utilizado pela empresa para identificar clientes que ainda não realizaram seu primeiro
depósito efetivo destinado à realização de operações no mercado financeiro. O cliente é então
atribuído a um agente financeiro responsável pelo acompanhamento de sua carteira. A distribuição
dos clientes ocorre de acordo com dois critérios principais: a classificação do agente (trainee,
intermediário ou profissional) e o perfil financeiro do investidor, categorizado de acordo com sua
capacidade de investimento e comportamento financeiro.
Cada agente é responsável por uma carteira média de aproximadamente 50 investidores,
acompanhando continuamente a atividade dessas contas. O modelo de negócio da corretora está
diretamente relacionado à realização de operações financeiras pelos clientes, uma vez que a
empresa e os agentes obtêm receita a partir da abertura de negociações e da manutenção da
atividade dos investidores na plataforma.
As operações financeiras realizadas pelos investidores ocorrem na plataforma digital Sirix,
fornecida pela empresa Leverate, ambiente no qual os clientes executam diretamente suas
negociações no mercado financeiro. Os agentes de retenção também possuem acesso à
plataforma em uma versão voltada ao acompanhamento das contas. Além da plataforma de
negociação, os agentes utilizam o sistema Microsoft Dynamics 365, que funciona como o sistema
de gestão de relacionamento com clientes (CRM) da empresa.
A Figura 1 apresenta o mapeamento do processo operacional elaborado por meio da notação
BPMN (Business Process Model and Notation).
Figura 1 – Mapeamento do processo operacional (BPMN)
Fonte: Elaborado pelos autores (2026).
Estado anterior à solução (AS-IS):
Antes do desenvolvimento do projeto BrokerLab, a geração de relatórios detalhados dependia da
extração manual de dados em planilhas eletrônicas (Google Sheets), o que dificultava a
consolidação das informações e reduzia a capacidade de análise integrada dos indicadores
operacionais. O acompanhamento de trades era realizado em planilha manual sem histórico

estruturado. O acesso estruturado às bases de dados do Sirix estava em processo de formalização
junto à Leverate.
Estado atual (TO-BE — solução implementada):
Ao longo do desenvolvimento do projeto, o acesso às bases de dados de ambos os sistemas foi
formalizado. A solução BrokerLab integra os dados do CRM (Dynamics 365) e da plataforma de
negociação (Sirix) em um pipeline analítico implementado em PostgreSQL, eliminando a
dependência de planilhas manuais para os indicadores cobertos pelo sistema. O Power BI,
integrado ao banco de dados, disponibiliza os indicadores operacionais em dashboards interativos
acessíveis pela gestão.
Tabela 2 – Informações técnicas sobre os sistemas utilizados
Elemento
Descrição
Plataforma de negociação
Sirix
Fornecedor da plataforma
Leverate
Sistema de CRM
Microsoft Dynamics 365
Infraestrutura de dados
(projeto)
Banco de dados PostgreSQL (db_brokerlab) — pipeline multicamadas (stg_raw,
bronze, silver, config, gold)
Integração de dados
Integração por banco de dados e APIs fornecidas pela Leverate; entidade-pivô
lv_tpaccountbase como ponte CRM↔Sirix
Tipos de dados integrados
Dados de clientes, histórico de operações de trading, transações financeiras
(depósitos/withdrawals), saldos e margem, cadastro de agentes e metas
Ferramentas analíticas
Microsoft Power BI — modelo semântico Star Schema com 3 dashboards
operacionais implementados
Capacidade analítica atual
Dashboards interativos com KPIs de performance por agente e piso, call list
operacional e evolução diária de metas
Fonte: Elaborado pelos autores (2026).
# 2. OBJETIVO E ESCOPO
Esta seção identifica e estrutura as necessidades de Inteligência Competitiva (IC) da GSRS S.A.S.
(grupo Cleverdemy), a partir do mapeamento de decisões estratégicas e das lacunas de
informação associadas. Como entregáveis, apresenta-se: (i) lista de decisões críticas; (ii) seleção
de uma decisão-chave; (iii) definição do Key Intelligence Topic (KIT); (iv) formulação das Key
Intelligence Questions (KIQs); e (v) justificativa de relevância para o contexto organizacional.
## 2.1 Mapeamento das decisões estratégicas (macro e microambiente)
Com base no diagnóstico organizacional (Etapa 1) e na análise do ambiente interno e externo,
foram elencadas as principais decisões estratégicas que exigem suporte informacional para a
operação estudada.
Decisão 1: Definir estratégias para aumentar a retenção de investidores brasileiros atendidos pela
unidade da Argentina, reduzindo inatividade e churn.
Decisão 2: Revisar a distribuição de carteiras (FTDs e demais clientes) entre agentes
(trainee/intermediário/profissional) considerando perfil do investidor, potencial de depósito e risco

de evasão.
Decisão 3: Definir metas, indicadores e critérios de performance para agentes e gestores, com
acompanhamento consolidado (individual, equipe e carteira) e critérios de remuneração
associados.
Decisão 4: Implementar uma solução de BI integrada entre Sirix (Leverate) e Microsoft Dynamics
365 para automatizar a geração de indicadores operacionais e eliminar a dependência de planilhas
manuais.
Decisão 5: Definir políticas e controles para uso seguro de dados (acessos, anonimização quando
aplicável, rastreabilidade e conformidade com LGPD), considerando a operação internacional e o
uso de plataformas de terceiros.
## 2.2 Escolha da decisão-chave
Entre as decisões mapeadas, foi priorizada aquela com maior impacto nos resultados do negócio,
maior urgência e maior incerteza informacional.
Decisão-chave selecionada: Implantar um acompanhamento estruturado e contínuo da
performance dos agentes de retenção, baseado em metas e indicadores operacionais (depósito
líquido diário e mensal, unique depositors, trades diários e volume negociado), para orientar
intervenções diárias, priorização de carteiras e melhoria de resultados, reduzindo a dependência de
controles manuais e aumentando a transparência da gestão.
## 2.3 Definição do KIT (Key Intelligence Topic)
O KIT delimita o tema central de inteligência que orientará a coleta e a análise de informações para
apoiar a decisão-chave.
KIT: Estruturar e analisar dados operacionais integrados (Sirix/Leverate e Dynamics 365) para
monitorar, por agente e por carteira, o atingimento de metas de depósito líquido (diário e mensal),
unique depositors, trades e volume negociado, apoiando decisões táticas e estratégicas da gestão
da área de retenção em tempo operacional.
## 2.4 Formulação das KIQs (Key Intelligence Questions)
Contexto operacional das metas:
(i) Meta mensal de depósito líquido: calculada como depósitos aprovados menos withdrawals
aprovados; o objetivo diário é definido como meta mensal ÷ dias úteis do mês, com base em
calendário de negócios parametrizado;
(ii) Meta mensal de unique depositors: conta-se apenas o primeiro depósito aprovado de cada
cliente no mês vigente; as metas são parametrizadas individualmente por agente e mês;
(iii) Meta de trade: número de clientes que abriram pelo menos uma posição de mercado (CMD 0
ou CMD 1) no dia, por agente; a meta mensal deriva da meta diária multiplicada pelos dias úteis
do mês;
(iv) Run rate: projeção do realizado ao ritmo diário atual para o mês cheio, utilizado para antecipar
riscos de não atingimento da meta.

As KIQs são perguntas específicas, acionáveis e orientadas à decisão, que guiaram a concepção
da solução implementada e são diretamente respondidas pelos dashboards do BrokerLab:
KIQ 1: Como acompanhar o atingimento da meta mensal e diária de depósito líquido por agente e
pelo piso (equipe), comparando o realizado com a meta e com o run rate esperado para o dia?
KIQ 2: Como medir a meta mensal de unique depositors por agente, contabilizando apenas o
primeiro depósito aprovado de cada cliente no mês vigente, e comparar o resultado com as metas
mensais configuradas?
KIQ 3: Como acompanhar a meta diária de trade — identificando quais clientes da carteira de cada
agente operaram no dia e gerando a lista de pendentes (clientes que ainda não operaram) para
ação imediata?
KIQ 4: Como monitorar a evolução diária de cada agente ao longo do mês, permitindo identificar
consistência de performance, concentração de resultados e desvio em relação ao ritmo esperado?
KIQ 5: Quais critérios devem orientar a priorização diária da carteira (quem contatar primeiro),
combinando sinais de situação financeira do cliente (balance, equity, margem), ausência de
operação no dia e perfil de lead status?
KIQ 6 (lacuna reconhecida — evolução futura): Como monitorar a produtividade de contato por
agente (tempo em chamada e volume de contatos via plataforma de telefonia), correlacionando
com resultados de depósito e trade? Esta KIQ foi identificada como necessidade relevante, porém
não está contemplada na solução implementada neste projeto, por depender de integração com
logs de telefonia (Voiso/Microsip) ainda não disponíveis de forma estruturada.
## 2.5 Justificativa da relevância do KIT e das KIQs
O KIT e as KIQs propostos são relevantes porque direcionam a Inteligência Competitiva para o
principal objetivo gerencial identificado no contexto da unidade: melhorar a performance dos
agentes de retenção por meio de metas e rotinas diárias de acompanhamento. Ao estruturar os
dados antes dispersos entre sistemas operacionais e controles manuais, a solução BrokerLab
entrega indicadores padronizados e auditáveis que permitem: (i) acompanhar o atingimento de
metas por agente e pelo piso; (ii) calcular run rate e gap de meta em tempo real, antecipando riscos
de não atingimento; (iii) gerar a lista operacional de clientes pendentes (call list) para direcionar
ações diárias; e (iv) reduzir retrabalho e inconsistências decorrentes de controles manuais sem
histórico. O KIT também orienta lacunas técnicas remanescentes — como a integração de dados
de telefonia — e os requisitos de conformidade aplicáveis (LGPD, controle de acesso e
rastreabilidade), garantindo que a solução seja aderente ao contexto operacional e às restrições de
uma operação internacional baseada em dados financeiros sensíveis.
# 3. MAPEAMENTO DE DADOS E IDENTIFICAÇÃO DAS NECESSIDADES DE
## INFORMAÇÃO
Esta seção relaciona as KIQs definidas na seção 2.4 às informações necessárias para
respondê-las, identificando as fontes de dados integradas pela solução BrokerLab e avaliando
disponibilidade, confiabilidade e o estado de implementação de cada item.

Tabela 3 – Mapeamento de KIQs, dados e fontes implementadas
## KIQ
Dados/campos implementados
Fonte no BrokerLab
Status
KIQ 1 — Meta
de depósito
deposit_amount_usd,
withdrawal_amount_usd,
net_deposit_usd, approved_on,
agente_sk;
target_deposit_month_usd,
target_deposit_day_usd; busines
s_day_number_in_month;
run_rate_usd, gap_meta_usd
gold.fato_movimentacao_finance
ira gold.fato_meta_agente_mes
gold.vw_agent_month_performa
nce gold.vw_team_month_perfor
mance
Implementado
KIQ 2 — Unique
depositors
eh_ftd, cliente_sk, agente_sk,
approved_on;
target_unique_month;
unique_deposit_month
gold.fato_movimentacao_finance
ira gold.fato_meta_agente_mes
gold.vw_agent_month_performa
nce
Implementado
KIQ 3 — Trade
diário / Call list
has_open_today, traded_today,
is_pending_today, priority_label;
balance, equity, margin_level,
last_activity_date,
last_deposit_date
gold.fato_cliente_trade_dia
gold.vw_call_list_today
gold.dim_cliente
Implementado
## KIQ 4 —
Evolução diária
do agente
net_deposit_day,
target_deposit_day_usd,
net_deposit_acumulado_mes,
clientes_operaram_dia,
total_trades_dia
gold.vw_agent_day_performance
Implementado
## KIQ 5 —
Priorização da
carteira
balance, equity, margin_level,
traded_today, is_pending_today,
last_deposit_date,
lead_status_text, priority_label
gold.vw_call_list_today
Implementado
## KIQ 6 —
Produtividade de
contato
(telefonia)
Não disponível
Não integrado (fonte
Voiso/Microsip não
disponibilizada de forma
estruturada)
## NÃO
implementado
— evolução
futura
Fonte: Elaborado pelos autores (2026).
## 3.1 Observações técnicas (chaves, padronização e tipos de dados)
Chaves de integração implementadas:
A integração entre o CRM (Dynamics 365) e a plataforma de negociação (Sirix) é realizada por
meio da entidade-pivô lv_tpaccountbase, onde o campo lv_name corresponde ao sirix_login do
usuário Sirix. Essa chave conecta crm_account_id (identificador do cliente no CRM) ao sirix_login
(identificador da conta de trading), permitindo rastrear transações financeiras e operações de
trading de um mesmo cliente de forma unificada. A efetividade dessa integração é monitorada
pelos campos bridge_quality_status, has_tp_match e has_sirix_match na camada Silver, e pelo
campo _agente_quality nas camadas Silver e Gold.
Padronização de tipos implementada:
Todos os valores monetários são armazenados em USD com tipo numérico de alta precisão; datas
são separadas em DATE (para dimensão tempo) e TIMESTAMP (para eventos operacionais);
booleanos são usados para flags operacionais (eh_aprovada, eh_ftd, traded_today,
is_pending_today). O schema domain centraliza os lookups canônicos para decodificação de
códigos numéricos do CRM e do Sirix (lead status, tipo de transação, CMD, método de pagamento,

moeda).
Qualidade de dados e monitoramento:
A view gold.vw_data_quality_summary centraliza checks de qualidade do pipeline, classificados por
status (OK, WARN, INFO). São monitorados: aliases de agentes sem correspondência, clientes
sem bridge CRM↔Sirix resolvida, operações suspeitas (_eh_suspeito) e transações ou trades sem
cliente atribuído.
Trades e histórico:
A limitação de controle manual em Google Sheets foi integralmente resolvida pela solução. A tabela
gold.fato_operacao registra todos os tickets Sirix com open_time, close_time, cmd_tipo,
volume_lots e profit_liquido, com rastreabilidade completa e histórico disponível para análises
retroativas. A tabela gold.fato_cliente_trade_dia agrega, por cliente e dia, o número de trades,
volume e PnL, alimentando diretamente a call list e os indicadores de meta de trade.
# 4. ESPECIFICAÇÃO DE REQUISITOS INFORMACIONAIS
Esta seção traduz as KIQs em requisitos de informação e indicadores-chave (KPIs) gerados pela
solução BrokerLab, com distinção entre os requisitos implementados e os planejados para
evolução futura.
## 4.1 KPIs implementados e regras de cálculo
Tabela 4 – KPIs implementados na solução BrokerLab
## KPI
Definição
Regra de cálculo
Periodicida
de
Tabela/view
Depósito líquido
## (USD)
Resultado líquido de
captação: depósitos
aprovados menos
withdrawals
aprovados
SUM(deposit_amount_
usd) - SUM(withdrawal
_amount_usd) sobre
transações com
eh_aprovada = TRUE
Diária e
mensal
vw_agent_day_perf
ormance vw_agent_
month_performance
vw_team_month_pe
rformance
Meta mensal de
depósito líquido
Meta individual de
captação líquida por
agente/mês,
configurada no
sistema
target_deposit_month_
usd; objetivo diário =
meta mensal ÷ dias
úteis do mês
Mensal
(com acom
panhament
o diário)
fato_meta_agente_
mes vw_agent_mon
th_performance
Atingimento da
meta de depósito
(%)
Percentual de
atingimento da meta
mensal de depósito
líquido
DIVIDE(net_deposit_m
onth_usd, target_depo
sit_month_usd)
Mensal
(com
acumulado
diário)
Medida DAX: Agent
Month Target
Deposit %
Run Rate (USD)
Projeção do
realizado ao ritmo
diário atual para o
mês cheio
net_deposit_acumulad
o × business_days_in_
month ÷ business_day
_number_today
Mensal
(mês
corrente)
vw_agent_month_p
erformance vw_tea
m_month_performa
nce
Gap Meta (USD)
Valor faltante para
atingir a meta
target_deposit_month_
usd - net_deposit_mont
h_usd
Mensal
Medida DAX:
Agent/Team Month
Gap Meta USD

## KPI
Definição
Regra de cálculo
Periodicida
de
Tabela/view
Gap Run Rate
## (USD)
Diferença entre
realizado e run rate
esperado
net_deposit_month_us
d - run_rate_usd
(negativo = abaixo do
ritmo)
Mensal
Medida DAX: Agent
Month Gap Run
Rate USD
Unique
Depositors (mês)
Clientes cujo
primeiro depósito
aprovado ocorreu no
mês vigente, por
agente
## COUNT(DISTINCT
cliente_sk) sobre
depósitos aprovados,
considerando apenas o
primeiro do mês por
cliente
Mensal
vw_agent_month_p
erformance —
campo unique_depo
sit_month
Meta de unique
depositors
Meta mensal de
unique depositors
por agente/mês,
configurada
individualmente
target_unique_month
da fato_meta_agente_
mes
Mensal
fato_meta_agente_
mes
Atingimento de
meta de unique
(%)
Percentual de
atingimento da meta
mensal de unique
DIVIDE(unique_deposit
_month,
target_unique_month)
Mensal
Medida DAX: Agent
Month Target
Unique %
Trades (clientes
que operaram no
dia)
Clientes da carteira
do agente que
abriram pelo menos
uma posição (CMD
0/1) no dia
## COUNT(DISTINCT
cliente_sk) sobre
fato_cliente_trade_dia
para o dia de
referência
Diária
fato_cliente_trade_d
ia vw_call_list_today
— flag traded_today
Pendentes hoje
Clientes da carteira
que ainda não
operaram no dia
Carteira do agente
menos clientes com
traded_today = TRUE
Diária
vw_call_list_today
— flag
is_pending_today
Trading Client
Days (mês)
Soma de ocorrências
cliente×dia com
operação no mês;
métrica base para
meta de trade
COUNT(*) sobre
fato_cliente_trade_dia
no mês
Mensal
vw_agent_month_p
erformance —
campo trading_clien
t_days_month
Meta mensal de
trade
Meta mensal de
trading client days
por agente/mês,
configurada no
sistema
target_trade_month da
fato_meta_agente_me
s
Mensal
fato_meta_agente_
mes
Volume
negociado (lots)
Volume total de
operações de
mercado em lotes,
por agente/mês
SUM(volume_lots)
sobre operações com
eh_operacao_mercado
## = TRUE
Mensal
vw_agent_month_p
erformance —
campo
volume_lots_month
PnL líquido (USD)
Resultado financeiro
líquido das
operações de trading
dos clientes da
carteira
SUM(profit_liquido)
sobre fato_operacao
Mensal
vw_agent_month_p
erformance —
campo pnl_month
Balance e Equity
da carteira (USD)
Saldo e equity total
da carteira de
clientes do agente
SUM(balance),
SUM(equity) sobre
dim_cliente filtrado por
agente
Snapshot
diário
gold.dim_cliente gol
d.vw_call_list_today

## KPI
Definição
Regra de cálculo
Periodicida
de
Tabela/view
Status Meta
Classificação textual
do atingimento da
meta
## SWITCH(TRUE(): >=
100% → Meta atingida;
>= 70% → XX% da
Meta; else → Abaixo
da Meta)
Mensal
Medida DAX: Status
Meta / Agent Month
Status Meta
Fonte: Elaborado pelos autores (2026).
KPIs planejados — evolução futura (não implementados neste projeto):
## KPI
Definição
Motivo de não implementação
Tempo em chamada
(por agente/dia)
Tempo total em chamadas de
voz por agente
Dependência de logs estruturados de telefonia
(Voiso/Microsip) não disponibilizados
Comissão calculada
## (USD)
Comissão do agente com base
em faixas de net deposit e
aceleradores
Lógica documentada em rascunho; sem meta oficial
validada pela gestão da empresa
Fonte: Elaborado pelos autores (2026).
## 4.2 Requisitos informacionais e funcionais da solução (BI/sistema)
Os requisitos abaixo refletem o estado final da solução, distinguindo os implementados dos
planejados.
R1 — Painel diário de performance por agente (implementado)
Exibe depósito líquido do dia, meta diária, acumulado do mês e comparativo vs. run rate. Disponível
na Aba 02 — Performance por Agente do dashboard BrokerLab.
R2 — Painel mensal de metas por piso e por agente (implementado)
Exibe a meta mensal total do piso e por agente, com evolução diária, atingimento percentual, run
rate e gap. Disponível na Aba 01 — Visão Executiva do Piso.
R2.1 — Calendário de dias úteis (implementado)
Calendário de negócios parametrizado em config.business_calendar, cobrindo o período de 2020 a
2035, com is_business_day, contagem e numeração de dias úteis por mês. Utilizado no cálculo
automático do objetivo diário e do run rate.
R3 — KPI de unique depositors mensal (implementado)
Exibe contagem de unique depositors no mês corrente por agente, com regra transparente
(primeiro depósito aprovado do mês por cliente) e comparativo com a meta configurada. Disponível
nas Abas 01 e 02.
R4 — Painel de trades (diário e mensal) (implementado)
Exibe número de clientes que operaram no dia por agente, acumulado mensal e atingimento da
meta de trading client days. Disponível nas Abas 01, 02 e 03.
R5 — Lista acionável de clientes pendentes (call list) (implementado)
Gera a lista diária de clientes que ainda não operaram no dia, por agente, com informações de
prioridade, saldo, equity, último depósito e lead status. Disponível na Aba 03 — Call List

Operacional e na Aba 02.
R6 — Cadastro de agentes, níveis e metas (com histórico) (implementado)
Mantido via templates Excel governados (brokerlab_config_agents.xlsx,
brokerlab_config_targets.xlsx) com carregamento automatizado por script Python. Persiste histórico
mensal de metas por agente em config.agent_target_month e gold.fato_meta_agente_mes.
R7 — Integração com telefonia (Voiso/Microsip) (não implementado — evolução futura)
Importação de logs de chamadas para geração de indicador de produtividade de contato.
Dependente da disponibilização de logs estruturados pela plataforma de telefonia. Identificado
como objetivo de médio prazo no PETI (Etapa 4).
R8 — Filtros e segmentações (implementado)
Filtros por mês, agente, equipe, nível do agente, país, lead status, prioridade e status de operação
disponíveis nas três abas do dashboard.
R9 — Governança e rastreabilidade (parcialmente implementado)
Rastreabilidade de ingestão implementada nas camadas bronze (_ingestao_ts, _origem,
_hash_linha) e monitoramento de qualidade via gold.vw_data_quality_summary. Controle de
versão dos templates de configuração via Git. Versionamento de dashboards a ser definido
operacionalmente pela empresa.
## 4.3 Justificativa dos KPIs e relação com as decisões estratégicas
Os KPIs implementados refletem diretamente a lógica de gestão da área de retenção. O depósito
líquido fornece a visão realista da captação ao descontar withdrawals; o run rate e o gap de meta
permitem antecipar riscos de não atingimento ainda dentro do mês; o unique depositors mensura a
capacidade do agente de reativar clientes ou converter novos; o trading client days diário
operacionaliza a rotina de contato com a call list; e o volume negociado e o PnL completam a visão
de atividade da carteira. Juntos, esses indicadores permitem que a gestão tome decisões táticas
diárias (priorização da call list, realocação de carteiras) e estratégicas mensais (ajuste de metas,
avaliação de performance individual e do piso) com base em dados estruturados e auditáveis.
# 5. LEVANTAMENTO DE FONTES DE DADOS EXISTENTES
Esta seção apresenta o inventário das fontes de dados integradas pela solução BrokerLab,
avaliando formato, acessibilidade, qualidade e status de implementação.
## 5.1 Inventário de dados disponíveis
Tabela 5 – Inventário de fontes de dados integradas
Fonte / tabela
Origem
Ingestão
Tabela no
BrokerLab
Uso principal
crm_account_base
CRM Dynamics
CSV → stg_raw
→ bronze →
silver
silver.account_clean
gold.dim_cliente
Cadastro de clientes: nome,
país, lead status, FTD, agente
responsável

Fonte / tabela
Origem
Ingestão
Tabela no
BrokerLab
Uso principal
crm_user_base
CRM Dynamics
CSV → stg_raw
→ bronze →
silver
silver.user_clean
gold.dim_agente
Cadastro de usuários/agentes:
nome, e-mail, perfil de acesso
lv_tpaccountbase
CRM Dynamics
CSV → stg_raw
→ bronze →
silver
silver.tpaccount_clea
n
Entidade-pivô CRM↔Sirix:
conecta crm_account_id ao
sirix_login; saldo, equity,
margem
lv_monetarytransac
tionbase
CRM Dynamics
CSV → stg_raw
→ bronze →
silver
silver.transaction_cle
an gold.fato_movime
ntacao_financeira
Transações financeiras:
depósitos, withdrawals,
aprovação, método de
pagamento, FTD
sirix_users_view
Sirix / Leverate
## CSV/API →
stg_raw →
bronze → silver
silver.sirix_account_
clean
gold.dim_cliente
(enriquecimento)
Contas de trading: login, saldo
Sirix, equity, leverage, grupo,
última atividade
sirix_trades_view
Sirix / Leverate
## CSV/API →
stg_raw →
bronze → silver
silver.trade_clean
gold.fato_operacao
Histórico completo de trades:
ticket, CMD, símbolo, volume,
open/close time, profit
sirix_daily_view
Sirix / Leverate
## CSV/API →
stg_raw →
bronze → silver
silver.sirix_daily_clea
n
Snapshots diários de
saldo/equity por conta Sirix
Templates XLSX
de configuração
Controle interno
(projeto)
Excel → Python
→ PostgreSQL
config.*, domain.*
Cadastro de agentes, aliases,
metas mensais, catálogo de
ativos, calendário de dias úteis
Fonte: Elaborado pelos autores (2026).
## 5.2 Avaliação de qualidade, acessibilidade e prontidão dos dados
Acessibilidade:
Após a formalização do acesso às bases de dados do Sirix junto à Leverate, ambas as fontes
principais (CRM e Sirix) estão integradas ao pipeline de dados do BrokerLab. A ingestão é
realizada via extração para arquivos CSV e carregamento no schema stg_raw, seguido de
transformações automatizadas pelas camadas bronze, silver e gold.
Qualidade e rastreabilidade:
Cada linha ingerida nas camadas bronze recebe carimbo de ingestão (_ingestao_ts), identificador
de origem (_origem) e hash da linha (_hash_linha) para auditoria. A camada silver registra registros
invalidados com flag _eh_valido = FALSE e _motivo_invalido. A view
gold.vw_data_quality_summary centraliza os resultados dos checks automáticos de qualidade,
classificados por status (OK, WARN, INFO).
Casos de falha conhecidos e monitorados:
 Aliases de agentes: nem todos os nomes de retention_owner no CRM possuem
correspondência confirmada na tabela config.agent_alias, sendo monitorados via
gold.vw_unresolved_agent_alias;
 Bridge CRM↔Sirix: uma parcela dos clientes não possui o vínculo completo entre
crm_account_id e sirix_login, monitorada via gold.vw_unresolved_client_bridge e o campo
bridge_quality_status;

 Operações suspeitas: trades identificados com padrão atípico são sinalizados com _eh_suspeito
= TRUE na fato_operacao.
Prontidão para uso analítico:
Os dados transacionais (depósitos, withdrawals) e de trading (operações, volume) estão
disponíveis com histórico retroativo e regras de negócio aplicadas na camada gold. A dependência
de planilhas manuais para controle de trades foi eliminada pela integração com a base Sirix.
## 5.3 Lacunas e dados remanescentes
As seguintes lacunas foram identificadas durante o projeto e permanecem como itens para
evolução futura:
Dados de telefonia (Voiso/Microsip): para o KPI de produtividade de contato (tempo em
chamada e volume de contatos por agente), é necessária a extração de logs estruturados das
plataformas de telefonia com chave de integração mapeada ao agente do CRM. Esta integração
não foi implementada neste projeto.
Volume por chamada e correlação telefonia × resultados: dependente da integração de
telefonia descrita acima; também demanda definição de chaves de mapeamento entre o
identificador do agente na plataforma de discagem e o retention_owner do CRM.
Cálculo oficial de comissões: a lógica de cálculo de comissões por faixas de net deposit e
aceleradores foi documentada em rascunho, mas não foi validada pela gestão da empresa nem
implementada como funcionalidade oficial do dashboard.
# 6. COMPLIANCE DE TI E SEGURANÇA DA INFORMAÇÃO
Esta seção identifica os requisitos legais e normativos aplicáveis ao tratamento de dados no
contexto do projeto BrokerLab e apresenta as diretrizes de segurança da informação adotadas,
distinguindo as que foram implementadas na solução das que constituem recomendações
operacionais para a empresa.
## 6.1 Normas e regulamentações aplicáveis
LGPD (Lei nº 13.709/2018):
Aplicável por envolver tratamento de dados pessoais de investidores brasileiros (cadastros,
histórico de relacionamento e informações associadas à conta). Exige finalidade, necessidade,
segurança, controle de acesso, transparência e governança.
GDPR (Regulamento Europeu 2016/679) — análise de aplicabilidade:
Como a empresa possui sede na Itália e operação europeia, recomenda-se verificar internamente
se há exigências corporativas adicionais alinhadas ao GDPR. Para o escopo deste projeto, o foco
prático permanece na LGPD e nos controles de segurança coerentes com a operação brasileira.
Boas práticas de segurança e privacidade:
Minimização de dados, segregação de funções, rastreabilidade (logs de auditoria), gestão de
credenciais e armazenamento seguro.
## 6.2 Políticas de proteção de dados e segurança da informação
Implementadas na solução BrokerLab:

Pseudonimização na camada analítica: na camada gold e no modelo Power BI, os clientes são
referenciados por chaves internas (cliente_sk, crm_account_id, sirix_login) em vez de dados
pessoais diretos. Os dados identificáveis permanecem restritos às camadas bronze e silver, com
acesso controlado.
Rastreabilidade de ingestão: cada linha ingerida no banco de dados recebe _ingestao_ts,
_origem e _hash_linha, criando trilha de auditoria sobre a origem e o momento de cada dado
processado.
Controle de versão de configurações: os templates de configuração (agentes, metas, ativos,
calendário) são versionados via Git, garantindo histórico e rastreabilidade de mudanças nos
dados de negócio.
Monitoramento de qualidade: a view gold.vw_data_quality_summary registra checks
automáticos de integridade, detectando inconsistências de forma contínua.
Diretrizes recomendadas para operação pela empresa:
Classificação e finalidade: classificar os dados utilizados (pessoais, financeiros, operacionais) e
registrar formalmente a finalidade do uso.
Armazenamento e compartilhamento: centralizar a consolidação em repositórios corporativos
autorizados; proibir exportação de relatórios em Excel contendo dados pessoais de clientes para
dispositivos particulares de agentes ou colaboradores.
Retenção e descarte: definir prazos de retenção para dados históricos e exports operacionais,
com descarte seguro quando expirados.
Gestão de incidentes: estabelecer procedimento de reporte e resposta a incidentes (vazamento,
acesso indevido), com responsáveis e prazos definidos.
## 6.3 Diretrizes para anonimização, controle de acesso e rastreabilidade
Controle de acesso por perfil (RBAC):
A arquitetura do dashboard BrokerLab foi projetada com dois níveis de acesso: (i) agentes
visualizam exclusivamente os dados de sua própria carteira; (ii) gestores de mesa e diretores
possuem visão consolidada do piso, performance comparativa entre agentes e acesso a metas e
indicadores de toda a equipe. A implementação operacional do controle de acesso depende da
configuração de Row-Level Security (RLS) no Power BI pelo administrador da ferramenta na
empresa.
Pseudonimização em análises:
O modelo de dados utiliza IDs internos (cliente_sk, agente_sk, crm_account_id) como chaves no
BI, mantendo os dados pessoais identificáveis (nome, e-mail, telefone) restritos à camada CRM
com acesso controlado.
Logs e rastreabilidade:
O pipeline de dados registra carimbo de data/hora de cada ingestão e transformação. Os
indicadores utilizados para cobrança de metas têm regras de cálculo documentadas e versionadas
(arquivo bi-documentation.md e scripts SQL no repositório do projeto).
## 6.4 Procedimentos de auditoria e conformidade

Revisão periódica de acessos: validar periodicamente os acessos ao banco de dados, ao
Power BI e aos templates de configuração, removendo permissões indevidas.
Auditoria de indicadores: manter documentação das regras de cálculo (depósito líquido, unique
depositors, trading client days) e realizar checagens comparando os resultados do Power BI
com os scripts de validação SQL disponíveis no repositório (src/sql/validacao/), que reproduzem
as medidas DAX diretamente em SQL para conferência.
Controle de versões: o repositório Git do projeto centraliza o versionamento de scripts SQL,
scripts Python, templates de configuração e documentação do modelo semântico. Alterações no
pipeline ou nas regras de negócio devem ser registradas como commits rastreáveis.
Conformidade contínua: manter checklist simplificado de LGPD aplicado ao projeto (finalidade,
minimização, acesso, retenção e segurança), revisando-o a cada mudança relevante na fonte
de dados ou no escopo do BI.