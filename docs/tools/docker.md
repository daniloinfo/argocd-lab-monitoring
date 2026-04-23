# Docker - Container Platform

## Overview

Docker is a containerization platform that enables developers to package applications and their dependencies into standardized containers. In this Argo CD Lab, Docker is used for building and running Java applications in containerized environments.

## Local Access

- **Docker Daemon**: Unix socket `/var/run/docker.sock`
- **Docker Hub**: https://hub.docker.com
- **Registry**: Default Docker Hub registry

## Security Considerations

### Current Configuration
- **User Context**: Applications run as non-root user `appuser`
- **Base Images**: UBI8 OpenJDK 17 runtime images
- **Health Checks**: Implemented with proper curl installation
- **Multi-stage Builds**: Minimize attack surface and image size

### Security Fixes Applied
1. **Non-root Execution**: Containers run as dedicated user
2. **Minimal Base Images**: UBI8 runtime images only
3. **Package Management**: Clean package installation with microdnf
4. **File Permissions**: Proper ownership set for application files

## Useful Commands

### Container Management
```bash
# List all containers
docker ps -a

# List running containers
docker ps

# Stop container
docker stop <container-id>

# Remove container
docker rm <container-id>

# View container logs
docker logs <container-id>

# Follow container logs
docker logs -f <container-id>
```

### Image Management
```bash
# List all images
docker images

# Build image
docker build -t <image-name>:<tag> .

# Remove image
docker rmi <image-id>

# Remove dangling images
docker image prune

# View image layers
docker history <image-name>
```

### Security Scanning
```bash
# Scan image with Docker Scout
docker scout cves <image-name>

# View image security details
docker inspect <image-name>

# Check for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image <image-name>
```

### Resource Monitoring
```bash
# View container resource usage
docker stats

# View detailed container stats
docker stats --no-stream

# Inspect container resources
docker inspect <container-id> | grep -A 10 "Resources"
```

### Network Management
```bash
# List networks
docker network ls

# Create network
docker network create <network-name>

# Connect container to network
docker network connect <network-name> <container-name>

# Inspect network
docker network inspect <network-name>
```

### Volume Management
```bash
# List volumes
docker volume ls

# Create volume
docker volume create <volume-name>

# Inspect volume
docker volume inspect <volume-name>

# Remove unused volumes
docker volume prune
```

## Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check container logs
docker logs <container-id>

# Inspect container configuration
docker inspect <container-id>

# Check if port is in use
netstat -tulpn | grep <port>
```

#### Permission Issues
```bash
# Check user permissions
docker run --rm alpine id

# Fix Docker socket permissions
sudo usermod -aG docker $USER

# Restart Docker service
sudo systemctl restart docker
```

#### Resource Issues
```bash
# Check disk space
df -h

# Check memory usage
free -h

# Check Docker system usage
docker system df

# Clean up unused resources
docker system prune -a
```

#### Network Issues
```bash
# Test DNS resolution
docker run --rm alpine nslookup google.com

# Check network connectivity
docker run --rm alpine ping -c 3 8.8.8.8

# List port mappings
docker port <container-id>
```

## Performance Optimization

### Build Optimization
```bash
# Use .dockerignore to exclude unnecessary files
echo "target/" > .dockerignore
echo ".git/" >> .dockerignore
echo "*.md" >> .dockerignore

# Build with BuildKit for better caching
DOCKER_BUILDKIT=1 docker build .

# Use multi-stage builds to reduce image size
# Already implemented in current Dockerfiles
```

### Runtime Optimization
```bash
# Set resource limits
docker run --memory=512m --cpus=0.5 <image-name>

# Use health checks for automatic restarts
docker run --restart=unless-stopped <image-name>

# Optimize for production
docker run --read-only --tmpfs /tmp <image-name>
```

## Integration with Kubernetes

### Kind Integration
```bash
# Load image into Kind cluster
kind load docker-image <image-name> --name argocd-lab

# List images in Kind cluster
docker exec argocd-lab-control-plane crictl images

# Remove image from Kind
docker exec argocd-lab-control-plane crictl rmi <image-id>
```

### Build Pipeline Integration
```bash
# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 -t <image-name> .

# Push to registry
docker push <registry>/<image-name>:<tag>

# Sign images (if using content trust)
DOCKER_CONTENT_TRUST=1 docker push <image-name>
```

## Best Practices

### Security
1. **Use non-root users** ✅ Implemented
2. **Minimal base images** ✅ Implemented  
3. **Scan images regularly** ⚠️ Needs automation
4. **Use secrets management** ⚠️ Not implemented
5. **Implement image signing** ⚠️ Not implemented

### Performance
1. **Multi-stage builds** ✅ Implemented
2. **Proper layer caching** ✅ Implemented
3. **Resource limits** ✅ Implemented in K8s
4. **Health checks** ✅ Implemented
5. **Optimized base images** ✅ Implemented

### Monitoring
1. **Structured logging** ✅ Implemented
2. **Metrics export** ✅ Implemented
3. **Health endpoints** ✅ Implemented
4. **Resource monitoring** ⚠️ Could be enhanced
5. **Security scanning** ⚠️ Needs automation

## Configuration Files

### Docker Compose (Optional)
```yaml
version: '3.8'
services:
  quarkus-demo:
    build: ./apps/quarkus-app
    ports:
      - "8081:8080"
    environment:
      - JAVA_OPTS=-Xmx256m -Xms128m
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  springboot-demo:
    build: ./apps/springboot-app
    ports:
      - "8082:8080"
    environment:
      - JAVA_OPTS=-Xmx256m -Xms128m
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

## Version Information

- **Docker Engine**: Check with `docker --version`
- **Docker Compose**: Check with `docker-compose --version`
- **BuildKit**: Enabled by default in recent versions
- **Base Images**: UBI8 OpenJDK 17 Runtime 1.18

## References

- [Docker Documentation](https://docs.docker.com/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kind Integration](https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster)
