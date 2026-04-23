# ArgoCD Setup Guide - GitOps Configuration

## Overview

This guide provides step-by-step instructions for configuring ArgoCD to manage the Java demo applications using GitOps principles. The setup includes individual applications and a root application for centralized management.

## Prerequisites

### Requirements
- **ArgoCD**: Installed and running in namespace `argocd`
- **kubectl**: Configured with `kind-argocd-lab` context
- **Git Repository**: Applications code pushed to GitHub repository
- **Access**: ArgoCD UI access and CLI authentication

### Verify Prerequisites
```bash
# Check ArgoCD status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Verify ArgoCD UI access
curl -f http://localhost:30080

# Check kubectl context
kubectl config current-context

# Verify Git repository
git ls-remote https://github.com/daniloinfo/argocd-lab-monitoring.git
```

## Setup Methods

### Method 1: ArgoCD UI (Recommended for Beginners)

#### Step 1: Access ArgoCD UI
1. Open browser: http://localhost:30080
2. Login with username: `admin`
3. Use initial password (get from secret):
   ```bash
   kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
   ```

#### Step 2: Configure Git Repository
1. Click **Settings** (gear icon) → **Repositories**
2. Click **Connect Repo**
3. Select **Connect via HTTPS**
4. Enter repository details:
   - **Repository URL**: `https://github.com/daniloinfo/argocd-lab-monitoring.git`
   - **Username**: Your GitHub username
   - **Password**: GitHub personal access token
5. Click **Connect**

#### Step 3: Create Applications

##### Create Root Application
1. Click **New App**
2. Select **Edit YAML mode**
3. Paste the content from `argocd-apps/applications-root.yaml`
4. Click **Create**

##### Create Individual Applications
1. Wait for root application to sync
2. Click **New App** for each application:
   - **Quarkus Demo**: Use `argocd-apps/quarkus-demo-app.yaml`
   - **Spring Boot Demo**: Use `argocd-apps/springboot-demo-app.yaml`
3. Click **Create** for each application

### Method 2: ArgoCD CLI (Recommended for Automation)

#### Step 1: Login to ArgoCD CLI
```bash
# Login to ArgoCD
argocd login localhost:30080 --username admin --password <initial-password> --insecure

# Change initial password (recommended)
argocd account update-password
```

#### Step 2: Add Git Repository
```bash
# Add repository
argocd repo add argocd-lab \
  --repo https://github.com/daniloinfo/argocd-lab-monitoring.git \
  --type git \
  --username <github-username> \
  --password <github-token>
```

#### Step 3: Create Applications
```bash
# Create root application
argocd app create -f argocd-apps/applications-root.yaml

# Create Quarkus application
argocd app create -f argocd-apps/quarkus-demo-app.yaml

# Create Spring Boot application
argocd app create -f argocd-apps/springboot-demo-app.yaml
```

#### Step 4: Verify Applications
```bash
# List all applications
argocd app list

# Check application status
argocd app get applications

# Check sync status
argocd app sync applications
```

### Method 3: Kubectl (Direct YAML Application)

#### Step 1: Apply Applications Directly
```bash
# Apply root application
kubectl apply -f argocd-apps/applications-root.yaml

# Apply Quarkus application
kubectl apply -f argocd-apps/quarkus-demo-app.yaml

# Apply Spring Boot application
kubectl apply -f argocd-apps/springboot-demo-app.yaml
```

#### Step 2: Verify Applications
```bash
# Check application status
kubectl get applications -n argocd

# Check application details
kubectl describe application quarkus-demo -n argocd

# Check application sync status
argocd app get quarkus-demo --refresh
```

## Application Configuration Details

### Root Application (applications-root.yaml)
- **Purpose**: Manages the `applications` namespace
- **Sync Wave**: `-1` (runs before other applications)
- **Auto-sync**: Enabled with self-healing
- **Pruning**: Automatically removes deleted resources
- **Repository**: Root `/apps` directory

### Quarkus Demo Application
- **Source Path**: `apps/quarkus-app`
- **Destination Namespace**: `applications`
- **Sync Wave**: `0` (runs after root application)
- **Resources**: Deployment, Service, Namespace
- **Monitoring**: Prometheus, Loki, Tempo, Pyroscope integration

### Spring Boot Demo Application
- **Source Path**: `apps/springboot-app`
- **Destination Namespace**: `applications`
- **Sync Wave**: `1` (runs after Quarkus app)
- **Resources**: Deployment, Service
- **Monitoring**: Prometheus, Loki, Tempo, Pyroscope integration

## Sync Strategy

### Wave-Based Deployment
The applications are configured with sync waves to ensure proper deployment order:

1. **Wave -1**: `applications` namespace creation
2. **Wave 0**: Quarkus application deployment
3. **Wave 1**: Spring Boot application deployment

This ensures:
- Namespace exists before applications deploy
- Quarkus app deploys before Spring Boot (if dependencies exist)
- Proper resource ordering

### Automated Sync Configuration
```yaml
syncPolicy:
  automated:
    prune: true        # Remove resources not in Git
    selfHeal: true      # Fix configuration drift
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
  retry:
    limit: 5           # Maximum retry attempts
    backoff:
      duration: 5s      # Initial backoff
      factor: 2          # Backoff multiplier
      maxDuration: 3m   # Maximum backoff
```

## Troubleshooting

### Common Issues

#### Repository Connection Issues
```bash
# Check repository connectivity
argocd repo get argocd-lab

# Test Git access
git ls-remote https://github.com/daniloinfo/argocd-lab-monitoring.git

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

#### Application Sync Failures
```bash
# Check application status
argocd app get <app-name>

