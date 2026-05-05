#!/bin/bash

# Pod Type Identification Script
# Identifies whether a pod is running Quarkus or Spring Boot application
# Supports multiple detection methods for reliability

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
NAMESPACE=""
POD_NAME=""
OUTPUT_FORMAT="table"
VERBOSE=false
ALL_PODS=false

# Help function
show_help() {
    cat << EOF
Pod Type Identification Script

USAGE:
    $0 [OPTIONS] [POD_NAME]

OPTIONS:
    -n, --namespace NAMESPACE    Specify namespace (default: current namespace)
    -o, --output FORMAT        Output format: table|json|yaml|csv (default: table)
    -v, --verbose              Enable verbose output
    -a, --all                 Analyze all pods in namespace
    -h, --help               Show this help message

EXAMPLES:
    # Identify specific pod
    $0 -n applications quarkus-demo-7d8f9c9b9-abc12

    # Analyze all pods in namespace
    $0 -n applications --all

    # Output in JSON format
    $0 -n applications -o json quarkus-demo-7d8f9c9b9-abc12

    # Verbose mode with table output
    $0 -n applications -v quarkus-demo-7d8f9c9b9-abc12

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
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -a|--all)
                ALL_PODS=true
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
                POD_NAME="$1"
                shift
                ;;
        esac
    done
}

# Validate arguments
validate_args() {
    if [ "$ALL_PODS" = false ] && [ -z "$POD_NAME" ]; then
        log_error "Pod name is required when not using --all option"
        show_help
        exit 1
    fi

    if [ -z "$NAMESPACE" ]; then
        NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')
        if [ -z "$NAMESPACE" ]; then
            NAMESPACE="default"
        fi
        log_verbose "Using namespace: $NAMESPACE"
    fi

    case $OUTPUT_FORMAT in
        table|json|yaml|csv)
            ;;
        *)
            log_error "Invalid output format: $OUTPUT_FORMAT"
            show_help
            exit 1
            ;;
    esac
}

# Check if pod exists
check_pod_exists() {
    local pod=$1
    if ! kubectl get pod "$pod" -n "$NAMESPACE" &>/dev/null; then
        log_error "Pod '$pod' not found in namespace '$NAMESPACE'"
        return 1
    fi
    return 0
}

# Method 1: Check pod labels and annotations
check_labels_annotations() {
    local pod=$1
    local result=""
    
    log_verbose "Checking labels and annotations for pod: $pod"
    
    # Check app label
    local app_label=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.app}' 2>/dev/null || echo "")
    
    # Check annotations
    local annotations=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.metadata.annotations}' 2>/dev/null || echo "")
    
    # Detection based on app label
    if [[ "$app_label" == *"quarkus"* ]]; then
        result="quarkus"
    elif [[ "$app_label" == *"springboot"* ]]; then
        result="springboot"
    fi
    
    # Detection based on annotations
    if [[ "$annotations" == *"quarkus"* ]]; then
        result="quarkus"
    elif [[ "$annotations" == *"springboot"* ]]; then
        result="springboot"
    fi
    
    echo "$result"
}

# Method 2: Check image name
check_image_name() {
    local pod=$1
    local result=""
    
    log_verbose "Checking image name for pod: $pod"
    
    local image=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || echo "")
    
    if [[ "$image" == *"quarkus"* ]]; then
        result="quarkus"
    elif [[ "$image" == *"springboot"* ]]; then
        result="springboot"
    fi
    
    echo "$result"
}

# Method 3: Check environment variables
check_environment() {
    local pod=$1
    local result=""
    
    log_verbose "Checking environment variables for pod: $pod"
    
    local env_vars=$(kubectl exec "$pod" -n "$NAMESPACE" -- printenv 2>/dev/null || echo "")
    
    # Check for Spring Boot specific environment variables
    if echo "$env_vars" | grep -q "SPRING_APPLICATION_NAME\|spring.profiles\|management.endpoints"; then
        result="springboot"
    fi
    
    # Check for Quarkus specific environment variables
    if echo "$env_vars" | grep -q "QUARKUS\|quarkus\|mp.metrics"; then
        result="quarkus"
    fi
    
    echo "$result"
}

