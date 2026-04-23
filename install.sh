#!/bin/bash

# Argo CD Lab with Complete Monitoring Stack - Automated Installation Script
# This script automates the entire installation process described in INSTALL.md

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    
    print_status "Waiting for pods in namespace '$namespace' to be ready..."
    kubectl wait --for=condition=Ready pod --all -n "$namespace" --timeout=${timeout}s
    print_status "All pods in '$namespace' are ready!"
}

# Function to verify service accessibility
verify_service() {
    local url=$1
    local service_name=$2
    
    print_status "Verifying $service_name at $url..."
    if curl -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
        print_status "$service_name is accessible!"
        return 0
    else
        print_error "$service_name is not accessible at $url"
        return 1
    fi
}

# Function to build Java applications
build_java_apps() {
    print_step "Building Java applications..."
    
    # Check if apps directory exists
    if [ ! -d "apps" ]; then
        print_error "apps directory not found!"
        return 1
    fi
    
    # Build Quarkus application
    print_status "Building Quarkus application..."
    cd apps/quarkus-app
    if docker build -t quarkus-demo:latest .; then
        print_status "Quarkus image built successfully!"
    else
        print_error "Failed to build Quarkus image"
        return 1
    fi
    cd ../..
    
    # Build Spring Boot application
    print_status "Building Spring Boot application..."
    cd apps/springboot-app
    if docker build -t springboot-demo:latest .; then
        print_status "Spring Boot image built successfully!"
    else
        print_error "Failed to build Spring Boot image"
        return 1
    fi
    cd ../..
    
    print_status "All Java applications built successfully!"
}

# Function to deploy Java applications
deploy_java_apps() {
    print_step "Deploying Java applications..."
    
    # Load images into Kind cluster
    print_status "Loading Docker images into Kind cluster..."
    kind load docker-image quarkus-demo:latest --name argocd-lab
    kind load docker-image springboot-demo:latest --name argocd-lab
    
    # Create applications namespace
    print_status "Creating applications namespace..."
    kubectl create namespace applications --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Quarkus application
    print_status "Deploying Quarkus application..."
    if kubectl apply -f apps/quarkus-app/k8s-deployment.yaml; then
        print_status "Quarkus application deployed successfully!"
    else
        print_error "Failed to deploy Quarkus application"
        return 1
    fi
    
    # Deploy Spring Boot application
    print_status "Deploying Spring Boot application..."
    if kubectl apply -f apps/springboot-app/k8s-deployment.yaml; then
        print_status "Spring Boot application deployed successfully!"
    else
        print_error "Failed to deploy Spring Boot application"
        return 1
    fi
    
    print_status "All Java applications deployed successfully!"
}

