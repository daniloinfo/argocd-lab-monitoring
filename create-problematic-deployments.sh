#!/bin/bash

# Script to create 5 problematic deployments and their services in applications namespace
# Now includes annotations for Prometheus/Grafana scrape and Service discovery.

set -e

NAMESPACE="applications"

echo "Creating 5 problematic deployments and services in namespace '$NAMESPACE'..."

# 1. ImagePullBackOff
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: problem-image-pull
  namespace: $NAMESPACE
  labels:
    app: problem-image-pull
spec:
  replicas: 1
  selector:
    matchLabels:
      app: problem-image-pull
  template:
    metadata:
      labels:
        app: problem-image-pull
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
        prometheus.io/path: "/metrics"
        profiles.grafana.com/memory.scrape: "true"
        profiles.grafana.com/memory.port: "80"
        profiles.grafana.com/cpu.scrape: "true"
        profiles.grafana.com/cpu.port: "80"
    spec:
      containers:
      - name: app
        image: nginx:this-tag-does-not-exist-12345
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: problem-image-pull-svc
  namespace: $NAMESPACE
  labels:
    app: problem-image-pull
spec:
  selector:
    app: problem-image-pull
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# 2. CrashLoopBackOff
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: problem-crash-loop
  namespace: $NAMESPACE
  labels:
    app: problem-crash-loop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: problem-crash-loop
  template:
    metadata:
      labels:
        app: problem-crash-loop
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
        prometheus.io/path: "/metrics"
        profiles.grafana.com/memory.scrape: "true"
        profiles.grafana.com/memory.port: "80"
        profiles.grafana.com/cpu.scrape: "true"
        profiles.grafana.com/cpu.port: "80"
    spec:
      containers:
      - name: app
        image: busybox
        command: ["/bin/sh", "-c", "echo 'I am going to crash now' && exit 1"]
---
apiVersion: v1
kind: Service
metadata:
  name: problem-crash-loop-svc
  namespace: $NAMESPACE
  labels:
    app: problem-crash-loop
spec:
  selector:
    app: problem-crash-loop
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# 3. Failing Liveness Probe
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: problem-liveness-probe
  namespace: $NAMESPACE
  labels:
    app: problem-liveness-probe
spec:
  replicas: 1
  selector:
    matchLabels:
      app: problem-liveness-probe
  template:
    metadata:
      labels:
        app: problem-liveness-probe
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
        prometheus.io/path: "/metrics"
        profiles.grafana.com/memory.scrape: "true"
        profiles.grafana.com/memory.port: "80"
        profiles.grafana.com/cpu.scrape: "true"
        profiles.grafana.com/cpu.port: "80"
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /non-existent-path
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: problem-liveness-probe-svc
  namespace: $NAMESPACE
  labels:
    app: problem-liveness-probe
spec:
  selector:
    app: problem-liveness-probe
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# 4. Pending (Impossible CPU request)
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: problem-pending-resources
  namespace: $NAMESPACE
  labels:
    app: problem-pending-resources
spec:
  replicas: 1
  selector:
    matchLabels:
      app: problem-pending-resources
  template:
    metadata:
      labels:
        app: problem-pending-resources
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
        prometheus.io/path: "/metrics"
        profiles.grafana.com/memory.scrape: "true"
        profiles.grafana.com/memory.port: "80"
        profiles.grafana.com/cpu.scrape: "true"
        profiles.grafana.com/cpu.port: "80"
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "1000" # Requests 1000 CPU cores
---
apiVersion: v1
kind: Service
metadata:
  name: problem-pending-resources-svc
  namespace: $NAMESPACE
  labels:
    app: problem-pending-resources
spec:
  selector:
    app: problem-pending-resources
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

# 5. OOMKilled
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: problem-oom-killed
  namespace: $NAMESPACE
  labels:
    app: problem-oom-killed
spec:
  replicas: 1
  selector:
    matchLabels:
      app: problem-oom-killed
  template:
    metadata:
      labels:
        app: problem-oom-killed
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
        prometheus.io/path: "/metrics"
        profiles.grafana.com/memory.scrape: "true"
        profiles.grafana.com/memory.port: "80"
        profiles.grafana.com/cpu.scrape: "true"
        profiles.grafana.com/cpu.port: "80"
    spec:
      containers:
      - name: app
        image: polinux/stress
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "150M", "--vm-hang", "1"]
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "50Mi"
          limits:
            memory: "100Mi" # Will be killed when trying to allocate 150M
---
apiVersion: v1
kind: Service
metadata:
  name: problem-oom-killed-svc
  namespace: $NAMESPACE
  labels:
    app: problem-oom-killed
spec:
  selector:
    app: problem-oom-killed
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

echo ""
echo "✅ Successfully created/updated 5 problematic deployments and their services with metrics annotations in namespace '$NAMESPACE'"
echo ""
echo "Wait a few seconds and run the following command to see the issues:"
echo "kubectl get pods,svc -n $NAMESPACE | grep problem"