# Method 4: Check endpoints and paths
check_endpoints() {
    local pod=$1
    local result=""
    
    log_verbose "Checking endpoints for pod: $pod"
    
    # Check if pod is ready and accessible
    if ! kubectl exec "$pod" -n "$NAMESPACE" -- curl -s http://localhost:8080/actuator/info &>/dev/null; then
        echo "unknown"
        return
    fi
    
    # Check actuator endpoints
    local info_response=$(kubectl exec "$pod" -n "$NAMESPACE" -- curl -s http://localhost:8080/actuator/info 2>/dev/null || echo "")
    
    # Check for Spring Boot specific info
    if echo "$info_response" | grep -q "Spring Boot\|spring-boot"; then
        result="springboot"
    fi
    
    # Check for Quarkus specific info
    if echo "$info_response" | grep -q "Quarkus\|quarkus\|SmallRye"; then
        result="quarkus"
    fi
    
    echo "$result"
}

# Method 5: Check metrics endpoint
check_metrics() {
    local pod=$1
    local result=""
    
    log_verbose "Checking metrics endpoint for pod: $pod"
    
    # Check Prometheus metrics
    local metrics_response=$(kubectl exec "$pod" -n "$NAMESPACE" -- curl -s http://localhost:8080/actuator/prometheus 2>/dev/null || echo "")
    
    # Check for Spring Boot specific metrics
    if echo "$metrics_response" | grep -q "jvm_memory_used_bytes\|http_server_requests_seconds_count\|spring_boot"; then
        result="springboot"
    fi
    
    # Check for Quarkus specific metrics
    if echo "$metrics_response" | grep -q "base_gc_total_seconds\|vendor_quarkus\|mp_metrics"; then
        result="quarkus"
    fi
    
    echo "$result"
}

# Method 6: Check Java system properties
check_java_properties() {
    local pod=$1
    local result=""
    
    log_verbose "Checking Java system properties for pod: $pod"
    
    # Get Java system properties
    local java_props=$(kubectl exec "$pod" -n "$NAMESPACE" -- curl -s http://localhost:8080/actuator/env 2>/dev/null || echo "")
    
    # Check for Spring Boot specific properties
    if echo "$java_props" | grep -q "spring.boot\|SpringApplication\|springframework"; then
        result="springboot"
    fi
    
    # Check for Quarkus specific properties
    if echo "$java_props" | grep -q "quarkus\|io.quarkus\|SmallRye"; then
        result="quarkus"
    fi
    
    echo "$result"
}

# Combine all detection methods
identify_pod_type() {
    local pod=$1
    local final_result="unknown"
    local confidence=0
    local method_results=()
    
    log_verbose "Identifying pod type for: $pod"
    
    # Method 1: Labels and annotations (high confidence)
    local result1=$(check_labels_annotations "$pod")
    if [ "$result1" != "" ]; then
        method_results+=("labels_annotations:$result1:high")
        final_result="$result1"
        confidence=3
    fi
    
    # Method 2: Image name (high confidence)
    local result2=$(check_image_name "$pod")
    if [ "$result2" != "" ]; then
        method_results+=("image_name:$result2:high")
        if [ "$final_result" = "unknown" ]; then
            final_result="$result2"
            confidence=3
        elif [ "$final_result" != "$result2" ]; then
            log_warn "Conflicting detection: labels_annotations=$final_result, image_name=$result2"
        fi
    fi
    
    # Method 3: Environment variables (medium confidence)
    local result3=$(check_environment "$pod")
    if [ "$result3" != "" ]; then
        method_results+=("environment:$result3:medium")
        if [ "$final_result" = "unknown" ]; then
            final_result="$result3"
            confidence=2
        elif [ "$final_result" != "$result3" ]; then
            log_warn "Conflicting detection: current=$final_result, environment=$result3"
        fi
    fi
    
    # Method 4: Endpoints (medium confidence)
    local result4=$(check_endpoints "$pod")
    if [ "$result4" != "unknown" ] && [ "$result4" != "" ]; then
        method_results+=("endpoints:$result4:medium")
        if [ "$final_result" = "unknown" ]; then
            final_result="$result4"
            confidence=2
        elif [ "$final_result" != "$result4" ]; then
            log_warn "Conflicting detection: current=$final_result, endpoints=$result4"
        fi
    fi
    
    # Method 5: Metrics (medium confidence)
    local result5=$(check_metrics "$pod")
    if [ "$result5" != "" ]; then
        method_results+=("metrics:$result5:medium")
        if [ "$final_result" = "unknown" ]; then
            final_result="$result5"
            confidence=2
        elif [ "$final_result" != "$result5" ]; then
            log_warn "Conflicting detection: current=$final_result, metrics=$result5"
        fi
    fi
    
    # Method 6: Java properties (low confidence)
    local result6=$(check_java_properties "$pod")
    if [ "$result6" != "" ]; then
        method_results+=("java_properties:$result6:low")
        if [ "$final_result" = "unknown" ]; then
            final_result="$result6"
            confidence=1
        elif [ "$final_result" != "$result6" ]; then
            log_warn "Conflicting detection: current=$final_result, java_properties=$result6"
        fi
    fi
    
    # Log all method results in verbose mode
    if [ "$VERBOSE" = true ]; then
        log_verbose "Detection methods results:"
        for method_result in "${method_results[@]}"; do
            log_verbose "  - $method_result"
        done
    fi
    
    echo "$final_result:$confidence"
}

# Format output as table
format_table() {
    local pod=$1
    local type=$2
    local confidence=$3
    local status=$4
    
    local type_display=""
    case $type in
        quarkus)
            type_display="Quarkus"
            ;;
        springboot)
            type_display="Spring Boot"
            ;;
        *)
            type_display="Unknown"
            ;;
    esac
    
    local confidence_display=""
    case $confidence in
        3)
            confidence_display="High"
            ;;
        2)
            confidence_display="Medium"
            ;;
        1)
            confidence_display="Low"
            ;;
        *)
            confidence_display="Unknown"
            ;;
    esac
    
    local status_display=""
    case $status in
        Running)
            status_display="Running"
            ;;
        Pending)
            status_display="Pending"
            ;;
        Failed)
            status_display="Failed"
            ;;
        *)
            status_display="$status"
            ;;
    esac
    
    printf "%-30s %-15s %-12s %-10s\n" "$pod" "$type_display" "$confidence_display" "$status_display"
}

