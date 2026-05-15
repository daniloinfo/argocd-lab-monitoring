# Kubernetes SRE Dashboards

Este diretório contém os dashboards oficiais de observabilidade em formato JSON, prontos para importação no Grafana. Cada dashboard foi projetado para casos de uso específicos em ambientes de produção Kubernetes.

## Catálogo de Dashboards

| Arquivo | Título no Grafana | Função Principal |
|---------|-------------------|------------------|
| [BMXx1_RojoA_Gemini6.json](./BMXx1_RojoA_Gemini6.json) | SRE - Kubernetes Cluster Upgrade Monitor Gemini 6 | Monitoramento base de operações de migração e disponibilidade (v1). |
| [BMXx1_RojoA_Gemini6_v2.json](./BMXx1_RojoA_Gemini6_v2.json) | SRE - Kubernetes Cluster Upgrade Monitor (Evoluído) | Painel avançado e otimizado para *Node Drains*, com rastreamento performático de Pods e detecção de anomalias (v2). |
| [BMXx1_RojoA_Gemini6_v3.json](./BMXx1_RojoA_Gemini6_v3.json) | SRE - Kubernetes Cluster Upgrade Monitor (Escala Massiva V3) | Foco extremo em performance "Zero Noise" (Top 10 ofensores e Tabelas Vadias se saudáveis), perfeito para clusters com milhares de recursos. |
| [BMXx1_RojoA_Gemini6_v4.json](./BMXx1_RojoA_Gemini6_v4.json) | SRE - Kubernetes Cluster Upgrade Monitor (Grafana v9.3 V4) | Clone direto da V3, mas otimizado com retrocompatibilidade para o Grafana v9.3.0 (`schemaVersion: 36`). |
| [BMXx1_RojoA_Gemini6_v5.json](./BMXx1_RojoA_Gemini6_v5.json) | SRE - Kubernetes Cluster Upgrade Monitor (Native Grafana v9.3 V5) | A versão definitiva e "à prova de falhas" (Zero Noise + `or vector(0)`) com variáveis absolutas baseadas no `kube_namespace_created` e 100% nativa para Grafana 9.3. |
| [BMXz1_BlueA_Windsurf_V1.json](./BMXz1_BlueA_Windsurf_V1.json) | SRE - Kubernetes Cluster Upgrade Monitor Windsurf V1 | Versão isolada/clonada do monitor de migrações para experimentações e uso do time Blue. |
| [BMXz1_GreenA_Gemini_V1.json](./BMXz1_GreenA_Gemini_V1.json) | Kubernetes Deployments Monitor | Tabela geral de consumo de recursos (CPU/Memory Limits & Requests) de Deployments. |
| [BMXz1_GreenA_Gemini_V2.json](./BMXz1_GreenA_Gemini_V2.json) | Kubernetes Deployments Monitor V2 | Tabela de consumo otimizada para alto desempenho, com barras visuais (Gauges) e foco em incidentes recentes (Restarts na última 1h). |

## Documentação Detalhada
Para detalhes técnicos de cada dashboard (Queries, painéis específicos, instruções de uso em incidentes), consulte o subdiretório:
👉 **[/docs](./docs/)**
