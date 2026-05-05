#!/bin/bash

# Performance Analyzer Script - Fixed Version
# Analyzes CPU and memory usage of containers in applications namespace
# Uses k6 for load testing and generates detailed HTML report

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
NAMESPACE="applications"
OUTPUT_DIR="performance-reports"
REPORT_FILE="performance-analysis-$(date +%Y%m%d-%H%M%S).html"
LOAD_TEST_DURATION="30s"
LOAD_TEST_VUS="10"
VERBOSE=false
SKIP_LOAD_TEST=false

# Help function
show_help() {
    cat << EOF
Performance Analyzer Script - Fixed Version

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -n, --namespace NAMESPACE      Specify namespace (default: applications)
    -o, --output-dir DIR           Output directory for reports (default: performance-reports)
    -d, --duration DURATION       Load test duration (default: 30s)
    -v, --vus VUS                  Number of virtual users (default: 10)
    -s, --skip-load-test          Skip load testing (analysis only)
    -v, --verbose                 Enable verbose output
    -h, --help                    Show this help message

EXAMPLES:
    # Basic analysis with load testing
    $0

    # Custom namespace and load test parameters
    $0 -n applications -d 60s -vus 20

    # Analysis only (no load testing)
    $0 -s

    # Verbose mode with custom output
    $0 -v -o /tmp/reports

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -d|--duration)
                LOAD_TEST_DURATION="$2"
                shift 2
                ;;
            -v|--vus)
                LOAD_TEST_VUS="$2"
                shift 2
                ;;
            -s|--skip-load-test)
                SKIP_LOAD_TEST=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                shift
                ;;
        esac
    done
}

# Check if metrics-server is available
check_metrics_server() {
    if kubectl top pod --help &>/dev/null; then
        # Try to get metrics for any pod to test if metrics-server is working
        if kubectl top pod -n kube-system --no-headers &>/dev/null; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

# Get resource usage with fallback
get_resource_usage() {
    local pod=$1
    local metrics_available=$(check_metrics_server)
    
    if [ "$metrics_available" = "true" ]; then
        log_verbose "Using metrics-server for resource usage"
        local cpu_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}' || echo "0m")
        local memory_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' || echo "0Mi")
        echo "$cpu_usage|$memory_usage"
    else
        log_verbose "Metrics-server not available, using estimates"
        # Use estimates based on pod type and configuration
        local cpu_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "100m")
        local memory_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "128Mi")
        
        # Estimate usage (typically 50-80% of requests for running applications)
        local cpu_usage=$(echo "$cpu_request" | sed 's/m//' | awk '{printf "%.0fm", $1 * 0.6}')
        local memory_usage=$(echo "$memory_request" | sed 's/Mi//' | awk '{printf "%.0fMi", $1 * 0.7}')
        
        echo "$cpu_usage|$memory_usage"
    fi
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check k6 (only if not skipping load test)
    if [ "$SKIP_LOAD_TEST" = "false" ]; then
        if ! command -v k6 &> /dev/null; then
            log_error "k6 is not installed or not in PATH"
            exit 1
        fi
    fi
    
    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Check metrics-server
    local metrics_available=$(check_metrics_server)
    if [ "$metrics_available" = "false" ]; then
        log_warn "Metrics-server is not available, using estimated resource usage"
        log_warn "For accurate metrics, install metrics-server: kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    else
        log_info "Metrics-server is available, using real resource usage"
    fi
    
    log_info "Prerequisites validation completed"
}

# Collect current resource usage
collect_resource_usage() {
    log_info "Collecting current resource usage..."
    
    local resource_file="$OUTPUT_DIR/resource-usage-$(date +%Y%m%d-%H%M%S).json"
    
    # Get pods in namespace
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    local resource_data="{\"timestamp\":\"$(date -Iseconds)\",\"namespace\":\"$NAMESPACE\",\"metrics_available\":\"$(check_metrics_server)\",\"pods\":["
    
    for pod in $pods; do
        log_verbose "Analyzing pod: $pod"
        
        # Get resource usage with fallback
        local usage_data=$(get_resource_usage "$pod")
        local cpu_usage=$(echo "$usage_data" | cut -d'|' -f1)
        local memory_usage=$(echo "$usage_data" | cut -d'|' -f2)
        
        # Get pod resource limits and requests
        local cpu_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "not-set")
        local cpu_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "not-set")
        local memory_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "not-set")
        local memory_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "not-set")
        
        # Get pod status
        local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        
        # Get pod type
        local pod_type=$(./scripts/pod-type-detector.sh "$pod" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
        
        resource_data+="{\"name\":\"$pod\",\"type\":\"$pod_type\",\"status\":\"$status\","
        resource_data+="\"cpu_usage\":\"$cpu_usage\",\"memory_usage\":\"$memory_usage\","
        resource_data+="\"cpu_request\":\"$cpu_request\",\"cpu_limit\":\"$cpu_limit\","
        resource_data+="\"memory_request\":\"$memory_request\",\"memory_limit\":\"$memory_limit\"},"
    done
    
    # Remove trailing comma and close JSON
    resource_data=${resource_data%,}
    resource_data+="]}"
    
    echo "$resource_data" > "$resource_file"
    echo "$resource_file"
}

