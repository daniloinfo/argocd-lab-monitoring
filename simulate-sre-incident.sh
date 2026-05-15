#!/bin/bash

# Script de simulação para os painéis:
# 1. Indisponibilidade em Tempo Real
# 2. Migração de Pods por Node (Drain Visível)

CLUSTER_CONTEXT="kind-argocd-lab"
NAMESPACE="sre-simulacao"

echo "=========================================================="
echo "🚀 Iniciando Simulação SRE para o Dashboard V2"
echo "=========================================================="

# 1. Prepara o namespace
kubectl --context $CLUSTER_CONTEXT create namespace $NAMESPACE --dry-run=client -o yaml | kubectl --context $CLUSTER_CONTEXT apply -f -

# 2. Cria Deployment Saudável (Para vermos a Migração)
echo "📦 Criando Deployment 'app-migracao' com 20 réplicas..."
cat <<EOF | kubectl --context $CLUSTER_CONTEXT apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-migracao
  namespace: $NAMESPACE
  labels:
    app: app-migracao
spec:
  replicas: 20
  selector:
    matchLabels:
      app: app-migracao
  template:
    metadata:
      labels:
        app: app-migracao
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        resources:
          requests:
            cpu: "5m"
            memory: "15Mi"
EOF

# 3. Cria Deployment Indisponível (Para disparar a Indisponibilidade)
# Solicitando 999 CPUs vai forçar os Pods a ficarem presos em "Pending" eternamente.
echo "🔥 Criando Deployment 'app-indisponivel' (Preso em Pending)..."
cat <<EOF | kubectl --context $CLUSTER_CONTEXT apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-indisponivel
  namespace: $NAMESPACE
  labels:
    app: app-indisponivel
spec:
  replicas: 5
  selector:
    matchLabels:
      app: app-indisponivel
  template:
    metadata:
      labels:
        app: app-indisponivel
    spec:
      containers:
      - name: bug
        image: nginx:alpine
        resources:
          requests:
            cpu: "999" # Impossível de alocar
EOF

echo "⏳ Aguardando os Pods do 'app-migracao' ficarem prontos (Running)..."
kubectl --context $CLUSTER_CONTEXT rollout status deployment/app-migracao -n $NAMESPACE --timeout=90s || true

echo ""
echo "=========================================================="
echo "✅ Cenário montado!"
echo "👉 PASSO 1: Abra o Grafana no dashboard 'BMXx1_RojoA_Gemini6_v2'"
echo "👉 PASSO 2: No topo, selecione a variável namespace = $NAMESPACE"
echo "👀 Observe o painel 'Indisponibilidade em Tempo Real (> 0)'. Ele já deve estar acusando as 5 réplicas do app-indisponivel que não conseguem subir!"
echo "=========================================================="
read -p "Pressione [ENTER] quando estiver com o Grafana aberto olhando para a tela..."

# 4. Encontra um Node Worker para fazer o Drain
WORKER_NODE=$(kubectl --context $CLUSTER_CONTEXT get nodes | grep worker | head -n 1 | awk '{print $1}')

if [ -z "$WORKER_NODE" ]; then
    echo "❌ Nenhum worker node encontrado para simular o Drain!"
    exit 1
fi

echo ""
echo "🚨 ATENÇÃO: Iniciando o DRAIN no node '$WORKER_NODE' agora!"
echo "👀 OLHE PARA O PAINEL 'Migração de Pods por Node (Drain)' NO GRAFANA!"
echo "Você verá a linha deste node caindo e a linha de outro node subindo!"
echo ""

kubectl --context $CLUSTER_CONTEXT drain $WORKER_NODE --ignore-daemonsets --delete-emptydir-data --force

echo ""
echo "=========================================================="
echo "✅ Drain concluído. Os pods 'fugiram' desse node e foram para outro."
echo "Você deve ter visto a dança das linhas no gráfico!"
echo "=========================================================="
read -p "Pressione [ENTER] para devolver o Node ao cluster (Uncordon) e limpar a simulação..."

# 5. Limpeza
echo "♻️ Devolvendo o node $WORKER_NODE ao cluster..."
kubectl --context $CLUSTER_CONTEXT uncordon $WORKER_NODE

echo "🧹 Removendo o namespace da simulação ($NAMESPACE)..."
kubectl --context $CLUSTER_CONTEXT delete namespace $NAMESPACE

echo "🎉 Simulação finalizada!"
