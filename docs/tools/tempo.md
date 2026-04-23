# Tempo - Distributed Tracing

## Overview

Tempo is an open-source, easy-to-use, and large-scale distributed tracing backend. It natively supports OpenTelemetry, Jaeger, and Zipkin trace formats, making it compatible with most open-source tracing instrumentation.

## Local Access

- **Tempo UI**: http://localhost:31461 (main UI port)
- **Tempo API**: http://localhost:30120 (alternative API port)
- **Configuration**: ConfigMap in monitoring namespace
- **Storage**: Ephemeral (local cluster setup)

## Security Considerations

### Current Configuration
- **HTTP Access**: No authentication (local development)
- **Network**: ClusterIP service with NodePort access
- **Storage**: Ephemeral (no persistence)
- **Trace Ingestion**: OpenTelemetry collector integration

### Security Issues Identified
1. **No Authentication**: UI and API accessible without auth
2. **No TLS**: HTTP only communication
3. **Ephemeral Storage**: Trace data lost on cluster restart
4. **No Access Control**: All traces accessible to all users
5. **Default Configuration**: No security hardening

## Useful Commands

### Tempo Management
```bash
# Check Tempo pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo

# Check Tempo service
kubectl get svc tempo -n monitoring

# Port-forward Tempo UI
kubectl port-forward -n monitoring svc/tempo 31461:3200

# View Tempo logs
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo

# Check Tempo configuration
kubectl get configmap tempo -n monitoring -o yaml
```

### Trace Querying
```bash
# Query traces via API
curl -X POST -H "Content-Type: application/json" \
  -d '{"service":"quarkus-demo","limit":20}' \
  http://localhost:30120/api/search

# Query specific trace
curl -X GET "http://localhost:30120/api/traces/<trace-id>"

# Search traces with filters
curl -X POST -H "Content-Type: application/json" \
  -d '{"service":"springboot-demo","tags":{"key":"value"},"limit":50}' \
  http://localhost:30120/api/search

# Get trace metrics
curl -s "http://localhost:30120/api/metrics"
```

### Service Management
```bash
# List available services
curl -s "http://localhost:30120/api/services"

# Get service operations
curl -s "http://localhost:30120/api/services/quarkus-demo/operations"

# Get service dependencies
curl -s "http://localhost:30120/api/dependencies"
```

## Troubleshooting

### Common Issues

#### Traces Not Appearing
```bash
# Check OpenTelemetry collector status
kubectl get pods -n monitoring -l app=opentelemetry-collector

# Check collector logs
kubectl logs -n monitoring -l app=opentelemetry-collector

# Verify Tempo configuration
kubectl get configmap tempo -n monitoring -o yaml | grep -A 10 "otlp"

# Test trace ingestion
curl -X POST -H "Content-Type: application/json" \
  -d '{"resourceSpans":[{"traceID":"test","spanID":"test","operationName":"test"}]}' \
  http://localhost:30120/api/push
```

#### High Resource Usage
```bash
# Check Tempo resource usage
kubectl top pods -n monitoring -l app.kubernetes.io/name=tempo

# Check configuration for retention
kubectl get configmap tempo -n monitoring -o yaml | grep -A 5 "retention"

# Check storage usage
kubectl exec -n monitoring <tempo-pod> -- du -sh /tmp/
```

#### UI Access Issues
```bash
# Check Tempo service
kubectl get svc tempo -n monitoring

# Check service endpoints
kubectl get endpoints -n monitoring tempo

# Port-forward for debugging
kubectl port-forward -n monitoring pod/<tempo-pod> 31461:3200

# Check Tempo logs
kubectl logs -n monitoring -l app.kubernetes.io/name=tempo | grep -i error
```

#### Query Performance Issues
```bash
# Check Tempo metrics
curl -s "http://localhost:30120/api/metrics" | grep tempo

# Check query performance
time curl -X POST -H "Content-Type: application/json" \
  -d '{"service":"quarkus-demo","limit":100}' \
  http://localhost:30120/api/search

# Check backend status
curl -s "http://localhost:30120/api/ready"
```

## Performance Optimization

### Configuration Tuning
```yaml
# Tempo configuration optimizations
server:
  http_listen_address: 0.0.0.0:3200

querier:
  frontend_worker:
    concurrent_search_jobs: 500
    max_block_bytes: 5000000
  trace_idle_timeout: 30s
  max_traces_per_query: 1000

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/blocks
      wal:
        path: /tmp/tempo/wal
```

### Resource Optimization
```yaml
# Resource limits for Tempo
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### Query Optimization
```bash
# Use efficient trace queries
# Limit time range
curl -X POST -H "Content-Type: application/json" \
  -d '{"service":"quarkus-demo","start":"2024-01-01T00:00:00Z","end":"2024-01-01T01:00:00Z","limit":100}' \
  http://localhost:30120/api/search

# Use specific filters
curl -X POST -H "Content-Type: application/json" \
  -d '{"service":"springboot-demo","tags":{"error":"true"},"limit":50}' \
  http://localhost:30120/api/search

# Use pagination for large results
curl -X POST -H "Content-Type: application/json" \
  -d '{"service":"quarkus-demo","limit":100,"offset":200}' \
  http://localhost:30120/api/search
