# Pyroscope - Continuous Profiling

## Overview

Pyroscope is an open-source continuous profiling platform that helps developers find and fix performance issues in their code. It can continuously collect, store, and analyze profiling data from running applications.

## Local Access

- **Pyroscope UI**: http://localhost:30150
- **Pyroscope API**: http://localhost:30150/api/v1
- **Configuration**: ConfigMap in monitoring namespace
- **Storage**: Ephemeral (local cluster setup)

## Security Considerations

### Current Configuration
- **HTTP Access**: No authentication (local development)
- **Network**: ClusterIP service with NodePort access
- **Storage**: Ephemeral (no persistence)
- **Profiling**: Automatic via annotations

### Security Issues Identified
1. **No Authentication**: UI and API accessible without auth
2. **No TLS**: HTTP only communication
3. **Ephemeral Storage**: Profiling data lost on cluster restart
4. **No Access Control**: All profiling data accessible
5. **Performance Impact**: Continuous profiling may affect performance

## Useful Commands

### Pyroscope Management
```bash
# Check Pyroscope pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=pyroscope

# Check Pyroscope service
kubectl get svc pyroscope -n monitoring

# Port-forward Pyroscope UI
kubectl port-forward -n monitoring svc/pyroscope 4040:4040

# Check Pyroscope configuration
kubectl get configmap pyroscope -n monitoring -o yaml
```

### Profile Management
```bash
# List all applications
curl -s "http://localhost:30150/api/v1/applications"

# Get application details
curl -s "http://localhost:30150/api/v1/applications/quarkus-demo"

# Get profile groups
curl -s "http://localhost:30150/api/v1/profile-groups"

# Get profile types
curl -s "http://localhost:30150/api/v1/profile-types"
```

### Profile Querying
```bash
# Query CPU profiles
curl -s "http://localhost:30150/api/v1/render?query=quarkus-demo.cpu.time&from=now-1h&until=now"

# Query memory profiles
curl -s "http://localhost:30150/api/v1/render?query=quarkus-demo.memory.alloc_objects&from=now-1h&until=now"

# Query goroutine profiles
curl -s "http://localhost:30150/api/v1/render?query=quarkus-demo.goroutines&from=now-1h&until=now"

# Query with specific parameters
curl -s "http://localhost:30150/api/v1/render?query=quarkus-demo.cpu.time&from=now-1h&until=now&step=30&max-nodes=10"
```

## Troubleshooting

### Common Issues

#### Profiles Not Appearing
```bash
# Check if applications are being scraped
curl -s "http://localhost:30150/api/v1/applications"

# Check Pyroscope logs
kubectl logs -n monitoring -l app.kubernetes.io/name=pyroscope

# Check service endpoints
kubectl get endpoints -n monitoring pyroscope

# Test profiling endpoint directly
kubectl exec -n applications <pod-name> -- curl -s http://localhost:8080/debug/pprof/profile
```

#### High Resource Usage
```bash
# Check Pyroscope memory usage
kubectl top pods -n monitoring -l app.kubernetes.io/name=pyroscope

# Check configuration for retention
kubectl get configmap pyroscope -n monitoring -o yaml | grep -A 5 "retention"

# Check storage usage
kubectl exec -n monitoring <pyroscope-pod> -- du -sh /tmp/
```

#### Performance Impact
```bash
# Check application performance
kubectl top pods -n applications -l app=quarkus-demo

# Check Pyroscope configuration
kubectl get configmap pyroscope -n monitoring -o yaml | grep -A 10 "scrape"

# Monitor profiling overhead
curl -s "http://localhost:30150/api/v1/targets" | jq '.data[] | select(.labels.app=="quarkus-demo")'
```

#### Storage Issues
```bash
# Check disk usage
kubectl exec -n monitoring <pyroscope-pod> -- df -h

# Check temporary directory
kubectl exec -n monitoring <pyroscope-pod> -- ls -la /tmp/

# Check retention configuration
kubectl get configmap pyroscope -n monitoring -o yaml | grep -A 10 "storage"
```

## Performance Optimization

### Configuration Tuning
```yaml
# Pyroscope configuration optimizations
server:
  http_listen_port: 4040
  grpc_listen_port: 4040

profiling:
  cpu_enabled: true
  mem_enabled: true
  block_enabled: true
  mutex_enabled: true
  goroutine_enabled: true

scrape_config:
  scrape_interval: 15s
  scrape_timeout: 10s
  enable_scraping: true

storage:
  path: /tmp/pyroscope
  retention: 15d
```

### Resource Optimization
```yaml
# Resource limits for Pyroscope
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### Profiling Optimization
```yaml
# Application profiling configuration
metadata:
  annotations:
    profiles.grafana.com/memory.scrape: "true"
    profiles.grafana.com/memory.port: "8080"
    profiles.grafana.com/cpu.scrape: "true"
    profiles.grafana.com/cpu.port: "8080"
    profiles.grafana.com/goroutine.scrape: "true"
    profiles.grafana.com/goroutine.port: "8080"
    profiles.grafana.com/block.scrape: "true"
    profiles.grafana.com/block.port: "8080"
    profiles.grafana.com/mutex.scrape: "true"
    profiles.grafana.com/mutex.port: "8080"
