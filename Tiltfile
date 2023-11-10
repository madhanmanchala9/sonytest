# Docker image to build
custom_nginx = 'localhost:5000/custom-nginx:latest'

# Kubernetes manifests to apply
k8s_yaml(['deployment.yaml', 'service.yaml'])

# Docker build
docker_build(custom_nginx, '.', dockerfile='Dockerfile')

# Allow Tilt to watch the Dockerfile and nginx configuration for changes
watch_file('Dockerfile')
watch_file('nginx.conf')