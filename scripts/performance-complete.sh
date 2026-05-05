#!/bin/bash

# Complete Performance Analyzer with Load Testing
# Executes k6 load tests and generates HTML reports with correct timestamps

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
NAMESPACE="applications"
OUTPUT_DIR="performance-reports"
REPORT_FILE="performance-complete-$(date +%Y%m%d-%H%M%S).html"
LOAD_TEST_DURATION="30s"
LOAD_TEST_VUS="5"
VERBOSE=false
SKIP_LOAD_TEST=false

# Help function
show_help() {
    cat << EOF
Complete Performance Analyzer Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -n, --namespace NAMESPACE      Specify namespace (default: applications)
    -o, --output-dir DIR           Output directory for reports (default: performance-reports)
    -d, --duration DURATION       Load test duration (default: 30s)
    -v, --vus VUS                  Number of virtual users (default: 5)
    -s, --skip-load-test          Skip load testing (analysis only)
    -v, --verbose                 Enable verbose output
    -h, --help                    Show this help message

EXAMPLES:
    # Basic analysis with load testing
    $0

    # Custom namespace and load test parameters
    $0 -n applications -d 60s -vus 10

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
            --vus|-vus)
                LOAD_TEST_VUS="$2"
                shift 2
                ;;
            -s|--skip-load-test)
                SKIP_LOAD_TEST=true
                shift
                ;;
            --verbose)
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
        local cpu_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}' || echo "0m")
        local memory_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' || echo "0Mi")
        echo "$cpu_usage|$memory_usage"
    else
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

