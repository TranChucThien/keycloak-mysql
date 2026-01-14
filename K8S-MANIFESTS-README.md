# Kubernetes Manifests for Keycloak 15 with Built-in Custom Mappers

## 📁 Folder: k8s-manifests-rebuild/

**Purpose:** Production deployment with custom token mappers built into Keycloak image

**Image:** `chucthien03/keycloak:15` (built from Dockerfile.builtin)

**Approach:** JAR files in `/opt/jboss/keycloak/standalone/deployments/`

**Files:**
- `keycloak-deployment.yaml` - Deployment + NodePort Service
- `keycloak-configmap.yaml` - Database configuration
- `keycloak-secret.yaml` - Credentials (base64 encoded)

## 🚀 Deployment

```bash
# Deploy all manifests
kubectl apply -f k8s-manifests-rebuild/

# Check status
kubectl get pods -l app=keycloak
kubectl logs -f deployment/keycloak

# Access Keycloak
# NodePort: http://<node-ip>:30080/auth
```

## 🔧 Configuration

**Database:** External MySQL at 172.28.174.197:3306

**Credentials:**
- Admin: `admin` / `admin_password`
- DB User: `keycloak_user` / `keycloak_password`

## 📚 Archive

Old approaches moved to `archive/`:
- `k8s-manifests-basic/` - Basic deployment without mappers
- `k8s-manifests-init-container/` - Init container pattern