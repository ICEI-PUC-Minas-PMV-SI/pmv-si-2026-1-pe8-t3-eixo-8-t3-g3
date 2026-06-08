# 1. Etapa 1 - Apresentação da empresa, mercado, processos e sistemas

## 1.1 Apresentação da empresa

A empresa selecionada para o desenvolvimento deste projeto foi a **GSRS S.A.S.**, pertencente ao grupo internacional **Cleverdemy**. Trata-se de uma corretora internacional de investimentos que atua no setor de serviços financeiros, especificamente no segmento de intermediação e suporte à negociação de ativos financeiros por meio de plataformas digitais. A organização possui natureza privada, com operações distribuídas em diferentes países da Europa e da América Latina. No contexto deste projeto, o estudo concentrou-se na unidade da Argentina, localizada em Buenos Aires, responsável pelo atendimento de investidores brasileiros.

A empresa possui aproximadamente 200 colaboradores em suas operações globais, sendo cerca de 35 profissionais na unidade analisada. A estrutura operacional dessa unidade é voltada principalmente para atendimento comercial, acompanhamento de investidores e retenção de clientes. O modelo de funcionamento baseia-se na gestão de carteiras de investidores por agentes de retenção, que acompanham a atividade das contas, orientam os clientes quanto ao uso da plataforma e monitoram indicadores operacionais relacionados a depósitos, retiradas, volume de operações, saldos, margem, clientes ativos e desempenho individual por carteira.

A escolha da empresa justifica-se pela existência de um problema real de gestão da informação. Embora a organização já utilizasse sistemas relevantes em sua rotina, como o **Microsoft Dynamics 365** para relacionamento com clientes e a plataforma **Sirix/Leverate** para operações de trading, parte do acompanhamento gerencial ainda dependia de consultas isoladas, extrações manuais e planilhas. Essa situação dificultava a consolidação dos dados, a rastreabilidade dos indicadores e a tomada de decisão diária pela gestão da área de retenção.

Esse cenário atende diretamente às orientações da Etapa 1, pois a empresa possui sistemas de informação e planilhas, mas não utilizava plenamente suas funcionalidades para análise gerencial, dashboards e Business Intelligence. A empresa também demonstrou abertura para colaboração com o grupo, disponibilizando informações sem exposição de dados sensíveis e permitindo o estudo dos processos, sistemas e necessidades informacionais da operação.

Nesse contexto, o projeto **BrokerLab** foi desenvolvido com o objetivo de estruturar um ambiente analítico integrado para apoiar a operação. A solução implementada organiza dados do CRM Dynamics 365 e da plataforma Sirix/Leverate em um **data warehouse PostgreSQL**, com camadas de tratamento e governança, e disponibiliza indicadores gerenciais em dashboards do **Power BI**. Dessa forma, o projeto contribui para melhorar o acompanhamento de metas, a performance dos agentes, a priorização de carteiras e a confiabilidade das informações utilizadas pela gestão.

## 1.2 Análise de mercado

A GSRS S.A.S. atua no mercado de serviços financeiros, no segmento de corretoras de investimento e plataformas digitais de negociação. Esse setor é caracterizado pela intermediação de operações financeiras, pelo suporte a investidores e pela disponibilização de ambientes tecnológicos para negociação de ativos como moedas, índices, commodities, ações e criptoativos.

Nos últimos anos, o setor passou por forte processo de digitalização. A expansão das plataformas on-line de investimento aumentou a competitividade entre corretoras e tornou a experiência digital, a qualidade do atendimento e a capacidade de uso de dados fatores importantes para a manutenção e retenção de clientes. Nesse ambiente, empresas que conseguem acompanhar o comportamento dos investidores de forma estruturada tendem a responder mais rapidamente a sinais de inatividade, queda de engajamento, redução de depósitos ou mudanças no perfil operacional das carteiras.

Entre os principais concorrentes do setor estão corretoras e plataformas internacionais como **eToro**, **XM**, **AvaTrade** e **Interactive Brokers**. Essas empresas competem pela variedade de ativos ofertados, pela qualidade das plataformas digitais, pela experiência do usuário, pela disponibilidade de informações em tempo operacional e pela capacidade de suporte ao investidor. Além disso, o mercado financeiro digital apresenta clientes cada vez mais exigentes quanto à agilidade, confiabilidade e clareza das informações.