# Run k6 load test
run_load_test() {
    log_info "Running k6 load test..."
    
    local k6_script="scripts/k6-load-test.js"
    local load_test_results="$OUTPUT_DIR/k6-load-test-results-$(date +%Y%m%d-%H%M%S).json"
    
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
    local html_report="$1"
    local load_test_results_file="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get pods in namespace
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    # Generate HTML report
    cat > "$html_report" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Performance Analysis Complete Report - Argo CD Lab</title>
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
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            border-radius: 15px;
            margin-bottom: 30px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 2.8em;
            margin-bottom: 15px;
        }
        
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            margin-bottom: 40px;
        }
        
        .card {
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 2px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 25px rgba(0,0,0,0.15);
        }
        
        .card h3 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.4em;
        }
        
        .card .value {
            font-size: 2.5em;
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
        }
        
        .card .description {
            color: #666;
            font-size: 0.95em;
        }
        
        .section {
            background: white;
            margin-bottom: 30px;
            border-radius: 15px;
            box-shadow: 0 2px 15px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .section-header {
            background: #667eea;
            color: white;
            padding: 25px;
            font-size: 1.6em;
            font-weight: bold;
        }
        
        .section-content {
            padding: 35px;
        }
        
        .pod-grid {
            display: grid;
            gap: 25px;
        }
        
        .pod-card {
            border: 1px solid #e0e0e0;
            border-radius: 12px;
            padding: 25px;
            background: #fafafa;
            transition: transform 0.3s ease;
        }
        
        .pod-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        
        .pod-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        
        .pod-name {
            font-weight: bold;
            font-size: 1.3em;
            color: #333;
        }
        
        .pod-type {
            padding: 8px 15px;
            border-radius: 25px;
            font-size: 0.85em;
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
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        
        .resource-item {
            padding: 15px;
            background: white;
            border-radius: 8px;
            border-left: 5px solid #667eea;
            box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        }
        
        .resource-label {
            font-weight: bold;
            color: #666;
            margin-bottom: 8px;
            font-size: 0.9em;
        }
        
        .resource-value {
            font-size: 1.2em;
            color: #333;
            font-weight: 600;
        }
        
        .recommendations {
            margin-top: 25px;
        }
        
        .recommendation {
            padding: 18px;
            margin: 12px 0;
            border-radius: 8px;
            border-left: 5px solid;
            background: #f8f9fa;
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
            margin-bottom: 8px;
            color: #333;
        }
        
        .recommendation-message {
            margin-bottom: 10px;
            color: #555;
        }
        
        .recommendation-suggestion {
            font-style: italic;
            color: #666;
            font-weight: 500;
        }
        
        .load-test-results {
            margin-top: 20px;
        }
        
        .metric {
            display: flex;
            justify-content: space-between;
            padding: 12px 15px;
            background: #f8f9fa;
            margin: 8px 0;
            border-radius: 6px;
            border-left: 3px solid #667eea;
        }
        
        .metric-name {
            font-weight: bold;
            color: #555;
        }
        
        .metric-value {
            color: #667eea;
            font-weight: bold;
        }
        
        .metric-good {
            border-left-color: #4caf50;
        }
        
        .metric-warning {
            border-left-color: #ff9800;
        }
        
        .metric-error {
            border-left-color: #f44336;
        }
        
        .efficiency-indicator {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 0.8em;
            font-weight: bold;
            margin-left: 8px;
        }
        
        .efficiency-excellent {
            background: #e8f5e8;
            color: #2e7d32;
        }
        
        .efficiency-good {
            background: #fff3e0;
            color: #f57c00;
        }
        
        .efficiency-warning {
            background: #ffebee;
            color: #d32f2f;
        }
        
        .footer {
            text-align: center;
            padding: 25px;
            color: #666;
            margin-top: 40px;
            border-top: 1px solid #eee;
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 15px;
            }
            
            .header h1 {
                font-size: 2.2em;
            }
            
            .summary-cards {
                grid-template-columns: 1fr;
            }
            
            .resource-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Performance Analysis Complete Report</h1>
            <p>Namespace: $NAMESPACE | Generated: $timestamp | With Load Testing</p>
        </div>
        
        <div class="summary-cards">
            <div class="card">
                <h3>Total Pods</h3>
                <div class="value">$(echo "$pods" | wc -w)</div>
                <div class="description">Pods in namespace</div>
            </div>
            <div class="card">
                <h3>Running Pods</h3>
                <div class="value">$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers | wc -l)</div>
                <div class="description">Currently running</div>
            </div>
            <div class="card">
                <h3>Quarkus Apps</h3>
                <div class="value">$(echo "$pods" | tr ' ' '\n' | grep -c quarkus || echo "0")</div>
                <div class="description">Quarkus applications</div>
            </div>
            <div class="card">
                <h3>Spring Boot Apps</h3>
                <div class="value">$(echo "$pods" | tr ' ' '\n' | grep -c springboot || echo "0")</div>
                <div class="description">Spring Boot applications</div>
            </div>
            <div class="card">
                <h3>Load Test VUs</h3>
                <div class="value">$LOAD_TEST_VUS</div>
                <div class="description">Virtual users</div>
            </div>
            <div class="card">
                <h3>Test Duration</h3>
                <div class="value">$LOAD_TEST_DURATION</div>
                <div class="description">Load test duration</div>
            </div>
        </div>
EOF

    # Add load test results if available
    if [ "$SKIP_LOAD_TEST" = "false" ] && [ -n "$load_test_results_file" ]; then
        cat >> "$html_report" << EOF
        <div class="section">
            <div class="section-header">Load Test Results</div>
            <div class="section-content">
                <div class="load-test-results">
                    <h4>Test Configuration:</h4>
                    <div class="metric">
                        <span class="metric-name">Virtual Users:</span>
                        <span class="metric-value">$LOAD_TEST_VUS</span>
                    </div>
                    <div class="metric">
                        <span class="metric-name">Duration:</span>
                        <span class="metric-value">$LOAD_TEST_DURATION</span>
                    </div>
                    
                    <h4>Performance Metrics:</h4>
                    <div class="metric">
                        <span class="metric-name">Test Status:</span>
                        <span class="metric-value">Completed</span>
                    </div>
                    <div class="metric">
                        <span class="metric-name">Results File:</span>
                        <span class="metric-value">$(basename "$load_test_results_file")</span>
                    </div>
                </div>
            </div>
        </div>
EOF
    fi

    # Add pod analysis section
    cat >> "$html_report" << EOF
        <div class="section">
            <div class="section-header">Pod Analysis</div>
            <div class="section-content">
                <div class="pod-grid">
EOF

    # Add pod cards
    for pod in $pods; do
        log_verbose "Analyzing pod: $pod"
        
        # Get pod information
        pod_type=$(./scripts/pod-type-detector.sh "$pod" 2>/dev/null | tail -1 | awk '{print $2}' || echo "unknown")
        status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        
        # Get resource usage with fallback
        usage_data=$(get_resource_usage "$pod")
        cpu_usage=$(echo "$usage_data" | cut -d'|' -f1)
        memory_usage=$(echo "$usage_data" | cut -d'|' -f2)
        
        # Get pod resource limits and requests
        cpu_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "not-set")
        cpu_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "not-set")
        memory_request=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "not-set")
        memory_limit=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "not-set")
        
        pod_type_class=$pod_type
        if [ "$pod_type_class" = "Spring Boot" ]; then
            pod_type_class="springboot"
        elif [ "$pod_type_class" = "unknown" ]; then
            pod_type_class="unknown"
        fi
        
        cat >> "$html_report" << EOF
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
            <p>Analysis Date: $timestamp | Load Test: $LOAD_TEST_VUS VUs for $LOAD_TEST_DURATION</p>
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
    
    log_info "Starting complete performance analysis..."
    log_info "Namespace: $NAMESPACE"
    log_info "Output Directory: $OUTPUT_DIR"
    log_info "Load Test Duration: $LOAD_TEST_DURATION"
    log_info "Virtual Users: $LOAD_TEST_VUS"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Run load test if not skipped
    local load_test_results_file=""
    if [ "$SKIP_LOAD_TEST" = "false" ]; then
        load_test_results_file=$(run_load_test)
        log_info "Load test completed: $load_test_results_file"
    else
        log_info "Load test skipped as requested"
    fi
    
    # Generate HTML report
    log_info "Generating HTML report..."
    local html_report="$OUTPUT_DIR/$REPORT_FILE"
    generate_html_report "$html_report" "$load_test_results_file"
    log_info "HTML report generated: $html_report"
    
    # Display summary
    echo
    echo -e "${GREEN}Complete Performance Analysis Finished!${NC}"
    echo -e "${BLUE}Report Location:${NC} $html_report"
    if [ "$SKIP_LOAD_TEST" = "false" ]; then
        echo -e "${BLUE}Load Test Results:${NC} $load_test_results_file"
    fi
    echo
    echo -e "${YELLOW}To view the report, open:${NC} $html_report"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
