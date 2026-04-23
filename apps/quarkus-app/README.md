# Quarkus Demo Application

## Overview

This is a demo Java application built with Spring Boot 2.7.18 and Java 11, designed to showcase monitoring integration with a complete observability stack. Despite the name "Quarkus", this application uses Spring Boot framework for consistency with the monitoring stack requirements.

## Features

- **Framework**: Spring Boot 2.7.18 with Java 11
- **Monitoring**: Prometheus metrics, OpenTelemetry tracing, Loki logs, Pyroscope profiling
- **Health Checks**: Spring Boot Actuator endpoints
- **REST Endpoints**: Simple API with monitoring annotations
- **Containerization**: Multi-stage Docker build
- **Kubernetes Ready**: Complete deployment manifests with monitoring annotations

## Architecture

### Technology Stack
- **Java 11** - Runtime environment
- **Spring Boot 2.7.18** - Application framework
- **Maven** - Build tool and dependency management
- **Micrometer** - Metrics collection (Prometheus registry)
- **Spring Boot Actuator** - Health checks and management endpoints
- **OpenTelemetry** - Distributed tracing (automatic injection)

### Application Structure
```
src/main/java/com/example/
├── QuarkusDemoApplication.java     # Main application class
│   ├── HelloController             # REST controller
│   └── AppInfo                     # Application info DTO
└── resources/
    ├── application.properties       # Spring Boot configuration
    └── application.yml            # Alternative configuration
```

## API Endpoints

### Health & Management
- **GET** `/actuator/health` - Application health status
- **GET** `/actuator/info` - Application information
- **GET** `/actuator/prometheus` - Prometheus metrics

### Application Endpoints
- **GET** `/hello/{name}` - Greeting endpoint with monitoring

#### Example Usage
```bash
# Health check
curl http://localhost:8080/actuator/health

# Greeting endpoint
curl http://localhost:8080/hello/World

# Metrics
curl http://localhost:8080/actuator/prometheus
```

## Monitoring Integration

### Prometheus Metrics
The application exports JVM and application metrics:
- `jvm_memory_used_bytes` - Memory usage
- `jvm_threads_live_threads` - Thread count
- `http_requests_total` - HTTP request count
- `hello_calls_total` - Custom hello endpoint counter
- `hello_duration_seconds` - Request duration histogram

### OpenTelemetry Tracing
Automatic tracing injection for:
- HTTP requests
- Database operations (when applicable)
- Custom business logic

### Loki Log Collection
All application logs are automatically collected by Loki with structured logging.

### Pyroscope Profiling
Continuous CPU and memory profiling for performance analysis.

## Configuration

### Application Properties
```properties
# Server configuration
server.port=8080

# Management endpoints
management.endpoints.web.exposure.include=health,info,prometheus
management.endpoint.health.show-details=always
management.metrics.export.prometheus.enabled=true
```

### Environment Variables
- `JAVA_OPTS` - JVM options (default: `-Xmx256m -Xms128m`)
- `OTEL_EXPORTER_OTLP_ENDPOINT` - OpenTelemetry collector endpoint
- `OTEL_RESOURCE_ATTRIBUTES` - OpenTelemetry resource attributes

## Build & Deployment

### Local Development
```bash
# Build the application
mvn clean package -DskipTests

# Run locally
java -jar target/quarkus-demo-1.0.0-SNAPSHOT.jar
```

### Docker Build
```bash
# Build Docker image
docker build -t quarkus-demo:latest .

# Run container
docker run -p 8080:8080 quarkus-demo:latest
```

### Kubernetes Deployment
```bash
# Deploy to Kubernetes
kubectl apply -f k8s-deployment.yaml

# Check deployment status
kubectl get pods -n applications -l app=quarkus-demo

# Port-forward for testing
kubectl port-forward -n applications deployment/quarkus-demo 8081:8080
```

## Kubernetes Configuration

