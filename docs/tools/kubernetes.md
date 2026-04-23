# Kubernetes with Kind - Container Orchestration

## Overview

Kubernetes is a container orchestration platform that automates deployment, scaling, and management of containerized applications. Kind (Kubernetes in Docker) runs Kubernetes clusters using Docker containers as nodes, perfect for local development and testing.

## Local Access

- **Kind Cluster**: `kind-argocd-lab`
- **Kubeconfig**: `~/.kube/config` (automatically configured)
- **API Server**: `https://127.0.0.1:6443` (internal)
- **Context**: `kind-argocd-lab`

## Security Considerations

### Current Configuration
- **Local Development**: Cluster runs in Docker containers
- **Network**: Docker bridge networking
- **Authentication**: Local admin permissions
- **Namespaces**: argocd, monitoring, applications

### Security Issues Identified
1. **No RBAC**: Cluster-wide admin permissions
2. **No Network Policies**: All pods can communicate freely
3. **No Pod Security Policies**: Pods run with default permissions
4. **Plain HTTP**: No TLS for internal communication
5. **Local Secrets**: No secret management implemented

## Useful Commands

### Cluster Management
```bash
# Check cluster status
kubectl cluster-info --context kind-argocd-lab

# List all contexts
kubectl config get-contexts

# Switch to kind context
kubectl config use-context kind-argocd-lab

# Get cluster nodes
kubectl get nodes --context kind-argocd-lab

# View cluster info
kubectl cluster-info dump --context kind-argocd-lab
```

### Namespace Management
```bash
# List all namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace <namespace-name>

# Describe namespace
kubectl describe namespace <namespace-name>

# Delete namespace
kubectl delete namespace <namespace-name>
```

### Pod Management
```bash
# List all pods
kubectl get pods --all-namespaces

# List pods in specific namespace
kubectl get pods -n <namespace>

# Get pod details
kubectl describe pod <pod-name> -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace>

# Follow pod logs
kubectl logs -f <pod-name> -n <namespace>

# Execute command in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Delete pod
kubectl delete pod <pod-name> -n <namespace>
```

### Service Management
```bash
# List all services
kubectl get services --all-namespaces

# List services in namespace
kubectl get svc -n <namespace>

# Describe service
kubectl describe svc <service-name> -n <namespace>

# Port-forward service
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n <namespace>

# Delete service
kubectl delete svc <service-name> -n <namespace>
```

### Deployment Management
```bash
# List all deployments
kubectl get deployments --all-namespaces

# List deployments in namespace
kubectl get deployments -n <namespace>

# Describe deployment
kubectl describe deployment <deployment-name> -n <namespace>

# Scale deployment
kubectl scale deployment <deployment-name> --replicas=<count> -n <namespace>

# Restart deployment
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# Check rollout status
kubectl rollout status deployment/<deployment-name> -n <namespace>

# Delete deployment
kubectl delete deployment <deployment-name> -n <namespace>
```

### Resource Management
```bash
# List resource quotas
kubectl get resourcequota -n <namespace>

# List limit ranges
kubectl get limitrange -n <namespace>

# Describe node resources
kubectl describe nodes

# Top pods by resource usage
kubectl top pods -n <namespace>

# Top nodes
kubectl top nodes
```

## Troubleshooting

### Common Issues

#### Cluster Connection Issues
```bash
# Check cluster status
kubectl cluster-info --context kind-argocd-lab

# Verify context
kubectl config current-context

# Test cluster connectivity
kubectl get nodes

# Check kubeconfig
kubectl config view
```

#### Pod Issues
```bash
# Check pod status
kubectl get pods -n <namespace> -o wide

# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace> --previous

# Check resource usage
kubectl top pod <pod-name> -n <namespace>

# Debug pod
kubectl debug <pod-name> -n <namespace> --image=busybox
```

#### Network Issues
```bash
# Check service endpoints
kubectl get endpoints -n <namespace>

# Test pod connectivity
kubectl exec -it <pod-name> -n <namespace> -- nslookup <service-name>

# Check network policies
kubectl get networkpolicies -n <namespace>

# Port-forward for debugging
kubectl port-forward pod/<pod-name> <local-port>:<container-port> -n <namespace>
```

