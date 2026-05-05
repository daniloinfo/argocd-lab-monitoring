#!/bin/bash

# Pod Type Detector
# Identifies whether a pod is running Quarkus or Spring Boot application

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
NAMESPACE="applications"
VERBOSE=false
ALL_PODS=false

# Help function
show_help() {
    cat << EOF
Pod Type Detector

USAGE:
    $0 [OPTIONS] [POD_NAME]

OPTIONS:
    -n, --namespace NAMESPACE    Specify namespace (default: applications)
    -v, --verbose              Enable verbose output
    -a, --all                 Analyze all pods in namespace
    -h, --help               Show this help message

EXAMPLES:
    # Identify specific pod
    $0 quarkus-demo-7d8f9c9b9-abc12

    # Analyze all pods in namespace
    $0 --all

    # Use different namespace
    $0 -n monitoring --all

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${GREEN}[VERBOSE]${NC} $1"
    fi
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
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
                echo "Unknown option: $1"
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

# Identify pod type
identify_pod_type() {
    local pod=$1
    local result="unknown"
    
    log_verbose "Analyzing pod: $pod"
    
    # Method 1: Check app label
    local app_label=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.app}' 2>/dev/null || echo "")
    log_verbose "App label: $app_label"
    
    if [[ "$app_label" == *"quarkus"* ]]; then
        result="quarkus"
    elif [[ "$app_label" == *"springboot"* ]]; then
        result="springboot"
    fi
    
    # Method 2: Check image name (only if not found)
    if [ "$result" = "unknown" ]; then
        local image=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || echo "")
        log_verbose "Image: $image"
        
        if [[ "$image" == *"quarkus"* ]]; then
            result="quarkus"
        elif [[ "$image" == *"springboot"* ]]; then
            result="springboot"
        fi
    fi
    
    echo "$result"
}

# Format output
format_output() {
    local pod=$1
    local type=$2
    local status=$3
    
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
    
    local status_display=""
    case $status in
        Running)
            status_display="Running"
            ;;
        *)
            status_display="$status"
            ;;
    esac
    
    printf "%-40s %-15s %-10s\n" "$pod" "$type_display" "$status_display"
}

# Analyze single pod
analyze_pod() {
    local pod=$1
    
    if ! kubectl get pod "$pod" -n "$NAMESPACE" &>/dev/null; then
        echo -e "${RED}Error: Pod '$pod' not found in namespace '$NAMESPACE'${NC}"
        return 1
    fi
    
    local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    local type=$(identify_pod_type "$pod")
    
    format_output "$pod" "$type" "$status"
}

# Analyze all pods
analyze_all() {
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    
    if [ -z "$pods" ]; then
        echo -e "${RED}No pods found in namespace '$NAMESPACE'${NC}"
        return 1
    fi
    
    printf "%-40s %-15s %-10s\n" "POD NAME" "TYPE" "STATUS"
    printf "%-40s %-15s %-10s\n" "----------------------------------------" "---------------" "----------"
    
    for pod in $pods; do
        analyze_pod "$pod"
    done
}

# Main function
main() {
    parse_args "$@"
    
    if [ "$ALL_PODS" = "true" ]; then
        analyze_all
    elif [ -n "$POD_NAME" ]; then
        printf "%-40s %-15s %-10s\n" "POD NAME" "TYPE" "STATUS"
        printf "%-40s %-15s %-10s\n" "----------------------------------------" "---------------" "----------"
        analyze_pod "$POD_NAME"
    else
        echo -e "${RED}Error: Please specify a pod name or use --all${NC}"
        show_help
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
