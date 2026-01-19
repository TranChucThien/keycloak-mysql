# Keycloak Upgrade Notes

## **🔄 Upgrade History**

### **Version 12 → 15 (Completed ✅)**

**Date:** Current release  
**Status:** Successfully completed  
**Migration:** Database schema migrated without issues

#### **Key Changes Made**

- **Deployment Path:** Moved JAR from `/opt/jboss/keycloak/providers/` to `/opt/jboss/keycloak/standalone/deployments/`
- **Configuration:** Eliminated XML configuration modifications using `sed` commands
- **Deployment Strategy:** Hot-deploy pattern after DB migration completes

#### **Issues Resolved**

- **XML Parsing Failure:** Previous approach modified XML config causing migration errors
- **Migration Conflicts:** DB migration now completes before custom mapper deployment
- **Startup Sequence:** Clean separation between schema migration and custom code loading

#### **Validation Results**

- ✅ Database migration successful
- ✅ Custom mappers auto-deployed
- ✅ All 4 mappers available in Admin Console
- ✅ Token generation functional with custom claims

---

## **🚀 Version 15 → 16 (Completed ✅)**

**Date:** Current release  
**Status:** Successfully completed  
**Migration:** Database schema migrated without issues

#### **Upgrade Results**

- ✅ Custom mappers rebuilt and deployed successfully
- ✅ Database migration completed without errors
- ✅ All 4 mappers functional in KC 16
- ✅ Token generation working with CIF claims as expected
- ✅ No API compatibility issues found

#### **Image Updated**
- **Previous:** `chucthien03/keycloak:15`
- **Current:** `chucthien03/keycloak:16`
- **Deployment:** K8s manifests updated to use version 16

#### **Validation Completed**
- Token endpoint functional
- CIF mapper working correctly
- All custom claims present in JWT tokens
- Admin console accessible
- No performance degradation observed

---

---

## **🚀 Version 16 → 18 (Completed ✅)**

**Date:** 2026-01-14  
**Status:** Successfully completed  
**Migration:** WildFly → Quarkus architecture migration successful

### **Major Architecture Change**
- **Runtime:** WildFly (Java EE) → Quarkus (Cloud-native)
- **Startup Time:** ~30-40s → ~5-10s (3-4x faster)
- **Memory Usage:** Reduced footprint with Quarkus optimization

### **Key Changes Implemented**

#### **1. Environment Variables Migration**
```yaml
# KC16 (WildFly)
DB_VENDOR: MYSQL
DB_ADDR: 172.28.174.197
DB_PORT: 3306
DB_DATABASE: keycloak
DB_USER: keycloak_user
DB_PASSWORD: keycloak_password
KEYCLOAK_USER: admin
KEYCLOAK_PASSWORD: admin_password

# KC18 (Quarkus)
KC_DB: mysql
KC_DB_URL: jdbc:mysql://172.28.174.197:3306/keycloak
KC_DB_USERNAME: keycloak_user
KC_DB_PASSWORD: keycloak_password
KEYCLOAK_ADMIN: admin
KEYCLOAK_ADMIN_PASSWORD: admin_password
KC_HOSTNAME_STRICT: false
KC_HTTP_ENABLED: true
KC_PROXY: edge
KC_HOSTNAME_STRICT_BACKCHANNEL: false
```

#### **2. URL Structure Change**
```bash
# KC16
http://<host>:30080/auth/admin          # Admin Console
http://<host>:30080/auth/realms/master  # Realms

# KC18 (removed /auth prefix)
http://<host>:30080/admin               # Admin Console
http://<host>:30080/realms/master       # Realms
```

#### **3. Custom Mapper Deployment**
```dockerfile
# KC16 Dockerfile
FROM jboss/keycloak:16.1.1
COPY --from=builder /app/target/*.jar \
  /opt/jboss/keycloak/standalone/deployments/
# Hot-deploy, no build step

# KC18 Dockerfile
FROM quay.io/keycloak/keycloak:18.0.0
COPY --from=builder --chown=keycloak:keycloak /app/target/*.jar \
  /opt/keycloak/providers/
RUN /opt/keycloak/bin/kc.sh build --db=mysql
# Build step required for production
```