No caso da empresa analisada, a área de retenção possui papel estratégico, pois atua diretamente na manutenção da atividade dos investidores dentro da plataforma. A ausência de um ambiente analítico integrado representava uma fragilidade operacional, uma vez que dificultava a visão consolidada sobre desempenho de agentes, depósitos, retiradas, clientes que operaram no dia e clientes pendentes de ação. Ao mesmo tempo, a existência de sistemas operacionais com grande volume de dados representava uma oportunidade clara para desenvolvimento de uma solução de Business Intelligence.

A matriz SWOT a seguir resume os principais fatores internos e externos identificados no contexto da empresa e do projeto.

**Tabela 1 - Matriz SWOT da empresa analisada**

| Ambiente | Elemento | Descrição |
|---|---|---|
| Interno | Forças | Estrutura comercial especializada em retenção de investidores; uso de sistemas operacionais consolidados, como Microsoft Dynamics 365 e Sirix/Leverate; geração contínua de dados sobre clientes, depósitos, retiradas, saldos, margem e operações de trading; proximidade dos agentes com o comportamento das carteiras. |
| Interno | Fraquezas | Antes do projeto, havia dependência de planilhas e extrações manuais para consolidação de indicadores; baixa integração analítica entre CRM e plataforma de trading; dificuldade de auditoria dos números usados para acompanhamento de metas; ausência de dashboards gerenciais integrados para a área de retenção. |
| Externo | Oportunidades | Crescimento do mercado de investimentos digitais; maior adoção de ferramentas de Business Intelligence no setor financeiro; possibilidade de uso de dados para aumentar retenção, produtividade comercial e governança; evolução futura para alertas automáticos, cálculo de comissões e análises preditivas. |
| Externo | Ameaças | Concorrência intensa entre corretoras digitais e fintechs; rápida evolução tecnológica do setor; exigências regulatórias e de privacidade relacionadas ao tratamento de dados financeiros e pessoais; risco de perda de clientes caso a empresa não acompanhe rapidamente sinais de inatividade ou queda de engajamento. |

Fonte: Elaborado pelos autores (2026).

A análise evidencia que a empresa possui estrutura operacional e fontes de dados relevantes, mas precisava evoluir na forma de integrar, tratar e transformar esses dados em informações gerenciais. O BrokerLab responde diretamente a essa necessidade ao consolidar os dados operacionais em um ambiente analítico, permitindo acompanhamento de metas, performance individual, visão executiva do piso e call list operacional.

## 1.3 Análise de processos e sistemas

O processo analisado neste projeto está relacionado à operação de retenção de investidores. Esse processo tem início quando um cliente é encaminhado para uma carteira acompanhada por um agente responsável. A partir desse momento, o agente passa a monitorar a atividade da conta, acompanhar depósitos, retiradas, saldos, equity, margem e operações realizadas na plataforma de trading. O objetivo operacional é manter o cliente ativo, estimular a continuidade das operações e apoiar o atingimento das metas individuais e coletivas da equipe.

Na rotina da empresa, os agentes utilizam o **Microsoft Dynamics 365** como sistema de gestão de relacionamento com clientes. Nesse ambiente são armazenadas informações cadastrais, dados de relacionamento, responsáveis pela carteira, status de leads e registros associados às contas dos investidores. Paralelamente, a plataforma **Sirix/Leverate** registra as contas de trading, saldos, equity, snapshots diários e operações realizadas pelos clientes.

Um ponto técnico relevante identificado no projeto é a necessidade de integrar os dados desses dois ambientes. A entidade `lv_tpaccountbase`, existente no contexto do CRM, funciona como ponte entre o cadastro do cliente e a conta de trading, permitindo relacionar o `crm_account_id` ao `sirix_login`. Sem esse vínculo, não seria possível associar de forma confiável as operações registradas no Sirix aos clientes e agentes cadastrados no CRM.

Antes do desenvolvimento da solução, o fluxo de informação apresentava limitações. Os dados existiam nos sistemas operacionais, mas a análise gerencial dependia de consultas fragmentadas, relatórios nativos e planilhas. O acompanhamento de clientes que operaram ou não operaram no dia, metas de depósito, unique depositors e desempenho por agente não possuía uma estrutura integrada e auditável. Essa situação gerava retrabalho, risco de divergência nos indicadores e menor velocidade para tomada de decisão.

A Figura 1, elaborada em BPMN na Etapa 1, representa o fluxo operacional da retenção de investidores, contemplando a habilitação da conta, a classificação do cliente, a atribuição ao agente de retenção, o acompanhamento das operações e o uso das informações registradas nos sistemas da empresa. O diagrama permanece válido como representação do processo de negócio, enquanto o BrokerLab complementa esse fluxo ao estruturar a camada analítica que consolida os dados gerados por ele.

