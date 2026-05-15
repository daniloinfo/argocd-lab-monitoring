# Documentação: BMXx1_RojoA_Gemini6_v4.json

## Visão Geral
A versão **V4** é um clone direto da versão **V3** (Foco em Escala Massiva e *Zero Noise*), mas construída especificamente com retrocompatibilidade para o **Grafana v9.3.0**. 
Isto significa que o `schemaVersion` foi rebaixado e as versões dos plugins foram ajustadas, evitando erros de incompatibilidade no momento da importação em clusters que utilizam infraestrutura mais legada.

## Funcionalidades e Performance
Esta versão herda 100% das evoluções de performance da V3:
- Tabela de "Saúde dos Deployments" reativa (Zero Noise - Oculta a linha se estiver sadio).
- Migração de Pods otimizada com `topk(15)`.
- Variável de `$node` para isolar a visão do *Drain*.

## Como Utilizar
Utilize este arquivo se o seu ambiente principal estiver rodando uma versão do Grafana anterior à 10.x. Basta importar o painel e vincular o Datasource.
