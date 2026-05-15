# Kubernetes SRE Dashboards

Este diretório contém os dashboards oficiais de observabilidade em formato JSON, prontos para importação no Grafana. Cada dashboard foi projetado para casos de uso específicos em ambientes de produção Kubernetes.

## Catálogo de Dashboards

| Arquivo | Título no Grafana | Função Principal |
|---------|-------------------|------------------|
| [BMXx1_RojoA_Gemini6.json](./BMXx1_RojoA_Gemini6.json) | SRE - Kubernetes Cluster Upgrade Monitor Gemini 6 | Monitoramento base de operações de migração e disponibilidade (v1). |
| [BMXx1_RojoA_Gemini6_v2.json](./BMXx1_RojoA_Gemini6_v2.json) | SRE - Kubernetes Cluster Upgrade Monitor (Evoluído) | Painel avançado e otimizado para *Node Drains*, com rastreamento performático de Pods e detecção de anomalias (v2). |
| [BMXz1_BlueA_Windsurf_V1.json](./BMXz1_BlueA_Windsurf_V1.json) | SRE - Kubernetes Cluster Upgrade Monitor Windsurf V1 | Versão isolada/clonada do monitor de migrações para experimentações e uso do time Blue. |
| [BMXz1_GreenA_Gemini_V1.json](./BMXz1_GreenA_Gemini_V1.json) | Kubernetes Deployments Monitor | Tabela geral de consumo de recursos (CPU/Memory Limits & Requests) de Deployments. |
| [BMXz1_GreenA_Gemini_V2.json](./BMXz1_GreenA_Gemini_V2.json) | Kubernetes Deployments Monitor V2 | Tabela de consumo otimizada para alto desempenho, com barras visuais (Gauges) e foco em incidentes recentes (Restarts na última 1h). |

## Documentação Detalhada
Para detalhes técnicos de cada dashboard (Queries, painéis específicos, instruções de uso em incidentes), consulte o subdiretório:
👉 **[/docs](./docs/)**
