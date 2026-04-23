# OpenTelemetry Collector - Telemetry Data Collection

## Overview

OpenTelemetry Collector is a vendor-agnostic, highly configurable observability data pipeline that collects, processes, and exports telemetry data (metrics, logs, and traces) to various backends.

## Local Access

- **Collector API**: http://localhost:4317 (various ports available)
- **Configuration**: ConfigMap in monitoring namespace
- **Services**: Multiple exporters and receivers configured

## Security Considerations

### Current Configuration
- **HTTP Access**: No authentication (local development)
- **Network**: ClusterIP service with NodePort access
- **Storage**: Ephemeral (no persistence)
- **Data Pipeline**: Multiple telemetry sources

### Security Issues Identified
1. **No Authentication**: API accessible without auth
2. **No TLS**: HTTP only communication
3. **Ephemeral Storage**: Configuration lost on cluster restart
4. **No Access Control**: All telemetry data accessible
5. **Default Configuration**: No security hardening

## Useful Commands

### Collector Management
```bash
# Check OpenTelemetry pods
kubectl get pods -n monitoring -l app=opentelemetry-collector

# Check Collector service
kubectl get svc opentelemetry-collector -n monitoring

# Port-forward Collector API
kubectl port-forward -n monitoring svc/opentelemetry-collector 4317:4317

# View Collector logs
kubectl logs -n monitoring -l app=opentelemetry-collector

# Check Collector configuration
kubectl get configmap opentelemetry-collector -n monitoring -o yaml
```

### Configuration Management
```bash
# Get current configuration
kubectl get configmap opentelemetry-collector -n monitoring -o yaml

# Validate configuration
kubectl exec -n monitoring <collector-pod> -- otelcol-validator --config /conf/collector.yaml

# Check configuration reload
kubectl logs -n monitoring -l app=opentelemetry-collector | grep -i "configuration loaded"

# Test configuration syntax
kubectl exec -n monitoring <collector-pod> -- otelcol --config /conf/collector.yaml --dry-run
```

### Telemetry Data Management
```bash
# Check received traces
curl -X GET http://localhost:4317/debug/tracez

# Check received metrics
curl -X GET http://localhost:4317/debug/metricsz

# Check received logs
curl -X GET http://localhost:4317/debug/logz

# Check component health
curl -X GET http://localhost:4317/debug/healthz
```

## Troubleshooting

### Common Issues

#### Telemetry Not Appearing
```bash
# Check Collector status
curl -X GET http://localhost:4317/debug/healthz

# Check component status
curl -X GET http://localhost:4317/debug/components

# Check Collector logs
kubectl logs -n monitoring -l app=opentelemetry-collector

# Check receiver configuration
kubectl get configmap opentelemetry-collector -n monitoring -o yaml | grep -A 10 "receivers"
```

#### High Resource Usage
```bash
# Check Collector memory usage
kubectl top pods -n monitoring -l app=opentelemetry-collector

# Check configuration for batching
kubectl get configmap opentelemetry-collector -n monitoring -o yaml | grep -A 5 "batch"

# Check buffer configuration
kubectl get configmap opentelemetry-collector -n monitoring -o yaml | grep -A 5 "memory_limiter"
```

#### Exporter Issues
```bash
# Check exporter configuration
kubectl get configmap opentelemetry-collector -n monitoring -o yaml | grep -A 10 "exporters"

# Test exporter connectivity
kubectl exec -n monitoring <collector-pod> -- curl -s http://tempo.monitoring.svc.cluster.local:3200

# Check exporter logs
kubectl logs -n monitoring -l app=opentelemetry-collector | grep -i exporter
```

#### Receiver Issues
```bash
# Check receiver configuration
kubectl get configmap opentelemetry-collector -n monitoring -o yaml | grep -A 10 "receivers"

# Test receiver connectivity
kubectl exec -n monitoring <collector-pod> -- curl -s http://localhost:4318

# Check receiver logs
kubectl logs -n monitoring -l app=opentelemetry-collector | grep -i receiver
```

## Performance Optimization

### Configuration Tuning
```yaml
# OpenTelemetry Collector configuration optimizations
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  zpages:
    endpoint: 0.0.0.0:55679

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
    send_batch_max_size: 2048
  
  memory_limiter:
    limit_mib: 512

exporters:
  otlp:
    endpoint: http://tempo.monitoring.svc.cluster.local:3200
    insecure: true
  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: otlp
```

### Resource Optimization
```yaml
# Resource limits for Collector
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

### Pipeline Optimization
```yaml
# Optimized pipeline configuration
processors:
  batch:
    timeout: 200ms
    send_batch_size: 8192
    send_batch_max_size: 8192
  
  memory_limiter:
    limit_mib: 1024
    spike_limit_mib: 512
  
  queued_retry:
    num_workers: 2
    queue_size: 1000
    retry_on_failure: true
```

## Security Hardening

### Authentication Setup
```yaml
# Enable basic authentication for receivers
apiVersion: v1
kind: Secret
metadata:
  name: otel-auth
  namespace: monitoring
