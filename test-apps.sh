#!/bin/bash

# Test Script for Argo CD Lab - Java Applications and Monitoring Stack
# This script tests all components to ensure everything is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Functions
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
    ((TESTS_TOTAL++))
}

test_passed() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

test_failed() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

# Test functions
test_service() {
    local service_name=$1
    local url=$2
    local expected_content=$3
    
    print_test "Testing $service_name at $url"
    if curl -s --connect-timeout 5 "$url" | grep -q "$expected_content"; then
        test_passed "$service_name is accessible"
        return 0
    else
        test_failed "$service_name is not accessible or content mismatch"
        return 1
    fi
}

test_k8s_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    print_test "Testing $resource_type $resource_name in namespace $namespace"
    if kubectl get "$resource_type" "$resource_name" -n "$namespace" --context kind-argocd-lab >/dev/null 2>&1; then
        test_passed "$resource_type $resource_name exists"
        return 0
    else
        test_failed "$resource_type $resource_name not found"
        return 1
    fi
}

test_pod_ready() {
    local pod_name=$1
    local namespace=$2
    
    print_test "Testing pod $pod_name readiness in namespace $namespace"
    local status=$(kubectl get pod "$pod_name" -n "$namespace" --context kind-argocd-lab -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$status" = "Running" ]; then
        local ready=$(kubectl get pod "$pod_name" -n "$namespace" --context kind-argocd-lab -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
        if [ "$ready" = "True" ]; then
            test_passed "Pod $pod_name is ready"
            return 0
        fi
    fi
    test_failed "Pod $pod_name is not ready (status: $status)"
    return 1
}

test_application_endpoint() {
    local app_name=$1
    local pod_selector=$2
    local namespace=$3
    local endpoint=$4
    local expected_content=$5
    
    print_test "Testing $app_name endpoint $endpoint"
    local pod_name=$(kubectl get pods -n "$namespace" -l "$pod_selector" --context kind-argocd-lab -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$pod_name" ]; then
        if kubectl exec -n "$namespace" "$pod_name" --context kind-argocd-lab -- curl -s "$endpoint" | grep -q "$expected_content" 2>/dev/null; then
            test_passed "$app_name endpoint $endpoint working"
            return 0
        fi
    fi
    test_failed "$app_name endpoint $endpoint failed"
    return 1
}

# Main test execution
main() {
    print_status "Starting comprehensive test suite for Argo CD Lab..."
    echo
    
    # Test 1: Core Services Accessibility
    print_status "=== Testing Core Services ==="
    
    test_service "Argo CD" "http://localhost:30080" "Argo CD"
    test_service "Grafana" "http://localhost:30100" "Grafana"
    test_service "Prometheus" "http://localhost:30090" "Prometheus"
    test_service "Loki" "http://localhost:30111" "Loki"
    test_service "Tempo" "http://localhost:31461" "Tempo"
    test_service "Alloy" "http://localhost:30140" "Alloy"
    test_service "Pyroscope" "http://localhost:30150" "Pyroscope"
    
    echo
    
    # Test 2: Kubernetes Resources
    print_status "=== Testing Kubernetes Resources ==="
    
    # Test namespaces
    test_k8s_resource "namespace" "argocd" ""
    test_k8s_resource "namespace" "monitoring" ""
    test_k8s_resource "namespace" "applications" ""
    
    # Test deployments
    test_k8s_resource "deployment" "quarkus-demo" "applications"
    test_k8s_resource "deployment" "springboot-demo" "applications"
    
    # Test services
    test_k8s_resource "service" "quarkus-demo-service" "applications"
    test_k8s_resource "service" "springboot-demo-service" "applications"
    
    echo
    
    # Test 3: Application Pods
    print_status "=== Testing Application Pods ==="
    
    # Get pod names and test readiness
    local quarkus_pods=$(kubectl get pods -n applications -l app=quarkus-demo --context kind-argocd-lab -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    local springboot_pods=$(kubectl get pods -n applications -l app=springboot-demo --context kind-argocd-lab -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    for pod in $quarkus_pods; do
        test_pod_ready "$pod" "applications"
    done
    
    for pod in $springboot_pods; do
        test_pod_ready "$pod" "applications"
    done
    
    echo
    
    # Test 4: Application Endpoints
    print_status "=== Testing Application Endpoints ==="
    
    # Test Quarkus application
    test_application_endpoint "Quarkus" "app=quarkus-demo" "applications" "http://localhost:8080/actuator/health" "UP"
    test_application_endpoint "Quarkus" "app=quarkus-demo" "applications" "http://localhost:8080/hello/Test" "Hello"
    test_application_endpoint "Quarkus" "app=quarkus-demo" "applications" "http://localhost:8080/actuator/prometheus" "jvm_memory"
    
    # Test Spring Boot application
    test_application_endpoint "Spring Boot" "app=springboot-demo" "applications" "http://localhost:8080/actuator/health" "UP"
    test_application_endpoint "Spring Boot" "app=springboot-demo" "applications" "http://localhost:8080/hello/Test" "Hello"
    test_application_endpoint "Spring Boot" "app=springboot-demo" "applications" "http://localhost:8080/actuator/prometheus" "jvm_memory"
    
    echo
    
    # Test 5: Monitoring Integration
    print_status "=== Testing Monitoring Integration ==="
    
    print_test "Testing Prometheus targets for Java applications"
    if curl -s "http://localhost:30090/api/v1/targets" | grep -q "quarkus-demo" 2>/dev/null && \
       curl -s "http://localhost:30090/api/v1/targets" | grep -q "springboot-demo" 2>/dev/null; then
        test_passed "Prometheus is scraping Java applications"
    else
        test_failed "Prometheus is not scraping Java applications"
    fi
    
    print_test "Testing metrics collection"
    if curl -s "http://localhost:30090/api/v1/query?query=jvm_memory_used_bytes" | grep -q "result" 2>/dev/null; then
        test_passed "JVM metrics are being collected"
    else
        test_failed "JVM metrics not found in Prometheus"
    fi
    
    echo
    
    # Print final results
    print_status "=== Test Results ==="
    echo -e "Total Tests: ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo
    
    if [ $TESTS_FAILED -eq 0 ]; then
        print_status "🎉 All tests passed! The Argo CD Lab is fully operational."
        echo
        print_status "You can now:"
        echo "  - Access Grafana at http://localhost:30100"
        echo "  - View Java application metrics in Grafana dashboards"
        echo "  - Monitor logs with Loki"
        echo "  - Analyze traces with Tempo"
        echo "  - Profile applications with Pyroscope"
        exit 0
    else
        print_error "❌ $TESTS_FAILED tests failed. Please check the installation."
        echo
        print_status "Troubleshooting tips:"
        echo "  - Check pod logs: kubectl logs -n <namespace> <pod-name>"
        echo "  - Verify services: kubectl get svc -n <namespace>"
        echo "  - Check cluster status: kubectl cluster-info"
        exit 1
    fi
}

# Run main function
main "$@"
