# Documentação do Dashboard: SRE - Kubernetes Cluster Upgrade Monitor (Evoluído)

**Arquivo:** `BMXx1_RojoA_Gemini6_v2.json`  
**Tags:** `kubernetes`, `sre`, `drain`, `gemini-optimized`

## Visão Geral
Este dashboard foi projetado para equipes de *Site Reliability Engineering* (SRE) visando monitorar a estabilidade de aplicações durante operações críticas em clusters Kubernetes, como atualizações de versão (Upgrades) e esvaziamento de nós (*Node Drains*).

A versão **v2** foi evoluída para suportar clusters de produção de alta densidade (milhares de Pods), priorizando a performance das queries, melhor legibilidade e prevenindo erros matemáticos ao renderizar gráficos.

## Pré-requisitos
1. **Prometheus** (configurado como *Datasource* no Grafana).
2. **kube-state-metrics** (instalado no cluster e sendo raspado pelo Prometheus). O dashboard depende exclusivamente de métricas padrão do control plane (`kube_deployment_*` e `kube_pod_*`).

## Funcionalidade de Importação Dinâmica
A arquitetura do JSON utiliza variáveis de entrada (`__inputs`). Ao importar o arquivo no Grafana, o sistema exibirá uma interface solicitando que o usuário selecione a instância correta do Prometheus. 
Isso elimina referências fixas (UIDs *hardcoded*) e garante a portabilidade do painel entre diferentes ambientes (Dev, Staging, Produção).

---

## Variáveis (Templating)
O painel trabalha com variáveis dinâmicas encadeadas no topo da tela:
- **`namespace`**: Exibe os *namespaces* do cluster.
- **`deployment`**: Lista de *deployments* pertencentes de forma exclusiva ao *namespace* selecionado (reduz poluição visual).

---

## Estrutura dos Painéis

### 1. Disponibilidade Global de Deployments (%)
- **Tipo:** Stat Panel
- **Métrica Base:** `kube_deployment_status_replicas_available` vs `kube_deployment_spec_replicas`.
- **Diferencial:** Possui uma lógica de proteção matemática (`> 0` no denominador) para evitar divisões por zero (que causariam erros *NaN*/*Infinity* visuais) se um *Deployment* for intencionalmente escalado para `0` réplicas.
- **Comportamento:** Verde (100%), Laranja (80-99%) e Vermelho (< 80%).

### 2. Pods Problemáticos (Pending / Failed)
- **Tipo:** Stat Panel
- **Métrica Base:** `kube_pod_status_phase`
- **Diferencial:** Uma *query* extremamente leve que consolida Pods que estão travados nas fases `Pending`, `Failed` ou `Unknown`. Trata-se do alarme mais rápido para detectar falta de recursos de CPU/Memória em um novo Nó ou falhas de `ImagePullBackOff`.

### 3. Saúde dos Deployments (Desejado vs Disponível)
- **Tipo:** Tabela Analítica
- **Diferencial:** Utiliza as ferramentas internas de *Transformations* do Grafana (e não queries complexas do Prometheus) para calcular um campo chamado `Status Check`.
- **Indicadores:**
  - `OK` (Verde): Réplicas atuais equivalem às desejadas.
  - `CRÍTICO` (Vermelho): Déficit de réplicas (Available < Desired).
  - `FALHA` (Vermelho escuro): Ausência total de dados do serviço.

### 4. Indisponibilidade em Tempo Real (> 0)
- **Tipo:** Time Series (Gráfico de Linhas)
- **Diferencial:** Foca na anomalia. Mostra o déficit histórico de réplicas ao longo do tempo. Se a linha registrar picos acima do eixo 0, indica que houve instabilidade em *Deployments* (comportamento temporário tolerável durante a substituição rápida de *Pods* no processo de *Drain*).

### 5. Migração de Pods por Node (Drain Visível)
- **Tipo:** Time Series (Área Sobreposta)
- **Métrica Base:** `kube_pod_info`
- **Diferencial:** É o painel principal de visualização de operação de *Drain*. A distribuição de Pods é agrupada por Nó (`node`). 
- **Desempenho:** Na versão v2, a associação dos Pods ao *Deployment* selecionado no filtro é feita via RegEx nativo (`created_by_name=~"${deployment}-.*"`), evitando o uso pesado de *Metric Joins* no Prometheus, resultando em carregamento instantâneo da tela. Ao realizar o esvaziamento de um nó, o operador verá a linha da cor correspondente ao Nó "A" caindo abruptamente, enquanto a do Nó "B" sobe recebendo o tráfego.
