# Keycloak 16 (WildFly)

## 📊 Version Info
- **Keycloak**: 16.1.1
- **Java**: 11
- **Runtime**: WildFly (Java EE)
- **Database**: MySQL 8.0.23
- **Image**: `chucthien03/keycloak:16`

## 🔑 Key Features
- Last version using WildFly runtime
- Hot-deploy pattern for custom mappers
- Environment variables: `DB_*`, `KEYCLOAK_*`
- URL structure: Includes `/auth` prefix

## 📁 Structure
```
kc16/
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
docker build -f Dockerfile.builtin -t chucthien03/keycloak:16 .
```

## 🔗 Access
- **URL**: http://localhost:8080/auth (Docker) or http://<node-ip>:30080/auth (K8s)
- **Admin Console**: http://localhost:8080/auth/admin
- **Admin**: admin / admin_password

## ⚠️ Note
KC16 is the last WildFly-based version. KC18+ uses Quarkus runtime with breaking changes.
