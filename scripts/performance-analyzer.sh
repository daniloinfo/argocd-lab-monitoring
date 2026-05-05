#!/bin/bash

# Performance Analyzer Script
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
Performance Analyzer Script

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

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check k6
    if ! command -v k6 &> /dev/null; then
        log_error "k6 is not installed or not in PATH"
        exit 1
    fi
    
    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    log_info "Prerequisites validation completed"
}

# Collect current resource usage
collect_resource_usage() {
    log_info "Collecting current resource usage..."
    
    local resource_file="$OUTPUT_DIR/resource-usage-$(date +%Y%m%d-%H%M%S).json"
    
    # Get pods in namespace
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    local resource_data="{\"timestamp\":\"$(date -Iseconds)\",\"namespace\":\"$NAMESPACE\",\"pods\":["
    
    for pod in $pods; do
        log_verbose "Analyzing pod: $pod"
        
        # Get pod resource usage
        local cpu_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $2}' || echo "0m")
        local memory_usage=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' || echo "0Mi")
        
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

# Analyze resource usage and generate recommendations
analyze_resources() {
    log_info "Analyzing resource usage and generating recommendations..."
    
    local resource_file=$1
    local analysis_file="$OUTPUT_DIR/resource-analysis-$(date +%Y%m%d-%H%M%S).json"
    
    # Parse resource data and generate analysis
    python3 - << EOF
import json
import sys
from datetime import datetime

# Load resource data
with open('$resource_file', 'r') as f:
    data = json.load(f)

analysis = {
    "timestamp": datetime.now().isoformat(),
    "namespace": data["namespace"],
    "summary": {
        "total_pods": len(data["pods"]),
        "running_pods": len([p for p in data["pods"] if p["status"] == "Running"]),
        "quarkus_pods": len([p for p in data["pods"] if p["type"] == "Quarkus"]),
        "springboot_pods": len([p for p in data["pods"] if p["type"] == "Spring Boot"]),
    },
    "recommendations": [],
    "pod_analysis": []
}

# Analyze each pod
for pod in data["pods"]:
    pod_analysis = {
        "name": pod["name"],
        "type": pod["type"],
        "status": pod["status"],
        "current_usage": {
            "cpu": pod["cpu_usage"],
            "memory": pod["memory_usage"]
        },
        "resource_config": {
            "cpu_request": pod["cpu_request"],
            "cpu_limit": pod["cpu_limit"],
            "memory_request": pod["memory_request"],
            "memory_limit": pod["memory_limit"]
        },
        "recommendations": []
    }
    
    # CPU recommendations
    if pod["cpu_request"] == "not-set":
        pod_analysis["recommendations"].append({
            "type": "cpu_request",
            "severity": "high",
            "message": "Set CPU request for predictable performance",
            "suggested_value": "100m"
        })
    
    if pod["cpu_limit"] == "not-set":
        pod_analysis["recommendations"].append({
            "type": "cpu_limit",
            "severity": "medium",
            "message": "Set CPU limit to prevent resource starvation",
            "suggested_value": "500m"
        })
    
    # Memory recommendations
    if pod["memory_request"] == "not-set":
        pod_analysis["recommendations"].append({
            "type": "memory_request",
            "severity": "high",
            "message": "Set memory request for predictable performance",
            "suggested_value": "256Mi"
        })
    
    if pod["memory_limit"] == "not-set":
        pod_analysis["recommendations"].append({
            "type": "memory_limit",
            "severity": "medium",
            "message": "Set memory limit to prevent OOM kills",
            "suggested_value": "512Mi"
        })
    
    # Type-specific recommendations
    if pod["type"] == "Quarkus":
        pod_analysis["recommendations"].append({
            "type": "framework_specific",
            "severity": "low",
            "message": "Quarkus is optimized for low memory usage",
            "suggested_value": "Consider using smaller memory limits (128Mi-256Mi)"
        })
    elif pod["type"] == "Spring Boot":
        pod_analysis["recommendations"].append({
            "type": "framework_specific",
            "severity": "low",
            "message": "Spring Boot requires more memory for startup",
            "suggested_value": "Consider larger memory limits (512Mi-1Gi)"
        })
    
    analysis["pod_analysis"].append(pod_analysis)

# Generate overall recommendations
if analysis["summary"]["total_pods"] == 0:
    analysis["recommendations"].append({
        "type": "general",
        "severity": "high",
        "message": "No pods found in namespace",
        "suggested_value": "Check namespace and pod deployment"
    })

# Save analysis
with open('$analysis_file', 'w') as f:
    json.dump(analysis, f, indent=2)

print(analysis_file)
EOF
    
    echo "$analysis_file"
}