# Create k6 load test script
create_k6_test_script() {
    log_info "Creating k6 load test script..."
    
    local k6_script="$OUTPUT_DIR/load-test-$(date +%Y%m%d-%H%M%S).js"
    
    cat > "$k6_script" << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');
export let responseTime = new Trend('response_time');

// Test configuration
export let options = {
    stages: [
        { duration: '10s', target: __ENV.VUS },
        { duration: __ENV.DURATION, target: __ENV.VUS },
        { duration: '10s', target: 0 },
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'],
        http_req_failed: ['rate<0.1'],
    },
};

// Test data
const endpoints = [
    'http://localhost:8081/actuator/health',
    'http://localhost:8081/actuator/info',
    'http://localhost:8081/hello',
    'http://localhost:8082/actuator/health',
    'http://localhost:8082/actuator/info',
    'http://localhost:8082/hello',
];

export default function () {
    // Test each endpoint
    for (let endpoint of endpoints) {
        let response = http.get(endpoint);
        
        check(response, {
            'status is 200': (r) => r.status === 200,
            'response time < 500ms': (r) => r.timings.duration < 500,
        });
        
        errorRate.add(response.status !== 200);
        responseTime.add(response.timings.duration);
        
        sleep(0.1);
    }
}

export function handleSummary(data) {
    return {
        'performance-summary.json': JSON.stringify(data, null, 2),
        stdout: textSummary(data, { indent: ' ', enableColors: true }),
    };
}
EOF
    
    echo "$k6_script"
}

# Run k6 load test
run_load_test() {
    log_info "Running k6 load test..."
    
    local k6_script=$1
    local load_test_results="$OUTPUT_DIR/load-test-results-$(date +%Y%m%d-%H%M%S).json"
    
    # Set environment variables for k6
    export VUS="$LOAD_TEST_VUS"
    export DURATION="$LOAD_TEST_DURATION"
    
    # Run k6 test
    if k6 run --summary-export "$load_test_results" "$k6_script" 2>/dev/null; then
        log_info "Load test completed successfully"
    else
        log_warn "Load test failed or had issues"
    fi
    
    echo "$load_test_results"
}

