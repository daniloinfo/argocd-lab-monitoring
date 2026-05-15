#!/bin/bash

# Este script valida todas as queries PromQL de um Dashboard Grafana
# testando-as diretamente contra a API do Prometheus local.

PROMETHEUS_URL="http://localhost:30090"
DASHBOARD_FILE="Dashboards/BMXx1_RojoA_Gemini6_v2.json"

echo "🔍 Validando as queries do painel $DASHBOARD_FILE no Prometheus..."
echo "Endereço do Prometheus: $PROMETHEUS_URL"
echo ""

# Verifica se o arquivo existe
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "❌ Arquivo $DASHBOARD_FILE não encontrado!"
    exit 1
fi

# Extrai as queries usando jq (ignorando nulos)
QUERIES=$(jq -r '.panels[]?.targets[]?.expr | select(. != null)' "$DASHBOARD_FILE")

if [ -z "$QUERIES" ]; then
    echo "❌ Nenhuma query PromQL encontrada no JSON."
    exit 1
fi

count=1
while IFS= read -r query; do
    echo "--------------------------------------------------"
    echo "📋 Query $count Original:"
    echo "$query"
    
    # Substitui as variáveis do Grafana por expressões regulares válidas
    # para que o Prometheus aceite a query no teste.
    # Ex: $namespace vira .*
    clean_query=$(echo "$query" | sed 's/$namespace/.*/g' | sed 's/$deployment/.*/g' | sed 's/${deployment}/.*/g')
    
    echo "🔧 Query Adaptada para Teste:"
    echo "$clean_query"
    
    # Faz o URL Encode da query para passar no cURL
    encoded_query=$(jq -nr --arg q "$clean_query" '$q|@uri')
    
    # Chama a API do Prometheus
    response=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=$encoded_query")
    
    # Verifica o status da resposta
    status=$(echo "$response" | jq -r '.status')
    
    if [ "$status" == "success" ]; then
        # Pega a quantidade de resultados retornados (opcional, só para curiosidade)
        result_count=$(echo "$response" | jq '.data.result | length')
        echo "✅ STATUS: SUCESSO! A sintaxe é válida."
        echo "📊 Séries Temporais Encontradas: $result_count"
    else
        error=$(echo "$response" | jq -r '.error')
        echo "❌ STATUS: FALHOU!"
        echo "Motivo: $error"
    fi
    count=$((count+1))
done <<< "$QUERIES"

echo "--------------------------------------------------"
echo "🏁 Validação concluída!"