#### **4. Kubernetes Deployment Updates**
```yaml
# KC16
spec:
  containers:
  - name: keycloak
    image: chucthien03/keycloak:16
    # No args needed

# KC18
spec:
  containers:
  - name: keycloak
    image: chucthien03/keycloak:18-prod
    args: ["start"]  # or "start-dev" for development
```

### **Database Migration Results**

#### **Auto-Migration Executed**
Keycloak automatically ran Liquibase changesets:

```sql
-- Verified in DATABASECHANGELOG table
SELECT ID, AUTHOR, DATEEXECUTED FROM DATABASECHANGELOG 
WHERE ID LIKE '17.0.0%' OR ID LIKE '18.0.0%';

-- Results:
17.0.0-9562                       | keycloak | 2026-01-14 06:10:30
18.0.0-10625-IDX_ADMIN_EVENT_TIME | keycloak | 2026-01-14 06:10:30
```

#### **Migration Process**
1. KC18 detected KC16 schema version
2. Executed KC17 changesets (17.0.0-9562)
3. Executed KC18 changesets (18.0.0-10625-IDX_ADMIN_EVENT_TIME)
4. Updated schema version in DATABASECHANGELOG
5. Started successfully with migrated schema

### **Custom Mappers Validation**

#### **All 4 Mappers Loaded Successfully**
```bash
kubectl logs deployment/keycloak | grep "oidc.*mapper"

# Output:
KC-SERVICES0047: oidc-branch-property-mapper (BranchOIDCProtocolMapper)
KC-SERVICES0047: oidc-cif-property-mapper (CifOIDCProtocolMapper)
KC-SERVICES0047: oidc-user-level-property-mapper (UserLevelOIDCProtocolMapper)
KC-SERVICES0047: oidc-permissions-property-mapper (PermissionsOIDCProtocolMapper)
```

**Note:** `KC-SERVICES0047` warning is expected in KC18 - indicates internal SPI usage but mappers work correctly.

#### **Mapper Functionality Verified**
- ✅ All mappers appear in Admin Console
- ✅ Token generation includes custom claims (cif, branch, user_level, permissions)
- ✅ No code changes required in mapper implementations
- ✅ Same Java code works in both KC16 and KC18

### **Issues Encountered & Resolved**

#### **Issue 1: MySQL Driver Not Found**
**Error:** `No suitable driver found for jdbc:mysql://...`  
**Cause:** Using `start` command without pre-built MySQL driver  
**Solution:** Added `RUN /opt/keycloak/bin/kc.sh build --db=mysql` to Dockerfile

#### **Issue 2: Blank Admin Console Page**
**Error:** White page when accessing `/admin`  
**Cause:** Hostname validation mismatch (KC18 stricter than KC16)  
**Solution:** 
```yaml
KC_HOSTNAME_STRICT: "false"
KC_HOSTNAME_STRICT_BACKCHANNEL: "false"
# Removed KC_HOSTNAME for NodePort compatibility
```

#### **Issue 3: Old Environment Variables**
**Error:** `couldn't find key DB_USER in Secret`  
**Cause:** Old KC16 secret still deployed  
**Solution:** Deleted old resources before applying KC18 manifests
```bash
kubectl delete secret keycloak-secret
kubectl delete configmap keycloak-config
kubectl apply -f k8s-manifests-kc18/
```

### **Performance Improvements**

| Metric | KC16 (WildFly) | KC18 (Quarkus) | Improvement |
|--------|----------------|----------------|-------------|
| **Startup Time** | ~30-40s | ~5-10s | 3-4x faster |
| **Memory Usage** | Higher baseline | Optimized | Lower footprint |
| **Build Time** | N/A | ~8-10s | New requirement |
| **Image Size** | Larger | Smaller | Quarkus optimization |

### **Validation Results**
- ✅ Database migration successful (KC16 → KC17 → KC18)
- ✅ Custom mappers deployed and functional
- ✅ All 4 mappers available in Admin Console
- ✅ Token generation working with custom claims
- ✅ Admin console accessible at new URL (no /auth)
- ✅ Existing realms, clients, users preserved
- ✅ Authentication flows working correctly
- ✅ No performance degradation observed
- ✅ Production mode operational

### **Images Updated**
- **Previous:** `chucthien03/keycloak:16`
- **Current:** `chucthien03/keycloak:18-prod`
- **Deployment:** New manifests in `k8s-manifests-kc18/`