# Format output as JSON
format_json() {
    local pod=$1
    local type=$2
    local confidence=$3
    local status=$4
    
    cat << EOF
{
  "pod": "$pod",
  "namespace": "$NAMESPACE",
  "type": "$type",
  "confidence": $confidence,
  "status": "$status",
  "timestamp": "$(date -Iseconds)"
}
EOF
}

# Format output as YAML
format_yaml() {
    local pod=$1
    local type=$2
    local confidence=$3
    local status=$4
    
    cat << EOF
pod: $pod
namespace: $NAMESPACE
type: $type
confidence: $confidence
status: $status
timestamp: $(date -Iseconds)
---
EOF
}

# Format output as CSV
format_csv() {
    local pod=$1
    local type=$2
    local confidence=$3
    local status=$4
    
    echo "\"$pod\",\"$NAMESPACE\",\"$type\",$confidence,\"$status\",\"$(date -Iseconds)\""
}

# Analyze single pod
analyze_pod() {
    local pod=$1
    
    if ! check_pod_exists "$pod"; then
        return 1
    fi
    
    local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    # Only analyze if pod is running
    if [ "$status" != "Running" ]; then
        case $OUTPUT_FORMAT in
            table)
                format_table "$pod" "unknown" "0" "$status"
                ;;
            json)
                format_json "$pod" "unknown" "0" "$status"
                ;;
            yaml)
                format_yaml "$pod" "unknown" "0" "$status"
                ;;
            csv)
                format_csv "$pod" "unknown" "0" "$status"
                ;;
        esac
        return
    fi
    
    local result=$(identify_pod_type "$pod")
    local type=${result%:*}
    local confidence=${result#*:}
    
    case $OUTPUT_FORMAT in
        table)
            format_table "$pod" "$type" "$confidence" "$status"
            ;;
        json)
            format_json "$pod" "$type" "$confidence" "$status"
            ;;
        yaml)
            format_yaml "$pod" "$type" "$confidence" "$status"
            ;;
        csv)
            format_csv "$pod" "$type" "$confidence" "$status"
            ;;
    esac
}

# Analyze all pods in namespace
analyze_all_pods() {
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$pods" ]; then
        log_error "No pods found in namespace '$NAMESPACE'"
        return 1
    fi
    
    # Print header for table format
    if [ "$OUTPUT_FORMAT" = "table" ]; then
        printf "%-30s %-15s %-12s %-10s\n" "POD NAME" "TYPE" "CONFIDENCE" "STATUS"
        printf "%-30s %-15s %-12s %-10s\n" "------------------------------" "---------------" "------------" "----------"
    fi
    
    # Print header for CSV format
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
        echo "\"Pod\",\"Namespace\",\"Type\",\"Confidence\",\"Status\",\"Timestamp\""
    fi
    
    # Analyze each pod
    for pod in $pods; do
        analyze_pod "$pod"
    done
}

# Main function
main() {
    parse_args "$@"
    validate_args
    
    if [ "$ALL_PODS" = true ]; then
        analyze_all_pods
    else
        # Print header for table format
        if [ "$OUTPUT_FORMAT" = "table" ]; then
            printf "%-30s %-15s %-12s %-10s\n" "POD NAME" "TYPE" "CONFIDENCE" "STATUS"
            printf "%-30s %-15s %-12s %-10s\n" "------------------------------" "---------------" "------------" "----------"
        fi
        
        # Print header for CSV format
        if [ "$OUTPUT_FORMAT" = "csv" ]; then
            echo "\"Pod\",\"Namespace\",\"Type\",\"Confidence\",\"Status\",\"Timestamp\""
        fi
        
        analyze_pod "$POD_NAME"
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
