# Kubernetes Manifests

## Folders Overview

### k8s-manifests-basic/
- **Purpose**: Basic Keycloak deployment without custom mappers
- **Use case**: Testing standard Keycloak functionality
- **Features**: Simple deployment with ConfigMap and Secret

### k8s-manifests-init-container/
- **Purpose**: Advanced deployment with custom token mappers
- **Use case**: Production-ready setup with custom claims
- **Features**: Init container pattern to copy mappers from registry image

## Deployment Commands

```bash
# Basic deployment
kubectl apply -f k8s-manifests-basic/

# Init container deployment  
kubectl apply -f k8s-manifests-init-container/
```

## Prerequisites
- External MySQL database running
- For init-container: `chucthien03/custom-mapper-registry` image available