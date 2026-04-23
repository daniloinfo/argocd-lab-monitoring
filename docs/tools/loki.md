# Loki - Log Aggregation and Analysis

## Overview

Loki is a horizontally scalable, highly available, multi-tenant log aggregation system inspired by Prometheus. It is designed to be very cost-effective and easy to operate, as it does not index the contents of the logs, but rather a set of labels for each log stream.

## Local Access

- **Loki UI**: http://localhost:30111
- **Loki API**: http://localhost:30111/loki/api/v1
- **Configuration**: ConfigMap in monitoring namespace
- **Storage**: Ephemeral (local cluster setup)

## Security Considerations

### Current Configuration
- **HTTP Access**: No authentication (local development)
- **Network**: ClusterIP service with NodePort access
- **Storage**: Ephemeral (no persistence)
- **Log Collection**: Automatic via Promtail

### Security Issues Identified
1. **No Authentication**: UI and API accessible without auth
2. **No TLS**: HTTP only communication
3. **Ephemeral Storage**: Logs lost on cluster restart
4. **No Access Control**: All logs accessible to all users
5. **Plain Text Logs**: No encryption at rest

## Useful Commands

### Loki Management
```bash
# Check Loki pods
kubectl get pods -n monitoring -l app=loki

# Check Loki service
kubectl get svc loki -n monitoring

# Port-forward Loki UI
kubectl port-forward -n monitoring svc/loki 3100:3100

# View Loki logs
kubectl logs -n monitoring -l app=loki

# Check Loki configuration
kubectl get configmap loki -n monitoring -o yaml
```

### Log Querying
```bash
# Query all logs
curl -G -s "http://localhost:30111/loki/api/v1/query_range" \
  --data-urlencode 'query={app="quarkus-demo"}'

# Query specific time range
curl -G -s "http://localhost:30111/loki/api/v1/query_range" \
  --data-urlencode 'query={app="springboot-demo"}&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z'

# Query with filters
curl -G -s "http://localhost:30111/loki/api/v1/query_range" \
  --data-urlencode 'query={app="quarkus-demo",level="error"}'

# Get log labels
curl -s "http://localhost:30111/loki/api/v1/labels"
```

### Log Analysis
```bash
# Count logs by application
curl -G -s "http://localhost:30111/loki/api/v1/query_range" \
  --data-urlencode 'query=count_over_time({app=~".+"}, 1h)' \
  | jq '.data.result[0].value[1]'

# Get error rate
curl -G -s "http://localhost:30111/loki/api/v1/query_range" \
  --data-urlencode 'query=count_over_time({level="error"}, 1h)' \
  | jq '.data.result[0].value[1]'

# Analyze log patterns
curl -G -s "http://localhost:30111/loki/api/v1/query_range" \
  --data-urlencode 'query=rate({app="quarkus-demo"}[5m])'
```

### Label Management
```bash
# Get all label names
curl -s "http://localhost:30111/loki/api/v1/labels"

# Get label values
curl -s "http://localhost:30111/loki/api/v1/labels/app"

# Get label values with filters
curl -s "http://localhost:30111/loki/api/v1/labels/level?start=2024-01-01T00:00:00Z"
```

## Troubleshooting

### Common Issues

#### Logs Not Appearing
```bash
# Check Promtail status
kubectl get pods -n monitoring -l app=promtail

# Check Promtail logs
kubectl logs -n monitoring -l app=promtail

# Check Promtail configuration
kubectl get configmap promtail -n monitoring -o yaml

# Test Loki ingestion
curl -X POST -H "Content-Type: application/json" \
  -d '{"streams":[{"stream":{"app":"test"},"values":[{"timestamp":"2024-01-01T00:00:00Z","value":"test log"}]}' \
  http://localhost:30111/loki/api/v1/push
```

#### High Resource Usage
```bash
# Check Loki resource usage
kubectl top pods -n monitoring -l app=loki

# Check disk usage
kubectl exec -n monitoring <loki-pod> -- df -h

# Check memory usage
kubectl exec -n monitoring <loki-pod> -- free -h

# Check configuration for retention
kubectl get configmap loki -n monitoring -o yaml | grep -A 5 "retention"
```

#### Query Performance Issues
```bash
# Check Loki query performance
curl -G -s "http://localhost:30111/loki/api/v1/query_range" \
  --data-urlencode 'query={app="quarkus-demo"}&limit=1000' \
  -w "Time: %{time_total}s\n"

# Check Loki metrics
curl -s "http://localhost:30111/metrics" | grep loki

# Check query statistics
curl -s "http://localhost:30111/metrics" | grep query
```

#### Storage Issues
```bash
# Check Loki storage configuration
kubectl get configmap loki -n monitoring -o yaml | grep -A 10 "storage_config"

# Check disk space
kubectl exec -n monitoring <loki-pod> -- du -sh /loki/

# Check index maintenance
kubectl logs -n monitoring -l app=loki | grep -i compaction
```

## Performance Optimization

### Configuration Tuning
```yaml
# Loki configuration optimizations
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1:7946
    ring:
      kvstore:
        store: inmemory
        replication_factor: 1
    final_sleep: 0s
    flush_period: 1m
    chunk_idle_period: 3m
    max_transfer_retries: 0
    chunk_target_size: 1048576
    chunk_block_size: 262144

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    shared_store: filesystem
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

### Resource Optimization
```yaml
# Resource limits for Loki
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
# Use efficient LogQL queries
{app="quarkus-demo"} |= "error"  # Filter after stream selection
{app="springboot-demo"} | logfmt | status="500"  # Parse and filter

# Use time limits
{app="quarkus-demo"}[1h]  # Last hour only
count_over_time({app="quarkus-demo"}, 1h)  # Count instead of fetching all