# Check sync status
argocd app sync <app-name> --dry-run

# View application events
argocd app logs <app-name>

# Check application details
argocd app get <app-name> --refresh
```

#### Permission Issues
```bash
# Check ArgoCD service account
kubectl get serviceaccount argocd-server -n argocd

# Check cluster permissions
kubectl auth can-i create applications --namespace argocd

# Check RBAC rules
kubectl get roles -n argocd -o yaml
```

#### Resource Conflicts
```bash
# Check existing resources
kubectl get all -n applications

# Check resource ownership
kubectl get all -n applications -o wide

# Force sync (if needed)
argocd app sync <app-name> --force
```

### Manual Sync Commands
```bash
# Sync specific application
argocd app sync quarkus-demo

# Sync all applications
argocd app sync --all

# Sync with retry
argocd app sync quarkus-demo --retry

# Sync with force override
argocd app sync quarkus-demo --force
```

## Advanced Configuration

### Custom Sync Hooks
```yaml
# Add hooks to application manifest
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
spec:
  hooks:
    - type: Sync
      command: ["sh", "-c", "echo 'Pre-sync hook executed'"]
    - type: Sync
      command: ["sh", "-c", "echo 'Post-sync hook executed'"]
```

### Custom Sync Options
```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    - RespectIgnoreDifferences=true
    - ApplyOutOfSyncOnly=true
```

### Resource Customization
```yaml
# Override resource requirements
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: applications
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
  project: default
  source:
    repoURL: https://github.com/daniloinfo/argocd-lab-monitoring.git
    targetRevision: main
    path: apps/quarkus-app
  # Override specific resources
  override:
    - name: quarkus-demo
      kind: Deployment
      patch: |
        spec:
          template:
            spec:
              containers:
                - name: quarkus-demo
                  resources:
                    requests:
                      memory: "256Mi"
                      cpu: "200m"
                    limits:
                      memory: "1Gi"
                      cpu: "1000m"
```

## Monitoring and Observability

### ArgoCD Application Metrics
```bash
# Check ArgoCD metrics
curl http://localhost:30080/metrics

# Monitor application health
argocd app list --output json | jq '.[] | {name: .metadata.name, health: .status.health.status}'

# Check sync history
argocd app history quarkus-demo
```

### Integration with Monitoring Stack
The applications are automatically integrated with the monitoring stack:

- **Prometheus**: Metrics scraped from `/actuator/prometheus`
- **Loki**: Logs collected via Fluentd
- **Tempo**: Traces sent via OpenTelemetry
- **Pyroscope**: Continuous profiling enabled
- **Grafana**: Dashboards available for all metrics

## Best Practices

### GitOps Workflow
1. **Single Source of Truth**: Git repository contains all desired state
2. **Immutable Infrastructure**: Never make manual changes to cluster
3. **Automated Testing**: Include tests in CI/CD pipeline
4. **Progressive Delivery**: Use canary deployments when possible
5. **Rollback Strategy**: Always maintain ability to rollback

### Security
1. **Repository Security**: Use SSH keys or personal access tokens
2. **Branch Protection**: Protect main branch from direct pushes
3. **Access Control**: Implement proper RBAC in ArgoCD
4. **Secret Management**: Use Kubernetes secrets for sensitive data
5. **Audit Trail**: Maintain complete Git history

### Performance
1. **Sync Optimization**: Use appropriate sync intervals
2. **Resource Limits**: Set appropriate resource requests/limits
3. **Health Checks**: Implement proper health checks
4. **Monitoring**: Comprehensive monitoring of all applications
5. **Alerting**: Configure alerts for sync failures

## Maintenance

### Regular Tasks
```bash
# Check application health (daily)
argocd app list --output json | jq '.[] | select(.status.health.status != "Healthy")'

# Update applications (as needed)
git pull origin main
git push origin main

# Clean up old resources (monthly)
kubectl get all -n applications --no-headers | grep -E "(Terminating|Error)"

# Backup ArgoCD configuration (weekly)
kubectl get applications -n argocd -o yaml > argocd-backup.yaml
```

### Disaster Recovery
```bash
# Restore from Git history
argocd app get <app-name> --revision <previous-commit-hash>

# Force resync all applications
argocd app sync --all --force

# Restore from backup
kubectl apply -f argocd-backup.yaml

# Check cluster health
kubectl get nodes --context kind-argocd-lab
```

## Version Information

- **ArgoCD**: Check with `argocd version`
- **Kubernetes**: Check with `kubectl version --client`
- **Application**: Use Git commit hashes for versioning

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/user-guide/argocd-cli/)
- [ArgoCD Applications](https://argo-cd.readthedocs.io/en/stable/user-guide/applications/)
- [ArgoCD Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/waves/)
- [ArgoCD Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/hooks/)

## Quick Reference

### Essential Commands
```bash
# Login
argocd login localhost:30080 --username admin --password <password>

# List apps
argocd app list

# Sync app
argocd app sync <app-name>

# Get app status
argocd app get <app-name>

# View app logs
argocd app logs <app-name>

# Delete app
argocd app delete <app-name>
```

### Configuration Files
- **Root App**: `argocd-apps/applications-root.yaml`
- **Quarkus App**: `argocd-apps/quarkus-demo-app.yaml`
- **Spring Boot App**: `argocd-apps/springboot-demo-app.yaml`
- **Repository**: `https://github.com/daniloinfo/argocd-lab-monitoring.git`

### URLs
- **ArgoCD UI**: http://localhost:30080
- **Quarkus App**: http://localhost:8081 (after port-forward)
- **Spring Boot App**: http://localhost:8082 (after port-forward)