### **Documentation Created**
- ✅ `k8s-manifests-kc18/README.md` - Infrastructure migration guide
- ✅ `18-aje-keycloak-token-mapper/README.md` - Mapper migration guide
- ✅ Updated main README.md with KC18 information

---

## **🚀 Version 18 → 21 (Completed ✅)**

**Date:** 2026-01-14  
**Status:** Successfully completed  
**Migration:** API breaking changes - custom mapper code updated

### **Major API Breaking Change**
- **UserModel API:** `getAttribute()` method removed
- **New API:** Must use `getAttributeStream()` with Stream processing
- **Java Compatibility:** `.collect(Collectors.toList())` for Java 11

### **Key Changes Implemented**

#### **1. Version Updates**
```xml
<!-- pom.xml -->
<keycloak.version>21.1.2</keycloak.version>  <!-- Was 18.0.0 -->
```

```dockerfile
# Dockerfile.builtin
FROM quay.io/keycloak/keycloak:21.1.2  # Was 18.0.0
```

#### **2. Custom Mapper Code Changes (BREAKING)**

**Before (KC18):**
```java
public AccessToken transformAccessToken(AccessToken token, ...) {
    if (Objects.nonNull(userSession) && !userSession.getUser().getAttribute(CIF).isEmpty()) {
        token.getOtherClaims().put(CIF, userSession.getUser().getAttribute(CIF));
    }
    return token;
}
```

**After (KC21):**
```java
import java.util.stream.Collectors;  // New import

public AccessToken transformAccessToken(AccessToken token, ...) {
    if (Objects.nonNull(userSession)) {
        List<String> attributeValue = userSession.getUser().getAttributeStream(CIF)
            .filter(Objects::nonNull)
            .collect(Collectors.toList());  // Use collect() for Java 11
        if (!attributeValue.isEmpty()) {
            token.getOtherClaims().put(CIF, attributeValue);
        }
    }
    return token;
}
```

**Note:** `.toList()` requires Java 16+, use `.collect(Collectors.toList())` for Java 11.

#### **3. All 4 Mappers Updated**
- ✅ `BranchOIDCProtocolMapper.java`
- ✅ `CifOIDCProtocolMapper.java`
- ✅ `UserLevelOIDCProtocolMapper.java`
- ✅ `PermissionsOIDCProtocolMapper.java`

#### **4. Kubernetes Deployment (No Changes)**
```yaml
# Same as KC18, only image tag changed
spec:
  containers:
  - name: keycloak
    image: chucthien03/keycloak:21  # Was :18-prod
    args: ["start"]
```

### **Database Migration Results**

#### **Auto-Migration Executed**
```bash
kubectl logs deployment/keycloak | grep -i liquibase

# KC21 auto-migrated from KC18 schema
# All changesets 19.0.0 → 21.0.0 executed successfully
```

### **Custom Mappers Validation**

#### **All 4 Mappers Loaded Successfully**
```bash
kubectl logs deployment/keycloak | grep "oidc.*mapper"

# Output:
KC-SERVICES0047: oidc-branch-property-mapper (BranchOIDCProtocolMapper)
KC-SERVICES0047: oidc-cif-property-mapper (CifOIDCProtocolMapper)
KC-SERVICES0047: oidc-user-level-property-mapper (UserLevelOIDCProtocolMapper)
KC-SERVICES0047: oidc-permissions-property-mapper (PermissionsOIDCProtocolMapper)
```

**Note:** `KC-SERVICES0047` warning is expected - mappers work correctly.

### **Issues Encountered & Resolved**

#### **Issue 1: Compilation Error - getAttribute() not found**
**Error:** `error: cannot find symbol - method getAttribute(String)`  
**Cause:** KC21 removed `UserModel.getAttribute()` method  
**Solution:** Updated all mappers to use `getAttributeStream()`

#### **Issue 2: Compilation Error - toList() not found**
**Error:** `error: cannot find symbol - method toList()`  
**Cause:** `.toList()` requires Java 16+, project uses Java 11  
**Solution:** Changed to `.collect(Collectors.toList())`

### **Performance Metrics**

