# Argo CD - GitOps Continuous Delivery

## Overview

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. It follows the GitOps pattern of using Git as the single source of truth for defining the desired application state, automating application deployment and lifecycle management.

## Local Access

- **Argo CD UI**: http://localhost:30080
- **Argo CD API**: http://localhost:30080/api/v1
- **Username**: admin
- **Password**: Retrieved from secret (initial setup)
- **Namespace**: argocd

## Security Considerations

### Current Configuration
- **Default Admin**: Initial password stored in Kubernetes secret
- **UI Access**: HTTP (no TLS in local setup)
- **API Access**: Admin privileges
- **Git Integration**: Manual configuration required

### Security Issues Identified
1. **Default Password**: Initial admin password needs immediate change
2. **HTTP Only**: No TLS encryption for UI/API
3. **Admin Privileges**: Full cluster access via Argo CD
4. **No RBAC**: All users have admin privileges
5. **Git Credentials**: Stored in plaintext in some cases

## Useful Commands

### Installation and Setup
```bash
# Install Argo CD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Login to Argo CD
argocd login localhost:30080 --username admin --password <password> --insecure

# Change initial password
argocd account update-password
```

### Application Management
```bash
# List all applications
argocd app list

# Create application from Git repository
argocd app create <app-name> --repo <repo-url> --path <path> --dest-server https://kubernetes.default.svc --dest-namespace <namespace>

# Sync application
argocd app sync <app-name>

# Get application details
argocd app get <app-name>

# Delete application
argocd app delete <app-name>
```

### Application Status and Monitoring
```bash
# List applications with status
argocd app list -o wide

# Get application sync status
argocd app get <app-name> --refresh

# Watch application status
argocd app wait <app-name> --health

# Get application events
argocd app logs <app-name>
```

### Repository Management
```bash
# List configured repositories
argocd repo list

# Add Git repository
argocd repo add <repo-name> --repo <repo-url> --type git

# Update repository credentials
argocd repo update <repo-name>

# Delete repository
argocd repo delete <repo-name>
```

### Cluster Management
```bash
# List Argo CD projects
argocd proj list

# Create project
argocd proj create <project-name> --description "Project description"

# Add application to project
argocd app create <app-name> --project <project-name> --repo <repo-url>

# Delete project
argocd proj delete <project-name>
```

## Troubleshooting

### Common Issues

#### Application Sync Failures
```bash
# Check application status
argocd app get <app-name>

# Check sync status
argocd app sync <app-name> --dry-run

# Get application events
argocd app logs <app-name>

# Check repository connectivity
argocd repo get <repo-name>
```

#### Permission Issues
```bash
# Check cluster permissions
kubectl auth can-i create applications --namespace argocd

# Check Argo CD RBAC
kubectl get roles -n argocd

# Check service account permissions
kubectl describe serviceaccount argocd-server -n argocd
```

#### UI Access Issues
```bash
# Check Argo CD server status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Check server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check service configuration
kubectl get svc argocd-server -n argocd

# Port-forward for debugging
kubectl port-forward svc/argocd-server 8080:80 -n argocd
```

#### Git Integration Issues
```bash
# Test Git repository access
argocd repo get <repo-name>

# Check Git credentials
kubectl get secret -n argocd | grep repo

# Test repository connectivity
git ls-remote <repo-url>
```

## Application Management

### GitOps Workflow
```bash
# 1. Make changes to Git repository
git add .
git commit -m "Update application configuration"
git push

# 2. Sync changes in Argo CD
argocd app sync <app-name>

# 3. Monitor deployment
argocd app wait <app-name> --health
```

### Application of Apps Pattern
```yaml
# Application of Apps manifest
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### Multi-Environment Setup
```yaml
# Development environment
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: quarkus-demo-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: develop
    path: apps/quarkus-app
  destination:
    server: https://kubernetes.default.svc
    namespace: applications-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

# Production environment
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: quarkus-demo-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: main
    path: apps/quarkus-app
  destination:
    server: https://kubernetes.default.svc
    namespace: applications-prod
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
    - CreateNamespace=true
