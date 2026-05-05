# Scripts Collection

This directory contains utility scripts for managing and monitoring the Argo CD Lab environment.

## Pod Type Identification Script

### Overview
The `identify-pod-type.sh` script identifies whether a pod is running a Quarkus or Spring Boot application using multiple detection methods for reliability.

### Features
- **Multiple Detection Methods**: Labels, image name, environment variables, endpoints, metrics, and Java properties
- **Confidence Scoring**: High, medium, and low confidence based on detection method
- **Multiple Output Formats**: Table, JSON, YAML, and CSV
- **Verbose Mode**: Detailed logging of detection process
- **Batch Processing**: Analyze all pods in namespace
- **Error Handling**: Graceful handling of unavailable pods

### Detection Methods

#### 1. Labels and Annotations (High Confidence)
- Checks pod labels for `app: quarkus-demo` or `app: springboot-demo`
- Analyzes annotations for framework-specific markers

#### 2. Image Name (High Confidence)
- Examines container image names for `quarkus` or `springboot` patterns

#### 3. Environment Variables (Medium Confidence)
- Looks for Spring Boot specific variables: `SPRING_APPLICATION_NAME`, `spring.profiles`, `management.endpoints`
- Checks for Quarkus specific variables: `QUARKUS`, `quarkus`, `mp.metrics`

#### 4. Endpoint Analysis (Medium Confidence)
- Analyzes `/actuator/info` response for framework-specific information
- Checks for Spring Boot or Quarkus identifiers

#### 5. Metrics Endpoint (Medium Confidence)
- Examines `/actuator/prometheus` metrics for framework-specific patterns
- Spring Boot: `jvm_memory_used_bytes`, `http_server_requests_seconds_count`
- Quarkus: `base_gc_total_seconds`, `vendor_quarkus`, `mp_metrics`

#### 6. Java Properties (Low Confidence)
- Analyzes `/actuator/env` for framework-specific system properties
- Spring Boot: `spring.boot`, `SpringApplication`, `springframework`
- Quarkus: `quarkus`, `io.quarkus`, `SmallRye`

### Usage Examples

#### Basic Usage
```bash
# Identify specific pod
./scripts/identify-pod-type.sh -n applications quarkus-demo-7d8f9c9b9-abc12

# Analyze all pods in namespace
./scripts/identify-pod-type.sh -n applications --all
```

#### Output Formats
```bash
# Table format (default)
./scripts/identify-pod-type.sh -n applications quarkus-demo-7d8f9c9b9-abc12

# JSON format
./scripts/identify-pod-type.sh -n applications -o json quarkus-demo-7d8f9c9b9-abc12

# YAML format
./scripts/identify-pod-type.sh -n applications -o yaml quarkus-demo-7d8f9c9b9-abc12

# CSV format
./scripts/identify-pod-type.sh -n applications -o csv quarkus-demo-7d8f9c9b9-abc12
```

#### Verbose Mode
```bash
# Enable verbose logging
./scripts/identify-pod-type.sh -n applications -v quarkus-demo-7d8f9c9b9-abc12
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-n, --namespace NAMESPACE` | Specify namespace (default: current namespace) |
| `-o, --output FORMAT` | Output format: table|json|yaml|csv (default: table) |
| `-v, --verbose` | Enable verbose output |
| `-a, --all` | Analyze all pods in namespace |
| `-h, --help` | Show help message |

### Output Examples

#### Table Format
```
POD NAME                       TYPE            CONFIDENCE  STATUS    
------------------------------ --------------- ------------ ----------
quarkus-demo-7d8f9c9b9-abc12   Quarkus         High        Running    
springboot-demo-5f8c9d7e6-def34 Spring Boot     High        Running    
```

#### JSON Format
```json
{
  "pod": "quarkus-demo-7d8f9c9b9-abc12",
  "namespace": "applications",
  "type": "quarkus",
  "confidence": 3,
  "status": "Running",
  "timestamp": "2024-05-05T10:40:00-03:00"
}
```

#### YAML Format
```yaml
pod: quarkus-demo-7d8f9c9b9-abc12
namespace: applications
type: quarkus
confidence: 3
status: Running
timestamp: 2024-05-05T10:40:00-03:00
---
```

#### CSV Format
```csv
"Pod","Namespace","Type","Confidence","Status","Timestamp"
"quarkus-demo-7d8f9c9b9-abc12","applications","quarkus",3,"Running","2024-05-05T10:40:00-03:00"
```

### Confidence Levels

| Level | Description | Methods |
|-------|-------------|----------|
| High (3) | Very reliable identification | Labels, annotations, image name |
| Medium (2) | Good identification | Environment variables, endpoints, metrics |
| Low (1) | Basic identification | Java properties |

### Troubleshooting

#### Common Issues

**Pod Not Found**
```bash
Error: Pod 'pod-name' not found in namespace 'applications'
Solution: Check pod name and namespace with `kubectl get pods -n applications`
```

**Pod Not Running**
```bash
Status: Unknown
Solution: Wait for pod to be ready or check pod status
```

**Connection Timeout**
```bash
Error: Connection timeout
Solution: Check if pod is ready and accessible
```

#### Debug Mode
Use verbose mode to see detailed detection process:
```bash
./scripts/identify-pod-type.sh -v -n applications quarkus-demo-7d8f9c9b9-abc12
```

### Integration Examples

#### Monitoring Integration
```bash
# Create monitoring dashboard data
./scripts/identify-pod-type.sh -n applications --all -o json > pod-types.json

# Use in monitoring scripts
for pod in $(kubectl get pods -n applications -o name | cut -d'/' -f2); do
    type=$(./scripts/identify-pod-type.sh -n applications "$pod" -o json | jq -r '.type')
    echo "Pod $pod is of type: $type"
done
```

#### Automation Integration
```bash
# Automated pod type detection
#!/bin/bash
NAMESPACE="applications"
POD_TYPES_FILE="pod-types-$(date +%Y%m%d).csv"

./scripts/identify-pod-type.sh -n "$NAMESPACE" --all -o csv > "$POD_TYPES_FILE"
echo "Pod types saved to $POD_TYPES_FILE"
```

### Performance Considerations

- **Single Pod**: ~2-3 seconds
- **All Pods**: Depends on pod count (~5-10 seconds for 10 pods)
- **Network Latency**: Script requires network access to pods
- **Resource Usage**: Minimal CPU and memory usage

### Security Considerations

- **RBAC**: Requires `get`, `list`, and `exec` permissions on pods
- **Network Access**: Requires network connectivity to pod endpoints
- **Data Exposure**: Script accesses application endpoints (consider security implications)

### Dependencies

- **kubectl**: Kubernetes CLI tool
- **curl**: HTTP client (installed in pods)
- **jq**: JSON processor (for JSON output format)
- **bash**: Bash shell version 4.0+

### Version Information

- **Script Version**: 1.0.0
- **Kubernetes**: Compatible with v1.20+
- **Shell**: Bash 4.0+
- **Dependencies**: kubectl 1.20+, curl 7.0+, jq 1.6+

### Contributing

When adding new detection methods:
1. Add function following naming convention: `check_method_name()`
2. Return result or empty string
3. Add to `identify_pod_type()` function
4. Update documentation
5. Test with both Quarkus and Spring Boot applications

### License

This script is part of the Argo CD Lab project and follows the same licensing terms.