# Generate comprehensive HTML report
generate_html_report() {
    log_info "Generating HTML report..."
    
    local resource_file=$1
    local html_report="$OUTPUT_DIR/$REPORT_FILE"
    
    # Read resource data
    local resource_data=$(cat "$resource_file")
    local metrics_available=$(echo "$resource_data" | jq -r '.metrics_available // "false"')
    
    # Generate HTML report
    cat > "$html_report" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Performance Analysis Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .metrics-warning {
            background: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 20px;
            color: #856404;
        }
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
        }
        
        .card h3 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.3em;
        }
        
        .card .value {
            font-size: 2em;
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
        }
        
        .card .description {
            color: #666;
            font-size: 0.9em;
        }
        
        .section {
            background: white;
            margin-bottom: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .section-header {
            background: #667eea;
            color: white;
            padding: 20px;
            font-size: 1.5em;
            font-weight: bold;
        }
        
        .section-content {
            padding: 30px;
        }
        
        .pod-grid {
            display: grid;
            gap: 20px;
        }
        
        .pod-card {
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            background: #fafafa;
        }
        
        .pod-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }
        
        .pod-name {
            font-weight: bold;
            font-size: 1.2em;
            color: #333;
        }
        
        .pod-type {
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
        }
        
        .quarkus {
            background: #4caf50;
            color: white;
        }
        
        .springboot {
            background: #ff9800;
            color: white;
        }
        
        .unknown {
            background: #9e9e9e;
            color: white;
        }
        
        .resource-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 15px 0;
        }
        
        .resource-item {
            padding: 10px;
            background: white;
            border-radius: 5px;
            border-left: 4px solid #667eea;
        }
        
        .resource-label {
            font-weight: bold;
            color: #666;
            margin-bottom: 5px;
        }
        
        .resource-value {
            font-size: 1.1em;
            color: #333;
        }
        
        .estimated {
            font-style: italic;
            color: #666;
            font-size: 0.9em;
        }
        
        .recommendations {
            margin-top: 20px;
        }
        
        .recommendation {
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            border-left: 4px solid;
        }
        
        .high {
            background: #ffebee;
            border-left-color: #f44336;
        }
        
        .medium {
            background: #fff3e0;
            border-left-color: #ff9800;
        }
        
        .low {
            background: #f3e5f5;
            border-left-color: #9c27b0;
        }
        
        .recommendation-title {
            font-weight: bold;
            margin-bottom: 5px;
        }
        
        .recommendation-message {
            margin-bottom: 10px;
        }
        
        .recommendation-suggestion {
            font-style: italic;
            color: #666;
        }
        
        .footer {
            text-align: center;
            padding: 20px;
            color: #666;
            margin-top: 30px;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 10px;
            }
            
            .header h1 {
                font-size: 2em;
            }
            
            .summary-cards {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Performance Analysis Report</h1>
            <p>Namespace: $NAMESPACE | Generated: $(date)</p>
        </div>
EOF

    # Add metrics warning if needed
    if [ "$metrics_available" = "false" ]; then
        cat >> "$html_report" << EOF
        <div class="metrics-warning">
            <strong>⚠️ Metrics Server Not Available</strong><br>
            Resource usage data shown below are estimates based on configured requests. 
            For accurate metrics, install metrics-server with: 
            <code>kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml</code>
        </div>
EOF
    fi
    
    # Add summary cards
    local total_pods=$(echo "$resource_data" | jq -r '.pods | length')
    local running_pods=$(echo "$resource_data" | jq -r '.pods[] | select(.status == "Running") | .name' | wc -l)
    local quarkus_pods=$(echo "$resource_data" | jq -r '.pods[] | select(.type == "Quarkus") | .name' | wc -l)
    local springboot_pods=$(echo "$resource_data" | jq -r '.pods[] | select(.type == "Spring Boot") | .name' | wc -l)
    
    cat >> "$html_report" << EOF
        <div class="summary-cards">
            <div class="card">
                <h3>Total Pods</h3>
                <div class="value">$total_pods</div>
                <div class="description">Pods in namespace</div>
            </div>
            <div class="card">
                <h3>Running Pods</h3>
                <div class="value">$running_pods</div>
                <div class="description">Currently running</div>
            </div>
            <div class="card">
                <h3>Quarkus Apps</h3>
                <div class="value">$quarkus_pods</div>
                <div class="description">Quarkus applications</div>
            </div>
            <div class="card">
                <h3>Spring Boot Apps</h3>
                <div class="value">$springboot_pods</div>
                <div class="description">Spring Boot applications</div>
            </div>
        </div>
        
        <div class="section">
            <div class="section-header">Pod Analysis</div>
            <div class="section-content">
                <div class="pod-grid">
EOF

    # Add pod cards
    echo "$resource_data" | jq -r '.pods[] | @base64' | while read -r pod; do
        local pod_data=$(echo "$pod" | base64 -d)
        local pod_name=$(echo "$pod_data" | jq -r '.name')
        local pod_type=$(echo "$pod_data" | jq -r '.type')
        local pod_status=$(echo "$pod_data" | jq -r '.status')
        local cpu_usage=$(echo "$pod_data" | jq -r '.cpu_usage')
        local memory_usage=$(echo "$pod_data" | jq -r '.memory_usage')
        local cpu_request=$(echo "$pod_data" | jq -r '.cpu_request')
        local cpu_limit=$(echo "$pod_data" | jq -r '.cpu_limit')
        local memory_request=$(echo "$pod_data" | jq -r '.memory_request')
        local memory_limit=$(echo "$pod_data" | jq -r '.memory_limit')
        
        local pod_type_class=$pod_type
        if [ "$pod_type_class" = "Spring Boot" ]; then
            pod_type_class="springboot"
        elif [ "$pod_type_class" = "unknown" ]; then
            pod_type_class="unknown"
        fi
        
        local usage_class=""
        if [ "$metrics_available" = "false" ]; then
            usage_class="estimated"
        fi
        
        cat >> "$html_report" << EOF
                    <div class="pod-card">
                        <div class="pod-header">
                            <div class="pod-name">$pod_name</div>
                            <div class="pod-type $pod_type_class">$pod_type</div>
                        </div>
                        
                        <div class="resource-grid">
                            <div class="resource-item">
                                <div class="resource-label">Status</div>
                                <div class="resource-value">$pod_status</div>
                            </div>
                            <div class="resource-item">
                                <div class="resource-label">CPU Usage</div>
                                <div class="resource-value">$cpu_usage</div>
                                <div class="resource-label $usage_class">$([ "$metrics_available" = "false" ] && echo "Estimated")</div>
                            </div>
                            <div class="resource-item">
                                <div class="resource-label">Memory Usage</div>
                                <div class="resource-value">$memory_usage</div>
                                <div class="resource-label $usage_class">$([ "$metrics_available" = "false" ] && echo "Estimated")</div>
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
                        
                        <div class="recommendations">
                            <h4>Recommendations:</h4>
EOF

        # Generate recommendations based on configuration
        if [ "$cpu_request" = "not-set" ]; then
            cat >> "$html_report" << EOF
                            <div class="recommendation high">
                                <div class="recommendation-title">CPU Request Missing</div>
                                <div class="recommendation-message">Set CPU request for predictable performance</div>
                                <div class="recommendation-suggestion">Suggested: 100m</div>
                            </div>
EOF
        fi
        
        if [ "$memory_request" = "not-set" ]; then
            cat >> "$html_report" << EOF
                            <div class="recommendation high">
                                <div class="recommendation-title">Memory Request Missing</div>
                                <div class="recommendation-message">Set memory request for predictable performance</div>
                                <div class="recommendation-suggestion">Suggested: 256Mi</div>
                            </div>
EOF
        fi
        
        if [ "$cpu_limit" = "not-set" ]; then
            cat >> "$html_report" << EOF
                            <div class="recommendation medium">
                                <div class="recommendation-title">CPU Limit Missing</div>
                                <div class="recommendation-message">Set CPU limit to prevent resource starvation</div>
                                <div class="recommendation-suggestion">Suggested: 500m</div>
                            </div>
EOF
        fi
        
        if [ "$memory_limit" = "not-set" ]; then
            cat >> "$html_report" << EOF
                            <div class="recommendation medium">
                                <div class="recommendation-title">Memory Limit Missing</div>
                                <div class="recommendation-message">Set memory limit to prevent OOM kills</div>
                                <div class="recommendation-suggestion">Suggested: 512Mi</div>
                            </div>
EOF
        fi
        
        # Framework-specific recommendations
        if [ "$pod_type" = "Quarkus" ]; then
            cat >> "$html_report" << EOF
                            <div class="recommendation low">
                                <div class="recommendation-title">Framework Optimization</div>
                                <div class="recommendation-message">Quarkus is optimized for low memory usage</div>
                                <div class="recommendation-suggestion">Consider using smaller memory limits (128Mi-256Mi)</div>
                            </div>
EOF
        elif [ "$pod_type" = "Spring Boot" ]; then
            cat >> "$html_report" << EOF
                            <div class="recommendation low">
                                <div class="recommendation-title">Framework Optimization</div>
                                <div class="recommendation-message">Spring Boot requires more memory for startup</div>
                                <div class="recommendation-suggestion">Consider larger memory limits (512Mi-1Gi)</div>
                            </div>
EOF
        fi
        
        cat >> "$html_report" << EOF
                        </div>
                    </div>
EOF
    done
    
    # Close HTML
    cat >> "$html_report" << EOF
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>Generated by Performance Analyzer Script | Argo CD Lab</p>
        </div>
    </div>
</body>
</html>
EOF
    
    echo "$html_report"
}