```

## Security Hardening

### Authentication Setup
```yaml
# Enable basic authentication
apiVersion: v1
kind: Secret
metadata:
  name: pyroscope-auth
  namespace: monitoring
type: Opaque
data:
  auth: <base64-encoded-credentials>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: pyroscope
  namespace: monitoring
data:
  pyroscope.yaml: |
    server:
      basic_auth:
        username: admin
        password: <hashed-password>
```

### TLS Configuration
```yaml
# Enable TLS for Pyroscope
apiVersion: v1
kind: Secret
metadata:
  name: pyroscope-tls
  namespace: monitoring
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: pyroscope
  namespace: monitoring
data:
  pyroscope.yaml: |
    server:
      tls:
        cert_file: /etc/tls/cert
        key_file: /etc/tls/key
```

### Access Control
```yaml
# Configure access policies
apiVersion: v1
kind: ConfigMap
metadata:
  name: pyroscope
  namespace: monitoring
data:
  pyroscope.yaml: |
    server:
      access_control:
        enabled: true
        rules:
          - name: "deny-all"
            match:
              app: ".*"
            actions:
              - "read"
              - "write"
          - name: "allow-applications"
            match:
              app: "quarkus-demo|springboot-demo"
            actions:
              - "read"
```

## Monitoring Integration

### Grafana Integration
```bash
# Check Pyroscope datasource in Grafana
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources | jq '.[] | select(.type=="pyroscope")'

# Test Pyroscope queries in Grafana
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"queryType":"profile","refId":"A","key":"Q","expr":"quarkus-demo.cpu.time"}' \
  http://localhost:30100/api/ds/query

# Check Pyroscope datasource health
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources/uid/<pyroscope-uid>/health
```

### Application Profiling
```yaml
# Application profiling configuration (Java)
# Automatic profiling via annotations
metadata:
  annotations:
    profiles.grafana.com/memory.scrape: "true"
    profiles.grafana.com/memory.port: "8080"
    profiles.grafana.com/cpu.scrape: "true"
    profiles.grafana.com/cpu.port: "8080"
    profiles.grafana.com/goroutine.scrape: "true"
    profiles.grafana.com/goroutine.port: "8080"
```

## Advanced Configuration

### Multi-Tenant Setup
```yaml
# Configure tenant isolation
apiVersion: v1
kind: ConfigMap
metadata:
  name: pyroscope
  namespace: monitoring
data:
  pyroscope.yaml: |
    server:
      access_control:
        enabled: true
        tenants:
          - name: "applications"
            display_name: "Applications Team"
            rules:
              - name: "allow-applications"
                match:
                  app: "quarkus-demo|springboot-demo"
                actions:
                  - "read"
          - name: "monitoring"
            display_name: "Monitoring Team"
            rules:
              - name: "allow-monitoring"
                match:
                  app: ".*"
                actions:
                  - "read"
```

### Storage Configuration
```yaml
# Configure persistent storage
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pyroscope-storage
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: pyroscope
  namespace: monitoring
data:
  pyroscope.yaml: |
    storage:
      path: /data/pyroscope
      retention: 30d
```

### High Availability Setup
```yaml
# Configure Pyroscope in HA mode
apiVersion: v1
kind: ConfigMap
metadata:
  name: pyroscope
  namespace: monitoring
data:
  pyroscope.yaml: |
    server:
      http_listen_port: 4040
      grpc_listen_port: 4040
      
    profiling:
      cpu_enabled: true
      mem_enabled: true
      block_enabled: true
      mutex_enabled: true
      goroutine_enabled: true
      
    scrape_config:
      scrape_interval: 15s
      scrape_timeout: 10s
      enable_scraping: true
      
    storage:
      path: /tmp/pyroscope
      retention: 15d
```

## Version Information

- **Pyroscope**: Check with `pyroscope --version`
- **API Version**: Check via `/api/v1/version`
- **Configuration**: YAML-based configuration

## Best Practices

### Configuration
1. **Appropriate Retention**: Balance storage vs. historical data
2. **Proper Scrape Intervals**: Don't overwhelm applications
3. **Resource Limits**: Set appropriate memory and CPU limits
4. **Storage Planning**: Use persistent storage in production
5. **Configuration Management**: Use GitOps for config changes

### Security
1. **Enable Authentication**: Basic auth or OAuth
2. **Use TLS**: Encrypt all communications
3. **Access Control**: Implement tenant isolation
4. **Regular Updates**: Keep Pyroscope updated
5. **Audit Access**: Monitor who accesses profiling data

### Performance
1. **Optimize Scrape**: Use appropriate scrape intervals
2. **Resource Monitoring**: Monitor Pyroscope resource usage
3. **Storage Monitoring**: Monitor disk usage and performance
4. **Profile Filtering**: Use selective profiling types
5. **Performance Impact**: Monitor profiling overhead

## References

- [Pyroscope Documentation](https://grafana.com/docs/pyroscope/latest/)
- [Pyroscope Querying](https://grafana.com/docs/pyroscope/latest/querying/)
- [Pyroscope Integration](https://grafana.com/docs/pyroscope/latest/integrations/)
- [Pyroscope Architecture](https://grafana.com/docs/pyroscope/latest/architecture/)
