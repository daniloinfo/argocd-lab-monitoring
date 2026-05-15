# Documentação: BMXx1_RojoA_Gemini6_v2.json

## Visão Geral
Versão otimizada e evoluída do Upgrade Monitor. Projetada para clusters de alta densidade (milhares de Pods), priorizando a performance das queries, legibilidade em incidentes e prevenindo erros matemáticos ao renderizar gráficos.

## Melhorias em Relação à V1
1. **Proteção Matemática:** Uso de `> 0` no denominador das queries para evitar divisão por zero quando um *Deployment* for intencionalmente escalado para `0` réplicas.
2. **Novo Painel de Pods Problemáticos:** Um Stat Panel para identificar rapidamente qualquer Pod preso em `Pending` ou `Failed` durante a recriação.
3. **Query de Drain Otimizada:** O painel de "Migração por Node" usa regex no nível da busca do Pod (`created_by_name=~"${deployment}-.*"`), evitando junções (`joins`) pesadas no Prometheus.

## Como Utilizar
Ideal para War Rooms. Importe e selecione o Prometheus desejado. Mantenha os painéis "Pods Problemáticos" e "Indisponibilidade em Tempo Real" sempre com valores em zero. Qualquer aumento nas linhas ou números indica falha no provisionamento do Node de destino.