**Figura 1 - Mapeamento do processo de retenção de investidores (BPMN).**  
Disponível em: <https://lucid.app/lucidchart/1fefdc46-137a-46fc-bc02-4c8953696a5e/edit?viewport_loc=32%2C-66%2C1353%2C753%2C18_45&invitationId=inv_a59bc174-2a4e-4c04-bca8-46d143694730>

### 1.3.1 Arquitetura da solução desenvolvida

O projeto BrokerLab estruturou uma solução de dados para superar as limitações identificadas. A arquitetura implementada utiliza um banco PostgreSQL denominado `db_brokerlab`, organizado em camadas analíticas. O fluxo geral da solução integra dados do CRM Dynamics 365 e da plataforma Sirix/Leverate, consolida essas informações no data warehouse e disponibiliza as tabelas e views da camada `gold` para consumo pelo Power BI em modo Import.

```text
CRM Dynamics 365        Sirix/Leverate
       |                       |
       v                       v
    stg_raw  ->  bronze  ->  silver  ->  gold  ->  Power BI
                              ^
                              |
                       config / domain
```

A camada `stg_raw` recebe os dados brutos provenientes dos sistemas fonte. A camada `bronze` armazena cópias tipadas e auditáveis, preservando rastreabilidade de ingestão. A camada `silver` realiza limpeza, padronização, deduplicação e preparação dos dados para consumo analítico. As camadas `config` e `domain` concentram regras de negócio, cadastros governados, domínios, metas, calendário, agentes, aliases e catálogo de ativos. Por fim, a camada `gold` disponibiliza o modelo dimensional e as views semânticas utilizadas pelo Power BI.

Na camada `gold`, o projeto implementa dimensões e fatos voltados à análise gerencial. Entre as principais tabelas estão `gold.dim_tempo`, `gold.dim_agente`, `gold.dim_cliente`, `gold.dim_ativo`, `gold.fato_movimentacao_financeira`, `gold.fato_operacao`, `gold.fato_cliente_trade_dia` e `gold.fato_meta_agente_mes`. Além disso, foram criadas views semânticas para facilitar o consumo no Power BI, como `gold.vw_team_month_performance`, `gold.vw_agent_month_performance`, `gold.vw_agent_day_performance`, `gold.vw_call_list_today` e `gold.vw_data_quality_summary`.

Essa arquitetura está alinhada com o Planejamento Estratégico e a Governança de TI definidos na Etapa 4, pois transforma o uso dos dados em um processo mais controlado, auditável e orientado à tomada de decisão. A Etapa 4 prevê a continuidade dessa solução por meio de monitoramento frequente de qualidade de dados, governança, controle de acesso, registro de mudanças, backup e evolução futura para comissões, alertas automáticos e análises preditivas.

### 1.3.2 Dashboards e indicadores entregues

Os dashboards desenvolvidos no Power BI apoiam três frentes principais da operação:

- **Visão Executiva do Piso:** acompanha depósito líquido, meta mensal, percentual de atingimento, run rate, gap de meta, depósitos, withdrawals e ranking de agentes.
- **Performance por Agente:** apresenta desempenho individual, meta mensal e diária, evolução diária, unique depositors, trades, clientes pendentes e carteira do agente.
- **Operação Diária / Call List:** identifica clientes que já operaram no dia, clientes pendentes, prioridade de contato, saldos, equity, último depósito e distribuição por agente, prioridade e lead status.

Os principais indicadores implementados incluem depósito líquido, meta mensal de depósito, meta diária derivada, percentual de atingimento, run rate, gap de meta, unique depositors, clientes que operaram no dia, pendentes hoje, trading client days, volume negociado, PnL, balance e equity. A solução também contempla mecanismos de governança e verificação de qualidade, como checks de reconciliação financeira, identificação de clientes sem agente resolvido, aliases sem correspondência, operações sem ativo classificado e metas com valores default.

### 1.3.3 Maturidade dos sistemas de informação

Do ponto de vista da maturidade dos sistemas de informação, a empresa já possuía sistemas operacionais capazes de registrar dados relevantes, mas apresentava baixa maturidade analítica antes do projeto, devido à dependência de processos manuais e à ausência de integração estruturada para BI. Com a implementação do BrokerLab, a maturidade evolui para um modelo mais integrado, rastreável e orientado a indicadores, ainda que algumas funcionalidades permaneçam como evolução futura.

