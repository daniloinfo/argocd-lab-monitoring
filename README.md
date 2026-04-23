# Argo CD Lab with Kind - Complete Monitoring Stack

## Setup Complete

Your Argo CD lab is now running in a Kind cluster with a comprehensive monitoring stack!

## Access Information

### Argo CD
- **Argo CD UI**: http://localhost:30080
- **Username**: admin
- **Password**: 2zo8VwLvpELqLRJT

### Grafana Monitoring Stack
- **Grafana UI**: http://localhost:30100
- **Username**: admin
- **Password**: u7J2THzpya73X1dbaw0WkZ4y16x9LMH0LCJeDy0k

### Monitoring Components
- **Prometheus**: http://localhost:30090
- **Loki**: http://localhost:30111
- **Tempo**: http://localhost:31461 (main UI port)
- **Alloy**: http://localhost:30140
- **Pyroscope**: http://localhost:30150
- **OpenTelemetry Collector**: Multiple ports available (31923, 31213, 30581, 30249, etc.)

### Java Applications
Both applications are deployed in the `applications` namespace with full monitoring integration:

#### Quarkus Demo Application
- **Health**: http://localhost:8081/actuator/health (via port-forward)
- **Hello Endpoint**: http://localhost:8081/hello/{name}
- **Metrics**: http://localhost:8081/actuator/prometheus
- **Framework**: Spring Boot 2.7.18 with Java 11
- **Monitoring**: Prometheus metrics, OpenTelemetry tracing, Loki logs, Pyroscope profiling

#### Spring Boot Demo Application  
- **Health**: http://localhost:8082/actuator/health (via port-forward)
- **Hello Endpoint**: http://localhost:8082/hello/{name}
- **Metrics**: http://localhost:8082/actuator/prometheus
- **Framework**: Spring Boot 3.2.0 with Java 17
- **Monitoring**: Prometheus metrics, OpenTelemetry tracing, Loki logs, Pyroscope profiling

#### Access Java Applications
```bash
# Port-forward Quarkus app
kubectl port-forward -n applications deployment/quarkus-demo 8081:8080

# Port-forward Spring Boot app  
kubectl port-forward -n applications deployment/springboot-demo 8082:8080
```

## Port Mappings

### Argo CD
- Port 80 (HTTP) -> localhost:80
- Port 443 (HTTPS) -> localhost:443
- Port 30080 (Argo CD UI HTTP) -> localhost:30080
- Port 30443 (Argo CD UI HTTPS) -> localhost:30443

### Monitoring Stack
- Port 30090 (Prometheus) -> localhost:30090
- Port 30100 (Grafana) -> localhost:30100
- Port 30111 (Loki) -> localhost:30111
- Port 30120 (Tempo - alternative) -> localhost:30120
- Port 31461 (Tempo - main UI) -> localhost:31461
- Port 30140 (Alloy) -> localhost:30140
- Port 30150 (Pyroscope) -> localhost:30150

## Monitoring Stack Components

### Installed Components
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboarding
- **Loki**: Log aggregation and analysis
- **Tempo**: Distributed tracing
- **Alloy**: Data collection and processing
- **Pyroscope**: Continuous profiling
- **OpenTelemetry Collector**: Telemetry data collection

### Tools Available
- **Tanka**: Configuration management (installed via go install)
- **Beyla**: eBPF monitoring (manual setup required)
- **Faro**: Frontend monitoring (manual setup required)
- **k6**: Load testing (manual setup required)
- **Mimir**: Scalable metrics storage (requires K8s 1.29+)

## Testing and Verification

### Automated Installation Test
The installation script includes comprehensive testing of all components. If the installation completes successfully, all systems are verified to be working.

### Automated Testing Script
For ongoing verification, use the dedicated test script:

```bash
# Run comprehensive test suite
./test-apps.sh
```

The test script will verify:
- ✅ All monitoring services accessibility
- ✅ Kubernetes resources (namespaces, deployments, services)
- ✅ Application pod readiness
- ✅ Application endpoints (health, hello, metrics)
- ✅ Monitoring integration (Prometheus scraping, metrics collection)

This provides a complete health check of the entire Argo CD Lab environment.

### Manual Testing Steps

#### Test Core Services
```bash
# Test Argo CD
curl -s http://localhost:30080 | grep -q "Argo CD"

# Test Grafana
curl -s http://localhost:30100 | grep -q "Grafana"

# Test Prometheus
curl -s http://localhost:30090 | grep -q "Prometheus"

# Test Loki
curl -s http://localhost:30111 | grep -q "Loki"

# Test Tempo
curl -s http://localhost:31461 | grep -q "Tempo"

# Test Alloy
curl -s http://localhost:30140 | grep -q "Alloy"

# Test Pyroscope
curl -s http://localhost:30150 | grep -q "Pyroscope"
```

#### Test Java Applications
```bash
# Check application pods
kubectl get pods -n applications --context kind-argocd-lab

# Port-forward applications (in separate terminals)
kubectl port-forward -n applications deployment/quarkus-demo 8081:8080 &
kubectl port-forward -n applications deployment/springboot-demo 8082:8080 &

# Test Quarkus application
curl -s http://localhost:8081/actuator/health | grep -q "UP"
curl -s http://localhost:8081/hello/Test | grep -q "Hello"
curl -s http://localhost:8081/actuator/prometheus | grep -q "jvm_memory"

# Test Spring Boot application
curl -s http://localhost:8082/actuator/health | grep -q "UP"
curl -s http://localhost:8082/hello/Test | grep -q "Hello"
curl -s http://localhost:8082/actuator/prometheus | grep -q "jvm_memory"
```

