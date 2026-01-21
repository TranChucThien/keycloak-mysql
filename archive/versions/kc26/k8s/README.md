# Keycloak 26 K8s Manifests

## Quick Deploy

```bash
# Deploy all
kubectl apply -f k8s-manifests-kc26/

# Check status
kubectl get pods
kubectl logs -f deployment/keycloak

# Access
# NodePort: http://<node-ip>:30080
```

## Files

- **keycloak-deployment.yaml**: Deployment + Service (NodePort 30080)
- **keycloak-configmap.yaml**: DB config (MySQL @ 172.28.174.197:3306)
- **keycloak-secret.yaml**: Credentials (admin/admin_password)

## Image

- **Image**: `chucthien03/keycloak:26`
- **Base**: Keycloak 26.0.0 (Quarkus 3.x)
- **Java**: 17
- **Mappers**: 4 custom mappers built-in

## Verify Mappers

```bash
kubectl logs deployment/keycloak | grep -i "oidc.*mapper"
```

## Rollback to KC21

```bash
kubectl apply -f k8s-manifests-kc21/
```