| Metric | KC18 | KC21 | Change |
|--------|------|------|--------|
| **Startup Time** | ~5-10s | ~13.6s | Slightly slower |
| **Quarkus Version** | 2.7.5 | 2.13.8 | Updated |
| **Memory Usage** | Optimized | Similar | No change |
| **Build Time** | ~35s | ~40s | Slightly longer |

### **Validation Results**
- ✅ Database migration successful (KC18 → KC21)
- ✅ Custom mappers code updated (4/4)
- ✅ All mappers loaded and functional
- ✅ Token generation working with custom claims
- ✅ Admin console accessible
- ✅ Existing realms, clients, users preserved
- ✅ Authentication flows working correctly
- ✅ Java 11 compatibility maintained

### **Images Updated**
- **Previous:** `chucthien03/keycloak:18-prod`
- **Current:** `chucthien03/keycloak:21`
- **Deployment:** Manifests in `k8s-manifests-kc21/`

### **Documentation Created**
- ✅ `21-aje-keycloak-token-mapper/MIGRATION_KC21.md` - API changes guide
- ✅ Updated all 4 mapper source files
- ✅ Updated UPGRADE_NOTES.md

---

## **🚀 Version 21 → 26 (Completed ✅)**

**Date:** 2026-01-14  
**Status:** Successfully completed  
**Migration:** Java 17 upgrade, Quarkus 3.x migration successful

### **Major Changes**
- **Java:** 11 → 17 (REQUIRED)
- **Quarkus:** 2.13.8 → 3.x
- **Keycloak:** 21.1.2 → 26.0.0
- **Maven:** 3.8.4 → 3.9
- **Maven Compiler Plugin:** 3.7.0 → 3.11.0

### **Key Changes Implemented**

#### **1. Java 17 Upgrade (REQUIRED)**
```dockerfile
# Before (KC21)
FROM maven:3.8.4-openjdk-11-slim AS builder

# After (KC26)
FROM maven:3.9-openjdk-17-slim AS builder
```

#### **2. Version Updates**
```xml
<!-- pom.xml -->
<maven.compiler.source>17</maven.compiler.source>  <!-- Was 11 -->
<maven.compiler.target>17</maven.compiler.target>  <!-- Was 11 -->
<keycloak.version>26.0.0</keycloak.version>  <!-- Was 21.1.2 -->
```

```dockerfile
# Dockerfile.builtin
FROM quay.io/keycloak/keycloak:26.0.0  # Was 21.1.2
```

#### **3. Maven Compiler Plugin Update**
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <version>3.11.0</version>  <!-- Was 3.7.0 -->
</plugin>
```

#### **4. Custom Mapper Code (NO CHANGES NEEDED)**
- ✅ All 4 mappers work without modification
- ✅ `getAttributeStream()` API still compatible
- ✅ Same code from KC21 works in KC26

### **Database Migration Results**

#### **Auto-Migration Executed**
```bash
kubectl logs deployment/keycloak | grep -i liquibase

# KC26 auto-migrated from KC21 schema
# All changesets 22.0.0 → 26.0.0 executed successfully
```

### **Custom Mappers Validation**

#### **All 4 Mappers Loaded Successfully**
```bash
kubectl logs deployment/keycloak | grep "oidc.*mapper"

