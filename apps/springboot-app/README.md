# Spring Boot Demo Application

## Overview

This is a demo Java application built with Spring Boot 3.2.0 and Java 17, designed to showcase modern Spring Boot features with comprehensive monitoring integration. This application demonstrates best practices for observability in cloud-native environments.

## Features

- **Framework**: Spring Boot 3.2.0 with Java 17
- **Monitoring**: Prometheus metrics, OpenTelemetry tracing, Loki logs, Pyroscope profiling
- **Health Checks**: Spring Boot Actuator with comprehensive health indicators
- **REST Endpoints**: Modern API with monitoring annotations
- **Containerization**: Multi-stage Docker build with optimization
- **Kubernetes Ready**: Complete deployment manifests with monitoring annotations
- **Modern Java**: Records, switch expressions, and other Java 17 features

## Architecture

### Technology Stack
- **Java 17** - Latest LTS Java version
- **Spring Boot 3.2.0** - Modern Spring Boot framework
- **Maven** - Build tool and dependency management
- **Micrometer** - Metrics collection (Prometheus registry)
- **Spring Boot Actuator** - Production-ready features
- **OpenTelemetry** - Distributed tracing (automatic injection)

### Application Structure
```
src/main/java/com/example/
├── SpringbootDemoApplication.java  # Main application class
│   ├── HelloController            # REST controller
│   └── AppInfo                    # Application info record
└── resources/
    └── application.yml            # Spring Boot configuration
```

## API Endpoints

### Health & Management
- **GET** `/actuator/health` - Application health status with detailed components
- **GET** `/actuator/health/liveness` - Liveness probe
- **GET** `/actuator/health/readiness` - Readiness probe
- **GET** `/actuator/info` - Application information
- **GET** `/actuator/prometheus` - Prometheus metrics

### Application Endpoints
- **GET** `/hello/{name}` - Greeting endpoint with monitoring
- **GET** `/health` - Simple health endpoint (legacy)
- **GET** `/info` - Application info endpoint

#### Example Usage
```bash
# Comprehensive health check
curl http://localhost:8080/actuator/health

# Liveness probe
curl http://localhost:8080/actuator/health/liveness

# Greeting endpoint
curl http://localhost:8080/hello/World

# Metrics
curl http://localhost:8080/actuator/prometheus
```

## Monitoring Integration

### Prometheus Metrics
The application exports comprehensive metrics:
- `jvm_memory_used_bytes` - Memory usage by area
- `jvm_threads_live_threads` - Live thread count
- `jvm_gc_pause_seconds` - GC pause times
- `http_server_requests_seconds` - HTTP request metrics
- `hello_calls_total` - Custom hello endpoint counter
- `hello_duration_seconds` - Request duration histogram
- `process_cpu_usage` - CPU usage
- `system_cpu_usage` - System CPU usage

### OpenTelemetry Tracing
Automatic tracing injection for:
- HTTP requests and responses
- Spring MVC method execution
- Database operations (when applicable)
- Custom business logic spans

### Loki Log Collection
Structured logging with automatic collection:
- Application logs with correlation IDs
- Request tracing information
- Error logs with stack traces
- Performance metrics in logs

### Pyroscope Profiling
Continuous profiling for performance analysis:
- CPU profiling with flame graphs
- Memory allocation profiling
- Goroutine profiling (if applicable)
- Custom profiling events

## Configuration

### Application Configuration (application.yml)
```yaml
server:
  port: 8080

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      show-details: always
  metrics:
    export:
      prometheus:
        enabled: true

logging:
  level:
    com.example: INFO
    org.springframework: INFO
```

### Environment Variables
- `JAVA_OPTS` - JVM options (default: `-Xmx256m -Xms128m`)
- `OTEL_EXPORTER_OTLP_ENDPOINT` - OpenTelemetry collector endpoint
- `OTEL_RESOURCE_ATTRIBUTES` - OpenTelemetry resource attributes
- `SPRING_PROFILES_ACTIVE` - Spring profiles

### Spring Profiles
- **default** - Standard configuration
- **test** - Test configuration
- **prod** - Production configuration (when implemented)

## Build & Deployment

### Local Development
```bash
# Build the application
mvn clean package -DskipTests

# Run locally
java -jar target/springboot-demo-1.0.0-SNAPSHOT.jar

# Run with specific profile
java -jar target/springboot-demo-1.0.0-SNAPSHOT.jar --spring.profiles.active=dev
```

### Docker Build
```bash
# Build Docker image
docker build -t springboot-demo:latest .

# Run container
docker run -p 8080:8080 springboot-demo:latest

# Run with environment variables
docker run -p 8080:8080 \
  -e JAVA_OPTS="-Xmx512m -Xms256m" \
  springboot-demo:latest
```

