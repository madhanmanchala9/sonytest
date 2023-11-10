#!/bin/bash

# Define cluster name
CLUSTER_NAME=kind-with-registry
REGISTRY_PORT=5000

# Create a kind cluster with a local registry
function create_kind_cluster() {
  cat <<EOF | kind create cluster --name ${CLUSTER_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REGISTRY_PORT}"]
    endpoint = ["http://${REGISTRY_NAME}:${REGISTRY_PORT}"]
nodes:
- role: control-plane
EOF

  # Connect the registry to the cluster network
  docker network connect "kind" "kind-registry" || true

  # Document the local registry
  # https://github.com/kubernetes-sigs/kind/releases/tag/v0.11.0
  for node in $(kind get nodes --name ${CLUSTER_NAME}); do
    kubectl annotate node "${node}" "kind.x-k8s.io/registry=localhost:${REGISTRY_PORT}";
  done
}

# Start the local registry
function start_local_registry() {
  running="$(docker inspect -f '{{.State.Running}}' "kind-registry" 2>/dev/null || true)"
  if [ "${running}" != 'true' ]; then
    docker run \
      -d --restart=always -p "${REGISTRY_PORT}:5000" --name "kind-registry" \
      registry:2
  fi
}

# Build a custom nginx image and push it to the local registry
function build_nginx_image() {
  # Create a Dockerfile
  cat >Dockerfile <<EOF
FROM nginx:alpine
COPY nginx.conf /etc/nginx/nginx.conf
EOF

  # Create a custom nginx.conf
  cat >nginx.conf <<EOF
events {}
http {
  server {
    listen 8081;
    location / {
      root /usr/share/nginx/html;
      index index.html;
    }
  }
}
EOF

  # Build and push the image
  docker build -t localhost:${REGISTRY_PORT}/custom-nginx:latest .
  docker push localhost:${REGISTRY_PORT}/custom-nginx:latest
}

# Create Kubernetes deployment and service
function deploy_to_kubernetes() {
  # Create a kubernetes deployment file
  cat >deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: localhost:${REGISTRY_PORT}/custom-nginx:latest
        ports:
        - containerPort: 8081
EOF

  # Create a kubernetes service file
  cat >service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 8081
      targetPort: 8081
  type: ClusterIP
EOF

  # Deploy to Kubernetes using Tilt
  cat >Tiltfile <<EOF
k8s_yaml(['deployment.yaml', 'service.yaml'])
docker_build('localhost:${REGISTRY_PORT}/custom-nginx', '.')
EOF

  # Start Tilt in non-interactive mode to apply the configurations
  tilt up --no-browser
}

# Main script starts here
start_local_registry
create_kind_cluster
build_nginx_image
deploy_to_kubernetes