# Output:
KC-SERVICES0047: oidc-branch-property-mapper (BranchOIDCProtocolMapper)
KC-SERVICES0047: oidc-cif-property-mapper (CifOIDCProtocolMapper)
KC-SERVICES0047: oidc-user-level-property-mapper (UserLevelOIDCProtocolMapper)
KC-SERVICES0047: oidc-permissions-property-mapper (PermissionsOIDCProtocolMapper)
```

### **Performance Metrics**

| Metric | KC21 | KC26 | Change |
|--------|------|------|--------|
| **Startup Time** | ~13.6s | ~10-15s | Similar |
| **Quarkus Version** | 2.13.8 | 3.x | Major upgrade |
| **Java Version** | 11 | 17 | Required upgrade |
| **Memory Usage** | Optimized | Similar | No change |
| **Build Time** | ~40s | ~45s | Slightly longer |

### **Validation Results**
- ✅ Database migration successful (KC21 → KC26)
- ✅ Custom mappers work without code changes (4/4)
- ✅ All mappers loaded and functional
- ✅ Token generation working with custom claims
- ✅ Admin console accessible
- ✅ Existing realms, clients, users preserved
- ✅ Authentication flows working correctly
- ✅ Java 17 compatibility confirmed
- ✅ Quarkus 3.x working properly

### **Images Updated**
- **Previous:** `chucthien03/keycloak:21`
- **Current:** `chucthien03/keycloak:26`
- **Deployment:** Manifests in `k8s-manifests-kc26/`

### **Documentation Created**
- ✅ `26-aje-keycloak-token-mapper/` - KC26 mapper project
- ✅ `26-aje-keycloak-token-mapper/MIGRATION_KC26.md` - Migration guide
- ✅ `k8s-manifests-kc26/` - K8s deployment files
- ✅ Updated MIGRATION_QUICK_REF.md
- ✅ Updated UPGRADE_NOTES.md

---

## **🔮 Future Upgrades**

**Next Version:** KC 27+ (When available)  
**Status:** 🔵 Monitoring releases

#### **Lessons Learned from All Migrations**

| Lesson | Impact | Future Application |
|--------|--------|--------------------|
| **Env vars change (KC16→18)** | Update all manifests | Document all env var changes upfront |
| **URL structure change (KC16→18)** | Update client configs | Test all endpoints before production |
| **Hostname validation (KC18)** | Access issues | Disable strict validation for NodePort |
| **Build step required (KC18+)** | Deployment complexity | Include in Dockerfile, document clearly |
| **Auto-migration works** | No manual intervention | Trust Liquibase, verify in logs |
| **Mapper code unchanged (KC16→18, KC21→26)** | Easy migration | SPI stability across versions |
| **Mapper code changed (KC18→21)** | Breaking change | Always check API changes in release notes |
| **Java version matters** | `.toList()` vs `.collect()` | Match Java features to project version |
| **Java upgrade required (KC21→26)** | Major change | Plan Java upgrades early |
| **Delete old resources** | Avoid conflicts | Clean slate approach for major upgrades |
| **Quarkus upgrades (2.x→3.x)** | No mapper impact | Framework changes don't affect SPI |

---

### **Upgrade Process (Reference)**

#### **Steps Completed for 15→16:**
1. **Custom Mapper Rebuild**
   ```bash
   cd aje-keycloak-token-mapper-k8s-prod
   # Updated Dockerfile.builtin base image to KC 16
   mvn clean package
   docker build -f Dockerfile.builtin -t chucthien03/keycloak:16 .
   ```

2. **K8s Deployment Update**
   ```bash
   # Updated keycloak-deployment.yaml image tag
   # FROM: chucthien03/keycloak:15
   # TO: chucthien03/keycloak:16
   kubectl apply -f k8s-manifests-rebuild/
   ```

3. **Migration Monitoring**
   ```bash
   kubectl logs -f deployment/keycloak
   # Confirmed: No migration errors
   # Confirmed: Custom mappers deployed successfully
   ```

4. **Functional Testing**
   ```bash
   # Token generation test passed
   # CIF claims present in JWT as expected
   # All mappers available in Admin Console
   ```

---

## **📋 Upgrade Template**

### **Post-Upgrade Documentation**
After successful upgrade to version 16:

1. ✅ Updated this document with results
2. Update README.md version info
3. Tag release with upgrade notes
4. Document any new issues discovered
5. Update troubleshooting section if needed

### **Lessons Learned (All Migrations)**
- Hot-deploy pattern works well for custom extensions (KC12-16)
- Avoid XML configuration modifications during build
- Always test DB migration in isolated environment first
- Monitor logs closely during first 30 minutes post-upgrade
- **KC 15→16:** Seamless upgrade with no breaking changes for custom mappers
- **KC 16→18:** Major architecture change but smooth migration with proper preparation
- **KC 18→21:** API breaking changes require code updates
- **KC 21→26:** Java upgrade required but no code changes for mappers
- **CIF Token Validation:** Custom claims continue to work as expected across versions
- **Quarkus Migration:** Faster startup and lower memory usage worth the effort
- **Auto-migration:** Keycloak's Liquibase integration handles schema updates reliably
- **Documentation:** Comprehensive migration guides essential for major version jumps
- **Java Upgrades:** Plan early, test thoroughly, update all build tools
- **SPI Stability:** Keycloak's SPI layer is stable across major versions