type: Opaque
data:
  auth: <base64-encoded-credentials>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: opentelemetry-collector
  namespace: monitoring
data:
  collector.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            auth:
              authenticator: oidc
              oidc:
                issuer_url: https://your-oidc-provider.com
                audience: opentelemetry-collector
```

### TLS Configuration
```yaml
# Enable TLS for receivers
apiVersion: v1
kind: Secret
metadata:
  name: otel-tls
  namespace: monitoring
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: opentelemetry-collector
  namespace: monitoring
data:
  collector.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            tls:
              cert_file: /etc/tls/cert
              key_file: /etc/tls/key
              client_ca_file: /etc/tls/ca
```

### Access Control
```yaml
# Configure access policies
apiVersion: v1
kind: ConfigMap
metadata:
  name: opentelemetry-collector
  namespace: monitoring
data:
  collector.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            auth:
              authenticator: basic
              basic:
                username: ${OTEL_USERNAME}
                password: ${OTEL_PASSWORD}
```

## Monitoring Integration

### Tempo Integration
```bash
# Check Tempo exporter
curl -X GET http://localhost:4317/debug/tracez

# Test Tempo connectivity
kubectl exec -n monitoring <collector-pod> -- curl -s http://tempo.monitoring.svc.cluster.local:3200

# Check exported traces
curl -X GET http://localhost:4317/debug/tracez | jq '.tracez'
```

### Prometheus Integration
```bash
# Check Prometheus exporter
curl -X GET http://localhost:4317/debug/metricsz

# Test Prometheus connectivity
kubectl exec -n monitoring <collector-pod> -- curl -s http://prometheus.monitoring.svc.cluster.local:9090

# Check exported metrics
curl -X GET http://localhost:4317/debug/metricsz | jq '.metricsz'
```

### Loki Integration
```bash
# Check Loki exporter
curl -X GET http://localhost:4317/debug/logz

# Test Loki connectivity
kubectl exec -n monitoring <collector-pod> -- curl -s http://loki.monitoring.svc.cluster.local:3100

# Check exported logs
curl -X GET http://localhost:4317/debug/logz | jq '.logz'
```

## Advanced Configuration

### Multi-Exporter Setup
```yaml
# Configure multiple exporters
apiVersion: v1
kind: ConfigMap
metadata:
  name: opentelemetry-collector
  namespace: monitoring
data:
  collector.yaml: |
    exporters:
      otlp:
        endpoint: http://tempo.monitoring.svc.cluster.local:3200
        insecure: true
      prometheus:
        endpoint: "0.0.0.0:8889"
        namespace: otlp
        send_timestamps: true
        metric_expiration: 180m
        enable_open_metrics: true
      jaeger:
        endpoint: http://jaeger.monitoring.svc.cluster.local:14250
        tls:
          insecure: true
```

### Custom Processors
```yaml
# Configure custom processors
apiVersion: v1
kind: ConfigMap
metadata:
  name: opentelemetry-collector
  namespace: monitoring
data:
  collector.yaml: |
    processors:
      resource:
        attributes:
          - key: cloud.provider
            value: aws
            action: upsert
          - key: cloud.region
            value: us-east-1
            action: upsert
      filter:
        metrics:
          include:
            match_type: strict
            metric_names:
              - http.server.*
        traces:
          include:
            match_type: strict
            services:
              - quarkus-demo
              - springboot-demo
```

### Service Discovery
```yaml
# Configure Kubernetes service discovery
apiVersion: v1
kind: ConfigMap
metadata:
  name: opentelemetry-collector
  namespace: monitoring
data:
  collector.yaml: |
    receivers:
      k8s_cluster:
        collection_interval: 30s
        node_condition_types:
          - Ready
          - MemoryPressure
          - DiskPressure
          - PIDPressure
      k8s_cluster:
        auth_type: serviceAccount
```

## Version Information

- **OpenTelemetry Collector**: Check with `otelcol --version`
- **API Version**: Check via `/debug/healthz`
- **Configuration**: YAML-based configuration
- **Components**: Multiple receivers, processors, exporters

## Best Practices

### Configuration
1. **Appropriate Batching**: Optimize for throughput vs. latency
2. **Proper Resource Limits**: Set appropriate memory and CPU limits
3. **Use Memory Limiters**: Prevent OOM conditions
4. **Enable Health Checks**: Monitor collector health
5. **Configuration Management**: Use GitOps for config changes

### Security
1. **Enable Authentication**: Basic auth or mTLS
2. **Use TLS**: Encrypt all communications
3. **Access Control**: Implement receiver-level security
4. **Regular Updates**: Keep collector updated
5. **Audit Access**: Monitor who accesses telemetry data

### Performance
1. **Optimize Batching**: Balance batch size and timeout
2. **Resource Monitoring**: Monitor collector resource usage
3. **Pipeline Optimization**: Use appropriate processors
4. **Storage Planning**: Use appropriate storage backends
5. **Monitoring Integration**: Monitor all exporters

## References

- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)
- [Collector Components](https://opentelemetry.io/docs/collector/components/)
- [OpenTelemetry Security](https://opentelemetry.io/docs/collector/security/)
