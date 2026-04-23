# Installation Guide - Argo CD Lab with Complete Monitoring Stack

This document contains the exact steps used to successfully install the Argo CD lab with comprehensive monitoring stack using Kind.

## Prerequisites

- Docker installed and running
- kubectl installed
- helm installed
- Kind installed

## Step 1: Create Kind Cluster Configuration

Create `kind-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: argocd-lab
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30443
    hostPort: 30443
    protocol: TCP
  - containerPort: 30090
    hostPort: 30090
    protocol: TCP
  - containerPort: 30100
    hostPort: 30100
    protocol: TCP
  - containerPort: 30111
    hostPort: 30111
    protocol: TCP
  - containerPort: 30120
    hostPort: 30120
    protocol: TCP
  - containerPort: 30140
    hostPort: 30140
    protocol: TCP
  - containerPort: 30150
    hostPort: 30150
    protocol: TCP
```

## Step 2: Create Kind Cluster

```bash
kind create cluster --config kind-config.yaml
kubectl cluster-info --context kind-argocd-lab
```

## Step 3: Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.0/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":8080,"nodePort":30080},{"name":"https","port":443,"targetPort":8080,"nodePort":30443}]}}'
```

## Step 4: Add Helm Repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add grafana-alloy https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

## Step 5: Create Monitoring Namespace

```bash
kubectl create namespace monitoring
```

## Step 6: Install Prometheus and Grafana Stack

```bash
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30100 \
  --set grafana.defaultDatasources.enabled=false \
  --set grafana.sidecar.datasources.enabled=false
```

## Step 7: Install Loki Stack

```bash
helm install loki grafana/loki-stack --namespace monitoring \
  --set service.type=NodePort \
  --set service.nodePort=30111 \
  --set loki.service.type=NodePort \
  --set loki.service.nodePort=30111
```

## Step 8: Install Tempo

```bash
helm install tempo grafana/tempo --namespace monitoring \
  --set service.type=NodePort \
  --set service.nodePort=30120
```

## Step 9: Install Alloy

```bash
helm install alloy grafana-alloy/alloy --namespace monitoring \
  --set service.type=NodePort \
  --set service.nodePort=30140
```

## Step 10: Install Pyroscope

```bash
helm install pyroscope grafana/pyroscope --namespace monitoring \
  --set service.type=NodePort \
  --set service.nodePort=30150
```

## Step 11: Install OpenTelemetry Collector

```bash
helm install opentelemetry-collector open-telemetry/opentelemetry-collector --namespace monitoring \
  --set service.type=NodePort \
  --set image.repository=otel/opentelemetry-collector-contrib \
  --set mode=deployment
```

## Step 12: Install Tanka

```bash
go install github.com/grafana/tanka/cmd/tk@latest
```

## Step 13: Wait for Pods to be Ready

```bash
# Wait for all pods to be running
kubectl get pods -n argocd
kubectl get pods -n monitoring

# Wait until all pods show Running status
watch kubectl get pods -n monitoring
```

## Step 14: Retrieve Credentials

### Argo CD Password
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

### Grafana Password
```bash
kubectl get secret prometheus-grafana -n monitoring -o jsonpath='{.data}' | python3 -c "import sys, json, base64; data=json.load(sys.stdin); print(base64.b64decode(data['admin-password']).decode())"
```

## Step 15: Verify Access

Test all services are accessible:

```bash
# Argo CD
curl -s http://localhost:30080

# Grafana
curl -s http://localhost:30100

# Prometheus
curl -s http://localhost:30090

# Loki
curl -s http://localhost:30111

# Tempo (main UI port)
curl -s http://localhost:31461

# Alloy
curl -s http://localhost:30140

# Pyroscope
curl -s http://localhost:30150
```

## Step 16: Configure Pyroscope NodePort

```bash
kubectl patch svc pyroscope -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":4040,"targetPort":4040,"nodePort":30150}]}}'
```

## Access URLs and Credentials

After successful installation, access the services at:

- **Argo CD**: http://localhost:30080 (admin/password from Step 14)
- **Grafana**: http://localhost:30100 (admin/password from Step 14)
- **Prometheus**: http://localhost:30090
- **Loki**: http://localhost:30111
- **Tempo**: http://localhost:31461 (main UI)
- **Alloy**: http://localhost:30140
- **Pyroscope**: http://localhost:30150

## Cleanup

To remove the entire setup:

```bash
kind delete cluster --name argocd-lab
```

## Troubleshooting

### Grafana CrashLoopBackOff
If Grafana fails to start due to datasource provisioning errors, reinstall with disabled default datasources:

```bash
helm uninstall prometheus -n monitoring
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30100 \
  --set grafana.defaultDatasources.enabled=false \
  --set grafana.sidecar.datasources.enabled=false
```

### Port Mapping Issues
If services are not accessible via NodePorts, ensure the Kind cluster is recreated with the correct port mappings in `kind-config.yaml`.

### Component Status Check
```bash
# Check all pods
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Check specific pod logs
kubectl logs -n monitoring <pod-name>
```

## Notes

- This installation uses Kind v0.20.0 with Kubernetes v1.27.3
- Some components like Mimir require Kubernetes 1.29+ and were not installed
- Beyla, Faro, and k6 require manual setup and are documented in the main README
- All services are configured with NodePort for localhost accessibility
- The installation creates a complete monitoring stack with metrics, logs, traces, and profiling capabilities
