# Keycloak Migration Quick Reference

## 📊 Current State (2026-01-14)

### ✅ Completed Migrations
- **KC 15 → 16**: Seamless, no code changes
- **KC 16 → 18**: WildFly → Quarkus, no code changes
- **KC 18 → 21**: API breaking change, code updated ✅
- **KC 21 → 26**: Java 17 upgrade, completed ✅

### 🎯 Current Production
- **Version**: Keycloak 26.0.0
- **Image**: `chucthien03/keycloak:26`
- **Java**: 17
- **Quarkus**: 3.x
- **Database**: MySQL 8.0.23 @ 172.28.174.197:3306
- **K8s**: NodePort 30080
- **Mappers**: 4/4 working (Branch, CIF, UserLevel, Permissions)

---

## ✅ KC 21 → 26 Migration (COMPLETED)

### Changes Made

#### 1. Java 17 (REQUIRED)
```dockerfile
# Before (KC21)
FROM maven:3.8.4-openjdk-11-slim AS builder

# After (KC26)
FROM maven:3.9-openjdk-17-slim AS builder
```

#### 2. Keycloak Version
```xml
<!-- pom.xml -->
<keycloak.version>26.0.0</keycloak.version>  <!-- Was 21.1.2 -->
<maven.compiler.source>17</maven.compiler.source>
<maven.compiler.target>17</maven.compiler.target>
```

```dockerfile
FROM quay.io/keycloak/keycloak:26.0.0  # Was 21.1.2
```

#### 3. Maven Compiler Plugin
```xml
<version>3.11.0</version>  <!-- Was 3.7.0 -->
```

#### 4. Code Changes
- ✅ **No code changes needed**
- ✅ `getAttributeStream()` API still compatible
- ✅ All 4 mappers work without modification

---

## 📁 Project Structure

```
keycloak-mysql/
├── 21-aje-keycloak-token-mapper/     # Previous (KC21)
│   ├── src/main/java/
│   ├── pom.xml (KC 21.1.2, Java 11)
│   └── Dockerfile.builtin
│
├── 26-aje-keycloak-token-mapper/     # Current (KC26) ✅
│   ├── src/main/java/
│   │   ├── BranchOIDCProtocolMapper.java
│   │   ├── CifOIDCProtocolMapper.java
│   │   ├── UserLevelOIDCProtocolMapper.java
│   │   └── PermissionsOIDCProtocolMapper.java
│   ├── pom.xml (KC 26.0.0, Java 17)
│   ├── Dockerfile.builtin
│   ├── MIGRATION_KC26.md
│   └── README.md
│
├── k8s-manifests-kc26/               # Current K8s ✅
│   ├── keycloak-deployment.yaml
│   ├── keycloak-configmap.yaml
│   ├── keycloak-secret.yaml
│   └── README.md
│
└── UPGRADE_NOTES.md                  # Full history
```

---

## 🔑 Mapper Code Pattern (KC26)

```java
import java.util.stream.Collectors;

public AccessToken transformAccessToken(AccessToken token, ...) {
    if (Objects.nonNull(userSession)) {
        List<String> attributeValue = userSession.getUser()
            .getAttributeStream(CIF)
            .filter(Objects::nonNull)
            .collect(Collectors.toList());
        if (!attributeValue.isEmpty()) {
            token.getOtherClaims().put(CIF, attributeValue);
        }
    }
    setClaim(token, mappingModel, userSession, keycloakSession, clientSessionCtx);
    return token;
}
```

---

## 🚀 Build & Deploy KC26

### Build Image

```bash
cd 26-aje-keycloak-token-mapper

# Build
docker build -f Dockerfile.builtin -t chucthien03/keycloak:26 .

# Push
docker push chucthien03/keycloak:26
```

### Deploy to K8s

```bash
# Deploy
kubectl apply -f k8s-manifests-kc26/

# Check status
kubectl get pods
kubectl logs -f deployment/keycloak

# Verify version
kubectl logs deployment/keycloak | grep "Keycloak.*started"

# Verify mappers
kubectl logs deployment/keycloak | grep -i "oidc.*mapper"
```

### Access

- **URL**: http://<node-ip>:30080
- **Admin**: admin / admin_password

---

## ⚠️ Breaking Changes History

| Migration | Breaking Change | Solution |
|-----------|----------------|----------|
| KC16→18 | Env vars (`DB_*` → `KC_*`) | Update ConfigMap/Secret |
| KC16→18 | URL structure (removed `/auth`) | Update client configs |
| KC18→21 | `getAttribute()` removed | Use `getAttributeStream()` |
| KC21→26 | Java 11 deprecated | ✅ Upgraded to Java 17 |
| KC21→26 | Quarkus 2.x → 3.x | ✅ No impact on mappers |

---

## 🔄 Rollback

```bash
# Rollback to KC21
kubectl apply -f k8s-manifests-kc21/

# Rollback to KC18
kubectl apply -f k8s-manifests-kc18/
```

---

## 🎯 Version History

| Version | Java | Quarkus | Status | Image |
|---------|------|---------|--------|-------|
| KC 15 | 11 | - | Archive | - |
| KC 16 | 11 | - | Archive | - |
| KC 18 | 11 | 2.x | Archive | chucthien03/keycloak:18 |
| KC 21 | 11 | 2.13.8 | Stable | chucthien03/keycloak:21 |
| KC 26 | 17 | 3.x | **Current** ✅ | chucthien03/keycloak:26 |

---

## 📝 Testing Checklist

After deploying KC26:

- [ ] Keycloak starts successfully
- [ ] Database migration completes
- [ ] All 4 mappers loaded
- [ ] Admin console accessible
- [ ] Test realm/client works
- [ ] Token contains custom claims (cif, branch, etc.)
- [ ] No errors in logs

---

## 🎯 For Future Migrations

**Template for KC26 → Next Version:**

1. Check Java version requirement
2. Create new folder: `XX-aje-keycloak-token-mapper/`
3. Copy source files from KC26
4. Update pom.xml versions
5. Update Dockerfile base images
6. Review API changes in release notes
7. Test build locally
8. Deploy to K8s
9. Verify mappers and functionality

---

## 📚 Documentation

- **Main README**: `/keycloak-mysql/README.md`
- **KC26 Migration**: `/26-aje-keycloak-token-mapper/MIGRATION_KC26.md`
- **K8s Manifests**: `/k8s-manifests-kc26/README.md`
- **Full History**: `/UPGRADE_NOTES.md`
