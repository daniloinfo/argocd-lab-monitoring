# Grafana - Visualization and Dashboarding

## Overview

Grafana is an open-source visualization and analytics platform that enables you to query, visualize, alert on, and understand your metrics no matter where they are stored. It integrates seamlessly with Prometheus, Loki, Tempo, and Pyroscope.

## Local Access

- **Grafana UI**: http://localhost:30100
- **Grafana API**: http://localhost:30100/api
- **Username**: admin
- **Password**: Retrieved from secret (initial setup)
- **Namespace**: monitoring

## Security Considerations

### Current Configuration
- **Default Admin**: Initial password stored in Kubernetes secret
- **UI Access**: HTTP (no TLS in local setup)
- **API Access**: Admin privileges
- **Data Sources**: Multiple monitoring integrations

### Security Issues Identified
1. **Default Password**: Initial admin password needs immediate change
2. **HTTP Only**: No TLS encryption for UI/API
3. **Admin Privileges**: Full access to all data sources
4. **No RBAC**: All users have admin privileges
5. **Anonymous Access**: May be enabled in some configurations

## Useful Commands

### Grafana Management
```bash
# Check Grafana pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Check Grafana service
kubectl get svc grafana-service -n monitoring

# Port-forward Grafana UI
kubectl port-forward -n monitoring svc/grafana-service 3000:3000

# View Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check Grafana configuration
kubectl get configmap grafana -n monitoring -o yaml
```

### User Management
```bash
# Access Grafana CLI (if installed)
grafana-cli --server http://localhost:30100 admin list-users

# Create user via API
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"newuser","email":"user@example.com","login":"newuser","password":"password"}' \
  http://localhost:30100/api/admin/users

# Reset admin password
kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d
```

### Data Source Management
```bash
# List data sources via API
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources

# Test data source connection
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name":"test","type":"prometheus","url":"http://prometheus:9090","access":"proxy","isDefault":false}' \
  http://localhost:30100/api/datasources/test

# Delete data source
curl -X DELETE -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources/uid/<datasource-uid>
```

### Dashboard Management
```bash
# List dashboards via API
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/search?type=dash-db

# Import dashboard via API
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"dashboard":{"title":"My Dashboard","panels":[]},"overwrite":true}' \
  http://localhost:30100/api/dashboards/db

# Export dashboard
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/dashboards/uid/<dashboard-uid>/export
```

## Troubleshooting

### Common Issues

#### Data Source Connection Issues
```bash
# Check data source configuration
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources

# Test Prometheus connectivity
kubectl exec -n monitoring <prometheus-pod> -- curl -s http://localhost:9090/api/v1/targets

# Check service connectivity
kubectl exec -n monitoring <grafana-pod> -- curl -s http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/targets

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana | grep -i datasource
```

#### Dashboard Loading Issues
```bash
# Check dashboard configuration
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/dashboards/uid/<dashboard-uid>

# Check Grafana logs for errors
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana | grep -i error

# Verify data source health
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources/uid/<datasource-uid>/health

# Check database connectivity
kubectl exec -n monitoring <grafana-pod> -- sqlite3 /var/lib/grafana/grafana.db ".tables"
```

#### Performance Issues
```bash
# Check Grafana resource usage
kubectl top pods -n monitoring -l app.kubernetes.io/name=grafana

# Check database size
kubectl exec -n monitoring <grafana-pod> -- du -sh /var/lib/grafana/

# Check query performance
curl -H "Authorization: Bearer <token>" \
  -X POST -H "Content-Type: application/json" \
  -d '{"query":"up"}' \
  http://localhost:30100/api/ds/proxy/api/v1/query

# Check Grafana configuration
kubectl get configmap grafana -n monitoring -o yaml | grep -A 10 "database"
```

#### Authentication Issues
```bash
# Check admin password
kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d

# Reset admin password
kubectl patch secret grafana -n monitoring -p '{"data":{"admin-password":"<base64-new-password>"}}'

# Check user configuration
kubectl get configmap grafana -n monitoring -o yaml | grep -A 5 "auth"

# Restart Grafana service
kubectl rollout restart deployment/grafana -n monitoring
```

## Performance Optimization

### Configuration Tuning
```yaml
# Grafana configuration optimizations
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana
  namespace: monitoring
data:
  grafana.ini: |
    [database]
    type = sqlite3
    path = /var/lib/grafana/grafana.db
    [server]
    http_port = 3000
    [log]
    level = info
    [metrics]
    enabled = true
    [analytics]
    reporting_enabled = false
```

### Resource Optimization
```yaml
# Resource limits for Grafana
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Database Optimization
```yaml
# Use PostgreSQL for production
apiVersion: v1
kind: Secret
metadata:
  name: grafana-db
  namespace: monitoring