# Use appropriate label filters
{namespace="applications"}  # More specific than app filter
{level=~"error|critical"}  # Regex for multiple levels
```

## Security Hardening

### Authentication Setup
```yaml
# Enable basic authentication
apiVersion: v1
kind: Secret
metadata:
  name: loki-auth
  namespace: monitoring
type: Opaque
data:
  auth: <base64-encoded-credentials>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki
  namespace: monitoring
data:
  loki.yaml: |
    auth_enabled: true
    auth:
      type: basic
      basic:
        username: admin
        password: <hashed-password>
```

### TLS Configuration
```yaml
# Enable TLS for Loki
apiVersion: v1
kind: Secret
metadata:
  name: loki-tls
  namespace: monitoring
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki
  namespace: monitoring
data:
  loki.yaml: |
    server:
      http_listen_address: 0.0.0.0
      http_listen_port: 3100
      https_cert_file: /etc/tls/cert
      https_key_file: /etc/tls/key
```

### Access Control
```yaml
# Configure tenant isolation
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki
  namespace: monitoring
data:
  loki.yaml: |
    auth:
      type: basic
      basic:
        tenant_ids: ["applications", "monitoring", "argocd"]
    limits_config:
        enforce_metric_name: false
        reject_old_samples: true
```

## Monitoring Integration

### Grafana Integration
```bash
# Check Loki datasource in Grafana
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources | jq '.[] | select(.type=="loki")'

# Test Loki queries in Grafana
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"queryType":"range","refId":"A","key":"Q","query":"{app=\"quarkus-demo\"}","editorMode":"code","datasource":{"uid":"<loki-uid>","type":"loki"}}' \
  http://localhost:30100/api/ds/query

# Check Loki datasource health
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources/uid/<loki-uid>/health
```

### Promtail Integration
```bash
# Check Promtail configuration
kubectl get configmap promtail -n monitoring -o yaml

# Check Promtail logs
kubectl logs -n monitoring -l app=promtail

# Test Promtail targets
kubectl exec -n monitoring <promtail-pod> -- wget -qO- http://localhost:3100/targets
```

### Application Log Integration
```yaml
# Application logging configuration (Java)
# application.yml
logging:
  level:
    com.example: INFO
    org.springframework: INFO
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
  logback:
    appender:
      stdout:
        encoder:
          pattern: "%d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"

# Structured logging for better parsing
@Slf4j
@RestController
public class LoggingController {
    
    @GetMapping("/log-test")
    public String logTest() {
        log.info("Info level log message");
        log.warn("Warning level log message");
        log.error("Error level log message");
        
        MDC.put("requestId", UUID.randomUUID().toString());
        MDC.put("userId", "test-user");
        
        log.info("Request processed");
        
        MDC.clear();
        return "Log test completed";
    }
}
```

## Advanced Configuration

### Multi-Tenant Setup
```yaml
# Configure multiple tenants
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki
  namespace: monitoring
data:
  loki.yaml: |
    auth:
      type: basic
      basic:
        tenant_ids: ["team-a", "team-b", "team-c"]
    limits_config:
        per_tenant_override_config: |
          team-a:
            ingestion_rate_mb: 100
            max_series_per_user: 100000
          team-b:
            ingestion_rate_mb: 200
            max_series_per_user: 200000
```

### Storage Configuration
```yaml
# Configure object storage for production
apiVersion: v1
kind: Secret
metadata:
  name: loki-storage
  namespace: monitoring
type: Opaque
data:
  s3-access-key: <base64-access-key>
  s3-secret-key: <base64-secret-key>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki
  namespace: monitoring
data:
  loki.yaml: |
    storage_config:
      s3:
        s3: https://s3.amazonaws.com
        bucket: loki-logs
        access_key_id: <access-key>
        secret_access_key: <secret-key>
        region: us-east-1
```

### High Availability Setup
```yaml
# Configure Loki in HA mode
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki
  namespace: monitoring
data:
  loki.yaml: |
    target: all
    auth_enabled: false
    
    ingester:
      replicas: 3
      max_transfer_retries: 0
      chunk_idle_period: 1m
      chunk_target_size: 1048576
      lifecycler:
        address: 127.0.0.1:7946
        
    querier:
      replica: 3
      max_concurrent: 10
      
    query_scheduler:
      max_outstanding_requests_per_tenant: 2048
```

## Version Information

- **Loki**: Check with `loki --version`
- **API Version**: Check via `/loki/api/v1/status/buildinfo`
- **Configuration**: YAML-based configuration

## Best Practices

### Configuration
1. **Appropriate Retention**: Balance storage vs. historical data
2. **Efficient Indexing**: Use appropriate label strategies
3. **Resource Planning**: Set appropriate memory and CPU limits
4. **Storage Planning**: Use persistent storage in production
5. **Configuration Management**: Use GitOps for config changes

### Security
1. **Enable Authentication**: Basic auth or OAuth
2. **Use TLS**: Encrypt all communications
3. **Access Control**: Implement tenant isolation
4. **Log Classification**: Classify sensitive information
5. **Regular Auditing**: Monitor who accesses logs

### Performance
1. **Efficient Queries**: Use appropriate LogQL patterns
2. **Label Strategy**: Use consistent labeling
3. **Resource Monitoring**: Monitor Loki resource usage
4. **Query Optimization**: Use time limits and filters
5. **Storage Monitoring**: Monitor disk usage and performance

## References

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Reference](https://grafana.com/docs/loki/latest/logql/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)
- [Loki Architecture](https://grafana.com/docs/loki/latest/fundamentals/architecture/)
