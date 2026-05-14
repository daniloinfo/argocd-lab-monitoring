#!/bin/bash

# Script to create 50 deployments in applications namespace

set -e

NAMESPACE="applications"
BASE_NAME="simple-app"
COUNT=50

echo "Creating $COUNT deployments in namespace '$NAMESPACE'..."

# Create deployments in batches to avoid overwhelming the API server
for i in $(seq 1 $COUNT); do
    DEPLOYMENT_NAME="${BASE_NAME}-${i}"
    SERVICE_NAME="${BASE_NAME}-service-${i}"
    
    # Create deployment
    cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT_NAME
  namespace: $NAMESPACE
  labels:
    app: $DEPLOYMENT_NAME
    batch: "deployment-batch-$(date +%s)"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $DEPLOYMENT_NAME
  template:
    metadata:
      labels:
        app: $DEPLOYMENT_NAME
    spec:
      containers:
      - name: $DEPLOYMENT_NAME
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "25m"
            memory: "32Mi"
          limits:
            cpu: "100m"
            memory: "64Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

    # Create service
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
  namespace: $NAMESPACE
  labels:
    app: $DEPLOYMENT_NAME
    batch: "deployment-batch-$(date +%s)"
spec:
  selector:
    app: $DEPLOYMENT_NAME
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

    echo "Created deployment $i/$COUNT: $DEPLOYMENT_NAME"
    
    # Add small delay to prevent API server overload
    if [ $((i % 10)) -eq 0 ]; then
        echo "Sleeping for 2 seconds to prevent API server overload..."
        sleep 2
    fi
done

echo ""
echo "✅ Successfully created $COUNT deployments in namespace '$NAMESPACE'"
echo ""
echo "Checking deployment status..."
kubectl get deployments -n $NAMESPACE --no-headers | wc -l
echo "Deployments created: $(kubectl get deployments -n $NAMESPACE --no-headers | wc -l)"
echo "Services created: $(kubectl get services -n $NAMESPACE --no-headers | wc -l)"
echo ""
echo "To check status: kubectl get deployments -n $NAMESPACE"
echo "To check pods: kubectl get pods -n $NAMESPACE"
