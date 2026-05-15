# Documentação: BMXx1_RojoA_Gemini6_v3.json

## Visão Geral
Este é o painel supremo (V3) para acompanhamento de incidentes e Drain de Nodes focado inteiramente em **clusters de escala massiva** (ex: milhares de pods, 50+ nodes). 
Ele adota o princípio de design de interface conhecido como "Zero Noise", ocultando informações de sistemas saudáveis e forçando a visão do operador estritamente aos componentes afetados.

## Funcionalidades de Larga Escala (V3 Features)
- **Tabela "Zero Noise":** Ao invés de listar centenas de deployments ocupando toda a tela, a tabela usa a cláusula `and (...) > 0` no PromQL para suprimir os dados saudáveis. Se tudo estiver bem, a tabela ficará vazia. Só aparecerão nela os deployments que não atingiram a contagem de réplicas desejada.
- **Top 15 Nodes & Anti-Spaghetti:** O gráfico de migração de Drain aplica a função `topk(15, ...)` no Prometheus para mostrar apenas os nós com maior densidade de impacto, impedindo a plotagem simultânea de dezenas de linhas que causariam confusão.
- **Variável de Filtro `$node`:** Se for realizar um drain específico e quiser isolar o gráfico apenas para o nó de origem e de destino, basta selecionar os nomes na variável "Node" no menu superior.
- **Legendas Laterais (Tabelas):** Devido à alta densidade de nomes, as legendas dos gráficos de tempo foram movidas para a lateral direita como tabelas ordenáveis, agilizando a leitura de onde os pods estão caindo.

## Como Utilizar
Em situações normais do dia a dia, use a versão V2 ou o Monitor Verde. A **V3** foi projetada para *War Rooms* intensas em grandes topologias, pois ela reage com o "foco laser" escondendo a fumaça desnecessária. Selecione a fonte do Prometheus no import e pronto.
