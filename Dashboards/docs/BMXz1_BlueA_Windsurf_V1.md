# Documentação: BMXz1_BlueA_Windsurf_V1.json

## Visão Geral
Um clone experimental do "Kubernetes Cluster Upgrade Monitor" (versão V1), separado estruturalmente para garantir isolamento e permitir modificações livres pela equipe Blue sem impactar os dashboards principais do SRE.

## Funcionalidades
Mantém os exatos painéis da versão original V1:
- Saúde de Deployments (Tabela desejado vs disponível).
- Gráfico de Migração de Pods por Node.
- Indisponibilidade em Tempo Real (> 0).

## Como Utilizar
Utilize este painel caso deseje testar novas queries de métricas Kube-State-Metrics ou modificar o comportamento gráfico de migrações sem correr o risco de quebrar o painel de produção. Ele já suporta importação dinâmica pedindo o Datasource.
