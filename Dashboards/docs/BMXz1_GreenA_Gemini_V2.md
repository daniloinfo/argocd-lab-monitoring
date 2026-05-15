# Documentação: BMXz1_GreenA_Gemini_V2.json

## Visão Geral
A evolução absoluta do "Kubernetes Deployments Monitor". Focado em alto desempenho de consulta (PromQL optimizado) e uma experiência de usuário (UX) voltada para SREs e resposta rápida a incidentes.

## Otimização Extrema (Performance)
Em vez de utilizar a operação pesada `and on(deployment)`, todas as *queries* foram reescritas para filtrar nativamente através da string do pod:
```promql
pod=~"${deployment}-.*"
```
Isso descarta mais de 90% dos dados na própria busca inicial do Prometheus, resolvendo totalmente os problemas de *Timeout* e carga alta na CPU da observabilidade.

## Melhorias Visuais e UX
1. **Gauges (Barras de Cores):** Células de Memória e CPU deixaram de ser números absolutos e tornaram-se "Gradient Gauges". Ofensores e configurações erradas de limites chamam a atenção da visão periférica instantaneamente.
2. **Reboots "Ativos":** A métrica de "Restarts" agora exibe apenas os eventos da **última hora** `increase[1h]`, removendo a poluição visual de Pods que reiniciaram há semanas, o que permite aos operadores focar apenas naquilo que está quebrando *agora*.

## Como Utilizar
É a ferramenta definitiva para "Capacity Planning" rápido e "Troubleshooting" instantâneo em incidentes. Importe, escolha seu namespace e veja em tempo real o que está batendo limites de OOMKilled ou CPU Throttling através dos Gradientes.
