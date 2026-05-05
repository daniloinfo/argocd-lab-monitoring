#!/bin/bash

# Simple Performance Analyzer with Fixed Resource Usage
# Solves the issue where CPU and Memory Usage were not appearing

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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

log_info "Starting performance analysis with fixed resource usage..."

# Check if metrics-server is available
METRICS_AVAILABLE="false"
if kubectl top pod --help &>/dev/null && kubectl top pod -n kube-system --no-headers &>/dev/null; then
    METRICS_AVAILABLE="true"
    log_info "Metrics-server is available - using real resource usage"
else
    log_warn "Metrics-server not available - using estimated resource usage"
fi

# Get pods
pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
log_info "Found pods: $pods"

# Generate HTML report with fixed resource usage
html_file="$OUTPUT_DIR/performance-fixed-$(date +%Y%m%d-%H%M%S).html"

cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Performance Analysis Report - Fixed</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
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
        .metrics-warning {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
            color: #856404;
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
        .estimated {
            font-style: italic;
            color: #666;
            font-size: 0.9em;
        }
        .recommendation {
            padding: 10px;
            margin: 5px 0;
            border-radius: 5px;
            border-left: 4px solid #ff9800;
            background: #fff3e0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Performance Analysis Report - Fixed</h1>
            <p>Namespace: $NAMESPACE | Generated: $(date)</p>
        </div>
EOF

# Add metrics warning if needed
if [ "$METRICS_AVAILABLE" = "false" ]; then
    cat >> "$html_file" << EOF
        <div class="metrics-warning">
            <strong>⚠️ Metrics Server Not Available</strong><br>
            Resource usage data shown below are estimates based on configured requests. 
            For accurate metrics, install metrics-server with: 
            <code>kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml</code>
        </div>
EOF
fi

# Add pod data to HTML
for pod in $pods; do
    log_info "Analyzing pod: $pod"
    
    # Get pod information
    pod_type=$(./scripts/pod-type-detector.sh "$pod" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
    status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    cpu_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "not-set")
    cpu_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "not-set")
    memory_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "not-set")
    memory_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "not-set")
    
    # Get resource usage with fallback
    if [ "$METRICS_AVAILABLE" = "true" ]; then
        cpu_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}' || echo "0m")
        memory_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' || echo "0Mi")
        usage_class=""
        usage_note=""
    else
        # Estimate usage based on requests (60% CPU, 70% Memory)
        if [ "$cpu_request" != "not-set" ]; then
            cpu_usage=$(echo "$cpu_request" | sed 's/m//' | awk '{printf "%.0fm", $1 * 0.6}')
        else
            cpu_usage="60m"  # Default estimate
        fi
        
        if [ "$memory_request" != "not-set" ]; then
            memory_usage=$(echo "$memory_request" | sed 's/Mi//' | awk '{printf "%.0fMi", $1 * 0.7}')
        else
            memory_usage="90Mi"  # Default estimate
        fi
        usage_class="estimated"
        usage_note="Estimated"
    fi
    
    pod_type_class=$pod_type
    if [ "$pod_type_class" = "Spring Boot" ]; then
        pod_type_class="springboot"
    elif [ "$pod_type_class" = "unknown" ]; then
        pod_type_class="unknown"
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
                    <div class="resource-label $usage_class">$usage_note</div>
                </div>
                <div class="resource-item">
                    <div class="resource-label">Memory Usage</div>
                    <div class="resource-value">$memory_usage</div>
                    <div class="resource-label $usage_class">$usage_note</div>
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
EOF

    # Add recommendations
    cat >> "$html_file" << EOF
            <div class="recommendation">
                <strong>Recommendations:</strong><br>
EOF

    if [ "$cpu_request" = "not-set" ]; then
        cat >> "$html_file" << EOF
                • Set CPU request for predictable performance (suggested: 100m)<br>
EOF
    fi

    if [ "$memory_request" = "not-set" ]; then
        cat >> "$html_file" << EOF
                • Set memory request for predictable performance (suggested: 256Mi)<br>
EOF
    fi

    if [ "$cpu_limit" = "not-set" ]; then
        cat >> "$html_file" << EOF
                • Set CPU limit to prevent resource starvation (suggested: 500m)<br>
EOF
    fi

    if [ "$memory_limit" = "not-set" ]; then
        cat >> "$html_file" << EOF
                • Set memory limit to prevent OOM kills (suggested: 512Mi)<br>
EOF
    fi

    if [ "$pod_type" = "Quarkus" ]; then
        cat >> "$html_file" << EOF
                • Quarkus is optimized for low memory usage (consider 128Mi-256Mi)<br>
EOF
    elif [ "$pod_type" = "Spring Boot" ]; then
        cat >> "$html_file" << EOF
                • Spring Boot requires more memory (consider 512Mi-1Gi)<br>
EOF
    fi

    cat >> "$html_file" << EOF
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
log_info "Analysis completed successfully!"

echo
echo -e "${GREEN}Performance Analysis Results:${NC}"
echo -e "${BLUE}HTML Report:${NC} $html_report"
echo
echo -e "${YELLOW}To view the report, open:${NC} $html_report"
echo
echo -e "${BLUE}Resource Usage Status:${NC}"
if [ "$METRICS_AVAILABLE" = "true" ]; then
    echo -e "${GREEN}✓ Real metrics from metrics-server${NC}"
else
    echo -e "${YELLOW}⚠ Estimated metrics (metrics-server not available)${NC}"
    echo -e "${YELLOW}  To install metrics-server:${NC}"
    echo -e "${YELLOW}  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml${NC}"
fi
