# AGENTS.md - Project Stack and Guidelines

## Technology Stack

### Core Infrastructure
- **Kubernetes**: Container orchestration platform
- **Kind (Kubernetes in Docker)**: Local Kubernetes cluster
- **Argo CD**: GitOps continuous delivery platform

### Monitoring & Observability Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboarding
- **Loki**: Log aggregation and analysis
- **Tempo**: Distributed tracing
- **Alloy**: Data collection and processing
- **Pyroscope**: Continuous profiling
- **OpenTelemetry Collector**: Telemetry data collection

### Development Tools
- **Tanka**: Configuration management
- **Beyla**: eBPF monitoring (manual setup)
- **Faro**: Frontend monitoring (manual setup)
- **k6**: Load testing (manual setup)
- **Mimir**: Scalable metrics storage (requires K8s 1.29+)

## Project Structure

```
windsurf-project/
├── README.md              # Project documentation and setup guide
├── AGENTS.md              # This file - stack and guidelines
├── INSTALL.md             # Detailed installation instructions
├── install.sh             # Automated installation script
├── kind-config.yaml       # Kind cluster configuration
└── .windsurf/             # Windsurf IDE configuration
    └── workflows/         # Custom workflows
```

## Development Rules & Standards

### 1. File Organization
- Keep documentation files in the root directory
- Use descriptive names for all configuration files
- Maintain consistent naming conventions (kebab-case for files)

### 2. Configuration Management
- All Kubernetes configurations should use YAML format
- Store cluster configurations in `kind-config.yaml`
- Use environment-specific configurations when needed

### 3. Documentation Standards
- **README.md**: Main project documentation with setup instructions
- **AGENTS.md**: Technology stack and development guidelines
- **INSTALL.md**: Detailed step-by-step installation guide
- Keep documentation up-to-date with code changes

### 4. Port Mapping Standards
- Argo CD UI: 30080 (HTTP), 30443 (HTTPS)
- Grafana: 30100
- Prometheus: 30090
- Loki: 30111
- Tempo: 30120 (alternative), 31461 (main UI)
- Alloy: 30140
- Pyroscope: 30150

### 5. Monitoring Integration Rules
- All applications must include proper monitoring annotations
- Use OpenTelemetry instrumentation for tracing
- Configure Prometheus scraping for metrics
- Enable Loki log collection for all pods
- Set up Pyroscope profiling for performance analysis

### 6. Security Guidelines
- Never hardcode sensitive credentials in configuration files
- Use Kubernetes secrets for sensitive data
- Implement proper RBAC policies
- Regularly update dependencies and images

### 7. Development Workflow
- Use GitOps principles with Argo CD
- All changes go through Git repository
- Automated testing before deployment
- Monitor applications after deployment

## Application Deployment Standards

### Required Annotations
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

### Namespace Standards
- **argocd**: Argo CD components
- **monitoring**: Observability stack
- **applications**: User applications

## Best Practices

### Performance
- Monitor resource usage of monitoring stack
- Adjust scrape intervals for Prometheus
- Use appropriate retention periods
- Configure log sampling in Loki

### Reliability
- Set up proper alerting rules
- Configure backup strategies for monitoring data
- Use persistent storage for critical components
- Implement health checks for all services

### Scalability
- Use horizontal pod autoscaling where appropriate
- Configure resource limits and requests
- Plan for growth in monitoring data storage
- Optimize network policies for inter-service communication

## Troubleshooting Guidelines

### Common Issues
- Check pod logs with `kubectl logs`
- Verify service endpoints and network policies
- Ensure proper Prometheus annotations on pods
- Check Promtail configuration for log collection

### Debug Commands
```bash
# Check cluster status
kubectl cluster-info --context kind-argocd-lab

# Check Argo CD pods
kubectl get pods -n argocd --context kind-argocd-lab

# Check monitoring pods
kubectl get pods -n monitoring --context kind-argocd-lab

# Check services
kubectl get svc -n monitoring --context kind-argocd-lab
```

## Maintenance

### Regular Tasks
- Update dependencies and images
- Review and optimize monitoring configurations
- Clean up unused resources
- Backup critical configurations

### Cleanup
To delete the entire lab environment:
```bash
kind delete cluster --name argocd-lab
```

---

*This document should be updated as the project evolves and new technologies are added.*
