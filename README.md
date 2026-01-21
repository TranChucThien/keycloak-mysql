# Keycloak + MySQL with Custom Token Mappers

Production-ready Keycloak with MySQL and custom token mappers built into the image.

## 📊 Current Production

- **Version**: Keycloak 26.0.0
- **Image**: `chucthien03/keycloak:26`
- **Java**: 17
- **Quarkus**: 3.x
- **Database**: MySQL 8.0.23 @ 172.28.174.197:3306
- **K8s**: NodePort 30080
- **Mappers**: 4/4 working (Branch, CIF, UserLevel, Permissions)

## 📁 Project Structure

```
keycloak-mysql/
├── versions/
│   ├── kc12/              # Keycloak 12 (WildFly, Java 11)
│   ├── kc15/              # Keycloak 15 (WildFly, Java 11)
│   ├── kc16/              # Keycloak 16 (WildFly, Java 11)
│   ├── kc18/              # Keycloak 18 (Quarkus 2.x, Java 11) 
│   ├── kc21/              # Keycloak 21 (Quarkus 2.13, Java 17)
│   └── kc26/              # Keycloak 26 (Quarkus 3.x, Java 17) ✅ CURRENT
│       ├── mapper/        # Custom token mappers (not in git)
│       ├── k8s/          # Kubernetes manifests
│       ├── docker-compose/ # Docker Compose setup
│       └── README.md     # Version-specific guide
│
├── session-test/          # Session persistence test app
│   ├── app/              # Flask app
│   ├── k8s/              # K8s deployment
│   └── README.md         # Test guide
│
├── report/               # Analysis reports
├── archive/              # Old approaches and deprecated versions
├── images/               # Documentation screenshots
├── scripts/              # Utility scripts
├── MIGRATION_QUICK_REF.md # Quick migration reference
├── UPGRADE_NOTES.md      # Full upgrade history
└── README.md            # This file
```

## 🔑 Credentials

### Keycloak Admin
- **URL**: http://localhost:8080 (Docker) or http://<node-ip>:30080 (K8s)
- **Username**: `admin`
- **Password**: `admin_password`

### MySQL Database
- **Host**: 172.28.174.197:3306
- **Database**: `keycloak`
- **User**: `keycloak_user`
- **Password**: `keycloak_password`

## 🚀 Quick Start (KC26 - Current)

### Option 1: Kubernetes Deployment

```bash
cd versions/kc26/k8s
kubectl apply -f .
kubectl logs -f deployment/keycloak
```

### Option 2: Docker Compose

```bash
cd versions/kc26/docker-compose
docker-compose up -d
docker logs -f keycloak-kc26
```

### Build Custom Image

```bash
cd versions/kc26/mapper
docker build -f Dockerfile.builtin -t chucthien03/keycloak:26 .
docker push chucthien03/keycloak:26
```

## 🧪 Custom Token Mappers

### Available Mappers
- **BranchOIDCProtocolMapper** - Adds `branch` claim
- **CifOIDCProtocolMapper** - Adds `customer_id` claim  
- **UserLevelOIDCProtocolMapper** - Adds `user_level` claim
- **PermissionsOIDCProtocolMapper** - Adds `permissions` claim

### How It Works
1. Maven builds mapper JAR from source
2. Dockerfile copies JAR to `/opt/keycloak/providers/`
3. Keycloak auto-deploys on startup
4. Mappers available in Admin Console

## 📊 Version History

| Version | Java | Runtime | Status | Key Changes |
|---------|------|---------|--------|-------------|
| KC 12 | 11 | WildFly | Archive | Initial version |
| KC 15 | 11 | WildFly | Archive | Hot-deploy pattern |
| KC 16 | 11 | WildFly | Archive | Last WildFly version |
| KC 18 | 11 | Quarkus 2.7.5 | Stable | WildFly → Quarkus |
| KC 21 | 17 | Quarkus 2.13.8 | Stable | Stream API required |
| KC 26 | 17 | Quarkus 3.x | **Current** ✅ | Java 17, Quarkus 3.x |

## 🔄 Migration Guides

- **KC 12**: See `versions/kc12/README.md`
- **KC 15**: See `versions/kc15/README.md`
- **KC 16**: See `versions/kc16/README.md`
- **KC 18**: See `versions/kc18/README.md` + `versions/kc18/mapper/README.md`
- **KC 21**: See `versions/kc21/mapper/MIGRATION_KC21.md`
- **KC 26**: See `versions/kc26/mapper/MIGRATION_KC26.md`
- **Quick Ref**: See `MIGRATION_QUICK_REF.md`
- **Full History**: See `UPGRADE_NOTES.md`

## 🔧 Working with Different Versions

Each version folder is self-contained:

```bash
# Switch to KC18
cd versions/kc18
kubectl apply -f k8s/

# Switch to KC21
cd versions/kc21
kubectl apply -f k8s/

# Switch to KC26 (Current)
cd versions/kc26
kubectl apply -f k8s/
```

## 📝 Documentation

- **Main README**: This file
- **Version READMEs**: `versions/kc{12,15,16,18,21,26}/README.md`
- **Migration Quick Ref**: `MIGRATION_QUICK_REF.md`
- **Full Upgrade Notes**: `UPGRADE_NOTES.md`
- **K8s Manifests**: Each version has `k8s/README.md`
- **Mapper Details**: Each version has `mapper/README.md`

## 🎯 For New Users

1. Start with current version: `cd versions/kc26`
2. Read version README: `cat README.md`
3. Choose deployment method (K8s or Docker Compose)
4. Follow Quick Start instructions

## 🎯 For Migrations

1. Review `MIGRATION_QUICK_REF.md` for overview
2. Check target version README for specific changes
3. Read migration notes in mapper folder
4. Test in non-production environment first
5. Update `UPGRADE_NOTES.md` after completion