#### Resource Issues
```bash
# Check resource quotas
kubectl describe quota -n <namespace>

# Check limit ranges
kubectl describe limitrange -n <namespace>

# Check node resources
kubectl describe nodes

# Monitor resource usage
kubectl top pods -n <namespace>
```

## Performance Optimization

### Resource Management
```bash
# Set resource requests and limits
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
```

### Pod Optimization
```bash
# Use appropriate resource limits
# Implement health checks
# Use proper termination handling
# Set appropriate restart policies
```

### Cluster Optimization
```bash
# Monitor node resource usage
kubectl top nodes

# Check cluster events
kubectl get events --all-namespaces

# Optimize scheduler decisions
kubectl describe pod <pod-name> -n <namespace>
```

## Security Hardening

### RBAC Implementation
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: applications
  name: app-reader
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: applications
subjects:
- kind: ServiceAccount
  name: default
  namespace: applications
roleRef:
  kind: Role
  name: app-reader
  apiGroup: rbac.authorization.k8s.io
```

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: applications
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: applications
spec:
  podSelector:
    matchLabels:
      app: quarkus-demo
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
```

### Pod Security Standards
```yaml
apiVersion: v1
kind: Pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

## Monitoring Integration

### Prometheus Integration
```bash
# Check Prometheus targets
kubectl get servicemonitors -n monitoring

# Check ServiceMonitor configuration
kubectl describe servicemonitor <monitor-name> -n monitoring

# Verify metrics collection
curl http://prometheus-service.monitoring.svc.cluster.local:9090/api/v1/targets
```

### Logging Integration
```bash
# Check Fluentd configuration
kubectl get configmaps -n monitoring | grep fluentd

# Check log collection
kubectl logs -n monitoring -l app=fluentd

# Verify Loki integration
curl http://loki-service.monitoring.svc.cluster.local:3100/ready
```

### Tracing Integration
```bash
# Check OpenTelemetry Collector
kubectl get pods -n monitoring -l app=opentelemetry-collector

# Verify Tempo integration
curl http://tempo-service.monitoring.svc.cluster.local:3200/ready
```

## Kind-Specific Commands

### Cluster Management
```bash
# List kind clusters
kind get clusters

# Create kind cluster
kind create cluster --config kind-config.yaml

# Delete kind cluster
kind delete cluster --name argocd-lab

# Export kubeconfig
kind export kubeconfig --name argocd-lab

# Load Docker image
kind load docker-image <image-name> --name argocd-lab
```

### Configuration
```yaml
# kind-config.yaml example
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: argocd-lab
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30100
    hostPort: 30100
    protocol: TCP
```

## Backup and Recovery

### Etcd Backup
```bash
# Backup etcd (advanced)
kubectl get secrets -n kube-system etcd-certs
# Requires cluster admin access
```

### Resource Backup
```bash
# Backup all resources
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml

# Backup specific namespace
kubectl get all -n <namespace> -o yaml > namespace-backup.yaml
```

### Configuration Backup
```bash
# Backup kubeconfig
cp ~/.kube/config kubeconfig-backup

# Export cluster configuration
kind export kubeconfig --name argocd-lab > kind-kubeconfig
```

## Version Information

- **Kubernetes**: Check with `kubectl version --client`
- **Kind**: Check with `kind version`
- **kubectl**: Check with `kubectl version --short`
- **Cluster API**: Check with `kubectl version --short`

## Best Practices

### Development
1. **Use namespaces** for environment isolation
2. **Implement resource limits** for all pods
3. **Use health checks** for all applications
4. **Implement proper logging** with structured format
5. **Use GitOps** for configuration management

### Security
1. **Implement RBAC** with least privilege
2. **Use Network Policies** to restrict traffic
3. **Enable Pod Security** standards
4. **Use secrets management** for sensitive data
5. **Regular security scanning** of cluster

### Performance
1. **Set appropriate resource requests/limits**
2. **Use horizontal pod autoscaling** when needed
3. **Monitor resource usage** regularly
4. **Optimize container images** for size
5. **Use proper scheduling** constraints

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
