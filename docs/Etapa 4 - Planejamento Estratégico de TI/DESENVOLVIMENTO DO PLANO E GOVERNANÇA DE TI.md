# **4\. DESENVOLVIMENTO DO PLANO E GOVERNANÇA DE TI**

## **4.1 Peti (Plano Estratégico de Tecnologia da Informação)**

### **4.1.1 Finalidade do PETI**

Dar continuidade ao uso estratégico da TI na empresa, consolidando a cultura de tomada de decisões baseada em dados (*data-driven*) para maximizar o faturamento da corretora, otimizar a performance da mesa de traders e garantir a retenção e conversão de clientes.

### **4.1.2 Pontos Fortes e Limitações do Sistema/BI**

* **Pontos Fortes:** Centralização das bases do CRM (dados cadastrais) e Sirix (transações em tempo real); transparência total na auditoria de metas e comissões dos traders; facilidade em identificar gargalos operacionais e comportamento de ativos.  
* **Limitações:** Modelo de monitoramento passivo (depende do gestor abrir o dashboard para ver os dados); riscos de latência ou perda de sincronização se as APIs entre CRM e Sirix falharem.

### **4.1.3 Diretrizes Estratégicas de TI**

* **Monitoramento Frequente de Qualidade de Dados e Governança:** Implementação de uma rotina de checagem para garantir a consistência contínua entre o CRM e o Sirix. Isso evita duplicidades, atrasos na atualização de depósitos e falhas de atribuição, assegurando que a liderança tome decisões com base em dados 100% confiáveis e auditados. 

### **4.1.4 Objetivos Estratégicos de TI**

* **Curto Prazo (0 a 6 meses):** Estabilizar 100% a sincronização de dados CRM-Sirix e garantir a adoção completa da ferramenta pela gerência.  
* **Médio Prazo (6 a 12 meses):** Desenvolver o módulo de cálculo automatizado de comissões e homologar os primeiros alertas automáticos de ausência de depósitos.  
* **Longo Prazo (1 a 2 anos):** Evoluir o BI para uma plataforma preditiva e integrá-lo a novas fontes de dados ou plataformas de trading que a corretora venha a adotar.

###  **4.1.5 Indicadores de Acompanhamento**

* **Número de usuários ativos:** Adoção diária do dashboard pela gerência da corretora.  
* **Frequência de uso do sistema:** Quantas vezes ao dia as métricas são consultadas para tomada de decisão na mesa.  
* **Redução de perdas operacionais:** Diminuição do tempo de reação para salvar um cliente que parou de depositar.  
* **Tempo de resposta a decisões:** Velocidade em aplicar feedbacks ou remanejar carteiras de traders com baixa performance.

---

## **4.2 Auditoria e Governança de TI** 

### **4.2.1 Segurança e Proteção de Dados**

* **Tratamento de Dados Pessoais (LGPD):** A corretora lida com dados financeiros e cadastrais sensíveis. O acesso aos dados dos clientes (CRM) e ao histórico de operações (Sirix) fica restrito ao ambiente do dashboard. É proibida a exportação de relatórios em Excel contendo dados pessoais de clientes para dispositivos particulares de traders ou colaboradores.  
* **Controle de Acesso ao Sistema:** O acesso ao dashboard é estritamente controlado. Traders/Agentes possuem acesso exclusivo aos dados de sua própria carteira. Apenas os gestores de mesa e diretores possuem credenciais administrativas para visualizar a performance geral (*"dedo duro"*), metas e comissões de toda a equipe.

### **4.2.2 Práticas Recomendadas de Segurança**

**Gestão de Senhas e Credenciais:**

* As senhas de leitura dos bancos on-premises (*Sirix* e *Dynamics*) e a senha mestra do PostgreSQL devem ter no mínimo 16 caracteres, misturando letras, números e símbolos.    
* **Armazenamento Seguro:** As planilhas de configuração serão armazenadas no OneDrive corporativo, garantindo histórico de versões automático (caso alguém apague uma meta ou altere um domínio por erro).
### **4.2.3 Continuidade e Controle** 

* **Backup Periódico:** Configuração de backup automatizado e semanal de toda a base histórica que alimenta o dashboard (dados consolidados do CRM e relatórios de trading).  
* **Plano de Reação Rápida:** Caso o dashboard fique fora do ar durante o horário de pregão, os gestores utilizarão temporariamente os relatórios nativos e diretos das plataformas Sirix e CRM.  
* **Registro de Mudanças:** Criação de um histórico simples (uma planilha interna da TI) para registrar toda e qualquer alteração estrutural feita no dashboard ou nas regras de cálculo de comissões, evitando que atualizações quebrem o sistema sem que se saiba o motivo.

###   **4.2.4 Responsabilidades**

* **Administrador Principal (Dono do Pipeline):** Um profissional de dados (ou gestor técnico indicado) será o único com acesso de escrita/alteração nos scripts SQL estruturais, tabelas stg\_raw até gold e publicação de novas versões do Power BI.  
* **Co-administrador (Backup Técnico):** Uma segunda pessoa de confiança (ex: o Diretor de Operações ou um analista sênior) deve possuir as credenciais de emergência guardadas no gerenciador de senhas para o caso de ausência do administrador principal.  
* **Usuários de Negócio (Agentes e Operação):** Possuem acesso estrito de visualização no Power BI. Não editam relatórios, não alteram as planilhas base e não acessam o banco PostgreSQL.


### **4.2.5 Governança Simplificada e Boas Práticas**

* **Regras de Uso:** O dashboard deve ser utilizado exclusivamente para fins de auditoria de performance e planejamento comercial, sendo vedada a alteração manual de indicadores sem validação da diretoria.  
* **Avaliação Periódica:** A cada 6 meses, a diretoria se reunirá com os gestores para avaliar se o dashboard continua cumprindo sua função, se os indicadores de depósitos e performance ainda fazem sentido para a estratégia do negócio e se há necessidade de novas implementações.