```

## Security Hardening

### RBAC Configuration
```yaml
# Create role with limited permissions
apiVersion: v1
kind: Role
metadata:
  namespace: applications
  name: app-developer
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "update", "patch"]
---
apiVersion: v1
kind: RoleBinding
metadata:
  name: app-developer-binding
  namespace: applications
subjects:
- kind: ServiceAccount
  name: argocd-server
  namespace: argocd
roleRef:
  kind: Role
  name: app-developer
  apiGroup: rbac.authorization.k8s.io
```

### Project Configuration
```yaml
# Create project with restricted permissions
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: applications-project
  namespace: argocd
spec:
  description: Applications project with restricted permissions
  sourceRepos:
  - https://github.com/your-org/your-repo
  destinations:
  - namespace: applications
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ""
    kind: Namespace
  roles:
  - name: read-only
    description: Read-only access to applications
    policies:
    - p, proj:applications-project:*, application:*, action: read
    groups:
    - my-org:developers
```

### TLS Configuration
```yaml
# Enable TLS for Argo CD server
apiVersion: v1
kind: Secret
metadata:
  name: argocd-server-tls
  namespace: argocd
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  server.insecure: "false"
```

## Monitoring Integration

### Argo CD Metrics
```bash
# Check Argo CD metrics
curl http://localhost:30080/metrics

# Check application metrics
curl http://localhost:30080/api/v1/applications/<app-name>/metrics

# Monitor sync status
argocd app list --output json | jq '.[] | {name: .metadata.name, status: .status.health.status}'
```

### Health Monitoring
```bash
# Check Argo CD health
curl http://localhost:30080/healthz

# Check application health
argocd app get <app-name> --output json | jq '.status.health.status'

# Monitor sync status
watch -n 5 'argocd app list | grep -E "(Synced|OutOfSync)"'
```

### Log Monitoring
```bash
# Get Argo CD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Get application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check application sync logs
argocd app logs <app-name>
```

## Advanced Configuration

### Custom Sync Waves
```yaml
# Configure sync waves for staged deployments
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: multi-app-deployment
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    syncWave: "0"
  source:
    repoURL: https://github.com/your-org/your-repo
    path: apps
  destinations:
  - namespace: applications
    server: https://kubernetes.default.svc
  # Child applications with different waves
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: database-migration
  namespace: argocd
spec:
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    syncWave: "-1"  # Runs before main application
  source:
    repoURL: https://github.com/your-org/your-repo
    path: database/migration
  destinations:
  - namespace: applications
    server: https://kubernetes.default.svc
```

### Hooks and Sync Options
```yaml
# Application with hooks
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-with-hooks
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/your-org/your-repo
    path: app
  destinations:
  - namespace: applications
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    hooks:
    - type: Sync
      command: ["echo", "Pre-sync hook"]
    - type: Sync
      command: ["echo", "Post-sync hook"]
```

## Version Information

- **Argo CD**: Check with `argocd version`
- **API Version**: Check with `argocd version --short`
- **Kubernetes Integration**: v1alpha1 Application CRD

## Best Practices

### GitOps Workflow
1. **Single Source of Truth**: Git repository contains all desired state
2. **Automated Sync**: Enable automated sync for production readiness
3. **Branch Strategy**: Use different branches for environments
4. **Secrets Management**: Use external secret management
5. **Audit Trail**: Maintain Git history for all changes

### Security
1. **Change Default Password**: Immediately after installation
2. **Enable TLS**: Use HTTPS in production
3. **Implement RBAC**: Least privilege principle
4. **Use Projects**: Isolate applications by project
5. **Regular Updates**: Keep Argo CD updated

### Performance
1. **Resource Limits**: Set appropriate limits for Argo CD
2. **Sync Optimization**: Use selective sync options
3. **Monitoring**: Implement comprehensive monitoring
4. **Backup Strategy**: Regular backup of Git and cluster state
5. **Disaster Recovery**: Document recovery procedures

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Argo CD GitHub](https://github.com/argoproj/argo-cd)
- [GitOps Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/gitops/)
- [Argo CD Security](https://argo-cd.readthedocs.io/en/stable/operator-manual/security/)