### Kubernetes Deployment
```bash
# Deploy to Kubernetes
kubectl apply -f k8s-deployment.yaml

# Check deployment status
kubectl get pods -n applications -l app=springboot-demo

# Port-forward for testing
kubectl port-forward -n applications deployment/springboot-demo 8082:8080

# Check logs
kubectl logs -n applications -l app=springboot-demo -f
```

## Kubernetes Configuration

### Deployment Features
- **Replicas**: 2 pods for high availability
- **Resources**: CPU and memory limits/requests
- **Health Checks**: Liveness and readiness probes
- **Monitoring Annotations**: Complete observability integration
- **Graceful Shutdown**: Proper termination handling

### Service Configuration
- **Type**: ClusterIP
- **Port**: 8080
- **Selector**: `app=springboot-demo`
- **Target Port**: 8080

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
@RequestMapping("/api/v1")
public class NewController {
    
    @GetMapping("/users")
    @Counted(value = "users_calls", description = "Users endpoint calls")
    @Timed(value = "users_duration", description = "Users endpoint duration")
    public ResponseEntity<List<User>> getUsers() {
        List<User> users = userService.getAllUsers();
        return ResponseEntity.ok(users);
    }
    
    @GetMapping("/users/{id}")
    @Counted(value = "user_calls", description = "User endpoint calls")
    @Timed(value = "user_duration", description = "User endpoint duration")
    public ResponseEntity<User> getUser(@PathVariable Long id) {
        return userService.findById(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }
}
```

### Custom Metrics and Tracing
```java
@RestController
public class MetricsController {
    
    private final MeterRegistry meterRegistry;
    private final Tracer tracer;
    
    public MetricsController(MeterRegistry meterRegistry, Tracer tracer) {
        this.meterRegistry = meterRegistry;
        this.tracer = tracer;
    }
    
    @GetMapping("/custom-operation")
    public String customOperation() {
        Span span = tracer.nextSpan()
            .name("custom-operation")
            .start();
        
        try (Scope scope = span.makeCurrent()) {
            // Custom business logic
            performCustomOperation();
            
            // Custom metric
            meterRegistry.counter("custom_operations", "type", "success")
                .increment();
                
            return "Operation completed successfully";
        } finally {
            span.end();
        }
    }
}
```

### Health Indicators
```java
@Component
public class CustomHealthIndicator implements HealthIndicator {
    
    @Override
    public Health health() {
        // Custom health check logic
        boolean isHealthy = checkCustomHealth();
        
        if (isHealthy) {
            return Health.up()
                .withDetail("status", "All systems operational")
                .build();
        } else {
            return Health.down()
                .withDetail("error", "Custom system unavailable")
                .build();
        }
    }
    
