# Keycloak 16 K8s Manifests

## Quick Deploy

```bash
kubectl apply -f .
kubectl get pods
kubectl logs -f deployment/keycloak
```

## Access

- **URL**: http://<node-ip>:30080/auth
- **Admin Console**: http://<node-ip>:30080/auth/admin
- **Credentials**: admin / admin_password

## Files

- **keycloak-deployment.yaml**: Deployment + Service (NodePort 30080)
- **keycloak-secret.yaml**: Credentials

## Environment Variables

KC16 uses old-style env vars:
- `DB_VENDOR`, `DB_ADDR`, `DB_PORT`, `DB_DATABASE`
- `DB_USER`, `DB_PASSWORD`
- `KEYCLOAK_USER`, `KEYCLOAK_PASSWORD`

## Note

KC16 is WildFly-based. For Quarkus-based versions, see KC18+.