# Function to verify Java applications
verify_java_apps() {
    print_step "Verifying Java applications..."
    
    # Wait for pods to be ready
    print_status "Waiting for Java application pods to be ready..."
    if kubectl wait --for=condition=Ready pod --all -n applications --timeout=300s; then
        print_status "All Java application pods are ready!"
    else
        print_error "Java application pods failed to become ready"
        return 1
    fi
    
    # Test Quarkus application
    print_status "Testing Quarkus application..."
    local quarkus_pod=$(kubectl get pods -n applications -l app=quarkus-demo -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n applications "$quarkus_pod" -- curl -s http://localhost:8080/actuator/health | grep -q "UP"; then
        print_status "Quarkus application health check passed!"
    else
        print_error "Quarkus application health check failed"
        return 1
    fi
    
    # Test Spring Boot application
    print_status "Testing Spring Boot application..."
    local springboot_pod=$(kubectl get pods -n applications -l app=springboot-demo -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec -n applications "$springboot_pod" -- curl -s http://localhost:8080/actuator/health | grep -q "UP"; then
        print_status "Spring Boot application health check passed!"
    else
        print_error "Spring Boot application health check failed"
        return 1
    fi
    
    # Test application endpoints
    print_status "Testing application endpoints..."
    
    # Test Quarkus hello endpoint
    if kubectl exec -n applications "$quarkus_pod" -- curl -s http://localhost:8080/hello/Test | grep -q "Hello"; then
        print_status "Quarkus hello endpoint working!"
    else
        print_error "Quarkus hello endpoint failed"
        return 1
    fi
    
    # Test Spring Boot hello endpoint
    if kubectl exec -n applications "$springboot_pod" -- curl -s http://localhost:8080/hello/Test | grep -q "Hello"; then
        print_status "Spring Boot hello endpoint working!"
    else
        print_error "Spring Boot hello endpoint failed"
        return 1
    fi
    
    # Test metrics endpoints
    print_status "Testing metrics endpoints..."
    
    # Test Quarkus metrics
    if kubectl exec -n applications "$quarkus_pod" -- curl -s http://localhost:8080/actuator/prometheus | grep -q "jvm_memory"; then
        print_status "Quarkus metrics endpoint working!"
    else
        print_error "Quarkus metrics endpoint failed"
        return 1
    fi
    
    # Test Spring Boot metrics
    if kubectl exec -n applications "$springboot_pod" -- curl -s http://localhost:8080/actuator/prometheus | grep -q "jvm_memory"; then
        print_status "Spring Boot metrics endpoint working!"
    else
        print_error "Spring Boot metrics endpoint failed"
        return 1
    fi
    
    print_status "All Java applications verified successfully!"
}

# Main installation function
main() {
    print_status "Starting Argo CD Lab with Complete Monitoring Stack installation..."
    
    # Check prerequisites
    print_step "Checking prerequisites..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists helm; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists kind; then
        print_error "kind is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists python3; then
        print_error "python3 is not installed or not in PATH"
        exit 1
    fi
    
    print_status "All prerequisites found!"
    
    # Step 1: Create Kind cluster configuration
    print_step "Creating Kind cluster configuration..."
    cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: argocd-lab
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
  - containerPort: 30443
    hostPort: 30443
    protocol: TCP
  - containerPort: 30090
    hostPort: 30090
    protocol: TCP
  - containerPort: 30100
    hostPort: 30100
    protocol: TCP
  - containerPort: 30111
    hostPort: 30111
    protocol: TCP
  - containerPort: 30120
    hostPort: 30120
    protocol: TCP
  - containerPort: 30140
    hostPort: 30140
    protocol: TCP
  - containerPort: 30150
    hostPort: 30150
    protocol: TCP
EOF
    print_status "Kind cluster configuration created!"
    
    # Step 2: Create Kind cluster
    print_step "Creating Kind cluster..."
    if kind get clusters | grep -q "argocd-lab"; then
        print_warning "Cluster 'argocd-lab' already exists. Deleting it first..."
        kind delete cluster --name argocd-lab
    fi
    
    kind create cluster --config kind-config.yaml
    kubectl cluster-info --context kind-argocd-lab
    print_status "Kind cluster created successfully!"
    
    # Step 3: Install Argo CD
    print_step "Installing Argo CD..."
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.0/manifests/install.yaml
    kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"name":"http","port":80,"targetPort":8080,"nodePort":30080},{"name":"https","port":443,"targetPort":8080,"nodePort":30443}]}}'
    print_status "Argo CD installed successfully!"
    
    # Step 4: Add Helm repositories
    print_step "Adding Helm repositories..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add grafana-alloy https://grafana.github.io/helm-charts
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo update
    print_status "Helm repositories added successfully!"
    
    # Step 5: Create monitoring namespace
    print_step "Creating monitoring namespace..."
    kubectl create namespace monitoring
    print_status "Monitoring namespace created!"
    
    # Step 6: Install Prometheus and Grafana stack
    print_step "Installing Prometheus and Grafana stack..."
    helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring \
        --set prometheus.service.type=NodePort \
        --set prometheus.service.nodePort=30090 \
        --set grafana.service.type=NodePort \
        --set grafana.service.nodePort=30100 \
        --set grafana.defaultDatasources.enabled=false \
        --set grafana.sidecar.datasources.enabled=false
    print_status "Prometheus and Grafana stack installed successfully!"
    
    # Step 7: Install Loki stack
    print_step "Installing Loki stack..."
    helm install loki grafana/loki-stack --namespace monitoring \
        --set service.type=NodePort \
        --set service.nodePort=30111 \
        --set loki.service.type=NodePort \
        --set loki.service.nodePort=30111
    print_status "Loki stack installed successfully!"
    
    # Step 8: Install Tempo
    print_step "Installing Tempo..."
    helm install tempo grafana/tempo --namespace monitoring \
        --set service.type=NodePort \
        --set service.nodePort=30120
    print_status "Tempo installed successfully!"
    
    # Step 9: Install Alloy
    print_step "Installing Alloy..."
    helm install alloy grafana-alloy/alloy --namespace monitoring \
        --set service.type=NodePort \
        --set service.nodePort=30140
    print_status "Alloy installed successfully!"
    
    # Step 10: Install Pyroscope
    print_step "Installing Pyroscope..."
    helm install pyroscope grafana/pyroscope --namespace monitoring \
        --set service.type=NodePort \
        --set service.nodePort=30150
    print_status "Pyroscope installed successfully!"
    
    # Step 11: Install OpenTelemetry Collector
    print_step "Installing OpenTelemetry Collector..."
    helm install opentelemetry-collector open-telemetry/opentelemetry-collector --namespace monitoring \
        --set service.type=NodePort \
        --set image.repository=otel/opentelemetry-collector-contrib \
        --set mode=deployment
    print_status "OpenTelemetry Collector installed successfully!"
    
    # Step 12: Install Tanka
    print_step "Installing Tanka..."
    if command_exists go; then
        go install github.com/grafana/tanka/cmd/tk@latest
        print_status "Tanka installed successfully!"
    else
        print_warning "Go is not installed. Skipping Tanka installation."
    fi
    
    # Step 13: Wait for pods to be ready
    print_step "Waiting for all pods to be ready..."
    wait_for_pods "argocd" 300
    wait_for_pods "monitoring" 600
    print_status "All pods are ready!"
    
    # Step 14: Configure Pyroscope NodePort
    print_step "Configuring Pyroscope NodePort..."
    kubectl patch svc pyroscope -n monitoring -p '{"spec":{"type":"NodePort","ports":[{"port":4040,"targetPort":4040,"nodePort":30150}]}}'
    print_status "Pyroscope NodePort configured!"
    
    # Step 15: Build Java applications
    build_java_apps
    
    # Step 16: Deploy Java applications
    deploy_java_apps
    
    # Step 17: Wait for Java application pods to be ready
    print_step "Waiting for Java application pods to be ready..."
    wait_for_pods "applications" 300
    print_status "Java application pods are ready!"
    
    # Step 18: Verify Java applications
    verify_java_apps
    
    # Step 19: Retrieve credentials
    print_step "Retrieving credentials..."
    
    # Argo CD password
    ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
    
    # Grafana password
    GRAFANA_PASSWORD=$(kubectl get secret prometheus-grafana -n monitoring -o jsonpath='{.data}' | python3 -c "import sys, json, base64; data=json.load(sys.stdin); print(base64.b64decode(data['admin-password']).decode())" 2>/dev/null || echo "Failed to retrieve")
    
    # Step 20: Verify service accessibility
    print_step "Verifying service accessibility..."
    
    # Give services a moment to start
    sleep 30
    
    verify_service "http://localhost:30080" "Argo CD"
    verify_service "http://localhost:30100" "Grafana"
    verify_service "http://localhost:30090" "Prometheus"
    verify_service "http://localhost:30111" "Loki"
    verify_service "http://localhost:31461" "Tempo"
    verify_service "http://localhost:30140" "Alloy"
    verify_service "http://localhost:30150" "Pyroscope"
    
    # Print final summary
    print_status "Installation completed successfully!"
    echo
    echo -e "${GREEN}=== ACCESS INFORMATION ===${NC}"
    echo -e "${BLUE}Argo CD:${NC}"
    echo "  URL: http://localhost:30080"
    echo "  Username: admin"
    echo "  Password: ${ARGOCD_PASSWORD}"
    echo
    echo -e "${BLUE}Grafana:${NC}"
    echo "  URL: http://localhost:30100"
    echo "  Username: admin"
    echo "  Password: ${GRAFANA_PASSWORD}"
    echo
    echo -e "${BLUE}Other Services:${NC}"
    echo "  Prometheus: http://localhost:30090"
    echo "  Loki: http://localhost:30111"
    echo "  Tempo: http://localhost:31461"
    echo "  Alloy: http://localhost:30140"
    echo "  Pyroscope: http://localhost:30150"
    echo
    echo -e "${BLUE}Java Applications:${NC}"
    echo "  Quarkus Demo: Deployed in namespace 'applications'"
    echo "    - Health: http://localhost:8080/actuator/health (via kubectl port-forward)"
    echo "    - Hello: http://localhost:8080/hello/{name} (via kubectl port-forward)"
    echo "    - Metrics: http://localhost:8080/actuator/prometheus (via kubectl port-forward)"
    echo "  Spring Boot Demo: Deployed in namespace 'applications'"
    echo "    - Health: http://localhost:8080/actuator/health (via kubectl port-forward)"
    echo "    - Hello: http://localhost:8080/hello/{name} (via kubectl port-forward)"
    echo "    - Metrics: http://localhost:8080/actuator/prometheus (via kubectl port-forward)"
    echo
    echo -e "${YELLOW}To access Java applications:${NC}"
    echo "  kubectl port-forward -n applications deployment/quarkus-demo 8081:8080"
    echo "  kubectl port-forward -n applications deployment/springboot-demo 8082:8080"
    echo
    print_status "Save these credentials for future use!"
    print_status "You can now access all services through your browser."
    print_status "Java applications are deployed and monitored by the Grafana stack!"
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Installation failed! Cleaning up..."
        # Optionally add cleanup commands here
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"
