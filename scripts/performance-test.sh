#!/bin/bash

# Simple Performance Test Script
# Test basic functionality before full implementation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="applications"
OUTPUT_DIR="performance-reports"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Test basic functionality
log_info "Testing basic performance analysis..."

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_error "Namespace '$NAMESPACE' does not exist"
    exit 1
fi

# Get pods
pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
log_info "Found pods: $pods"

# Collect basic resource data
resource_data="{\"timestamp\":\"$(date -Iseconds)\",\"namespace\":\"$NAMESPACE\",\"pods\":["
for pod in $pods; do
    log_info "Analyzing pod: $pod"
    
    # Get pod status
    status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    
    # Get pod type
    pod_type=$(./scripts/pod-type-detector.sh "$pod" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
    
    # Get resource usage
    cpu_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}' || echo "0m")
    memory_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' || echo "0Mi")
    
    # Get resource limits
    cpu_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "not-set")
    cpu_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "not-set")
    memory_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "not-set")
    memory_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "not-set")
    
    resource_data+="{\"name\":\"$pod\",\"type\":\"$pod_type\",\"status\":\"$status\","
    resource_data+="\"cpu_usage\":\"$cpu_usage\",\"memory_usage\":\"$memory_usage\","
    resource_data+="\"cpu_request\":\"$cpu_request\",\"cpu_limit\":\"$cpu_limit\","
    resource_data+="\"memory_request\":\"$memory_request\",\"memory_limit\":\"$memory_limit\"},"
done

# Remove trailing comma and close JSON
resource_data=${resource_data%,}
resource_data+="]}"

# Save resource data
resource_file="$OUTPUT_DIR/resource-data-$(date +%Y%m%d-%H%M%S).json"
echo "$resource_data" > "$resource_file"
log_info "Resource data saved to: $resource_file"

# Generate simple HTML report
html_file="$OUTPUT_DIR/performance-test-$(date +%Y%m%d-%H%M%S).html"

cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Performance Test Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .pod-card {
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 15px;
            margin: 10px 0;
            background: #fafafa;
        }
        .pod-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        .pod-name {
            font-weight: bold;
            font-size: 1.2em;
        }
        .pod-type {
            padding: 5px 10px;
            border-radius: 15px;
            font-size: 0.8em;
            font-weight: bold;
        }
        .quarkus { background: #4caf50; color: white; }
        .springboot { background: #ff9800; color: white; }
        .unknown { background: #9e9e9e; color: white; }
        .resource-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 10px;
            margin: 10px 0;
        }
        .resource-item {
            padding: 8px;
            background: white;
            border-radius: 4px;
            border-left: 3px solid #667eea;
        }
        .resource-label {
            font-weight: bold;
            color: #666;
            font-size: 0.9em;
        }
        .resource-value {
            color: #333;
            font-size: 1.1em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Performance Test Report</h1>
            <p>Namespace: $NAMESPACE | Generated: $(date)</p>
        </div>
EOF

# Add pod data to HTML
for pod in $pods; do
    pod_type=$(./scripts/pod-type-detector.sh "$pod" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
    status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    cpu_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}' || echo "0m")
    memory_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' || echo "0Mi")
    cpu_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "not-set")
    cpu_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "not-set")
    memory_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "not-set")
    memory_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "not-set")
    
    pod_type_class=$pod_type
    if [ "$pod_type_class" = "Spring Boot" ]; then
        pod_type_class="springboot"
    fi
    
    cat >> "$html_file" << EOF
        <div class="pod-card">
            <div class="pod-header">
                <div class="pod-name">$pod</div>
                <div class="pod-type $pod_type_class">$pod_type</div>
            </div>
            <div class="resource-grid">
                <div class="resource-item">
                    <div class="resource-label">Status</div>
                    <div class="resource-value">$status</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">CPU Usage</div>
                    <div class="resource-value">$cpu_usage</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">Memory Usage</div>
                    <div class="resource-value">$memory_usage</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">CPU Request</div>
                    <div class="resource-value">$cpu_request</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">CPU Limit</div>
                    <div class="resource-value">$cpu_limit</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">Memory Request</div>
                    <div class="resource-value">$memory_request</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">Memory Limit</div>
                    <div class="resource-value">$memory_limit</div>
                </div>
            </div>
        </div>
EOF
done

# Close HTML
cat >> "$html_file" << EOF
    </div>
</body>
</html>
EOF

log_info "HTML report generated: $html_file"
log_info "Test completed successfully!"

echo
echo -e "${GREEN}Performance Test Results:${NC}"
echo -e "${BLUE}Resource Data:${NC} $resource_file"
echo -e "${BLUE}HTML Report:${NC} $html_file"
echo
echo -e "${YELLOW}To view the report, open:${NC} $html_file"
