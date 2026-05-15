# Documentação: BMXx1_RojoA_Gemini6.json

## Visão Geral
Dashboard voltado para operações SRE de migração, como `kubectl drain` ou atualizações de cluster Kubernetes. Ele mapeia a disponibilidade e as migrações dos pods entre os Nodes.

## Funcionalidades Principais
- **Global Availability**: Monitora a disponibilidade global cruzando réplicas desejadas x disponíveis.
- **Node Migration Tracking**: Mostra para onde os pods estão migrando em tempo real durante um esvaziamento de Node.

## Como Utilizar
Importe no Grafana usando a injeção de Datasource e filtre pelo `namespace` e `deployment` nas variáveis do topo. Acompanhe a tela durante a manutenção do nó.

## Ponto de Atenção
Esta é a versão V1. Ela possui cálculos de query que podem apresentar sobrecarga ou erros de divisão por zero (`NaN`) caso os deployments sejam escalados para zero. Para ambientes mais pesados, prefira utilizar a versão **V2**.