### Deployment Features
- **Replicas**: 2 pods for high availability
- **Resources**: CPU and memory limits defined
- **Health Checks**: Liveness and readiness probes
- **Monitoring Annotations**: Complete observability integration

### Service Configuration
- **Type**: ClusterIP
- **Port**: 8080
- **Selector**: `app=quarkus-demo`

### Monitoring Annotations
```yaml
annotations:
  # Prometheus metrics scraping
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
  
  # Pyroscope profiling
  profiles.grafana.com/memory.scrape: "true"
  profiles.grafana.com/memory.port: "8080"
  profiles.grafana.com/cpu.scrape: "true"
  profiles.grafana.com/cpu.port: "8080"
  
  # OpenTelemetry injection
  instrumentation.opentelemetry.io/inject-java: "true"
  
  # Loki log collection
  fluentd.org/include: "true"
  fluentd.org/exclude: "false"
```

## Development

### Adding New Endpoints
```java
@RestController
@RequestMapping("/api")
public class NewController {
    
    @GetMapping("/data")
    @Counted(value = "data_calls", description = "Data endpoint calls")
    @Timed(value = "data_duration", description = "Data endpoint duration")
    public ResponseEntity<String> getData() {
        return ResponseEntity.ok("Sample data");
    }
}
```

### Custom Metrics
```java
@RestController
public class MetricsController {
    
    private final Counter customCounter;
    
    public MetricsController(MeterRegistry meterRegistry) {
        this.customCounter = Counter.builder("custom_operations")
            .description("Custom operation count")
            .register(meterRegistry);
    }
    
    @GetMapping("/custom")
    public String customOperation() {
        customCounter.increment();
        return "Custom operation completed";
    }
}
```

## Testing

### Unit Tests
```bash
# Run all tests
mvn test

# Run specific test class
mvn test -Dtest=HelloControllerTest
```

### Integration Tests
```bash
# Run integration tests
mvn verify

# Test with specific profile
mvn test -Dspring.profiles.active=test
```

### Health Check Testing
```bash
# Test health endpoint
curl -f http://localhost:8080/actuator/health || exit 1

# Test metrics endpoint
curl -f http://localhost:8080/actuator/prometheus || exit 1
```

## Troubleshooting

### Common Issues

#### Application Not Starting
- Check Java version: `java -version` (should be Java 11)
- Verify Maven dependencies: `mvn dependency:tree`
- Check port conflicts: Ensure port 8080 is available

#### Health Check Failures
- Verify actuator endpoints are enabled
- Check application logs for errors
- Ensure proper Spring Boot configuration

#### Metrics Not Available
- Verify Prometheus endpoint is exposed: `/actuator/prometheus`
- Check Micrometer configuration
- Verify monitoring annotations in Kubernetes

### Debug Commands
```bash
# Check application logs
kubectl logs -n applications -l app=quarkus-demo

# Debug pod issues
kubectl describe pod -n applications -l app=quarkus-demo

# Test endpoint connectivity
kubectl exec -n applications <pod-name> -- curl -s http://localhost:8080/actuator/health
```

## Performance Considerations

### JVM Tuning
- **Heap Size**: Configured via `JAVA_OPTS` environment variable
- **GC Settings**: Default GC settings for containerized environments
- **Memory Limits**: Set to 512Mi in Kubernetes deployment

### Monitoring Overhead
- **Metrics Collection**: Minimal overhead with Micrometer
- **Tracing**: Configured for sampling to reduce overhead
- **Profiling**: Continuous profiling with Pyroscope

## Security

### Endpoints Security
- Actuator endpoints are exposed for monitoring
- Consider securing endpoints in production environments
- Use Spring Security for additional protection

### Container Security
- Non-root user execution (when possible)
- Minimal base image (UBI8 OpenJDK 17)
- No sensitive data in container image

## Version Information

- **Application Version**: 1.0.0-SNAPSHOT
- **Spring Boot Version**: 2.7.18
- **Java Version**: 11
- **Maven Version**: 3.8+

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is part of the Argo CD Lab monitoring demonstration.
