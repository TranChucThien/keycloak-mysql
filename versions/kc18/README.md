# Keycloak 18 (Quarkus)

## 📊 Version Info
- **Keycloak**: 18.0.0
- **Java**: 11
- **Quarkus**: 2.7.5
- **Database**: MySQL 8.0.23
- **Image**: `chucthien03/keycloak:18-prod`

## 🔑 Key Changes from KC16
- WildFly → Quarkus architecture
- Environment variables: `DB_*` → `KC_*`
- URL structure: Removed `/auth` prefix
- Build step required: `kc.sh build --db=mysql`

## 📁 Structure
```
kc18/
├── mapper/           # Custom token mappers
├── k8s/             # Kubernetes manifests
└── docker-compose/  # Docker Compose setup
```

## 🚀 Quick Start

### Docker Compose
```bash
cd docker-compose
docker-compose up -d
```

### Kubernetes
```bash
cd k8s
kubectl apply -f .
```

### Build Custom Image
```bash
cd mapper
docker build -f Dockerfile.builtin -t chucthien03/keycloak:18-prod .
```

## 🔗 Access
- **URL**: http://localhost:8080 (Docker) or http://<node-ip>:30080 (K8s)
- **Admin Console**: http://<node-ip>:30080/admin (no `/auth` prefix)
- **Admin**: admin / admin_password

## ⚠️ Common Issues

### Blank Page on Admin Console
**Symptom**: White/blank page when accessing `/admin`

**Cause**: Production mode requires HTTPS by default, HTTP access causes redirect loop

**Fix**: Ensure ConfigMap has:
```yaml
KC_HOSTNAME_STRICT: "false"
KC_HOSTNAME_STRICT_HTTPS: "false"  # Critical for HTTP access
KC_HOSTNAME_STRICT_BACKCHANNEL: "false"
```

**Apply:**
```bash
kubectl apply -f k8s/keycloak-configmap.yaml
kubectl rollout restart deployment/keycloak
```

## 📝 Migration Notes
See `mapper/MIGRATION_KC18.md` for detailed upgrade notes from KC16.
