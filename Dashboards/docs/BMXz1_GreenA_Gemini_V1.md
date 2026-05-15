# Documentação: BMXz1_GreenA_Gemini_V1.json

## Visão Geral
Tabela gerencial focada no consumo e configuração de recursos (CPU e Memória) de todos os Deployments no Cluster, baseada fortemente na leitura das labels de pods vs limits definidos no YAML.

## Funcionalidades Principais
Exibe uma tabela consolidada contendo:
- CPU Request
- CPU Limit
- Memory Request
- Memory Limit
- Reboots (Restarts Totais)

## Gargalos Conhecidos (Motivo da V2)
As *queries* neste painel usam `label_replace` indiscriminado em toda a base de Pods para fazer um `JOIN` massivo via `and on(deployment, namespace)`. Em clusters grandes, este Dashboard pode apresentar **Timeouts**, pois obriga o Prometheus a cruzar milhões de linhas de dados antes de aplicar os filtros do Grafana.

Recomenda-se migrar os usuários para a **V2**.
