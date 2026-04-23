# Prometheus - Metrics Collection and Storage

## Overview

Prometheus is an open-source monitoring and alerting toolkit that collects metrics from configured targets at given intervals, evaluates rule expressions, and can trigger alerts if some condition is observed to be true.

## Local Access

- **Prometheus UI**: http://localhost:30090
- **Prometheus API**: http://localhost:30090/api/v1
- **Configuration**: ConfigMap in monitoring namespace
- **Storage**: Ephemeral (local cluster setup)

## Security Considerations

### Current Configuration
- **HTTP Access**: No authentication (local development)
- **Network**: ClusterIP service with NodePort access
- **Storage**: Ephemeral (no persistence)
- **Targets**: Auto-discovery via annotations

### Security Issues Identified
1. **No Authentication**: UI and API accessible without auth
2. **No TLS**: HTTP only communication
3. **Ephemeral Storage**: Data lost on cluster restart
4. **No Network Policies**: All pods can scrape metrics
5. **Default Configuration**: No security hardening

## Useful Commands

### Prometheus Management
```bash
# Check Prometheus pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check Prometheus service
kubectl get svc prometheus-kube-prometheus-prometheus -n monitoring

# Port-forward Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Check Prometheus configuration
kubectl get configmap prometheus-kube-prometheus-prometheus -n monitoring -o yaml
```

### Metrics Querying
```bash
# Query all metrics
curl "http://localhost:30090/api/v1/label/__name__/values"

# Query specific metric
curl "http://localhost:30090/api/v1/query?query=up"

# Query metric range
curl "http://localhost:30090/api/v1/query_range?query=jvm_memory_used_bytes&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=60"

# Query targets
curl "http://localhost:30090/api/v1/targets"
```

### Target Management
```bash
# List all targets
curl "http://localhost:30090/api/v1/targets"

# Check specific target
curl "http://localhost:30090/api/v1/targets" | jq '.data.activeTargets[] | select(.labels.job=="quarkus-demo")'

# Check target health
curl "http://localhost:30090/api/v1/targets" | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}'
```

### Alert Management
```bash
# List alert rules
curl "http://localhost:30090/api/v1/rules"

# Check active alerts
curl "http://localhost:30090/api/v1/alerts"

# Check alert managers
curl "http://localhost:30090/api/v1/alertmanagers"
```

## Troubleshooting

### Common Issues

#### Metrics Not Appearing
```bash
# Check if targets are up
curl "http://localhost:30090/api/v1/targets" | jq '.data.activeTargets[] | select(.health=="up")'

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Check service endpoints
kubectl get endpoints -n monitoring prometheus-kube-prometheus-prometheus

# Test metrics endpoint directly
kubectl exec -n applications <pod-name> -- curl -s http://localhost:8080/actuator/prometheus
```

#### High Memory Usage
```bash
# Check Prometheus memory usage
kubectl top pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check configuration for retention
kubectl get configmap prometheus-kube-prometheus-prometheus -n monitoring -o yaml | grep -A 5 "retention"

# Check WAL size
kubectl exec -n monitoring <prometheus-pod> -- du -sh /prometheus/wal
```

#### Target Discovery Issues
```bash
# Check service monitor configuration
kubectl get servicemonitors -n monitoring

# Check Prometheus configuration reload
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus | grep "Loaded configuration file"

# Check annotation configuration
kubectl get pods -n applications -o wide | grep -E "(quarkus|springboot)"
kubectl describe pod <pod-name> -n applications | grep -A 10 "Annotations"
```

#### Storage Issues
```bash
# Check disk usage
kubectl exec -n monitoring <prometheus-pod> -- df -h

# Check WAL directory
kubectl exec -n monitoring <prometheus-pod> -- ls -la /prometheus/

# Check compaction status
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus | grep -i compaction
```

## Performance Optimization

### Configuration Tuning
```yaml
# Prometheus configuration optimizations
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s

storage:
  tsdb:
    retention.time: 15d
    retention.size: 10GB

rule_files:
  - "/etc/prometheus/rules/*.yml"
```

### Resource Optimization
```yaml
# Resource limits for Prometheus
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### Target Optimization
```yaml
# ServiceMonitor for efficient scraping
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: quarkus-demo-monitor
  namespace: applications
spec:
  selector:
    matchLabels:
      app: quarkus-demo
  endpoints:
  - port: http
    path: /actuator/prometheus
    interval: 30s
    scrapeTimeout: 10s
    honorLabels: true
