# Keycloak 26 (Quarkus 3.x)

## 📊 Version Info
- **Keycloak**: 26.0.0
- **Java**: 17 (REQUIRED)
- **Quarkus**: 3.x
- **Database**: MySQL 8.0.23
- **Image**: `chucthien03/keycloak:26`

## 🔑 Key Changes from KC21
- Java 11 → 17 (REQUIRED)
- Quarkus 2.13.8 → 3.x
- Maven 3.8.4 → 3.9
- No code changes for mappers ✅

## 📁 Structure
```
kc26/
├── mapper/           # Custom token mappers (same code as KC21)
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
docker build -f Dockerfile.builtin -t chucthien03/keycloak:26 .
```

## 🔗 Access
- **URL**: http://localhost:8080 (Docker) or http://<node-ip>:30080 (K8s)
- **Admin**: admin / admin_password

## 📝 Migration Notes
See `mapper/MIGRATION_KC26.md` for detailed upgrade notes from KC21.

## ✅ Good News
No mapper code changes needed! Only infrastructure updates:
- Java 17 in Dockerfile and pom.xml
- Keycloak version bump
- Maven version update
