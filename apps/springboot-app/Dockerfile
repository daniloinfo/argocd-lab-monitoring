# Build stage
FROM maven:3.9.4-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn package -DskipTests

# Runtime stage
FROM registry.access.redhat.com/ubi8/openjdk-17-runtime:1.18

# Install curl for health check and create non-root user
RUN microdnf update -y && \
    microdnf install -y curl && \
    microdnf clean all && \
    groupadd -r appuser && \
    useradd -r -g appuser appuser

WORKDIR /app

# Copy the built JAR
COPY --from=build /app/target/springboot-demo-1.0.0.jar /app/app.jar

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application
CMD ["java", "-jar", "app.jar"]
