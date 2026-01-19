# 📁 Project Structure - Reorganized

## ✅ New Organization (Version-Based)

Mỗi version là một folder độc lập, chứa đầy đủ:
- Custom mapper source code
- Kubernetes manifests
- Docker Compose setup
- Version-specific README

```
keycloak-mysql/
├── versions/
│   ├── kc18/                    # Keycloak 18
│   │   ├── mapper/              # Source code + Dockerfile
│   │   │   ├── src/
│   │   │   ├── pom.xml
│   │   │   ├── Dockerfile.builtin
│   │   │   ├── MIGRATION_KC18.md
│   │   │   └── README.md
│   │   ├── k8s/                 # K8s deployment
│   │   │   ├── keycloak-deployment.yaml
│   │   │   ├── keycloak-configmap.yaml
│   │   │   ├── keycloak-secret.yaml
│   │   │   └── README.md
│   │   ├── docker-compose/      # Docker Compose
│   │   │   └── docker-compose.yml
│   │   └── README.md            # Version overview
│   │
│   ├── kc21/                    # Keycloak 21
│   │   ├── mapper/
│   │   │   ├── src/
│   │   │   ├── pom.xml
│   │   │   ├── Dockerfile.builtin
│   │   │   ├── MIGRATION_KC21.md
│   │   │   └── README.md
│   │   ├── k8s/
│   │   │   ├── keycloak-deployment.yaml
│   │   │   ├── keycloak-configmap.yaml
│   │   │   ├── keycloak-secret.yaml
│   │   │   └── README.md
│   │   ├── docker-compose/
│   │   │   └── docker-compose.yml
│   │   └── README.md
│   │
│   └── kc26/                    # Keycloak 26 ✅ CURRENT
│       ├── mapper/
│       │   ├── src/
│       │   ├── pom.xml
│       │   ├── Dockerfile.builtin
│       │   ├── MIGRATION_KC26.md
│       │   └── README.md
│       ├── k8s/
│       │   ├── keycloak-deployment.yaml
│       │   ├── keycloak-configmap.yaml
│       │   ├── keycloak-secret.yaml
│       │   └── README.md
│       ├── docker-compose/
│       │   └── docker-compose.yml
│       └── README.md
│
├── archive/                     # Old versions & deprecated approaches
│   ├── 16-aje-keycloak-token-mapper-k8s-prod/
│   ├── k8s-manifests-basic/
│   ├── k8s-manifests-init-container/
│   ├── k8s-manifests-rebuild/
│   ├── mysql-only/
│   └── docker-compose.*.yml
│
├── images/                      # Documentation screenshots
├── scripts/                     # Utility scripts
│
├── README.md                    # Main documentation
├── MIGRATION_QUICK_REF.md       # Quick migration reference
└── UPGRADE_NOTES.md             # Full upgrade history
```

## 🎯 Benefits

### 1. Self-Contained Versions
Mỗi version có tất cả files cần thiết trong một folder:
```bash
cd versions/kc26
ls
# mapper/  k8s/  docker-compose/  README.md
```

### 2. Easy Switching
```bash
# Deploy KC21
cd versions/kc21/k8s
kubectl apply -f .

# Deploy KC26
cd versions/kc26/k8s
kubectl apply -f .
```

### 3. Clear Documentation
- Root `README.md` - Overview và current version
- `versions/kcXX/README.md` - Version-specific guide
- `versions/kcXX/mapper/MIGRATION_KCXX.md` - Migration details
- `MIGRATION_QUICK_REF.md` - Quick reference
- `UPGRADE_NOTES.md` - Full history

### 4. Clean Archive
Old approaches moved to `archive/`:
- KC16 code
- Init-container pattern
- Local mount approach
- Basic deployments

## 📝 Usage Examples

### Build Specific Version
```bash
cd versions/kc26/mapper
docker build -f Dockerfile.builtin -t chucthien03/keycloak:26 .
```

### Deploy with K8s
```bash
cd versions/kc26/k8s
kubectl apply -f .
```

### Deploy with Docker Compose
```bash
cd versions/kc26/docker-compose
docker-compose up -d
```

### Compare Versions
```bash
# Compare pom.xml
diff versions/kc21/mapper/pom.xml versions/kc26/mapper/pom.xml

# Compare Dockerfile
diff versions/kc21/mapper/Dockerfile.builtin versions/kc26/mapper/Dockerfile.builtin
```

## 🔄 Migration Workflow

1. **Review current version**
   ```bash
   cd versions/kc26
   cat README.md
   ```

2. **Check migration notes**
   ```bash
   cat mapper/MIGRATION_KC26.md
   ```

3. **Build new image**
   ```bash
   cd mapper
   docker build -f Dockerfile.builtin -t chucthien03/keycloak:26 .
   ```

4. **Deploy**
   ```bash
   cd ../k8s
   kubectl apply -f .
   ```

## ✅ Cleanup Completed

Removed old structure:
- ❌ `18-aje-keycloak-token-mapper/`
- ❌ `21-aje-keycloak-token-mapper/`
- ❌ `26-aje-keycloak-token-mapper/`
- ❌ `k8s-manifests-kc18/`
- ❌ `k8s-manifests-kc21/`
- ❌ `k8s-manifests-kc26/`
- ❌ `docker-compose-kc18.yml`
- ❌ `docker-compose.yml`

New structure:
- ✅ `versions/kc18/` (mapper + k8s + docker-compose)
- ✅ `versions/kc21/` (mapper + k8s + docker-compose)
- ✅ `versions/kc26/` (mapper + k8s + docker-compose)
- ✅ Each version has README.md
- ✅ Clean root directory