```

## Security Hardening

### Authentication Setup
```yaml
# Enable basic authentication
apiVersion: v1
kind: Secret
metadata:
  name: tempo-auth
  namespace: monitoring
type: Opaque
data:
  auth: <base64-encoded-credentials>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tempo
  namespace: monitoring
data:
  tempo.yaml: |
    server:
      auth:
        enabled: true
        basic:
          users:
            - username: admin
              password: <hashed-password>
```

### TLS Configuration
```yaml
# Enable TLS for Tempo
apiVersion: v1
kind: Secret
metadata:
  name: tempo-tls
  namespace: monitoring
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tempo
  namespace: monitoring
data:
  tempo.yaml: |
    server:
      http_tls:
        cert_file: /etc/tls/cert
        key_file: /etc/tls/key
```

### Access Control
```yaml
# Configure access policies
apiVersion: v1
kind: ConfigMap
metadata:
  name: tempo
  namespace: monitoring
data:
  tempo.yaml: |
    server:
      cors:
        allowed_origins:
          - https://grafana.example.com
        allowed_methods:
          - GET
          - POST
      http:
        access_log: true
        base_path: /
```

## Monitoring Integration

### OpenTelemetry Collector Integration
```bash
# Check collector configuration
kubectl get configmap opentelemetry-collector -n monitoring -o yaml

# Verify collector to Tempo connection
kubectl logs -n monitoring -l app=opentelemetry-collector | grep -i tempo

# Check collector metrics
curl -s "http://localhost:4318/metrics" | grep tempo
```

### Grafana Integration
```bash
# Check Tempo datasource in Grafana
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources | jq '.[] | select(.type=="tempo")'

# Test Tempo queries in Grafana
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"queryType":"traceql","refId":"A","key":"Q","expr":"{service=\"quarkus-demo\"}"}' \
  http://localhost:30100/api/ds/query

# Check Tempo datasource health
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources/uid/<tempo-uid>/health
```

### Application Tracing
```yaml
# Application tracing configuration (Java)
# OpenTelemetry automatic injection via annotations
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"

# Manual OpenTelemetry configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: tracing-config
  namespace: applications
data:
  otel-config.yaml: |
    exporter:
      otlp:
        endpoint: http://opentelemetry-collector.monitoring.svc.cluster.local:4317
        protocol: grpc
    service:
      name: quarkus-demo
      version: 1.0.0
    resource:
      attributes:
        service.name: quarkus-demo
        service.version: 1.0.0
        namespace: applications
```

## Advanced Configuration

### Multi-Tenant Setup
```yaml
# Configure tenant isolation
apiVersion: v1
kind: ConfigMap
metadata:
  name: tempo
  namespace: monitoring
data:
  tempo.yaml: |
    multitenancy_enabled: true
    overrides:
      per_tenant_override_config: |
        retention:
          traces:
            per_tenant:
              team-a: 48h
              team-b: 72h
        limits:
          per_tenant:
            team-a:
              max_traces_per_second: 100
            team-b:
              max_traces_per_second: 200
```

### Storage Configuration
```yaml
# Configure object storage for production
apiVersion: v1
kind: Secret
metadata:
  name: tempo-storage
  namespace: monitoring
type: Opaque
data:
  s3-access-key: <base64-access-key>
  s3-secret-key: <base64-secret-key>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tempo
  namespace: monitoring
data:
  tempo.yaml: |
    storage:
      trace:
        backend: s3
        s3:
          bucket: tempo-traces
          region: us-east-1
          access_key: ${S3_ACCESS_KEY}
          secret_key: ${S3_SECRET_KEY}
```

### High Availability Setup
```yaml
# Configure Tempo in HA mode
apiVersion: v1
kind: ConfigMap
metadata:
  name: tempo
  namespace: monitoring
data:
  tempo.yaml: |
    distributor:
      ring_hash_function: consistent_hash
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
    ingester:
      replicas: 3
      lifecycler:
        num_workers: 5
    querier:
      replicas: 3
      frontend_worker:
        concurrent_search_jobs: 1000
```

## Version Information

- **Tempo**: Check with `tempo --version`
- **API Version**: Check via `/api/version`
- **Configuration**: YAML-based configuration

## Best Practices

### Configuration
1. **Appropriate Retention**: Balance storage vs. historical data
2. **Efficient Storage**: Use appropriate storage backend
3. **Resource Limits**: Set appropriate memory and CPU limits
4. **High Availability**: Configure multiple replicas for production
5. **Configuration Management**: Use GitOps for config changes

### Security
1. **Enable Authentication**: Basic auth or OAuth
2. **Use TLS**: Encrypt all communications
3. **Access Control**: Implement tenant isolation
4. **Regular Updates**: Keep Tempo updated
5. **Audit Access**: Monitor who accesses traces

### Performance
1. **Optimize Queries**: Use appropriate filters and time ranges
2. **Resource Monitoring**: Monitor Tempo resource usage
3. **Storage Planning**: Use appropriate storage backend
4. **Query Caching**: Enable query result caching
5. **Trace Sampling**: Use appropriate sampling rates

## References

- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Tempo Querying](https://grafana.com/docs/tempo/latest/querying/)
- [OpenTelemetry Integration](https://grafana.com/docs/tempo/latest/opentelemetry/)
- [Tempo Architecture](https://grafana.com/docs/tempo/latest/architecture/)