type: Opaque
data:
  GF_DATABASE_TYPE: cG9zdGdyZWN0cmU=
  GF_DATABASE_HOST: cG9zdGdyZWN0LWRiLW1vbml0b3Jpbmcuc3ZjLmNsdXNlci5jbHVzdGVyLmxvY2Fs
  GF_DATABASE_USER: Z3JhZmFuYQ==
  GF_DATABASE_PASSWORD: <base64-password>
  GF_DATABASE_NAME: Z3JhZmFuYQ==
```

## Security Hardening

### Authentication Setup
```yaml
# Enable OAuth authentication
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana
  namespace: monitoring
data:
  grafana.ini: |
    [auth.generic_oauth]
    enabled = true
    name = OAuth
    allow_sign_up = true
    auto_login = false
    client_id = <oauth-client-id>
    client_secret = <oauth-client-secret>
    scopes = openid profile email
    auth_url = https://oauth-provider.com/auth
    token_url = https://oauth-provider.com/token
    api_url = https://oauth-provider.com/userinfo
```

### RBAC Configuration
```yaml
# Create role with limited permissions
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana
  namespace: monitoring
data:
  grafana.ini: |
    [auth.basic]
    enabled = true
    [auth.anonymous]
    enabled = false
    [users]
    allow_sign_up = false
    auto_assign_org_role = Viewer
```

### TLS Configuration
```yaml
# Enable TLS for Grafana
apiVersion: v1
kind: Secret
metadata:
  name: grafana-tls
  namespace: monitoring
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana
  namespace: monitoring
data:
  grafana.ini: |
    [server]
    protocol = https
    cert_file = /etc/tls/tls.crt
    cert_key = /etc/tls/tls.key
```

## Monitoring Integration

### Prometheus Integration
```bash
# Check Prometheus datasource
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources | jq '.[] | select(.type=="prometheus")'

# Test Prometheus queries
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"queries":[{"refId":"A","key":"Q","expr":"up","hide":false,"type":"time_series"}]}' \
  http://localhost:30100/api/ds/query

# Check Prometheus target status
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources/uid/<prometheus-uid>/health
```

### Loki Integration
```bash
# Check Loki datasource
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources | jq '.[] | select(.type=="loki")'

# Test Loki queries
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"query":"{app=\"quarkus-demo\"}"}' \
  http://localhost:30100/api/loki/api/v1/query_range

# Check Loki health
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources/uid/<loki-uid>/health
```

### Tempo Integration
```bash
# Check Tempo datasource
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources | jq '.[] | select(.type=="tempo")'

# Test Tempo queries
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources/uid/<tempo-uid>/api/search

# Check Tempo health
curl -H "Authorization: Bearer <token>" \
  http://localhost:30100/api/datasources/uid/<tempo-uid>/health
```

## Advanced Configuration

### Custom Plugins
```bash
# Install plugins via configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana
  namespace: monitoring
data:
  grafana.ini: |
    [plugins]
    allow_loading_unsigned_plugins = false
    plugin_admin_enabled = false
    plugin_catalog_url = https://grafana.com/api/plugins
```

### Alerting Configuration
```yaml
# Configure alerting
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana
  namespace: monitoring
data:
  grafana.ini: |
    [alerting]
    enabled = true
    execute_alerts = true
    evaluation_timeout_seconds = 30
    notification_timeout_seconds = 30
```

### Multi-Organization Setup
```yaml
# Configure multiple organizations
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana
  namespace: monitoring
data:
  grafana.ini: |
    [users]
    auto_assign_org = true
    viewers_can_org_edit = false
    editors_can_admin = false
```

## Version Information

- **Grafana**: Check with `grafana-cli --version` or UI
- **API Version**: Check via `/api/health`
- **Plugins**: Check via UI or `/api/plugins`

## Best Practices

### Configuration
1. **Change Default Password**: Immediately after installation
2. **Use External Database**: PostgreSQL for production
3. **Enable TLS**: Use HTTPS in production
4. **Configure Backups**: Regular database backups
5. **Use GitOps**: Manage dashboards as code

### Security
1. **Implement RBAC**: Role-based access control
2. **Enable Authentication**: OAuth or SAML
3. **Use Network Policies**: Restrict access to Grafana
4. **Regular Updates**: Keep Grafana updated
5. **Audit Access**: Monitor who accesses dashboards

### Performance
1. **Optimize Queries**: Use efficient PromQL/LogQL
2. **Dashboard Optimization**: Limit panel refresh rates
3. **Resource Monitoring**: Monitor Grafana resource usage
4. **Database Optimization**: Use appropriate database type
5. **Caching**: Enable query caching

## References

- [Grafana Documentation](https://grafana.com/docs/)
- [Grafana API Reference](https://grafana.com/docs/http_api/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Grafana Security](https://grafana.com/docs/grafana/latest/administration/security/)
