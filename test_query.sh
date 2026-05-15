#!/bin/bash
PROMETHEUS_URL="http://localhost:30090"
clean_query='sum by (namespace, deployment) (kube_deployment_spec_replicas{namespace=~".*", deployment=~".*"}) and ((sum by (namespace, deployment) (kube_deployment_spec_replicas{namespace=~".*", deployment=~".*"}) - sum by (namespace, deployment) (kube_deployment_status_replicas_available{namespace=~".*", deployment=~".*"})) > 0)'
encoded_query=$(jq -nr --arg q "$clean_query" '$q|@uri')
curl -s "$PROMETHEUS_URL/api/v1/query?query=$encoded_query" | jq .
