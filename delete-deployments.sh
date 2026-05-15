#!/bin/bash

# Script to delete resources created by create-deployments.sh and create-problematic-deployments.sh

set -e

NAMESPACE="applications"

echo "🧹 Deleting problematic deployments and services in namespace '$NAMESPACE'..."
kubectl delete deployment,svc -n $NAMESPACE \
  problem-image-pull problem-image-pull-svc \
  problem-crash-loop problem-crash-loop-svc \
  problem-liveness-probe problem-liveness-probe-svc \
  problem-pending-resources problem-pending-resources-svc \
  problem-oom-killed problem-oom-killed-svc \
  --ignore-not-found

echo "🧹 Deleting 'simple-app' deployments and services (this might take a moment)..."
# We can delete all resources that have the 'batch' label (created by create-deployments.sh)
kubectl delete deployment,svc -n $NAMESPACE -l 'batch' --ignore-not-found

echo ""
echo "✅ Cleanup completed successfully!"
echo ""
echo "Checking remaining resources in namespace '$NAMESPACE':"
kubectl get deployments,svc,pods -n $NAMESPACE
