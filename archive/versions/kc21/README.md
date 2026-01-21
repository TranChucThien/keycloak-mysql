# Keycloak 21 (Quarkus)

## 📊 Version Info
- **Keycloak**: 21.1.2
- **Java**: 11
- **Quarkus**: 2.13.8
- **Database**: MySQL 8.0.23
- **Image**: `chucthien03/keycloak:21`

## 🔑 Key Changes from KC18
- API Breaking Change: `getAttribute()` → `getAttributeStream()`
- All 4 mappers updated to use Stream API
- Quarkus 2.7.5 → 2.13.8

## 📁 Structure
```
kc21/
├── mapper/           # Custom token mappers (updated code)
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
docker build -f Dockerfile.builtin -t chucthien03/keycloak:21 .
```

## 🔗 Access
- **URL**: http://localhost:8080 (Docker) or http://<node-ip>:30080 (K8s)
- **Admin**: admin / admin_password

## 📝 Migration Notes
See `mapper/MIGRATION_KC21.md` for detailed upgrade notes from KC18.

## ⚠️ Breaking Changes
Custom mapper code requires updates:
```java
// Old (KC18)
userSession.getUser().getAttribute(CIF)

// New (KC21)
userSession.getUser().getAttributeStream(CIF)
    .filter(Objects::nonNull)
    .collect(Collectors.toList())
```