#### Test Monitoring Integration
```bash
# Verify Prometheus is scraping Java applications
curl -s "http://localhost:30090/api/v1/targets" | grep -q "quarkus-demo"
curl -s "http://localhost:30090/api/v1/targets" | grep -q "springboot-demo"

# Check metrics in Prometheus
curl -s "http://localhost:30090/api/v1/query?query=jvm_memory_used_bytes" | grep -q "result"

# Verify logs are being collected (in Grafana)
# Access Grafana -> Explore -> Loki -> Search for "applications"
```

### Expected Results
If all tests pass, you should see:
- ✅ All 4 core monitoring services accessible
- ✅ Both Java applications running and healthy
- ✅ Metrics being collected by Prometheus
- ✅ Logs being collected by Loki
- ✅ Applications properly annotated for monitoring

## Cluster Management

### Check cluster status
```bash
kubectl cluster-info --context kind-argocd-lab
```

### Check Argo CD pods
```bash
kubectl get pods -n argocd --context kind-argocd-lab
```

### Check monitoring pods
```bash
kubectl get pods -n monitoring --context kind-argocd-lab
```

### Check application pods
```bash
kubectl get pods -n applications --context kind-argocd-lab
```

### Check monitoring services
```bash
kubectl get svc -n monitoring --context kind-argocd-lab
```

### Check application services
```bash
kubectl get svc -n applications --context kind-argocd-lab
```

### Check Argo CD service
```bash
kubectl get svc argocd-server -n argocd --context kind-argocd-lab
```

## Install Argo CD CLI (optional)

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

## Login with CLI

### Argo CD CLI
```bash
argocd login localhost:30080 --username admin --password cI72Wv7VTJl9v0nX --insecure
```

### Grafana Data Sources Configuration
The monitoring stack comes with pre-configured data sources in Grafana:

1. **Prometheus**: Metrics from http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
2. **Loki**: Logs from http://loki.monitoring.svc.cluster.local:3100
3. **Tempo**: Traces from http://tempo.monitoring.svc.cluster.local:3200
4. **Pyroscope**: Profiles from http://pyroscope.monitoring.svc.cluster.local:4040

## Usage Tips

### Grafana Dashboard Setup
1. Access Grafana at http://localhost:30100
2. Login with admin credentials
3. Import pre-built dashboards from the Grafana dashboard library
4. Explore metrics, logs, and traces in one interface

### Monitoring Your Applications
Add these annotations to your pods to enable monitoring:

```yaml
metadata:
  annotations:
    # Prometheus metrics
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
    
    # Pyroscope profiling
    profiles.grafana.com/memory.scrape: "true"
    profiles.grafana.com/memory.port: "8080"
    profiles.grafana.com/cpu.scrape: "true"
    profiles.grafana.com/cpu.port: "8080"
    
    # OpenTelemetry
    instrumentation.opentelemetry.io/inject-java: "true"
    instrumentation.opentelemetry.io/inject-python: "true"
```

### Log Collection with Loki
Loki automatically collects logs from all pods in the cluster. Use LogQL queries in Grafana to search and analyze logs.

### Distributed Tracing with Tempo
Tempo receives traces from OpenTelemetry instrumentation. Set up tracing in your applications to see request flows across services.

### Continuous Profiling with Pyroscope
Pyroscope collects continuous profiles from applications with the proper annotations. Analyze CPU and memory usage patterns over time.

## Cleanup

To delete the entire lab environment:

```bash
kind delete cluster --name argocd-lab
```

## Next Steps

### Argo CD
1. Access the Argo CD UI at http://localhost:30080
2. Login with admin credentials
3. Create your first application
4. Connect a Git repository
5. Deploy applications to your cluster

### Monitoring Stack
1. Access Grafana at http://localhost:30100
2. Explore pre-configured dashboards
3. Set up alerts in AlertManager
4. Configure data sources for your applications
5. Instrument your applications with OpenTelemetry

### Advanced Configuration
- Set up Beyla for eBPF-based monitoring
- Configure Faro for frontend monitoring
- Install k6 for load testing
- Use Tanka for configuration management

## Troubleshooting

### Argo CD Issues
If pods are not starting properly, check the logs:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --context kind-argocd-lab
```

### Monitoring Stack Issues
Check individual component logs:
```bash
# Prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Loki
kubectl logs -n monitoring -l app.kubernetes.io/name=loki

# Tempo
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo
```

### Common Issues
- **Pods not starting**: Check resource limits and node capacity
- **Data sources not working**: Verify service endpoints and network policies
- **Metrics not appearing**: Ensure proper Prometheus annotations on pods
- **Logs not collected**: Check Promtail configuration and pod labels

## Performance Tips

### For Production Use
- Increase resource limits for monitoring components
- Configure persistent storage for long-term data retention
- Set up proper alerting rules
- Configure backup strategies for monitoring data

### Resource Optimization
- Monitor resource usage of monitoring stack itself
- Adjust scrape intervals for Prometheus
- Use appropriate retention periods
- Configure log sampling in Loki