    private boolean checkCustomHealth() {
        // Implement custom health check logic
        return true;
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

# Run tests with coverage
mvn test jacoco:report
```

### Integration Tests
```bash
# Run integration tests
mvn verify

# Test with specific profile
mvn test -Dspring.profiles.active=test

# Run performance tests
mvn test -Dspring.profiles.active=perf
```

### Health Check Testing
```bash
# Test comprehensive health
curl -f http://localhost:8080/actuator/health || exit 1

# Test liveness probe
curl -f http://localhost:8080/actuator/health/liveness || exit 1

# Test readiness probe
curl -f http://localhost:8080/actuator/health/readiness || exit 1

# Test metrics endpoint
curl -f http://localhost:8080/actuator/prometheus || exit 1
```

### Load Testing
```bash
# Install Apache Bench if not available
sudo apt-get install apache2-utils

# Load test the hello endpoint
ab -n 1000 -c 10 http://localhost:8080/hello/Test

# Load test with custom headers
ab -n 500 -c 5 -H "Content-Type: application/json" http://localhost:8080/hello/LoadTest
```

## Performance Considerations

### JVM Tuning for Spring Boot 3
- **Heap Size**: Configured via `JAVA_OPTS` environment variable
- **GC Settings**: G1GC is default in Java 17, optimized for containerized environments
- **Memory Limits**: Set to 512Mi in Kubernetes deployment
- **Native Image**: Consider GraalVM native image for production

### Spring Boot 3 Performance Features
- **Lazy Initialization**: Reduced startup time
- **Observability**: Built-in metrics and tracing
- **AOT Compilation**: Ahead-of-time compilation support
- **Virtual Threads**: Project Loom integration (when available)

### Monitoring Overhead
- **Metrics Collection**: Minimal overhead with Micrometer 1.10+
- **Tracing**: Configured for sampling to reduce overhead
- **Profiling**: Continuous profiling with Pyroscope
- **Logging**: Structured logging with correlation IDs

## Security

### Actuator Security
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      show-details: when-authorized
  security:
    enabled: true
```

### Production Security Considerations
- Secure actuator endpoints with Spring Security
- Use HTTPS in production environments
- Implement proper authentication and authorization
- Regular security updates and dependency scanning

### Container Security
- Non-root user execution (when possible)
- Minimal base image (UBI8 OpenJDK 17)
- No sensitive data in container image
- Security scanning in CI/CD pipeline

## Observability Best Practices

### Structured Logging
```java
@RestController
public class ObservabilityController {
    
    private static final Logger logger = LoggerFactory.getLogger(ObservabilityController.class);
    
    @GetMapping("/observable-operation")
    public String observableOperation(@RequestParam String input) {
        logger.info("Starting observable operation with input: {}", input);
        
        try {
            String result = processOperation(input);
            logger.info("Operation completed successfully");
            return result;
        } catch (Exception e) {
            logger.error("Operation failed", e);
            throw e;
        }
    }
}
```

### Custom Metrics
```java
@Component
public class CustomMetrics {
    
    private final Counter requestCounter;
    private final Timer requestTimer;
    private final Gauge activeConnections;
    
    public CustomMetrics(MeterRegistry meterRegistry) {
        this.requestCounter = Counter.builder("api_requests")
            .description("Total API requests")
            .register(meterRegistry);
            
        this.requestTimer = Timer.builder("api_request_duration")
            .description("API request duration")
            .register(meterRegistry);
            
        this.activeConnections = Gauge.builder("active_connections")
            .description("Active database connections")
            .register(meterRegistry, this, CustomMetrics::getActiveConnections);
    }
    
    public void recordRequest(String endpoint, Duration duration) {
        requestCounter.increment(Tags.of("endpoint", endpoint));
        requestTimer.record(duration);
    }
    
    private double getActiveConnections() {
        // Return current active connections
        return connectionPool.getActiveConnections();
    }
}
```

## Troubleshooting

### Common Issues

#### Application Not Starting
- Check Java version: `java -version` (should be Java 17)
- Verify Maven dependencies: `mvn dependency:tree`
- Check port conflicts: Ensure port 8080 is available
- Verify Spring Boot 3 compatibility

#### Health Check Failures
- Verify actuator endpoints are enabled
- Check application logs for errors
- Ensure proper Spring Boot 3 configuration
- Validate health indicator implementations

#### Metrics Not Available
- Verify Prometheus endpoint: `/actuator/prometheus`
- Check Micrometer configuration
- Verify monitoring annotations in Kubernetes
- Ensure proper Spring Boot 3 metrics setup

#### Memory Issues
- Check JVM heap settings: `-Xmx256m -Xms128m`
- Monitor memory usage: `jvm_memory_used_bytes`
- Verify container memory limits
- Consider increasing heap size if needed

### Debug Commands
```bash
# Check application logs
kubectl logs -n applications -l app=springboot-demo

# Debug pod issues
kubectl describe pod -n applications -l app=springboot-demo

# Test endpoint connectivity
kubectl exec -n applications <pod-name> -- curl -s http://localhost:8080/actuator/health

# Check resource usage
kubectl top pods -n applications -l app=springboot-demo

# Port-forward for debugging
kubectl port-forward -n applications deployment/springboot-demo 8082:8080
```

### Performance Debugging
```bash
# Generate thread dump
kubectl exec -n applications <pod-name> -- jstack 1

# Generate heap dump
kubectl exec -n applications <pod-name> -- jmap -dump:format=b,file=heap.hprof 1

# Check GC activity
kubectl exec -n applications <pod-name> -- jstat -gc 1

# Monitor class loading
kubectl exec -n applications <pod-name> -- jstat -class 1
```

## Version Information

- **Application Version**: 1.0.0-SNAPSHOT
- **Spring Boot Version**: 3.2.0
- **Java Version**: 17 (LTS)
- **Maven Version**: 3.8+
- **Micrometer Version**: 1.12.0

## Migration Notes

### From Spring Boot 2.x to 3.x
- Java 17 is required
- Jakarta EE namespace changes
- Configuration property changes
- Actuator endpoint updates
- Metrics naming changes

### Breaking Changes
- `javax.*` packages → `jakarta.*`
- Some actuator endpoints changed
- Metrics naming conventions updated
- Configuration properties renamed

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass: `mvn test`
6. Commit your changes: `git commit -m 'Add amazing feature'`
7. Push to branch: `git push origin feature/amazing-feature`
8. Open a pull request

## License

This project is part of the Argo CD Lab monitoring demonstration and follows the same licensing terms.
