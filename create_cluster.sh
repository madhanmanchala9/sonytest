#!/bin/bash

# Variables
CLUSTER_NAME=kind-with-registry
REGISTRY_PORT=5000
REGISTRY_NAME=kind-registry

# Start the local registry
docker run -d --restart=always -p "${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" registry:2

# Create a kind cluster with a local registry
kind create cluster --name "${CLUSTER_NAME}" --config=kind-config.yaml

# Connect the registry to the cluster network
docker network connect "kind" "${REGISTRY_NAME}" || true

# Build a custom nginx image and push it to the local registry
docker build -t localhost:${REGISTRY_PORT}/custom-nginx:latest .
docker push localhost:${REGISTRY_PORT}/custom-nginx:latest

# Apply the Kubernetes manifests
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Start Tilt
tilt up