# Generate HTML report
generate_html_report() {
    log_info "Generating HTML report..."
    
    local resource_file=$1
    local analysis_file=$2
    local load_test_results=$3
    
    local html_report="$OUTPUT_DIR/$REPORT_FILE"
    
    python3 - << EOF
import json
import sys
from datetime import datetime

# Load data
resource_data = json.load(open('$resource_file'))
analysis_data = json.load(open('$analysis_file'))

load_test_data = {}
if '$load_test_results' and '$load_test_results' != '':
    try:
        load_test_data = json.load(open('$load_test_results'))
    except:
        pass

# Generate HTML report
html_content = '''<!DOCTYPE html>
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
        
        .load-test-results {
            margin-top: 20px;
        }
        
        .metric {
            display: flex;
            justify-content: space-between;
            padding: 10px;
            background: #f5f5f5;
            margin: 5px 0;
            border-radius: 5px;
        }
        
        .metric-name {
            font-weight: bold;
        }
        
        .metric-value {
            color: #667eea;
            font-weight: bold;
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
            <p>Namespace: {namespace} | Generated: {timestamp}</p>
        </div>
        
        <div class="summary-cards">
            <div class="card">
                <h3>Total Pods</h3>
                <div class="value">{total_pods}</div>
                <div class="description">Pods in namespace</div>
            </div>
            <div class="card">
                <h3>Running Pods</h3>
                <div class="value">{running_pods}</div>
                <div class="description">Currently running</div>
            </div>
            <div class="card">
                <h3>Quarkus Apps</h3>
                <div class="value">{quarkus_pods}</div>
                <div class="description">Quarkus applications</div>
            </div>
            <div class="card">
                <h3>Spring Boot Apps</h3>
                <div class="value">{springboot_pods}</div>
                <div class="description">Spring Boot applications</div>
            </div>
        </div>
        
        <div class="section">
            <div class="section-header">Pod Analysis</div>
            <div class="section-content">
                <div class="pod-grid">
                    {pod_cards}
                </div>
            </div>
        </div>
        
        {load_test_section}
        
        <div class="footer">
            <p>Generated by Performance Analyzer Script | Argo CD Lab</p>
        </div>
    </div>
</body>
</html>'''

# Generate pod cards
pod_cards = ""
for pod in analysis_data["pod_analysis"]:
    pod_type_class = pod["type"].lower().replace(" ", "")
    if pod_type_class == "springboot":
        pod_type_class = "springboot"
    
    pod_cards += f'''
    <div class="pod-card">
        <div class="pod-header">
            <div class="pod-name">{pod["name"]}</div>
            <div class="pod-type {pod_type_class}">{pod["type"]}</div>
        </div>
        
        <div class="resource-grid">
            <div class="resource-item">
                <div class="resource-label">CPU Usage</div>
                <div class="resource-value">{pod["current_usage"]["cpu"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">Memory Usage</div>
                <div class="resource-value">{pod["current_usage"]["memory"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">CPU Request</div>
                <div class="resource-value">{pod["resource_config"]["cpu_request"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">CPU Limit</div>
                <div class="resource-value">{pod["resource_config"]["cpu_limit"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">Memory Request</div>
                <div class="resource-value">{pod["resource_config"]["memory_request"]}</div>
            </div>
            <div class="resource-item">
                <div class="resource-label">Memory Limit</div>
                <div class="resource-value">{pod["resource_config"]["memory_limit"]}</div>
            </div>
        </div>
        
        <div class="recommendations">
            <h4>Recommendations:</h4>'''

    for rec in pod["recommendations"]:
        pod_cards += f'''
            <div class="recommendation {rec["severity"]}">
                <div class="recommendation-title">{rec["type"].replace("_", " ").title()}</div>
                <div class="recommendation-message">{rec["message"]}</div>
                <div class="recommendation-suggestion">Suggested: {rec["suggested_value"]}</div>
            </div>'''
    
    pod_cards += '''
        </div>
    </div>'''

# Generate load test section
load_test_section = ""
if load_test_data:
    load_test_section = '''
    <div class="section">
        <div class="section-header">Load Test Results</div>
        <div class="section-content">
            <div class="load-test-results">
                <h4>Test Configuration:</h4>
                <div class="metric">
                    <span class="metric-name">Virtual Users:</span>
                    <span class="metric-value">{vus}</span>
                </div>
                <div class="metric">
                    <span class="metric-name">Duration:</span>
                    <span class="metric-value">{duration}</span>
                </div>
                
                <h4>Performance Metrics:</h4>'''
    
    if "metrics" in load_test_data:
        for metric_name, metric_value in load_test_data["metrics"].items():
            if isinstance(metric_value, dict) and "value" in metric_value:
                load_test_section += f'''
                <div class="metric">
                    <span class="metric-name">{metric_name}:</span>
                    <span class="metric-value">{metric_value["value"]}</span>
                </div>'''
    
    load_test_section += '''
            </div>
        </div>
    </div>'''

# Replace placeholders
html_content = html_content.format(
    namespace=resource_data["namespace"],
    timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    total_pods=analysis_data["summary"]["total_pods"],
    running_pods=analysis_data["summary"]["running_pods"],
    quarkus_pods=analysis_data["summary"]["quarkus_pods"],
    springboot_pods=analysis_data["summary"]["springboot_pods"],
    pod_cards=pod_cards,
    load_test_section=load_test_section,
    vus=load_test_data.get("vus", "N/A"),
    duration=load_test_data.get("duration", "N/A")
)

# Save HTML report
with open('$html_report', 'w') as f:
    f.write(html_content)

print(html_report)
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
    
    # Analyze resources
    local analysis_file=$(analyze_resources "$resource_file")
    log_info "Resource analysis completed: $analysis_file"
    
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
    
    # Generate HTML report
    local html_report=$(generate_html_report "$resource_file" "$analysis_file" "$load_test_results")
    log_info "HTML report generated: $html_report"
    
    # Display summary
    echo
    echo -e "${GREEN}Performance Analysis Completed!${NC}"
    echo -e "${BLUE}Report Location:${NC} $html_report"
    echo -e "${BLUE}Resource Data:${NC} $resource_file"
    echo -e "${BLUE}Analysis Data:${NC} $analysis_file"
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