# Main function
main() {
    parse_args "$@"
    
    log_info "Starting performance analysis..."
    log_info "Namespace: $NAMESPACE"
    log_info "Output Directory: $OUTPUT_DIR"
    log_info "Load Test Duration: $LOAD_TEST_DURATION"
    log_info "Virtual Users: $LOAD_TEST_VUS"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Collect resource usage
    local resource_file=$(collect_resource_usage)
    log_info "Resource usage collected: $resource_file"
    
    # Generate HTML report
    local html_report=$(generate_html_report "$resource_file")
    log_info "HTML report generated: $html_report"
    
    # Run load test if not skipped
    local load_test_results=""
    if [ "$SKIP_LOAD_TEST" = "false" ]; then
        local k6_script=$(create_k6_test_script)
        log_info "K6 script created: $k6_script"
        
        load_test_results=$(run_load_test "$k6_script")
        log_info "Load test completed: $load_test_results"
    else
        log_info "Load test skipped as requested"
    fi
    
    # Display summary
    echo
    echo -e "${GREEN}Performance Analysis Completed!${NC}"
    echo -e "${BLUE}Report Location:${NC} $html_report"
    echo -e "${BLUE}Resource Data:${NC} $resource_file"
    if [ "$SKIP_LOAD_TEST" = "false" ]; then
        echo -e "${BLUE}Load Test Results:${NC} $load_test_results"
    fi
    echo
    echo -e "${YELLOW}To view the report, open:${NC} $html_report"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
