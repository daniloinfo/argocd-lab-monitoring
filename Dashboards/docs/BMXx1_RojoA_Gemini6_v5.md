# Documentação: BMXx1_RojoA_Gemini6_v5.json

## Visão Geral
A versão **V5** (Native Grafana v9.3 V5) representa a consolidação final de todos os aprendizados na engenharia de observabilidade em larga escala ("Zero Noise"), construída do zero com arquitetura nativa para o **Grafana 9.3**. 

Ao contrário da V4 (que foi um "downgrade" adaptado a partir da V3), a **V5** incorpora a fundação definitiva para versões mais antigas do Grafana, garantindo 100% de precisão nos seletores de métricas globais e ausência de falsos "No Data" na visualização SRE.

## Funcionalidades e Performance (Standard V5)
- **Seletores Absolutos (Variáveis à prova de falha)**: As variáveis `$namespace` e `$deployment` abandonam as voláteis métricas de status e passam a buscar nas métricas estáticas do `kube-state-metrics` (`kube_namespace_created` e `kube_deployment_labels`), garantindo o mapeamento perfeito mesmo se o cluster estiver em falha massiva.
- **Fail-proof Gauges**: Gráficos Stat como "Pods Problemáticos" contam com o fallback PromQL `or vector(0)`, desenhando o desejado '0' verde na tela ao invés de exibir erro ou "No Data" quando tudo está saudável.
- **Datasources Nativos v9.3**: A injeção de `__inputs` respeita rigorosamente o formato String do Grafana v9.3, eliminando panes na hora da importação em diferentes tenants.
- **Zero Noise**: Tabelas focam apenas em ofensores `(Desejado - Disponível) > 0`, ocultando linhas sadias para manter o painel limpo.

## Como Utilizar
Esta é agora a **versão recomendada e oficial** caso seu ambiente principal não esteja rodando o Grafana 10+. Importe o JSON pelo painel principal e defina o Datasource.