Antes do BrokerLab, o Microsoft Dynamics 365 e o Sirix/Leverate eram utilizados principalmente como sistemas operacionais. Após o desenvolvimento do projeto, os dados desses sistemas passaram a alimentar um pipeline analítico em PostgreSQL, com regras de transformação, validação, documentação e consumo no Power BI. Essa mudança reduz a dependência de planilhas e melhora a capacidade de acompanhamento gerencial da operação.

### 1.3.4 Informações técnicas dos sistemas e da solução

**Tabela 2 - Informações técnicas sobre os sistemas e a solução**

| Elemento | Descrição |
|---|---|
| Sistema de CRM | Microsoft Dynamics 365 |
| Plataforma de trading | Sirix/Leverate |
| Banco analítico do projeto | PostgreSQL `db_brokerlab` |
| Arquitetura de dados | Camadas `stg_raw`, `bronze`, `silver`, `config`, `domain` e `gold` |
| Modelo de consumo | Star schema e views semânticas na camada `gold` |
| Ferramenta de BI | Microsoft Power BI em modo Import |
| Fontes principais | Dados cadastrais, contas, agentes, transações financeiras, depósitos, withdrawals, trades, snapshots diários, metas, calendário e ativos |
| Integração CRM-Sirix | Realizada por chaves de conta, com destaque para `lv_tpaccountbase` como entidade de ligação entre cliente CRM e login Sirix |
| Governança de dados | Templates Excel versionados, scripts Python de carga, domínios de negócio, checks SQL e views de qualidade |
| Relatórios e dashboards | Visão executiva, performance por agente e call list operacional |
| Limitações atuais | Telefonia não integrada, comissão oficial em evolução futura, necessidade de ajustes operacionais para data dinâmica, acessos e Row-Level Security |

Fonte: Elaborado pelos autores (2026).

### 1.3.5 Gargalos identificados e oportunidades de melhoria

A análise dos processos e sistemas evidencia que os principais gargalos iniciais estavam relacionados à fragmentação das fontes de dados, dependência de planilhas, baixa rastreabilidade dos indicadores e dificuldade de visualização consolidada da performance da equipe. O BrokerLab foi construído justamente para reduzir esses gargalos, organizando as informações em um ambiente analítico integrado e disponibilizando dashboards para a gestão.

Mesmo com a evolução entregue pelo projeto, permanecem oportunidades de melhoria futuras. Entre elas estão a integração estruturada com plataformas de telefonia, como Voiso ou Microsip, para mensurar produtividade de contato; a implementação oficial do cálculo de comissões; a configuração operacional de alertas automáticos; e o fortalecimento de controles de acesso, como Row-Level Security no Power BI. Esses pontos estão alinhados ao roadmap descrito na Etapa 4, que trata do Plano Estratégico de TI, da auditoria, da governança e da continuidade da solução.

O mapeamento de processos e sistemas demonstra que a principal contribuição do projeto está na transformação de dados operacionais dispersos em informações gerenciais integradas. A solução BrokerLab reduz a dependência de planilhas manuais para os indicadores cobertos pelo MVP, aumenta a rastreabilidade dos cálculos e oferece uma base mais consistente para tomada de decisão na área de retenção.

## Organização da equipe de trabalho

Para o desenvolvimento do projeto, a equipe foi organizada de forma colaborativa, contemplando atividades de levantamento de requisitos, análise organizacional, modelagem de dados, desenvolvimento do pipeline, construção dos dashboards, documentação e revisão das entregas. A divisão de responsabilidades considerou as etapas do projeto e as competências necessárias para análise de negócio, engenharia de dados, Business Intelligence e governança de TI.

As principais frentes de trabalho foram:

- levantamento e documentação da empresa, mercado, processos e sistemas;
- análise das fontes de dados do CRM Dynamics 365 e da plataforma Sirix/Leverate;
- modelagem do banco analítico PostgreSQL e definição das camadas `stg_raw`, `bronze`, `silver`, `config`, `domain` e `gold`;
- construção dos scripts SQL, templates de configuração e rotinas de validação;
- desenvolvimento do modelo semântico e dashboards no Power BI;
- elaboração das etapas documentais, incluindo inteligência competitiva, requisitos informacionais, PETI, governança e auditoria de TI;
- revisão final da documentação para garantir alinhamento entre o que foi proposto, o que foi implementado no código e o que está previsto como evolução futura.

Essa organização permitiu que a entrega final refletisse tanto o diagnóstico inicial da empresa quanto a solução efetivamente implementada ao longo do projeto.