```

## Security Hardening

### Authentication Setup
```yaml
# Enable basic authentication
apiVersion: v1
kind: Secret
metadata:
  name: prometheus-basic-auth
  namespace: monitoring
type: Opaque
data:
  auth: <base64-encoded-credentials>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      basic_auth_users:
        admin: <hashed-password>
```

### TLS Configuration
```yaml
# Enable TLS for Prometheus
apiVersion: v1
kind: Secret
metadata:
  name: prometheus-tls
  namespace: monitoring
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      tls_config:
        cert_file: /etc/tls/cert
        key_file: /etc/tls/key
```

### Network Policies
```yaml
# Restrict access to Prometheus
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: prometheus-access
  namespace: monitoring
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: prometheus
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: argocd
    - namespaceSelector:
        matchLabels:
          name: applications
    ports:
    - protocol: TCP
      port: 9090
```

## Monitoring Integration

### Grafana Integration
```bash
# Check Grafana datasource
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources

# Test Prometheus datasource
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name":"prometheus","type":"prometheus","url":"http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090","access":"proxy","isDefault":true}' \
  http://localhost:30100/api/datasources
```

### Alertmanager Integration
```bash
# Check Alertmanager configuration
kubectl get configmap alertmanager-kube-prometheus-alertmanager -n monitoring -o yaml

# Test alert routing
curl -X POST -H "Content-Type: application/json" \
  -d '{"receiver":"web.hook","status":"firing","alerts":[{"labels":{"alertname":"HighErrorRate","severity":"critical"}}]}' \
  http://localhost:9093/api/v1/alerts
```

### Custom Metrics
```yaml
# Application metrics configuration
# In application (Java/Micrometer)
@Timed(value = "api_request_duration", description = "API request duration")
@Counted(value = "api_requests_total", description = "Total API requests")
public class MetricsController {
    
    @GetMapping("/metrics")
    public String getMetrics() {
        // Custom metrics automatically collected by Micrometer
        return "Metrics endpoint";
    }
}
```

## Advanced Configuration

### Remote Write
```yaml
# Configure remote write to long-term storage
remote_write:
  - url: "http://remote-storage:9201/api/v1/write"
    queue_config:
      max_samples_per_send: 1000
      max_shards: 200
      capacity: 2500
```

### Federation
```yaml
# Configure federation for multi-cluster setup
- job_name: 'federate'
  scrape_interval: 15s
  honor_labels: true
  metrics_path: /federate
  static_configs:
    - targets: ['source-prometheus:9090']
```

### Recording Rules
```yaml
# Create recording rules for better performance
groups:
- name: kubernetes.rules
  rules:
  - record: kubernetes_pod_name:node_memory_usage_bytes
    expr: container_memory_usage_bytes{container="",pod!=""} / on(pod) group_left(node) by (pod) (kube_pod_info * on(pod) group_left(node) kube_node_info)
  - record: kubernetes_pod_name:node_cpu_usage_cores
    expr: rate(container_cpu_usage_seconds_total{container="",pod!=""}[5m]) / on(pod) group_left(node) by (pod) (kube_pod_info * on(pod) group_left(node) kube_node_info)
```

## Version Information

- **Prometheus**: Check with `prometheus --version`
- **API Version**: Check via `/api/v1/status/config`
- **Configuration**: Stored in ConfigMap
- **Storage**: TSDB format

## Best Practices

### Configuration
1. **Appropriate Retention**: Balance storage vs. historical data
2. **Proper Scrape Intervals**: Don't overwhelm targets
3. **Resource Limits**: Set appropriate memory and CPU limits
4. **Storage Planning**: Use persistent storage in production
5. **Configuration Management**: Use GitOps for config changes

### Security
1. **Enable Authentication**: Basic auth or OAuth
2. **Use TLS**: Encrypt all communications
3. **Network Policies**: Restrict access to metrics
4. **Regular Updates**: Keep Prometheus updated
5. **Audit Access**: Monitor who accesses metrics

### Performance
1. **Optimize Queries**: Use efficient PromQL
2. **Recording Rules**: Pre-compute complex queries
3. **Target Optimization**: Configure appropriate scrape intervals
4. **Storage Monitoring**: Monitor disk usage and performance
5. **Resource Monitoring**: Monitor Prometheus resource usage

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Prometheus Querying](https://prometheus.io/docs/prometheus/latest/querying/)
- [Prometheus Alerting](https://prometheus.io/docs/prometheus/latest/alerting/)
- [Kubernetes Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
