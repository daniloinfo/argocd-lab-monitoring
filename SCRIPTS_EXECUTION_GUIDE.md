# Scripts Execution Guide - Argo CD Lab

Este guia completo documenta todos os scripts disponíveis no projeto e como executá-los para análise de performance, identificação de pods e monitoramento.

## 📋 Índice

1. [Visão Geral dos Scripts](#visão-geral-dos-scripts)
2. [Pré-requisitos](#pré-requisitos)
3. [Scripts de Identificação de Pods](#scripts-de-identificação-de-pods)
4. [Scripts de Análise de Performance](#scripts-de-análise-de-performance)
5. [Scripts de Testes de Carga](#scripts-de-testes-de-carga)
6. [Exemplos de Uso](#exemplos-de-uso)
7. [Troubleshooting](#troubleshooting)
8. [Integração e Automação](#integração-e-automatização)

---

## 🎯 Visão Geral dos Scripts

### Scripts Disponíveis

| Script | Função | Linguagem | Status |
|--------|--------|-----------|---------|
| `pod-type-detector.sh` | Identificação de tipo de pod (Quarkus vs Spring Boot) | Bash | ✅ Funcional |
| `performance-simple.sh` | Análise básica de performance | Bash | ✅ Funcional |
| `performance-analyzer-fixed.sh` | Análise completa com k6 | Bash | ✅ Funcional |
| `k6-load-test.js` | Testes de carga com k6 | JavaScript | ✅ Funcional |
| `resource_analyzer.py` | Análise avançada de recursos | Python | ✅ Funcional |

---

## 🔧 Pré-requisitos

### Ferramentas Necessárias

```bash
# Verificar instalações
kubectl version --client
k6 version
python3 --version
jq --version
```

### Configuração do Cluster

```bash
# Verificar contexto atual
kubectl config current-context

# Verificar namespaces
kubectl get namespaces

# Verificar pods no namespace applications
kubectl get pods -n applications
```

### Metrics-Server (Obrigatório para métricas reais)

```bash
# Instalar metrics-server para clusters Kind
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Para clusters Kind com problemas de TLS:
kubectl apply -f metrics-server-fixed.yaml

# Verificar status
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=60s

# Testar métricas
kubectl top pod -n applications
```

---

## 🔍 Scripts de Identificação de Pods

### pod-type-detector.sh

Identifica se um pod está rodando Quarkus ou Spring Boot usando múltiplos métodos de detecção.

#### Uso Básico

```bash
# Identificar pod específico
./scripts/pod-type-detector.sh quarkus-demo-55f7d5f4b9-jlbhf

# Analisar todos os pods
./scripts/pod-type-detector.sh --all

# Namespace personalizado
./scripts/pod-type-detector.sh -n monitoring --all
```

#### Opções Avançadas

| Opção | Descrição | Padrão |
|-------|-----------|---------|
| `-n, --namespace` | Namespace específico | `applications` |
| `-v, --verbose` | Modo verboso | `false` |
| `-a, --all` | Analisar todos os pods | `false` |
| `-h, --help` | Ajuda completa | - |

#### Exemplos Práticos

```bash
# Modo verboso para debugging
./scripts/pod-type-detector.sh -v quarkus-demo-55f7d5f4b9-jlbhf

# Análise completa com todos os pods
./scripts/pod-type-detector.sh --all

# Namespace diferente
./scripts/pod-type-detector.sh -n argocd --all
```

#### Métodos de Detecção

1. **Labels e Annotations** (Alta confiança)
2. **Nome da Imagem** (Alta confiança)
3. **Variáveis de Ambiente** (Média confiança)

---

## 📊 Scripts de Análise de Performance

### performance-simple.sh

Análise básica de performance com métricas reais ou estimadas.

#### Uso Básico

```bash
# Executar análise completa
./scripts/performance-simple.sh
```

#### Funcionalidades

- ✅ Detecção automática do metrics-server
- ✅ Métricas reais quando disponível
- ✅ Estimativas quando metrics-server não disponível
- ✅ Relatório HTML completo
- ✅ Recomendações de otimização

#### Saída Esperada

```
[INFO] Starting performance analysis with fixed resource usage...
[INFO] Metrics-server is available - using real resource usage
[INFO] Found pods: quarkus-demo-55f7d5f4b9-jlbhf quarkus-demo-55f7d5f4b9-mj2n5 springboot-demo-86b9b74bc8-kwhfn springboot-demo-86b9b74bc8-wxd2p
[INFO] HTML report generated: performance-reports/performance-fixed-20260505-112712.html
[INFO] Analysis completed successfully!

Performance Analysis Results:
HTML Report: performance-reports/performance-fixed-20260505-112712.html
Resource Usage Status:
✓ Real metrics from metrics-server
```

### performance-analyzer-fixed.sh

Análise completa com testes de carga k6 e relatórios detalhados.

#### Uso Básico

```bash
# Análise completa com testes de carga
./scripts/performance-analyzer-fixed.sh

# Apenas análise (sem testes de carga)
./scripts/performance-analyzer-fixed.sh --skip-load-test

# Parâmetros personalizados
./scripts/performance-analyzer-fixed.sh -n applications -d 60s -vus 20
```

#### Opções Completas

| Opção | Descrição | Padrão |
|-------|-----------|---------|
| `-n, --namespace` | Namespace específico | `applications` |
| `-o, --output-dir` | Diretório de saída | `performance-reports` |
| `-d, --duration` | Duração do teste de carga | `30s` |
| `-v, --vus` | Número de usuários virtuais | `10` |
| `-s, --skip-load-test` | Pular testes de carga | `false` |
| `-v, --verbose` | Modo verboso | `false` |

#### Exemplos Avançados

```bash
# Teste de carga intenso
./scripts/performance-analyzer-fixed.sh -d 120s -vus 50

# Análise apenas (sem carga)
./scripts/performance-analyzer-fixed.sh --skip-load-test

# Namespace customizado
./scripts/performance-analyzer-fixed.sh -n production -d 60s -vus 30

# Saída personalizada
./scripts/performance-analyzer-fixed.sh -o /tmp/reports -v
```

---

## ⚡ Scripts de Testes de Carga

### k6-load-test.js

Script k6 para testes de carga das aplicações.

#### Configuração

```javascript
// Configuração de estágios
export let options = {
    stages: [
        { duration: '10s', target: __ENV.VUS || 10 },
        { duration: __ENV.DURATION || '30s', target: __ENV.VUS || 10 },
        { duration: '10s', target: 0 },
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'],
        http_req_failed: ['rate<0.1'],
    },
};
```

#### Endpoints Testados

- `http://localhost:8081/actuator/health`
- `http://localhost:8081/actuator/info`
- `http://localhost:8081/hello`
- `http://localhost:8082/actuator/health`
- `http://localhost:8082/actuator/info`
- `http://localhost:8082/hello`

#### Execução Manual

```bash
# Executar com parâmetros personalizados
VUS=20 DURATION=60s k6 run --summary-export results.json scripts/k6-load-test.js

# Execução básica
k6 run scripts/k6-load-test.js
```

---

## 🚀 Exemplos de Uso

### Cenário 1: Análise Completa de Performance

```bash
# 1. Verificar status do cluster
kubectl get pods -n applications

# 2. Executar análise completa
./scripts/performance-analyzer-fixed.sh

# 3. Verificar relatório gerado
ls -la performance-reports/
```

### Cenário 2: Identificação Rápida de Pods

```bash
# Identificar todos os pods
./scripts/pod-type-detector.sh --all

# Verificar pod específico
./scripts/pod-type-detector.sh -v pod-name

# Exportar para JSON
./scripts/pod-type-detector.sh --all -o json > pod-types.json
```

### Cenário 3: Monitoramento Contínuo

```bash
#!/bin/bash
# monitoramento-continuo.sh

NAMESPACE="applications"
INTERVAL=300  # 5 minutos

while true; do
    echo "$(date): Iniciando análise de performance..."
    ./scripts/performance-analyzer-fixed.sh --skip-load-test
    
    echo "$(date): Aguardando $INTERVAL segundos..."
    sleep $INTERVAL
done
```

### Cenário 4: Relatórios Agendados

```bash
#!/bin/bash
# relatorio-diario.sh

DATE=$(date +%Y%m%d)
REPORT_DIR="daily-reports/$DATE"

mkdir -p "$REPORT_DIR"

echo "Gerando relatório diário: $DATE"
./scripts/performance-analyzer-fixed.sh -o "$REPORT_DIR"

# Enviar relatório (opcional)
# mail -s "Relatório Performance $DATE" admin@example.com < "$REPORT_DIR"/*.html
```

---

## 🔧 Troubleshooting

### Problemas Comuns

#### 1. Metrics-Server Não Disponível

```bash
# Verificar status
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Verificar logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# Reinstalar
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

#### 2. Pods Não Encontrados

```bash
# Verificar namespace atual
kubectl config view --minify --output 'jsonpath={..namespace}'

# Listar todos os namespaces
kubectl get namespaces

# Verificar pods no namespace correto
kubectl get pods -n applications
```

#### 3. Erros de Permissão

```bash
# Verificar permissões RBAC
kubectl auth can-i get pods --namespace=applications
kubectl auth can-i top pods --namespace=applications

# Verificar service account
kubectl get serviceaccount
```

#### 4. Problemas de Rede

```bash
# Verificar conectividade
kubectl port-forward -n applications svc/quarkus-demo-service 8081:8080
kubectl port-forward -n applications svc/springboot-demo-service 8082:8080

# Testar endpoints
curl http://localhost:8081/actuator/health
curl http://localhost:8082/actuator/health
```

### Debug Mode

```bash
# Modo verboso para pod identification
./scripts/pod-type-detector.sh -v pod-name

# Debug de performance
./scripts/performance-analyzer-fixed.sh -v --skip-load-test

# Verificar logs completos
kubectl logs -n applications pod-name
```

---

## 🔄 Integração e Automação

### Integração com Monitoring

```bash
# Criar dashboard data
./scripts/identify-pod-type.sh -n applications --all -o json > pod-types.json

# Processar resultados
jq '.[] | select(.type == "Quarkus")' pod-types.json
jq '.[] | select(.type == "Spring Boot")' pod-types.json
```

### Scripts de Automação

#### Análise Automatizada

```bash
#!/bin/bash
# auto-analysis.sh

NAMESPACE="applications"
OUTPUT_DIR="automated-reports/$(date +%Y%m%d)"

mkdir -p "$OUTPUT_DIR"

# 1. Identificar tipos de pods
echo "Identificando tipos de pods..."
./scripts/pod-type-detector.sh -n "$NAMESPACE" --all -o json > "$OUTPUT_DIR/pod-types.json"

# 2. Análise de performance
echo "Analisando performance..."
./scripts/performance-analyzer-fixed.sh -n "$NAMESPACE" -o "$OUTPUT_DIR" --skip-load-test

# 3. Gerar resumo
echo "Gerando resumo..."
echo "Análise completada em $(date)" > "$OUTPUT_DIR/summary.txt"
echo "Pods analisados: $(jq length "$OUTPUT_DIR/pod-types.json")" >> "$OUTPUT_DIR/summary.txt"
echo "Relatório HTML: $(ls "$OUTPUT_DIR"/*.html)" >> "$OUTPUT_DIR/summary.txt"

echo "Análise automatizada concluída!"
```

#### Monitoramento de Saúde

```bash
#!/bin/bash
# health-check.sh

NAMESPACE="applications"
ALERT_THRESHOLD=80

# Verificar saúde dos pods
pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

for pod in $pods; do
    status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    
    if [ "$status" != "Running" ]; then
        echo "ALERTA: Pod $pod está com status $status"
    fi
    
    # Verificar uso de recursos
    if kubectl top pod "$pod" -n "$NAMESPACE" &>/dev/null; then
        cpu_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers | awk '{print $2}')
        memory_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers | awk '{print $3}')
        
        echo "Pod $pod: CPU=$cpu_usage, Memory=$memory_usage"
    fi
done
```

### Integração CI/CD

#### GitHub Actions Example

```yaml
name: Performance Analysis

on:
  schedule:
    - cron: '0 */6 * * *'  # A cada 6 horas
  workflow_dispatch:

jobs:
  performance-analysis:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup k6
      run: |
        sudo gpg -k /etc/apt/trusted.gpg.d/
        sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
        echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
        sudo apt-get update
        sudo apt-get install k6
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v1
      with:
        version: 'v1.24.0'
    
    - name: Run Performance Analysis
      run: |
        chmod +x scripts/*.sh
        ./scripts/performance-analyzer-fixed.sh --skip-load-test
    
    - name: Upload Reports
      uses: actions/upload-artifact@v2
      with:
        name: performance-reports
        path: performance-reports/
```

---

## 📈 Métricas e KPIs

### Métricas Coletadas

#### CPU
- **Uso atual**: Em millicores (m)
- **Request**: Configurado no deployment
- **Limit**: Configurado no deployment
- **Eficiência**: Uso / Request

#### Memory
- **Uso atual**: Em MiB
- **Request**: Configurado no deployment
- **Limit**: Configurado no deployment
- **Eficiência**: Uso / Request

#### Status
- **Pod Status**: Running, Pending, Failed
- **Pod Type**: Quarkus, Spring Boot, Unknown
- **Restarts**: Número de restarts

### KPIs Importantes

1. **CPU Efficiency**: < 80% é bom
2. **Memory Efficiency**: < 85% é bom
3. **Pod Health**: 100% Running é ideal
4. **Resource Utilization**: 60-80% dos requests

---

## 🎯 Best Practices

### Execução de Scripts

1. **Sempre verificar namespace** antes de executar
2. **Usar modo verboso** para debugging
3. **Verificar metrics-server** para métricas reais
4. **Monitorar recursos** durante testes de carga
5. **Salvar relatórios** para análise histórica

### Performance

1. **Executar em horários de baixo uso** para testes de carga
2. **Monitorar cluster health** durante análise
3. **Usar limites adequados** para não sobrecarregar
4. **Documentar resultados** para comparação

### Segurança

1. **Não expor credenciais** em scripts
2. **Usar RBAC apropriado** para permissões
3. **Validar inputs** em scripts automatizados
4. **Auditar execuções** regularmente

---

## 📞 Suporte

### Ajuda Rápida

```bash
# Ajuda dos scripts
./scripts/pod-type-detector.sh --help
./scripts/performance-analyzer-fixed.sh --help

# Verificar status geral
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
```

### Contato e Documentação

- **Documentação completa**: Ver arquivos `README.md` em cada diretório
- **Relatórios gerados**: `performance-reports/`
- **Logs de execução`: Ver output dos scripts
- **Issues**: Criar issues no repositório do projeto

---

## 📝 Histórico de Mudanças

| Versão | Data | Mudanças |
|--------|------|----------|
| 1.0.0 | 2024-05-05 | Scripts iniciais de identificação e performance |
| 1.1.0 | 2024-05-05 | Correção do metrics-server para clusters Kind |
| 1.2.0 | 2024-05-05 | Adição de testes de carga k6 e relatórios HTML |

---

**Guia completo criado para facilitar o uso e automação dos scripts de análise do Argo CD Lab!** 🚀
