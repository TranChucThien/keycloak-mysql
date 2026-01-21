# Keycloak 16 → 18 Migration Guide (Kubernetes)

## **🎯 Overview**

Complete guide for migrating Keycloak from version 16 (WildFly) to version 18 (Quarkus) on Kubernetes with MySQL 8 and custom token mappers.

## **📊 Major Changes: KC16 vs KC18**

### **1. Architecture Change**

| Aspect | Keycloak 16 | Keycloak 18 |
|--------|-------------|-------------|
| **Runtime** | WildFly (Java EE) | Quarkus (Cloud-native) |
| **Startup Time** | ~30-40s | ~5-10s |
| **Memory Usage** | Higher | Lower (optimized) |
| **Build Step** | Not required | Required for production |

### **2. URL Structure**

```bash
# Keycloak 16
http://<host>:8080/auth/admin          # Admin Console
http://<host>:8080/auth/realms/master  # Master realm

# Keycloak 18
http://<host>:8080/admin               # Admin Console (no /auth)
http://<host>:8080/realms/master       # Master realm (no /auth)
```

### **3. Environment Variables**

| Purpose | KC16 | KC18 |
|---------|------|------|
| **Database Type** | `DB_VENDOR: MYSQL` | `KC_DB: mysql` |
| **Database URL** | `DB_ADDR` + `DB_PORT` + `DB_DATABASE` | `KC_DB_URL: jdbc:mysql://...` |
| **DB Username** | `DB_USER` | `KC_DB_USERNAME` |
| **DB Password** | `DB_PASSWORD` | `KC_DB_PASSWORD` |
| **Admin User** | `KEYCLOAK_USER` | `KEYCLOAK_ADMIN` |
| **Admin Password** | `KEYCLOAK_PASSWORD` | `KEYCLOAK_ADMIN_PASSWORD` |
| **Hostname** | `KEYCLOAK_FRONTEND_URL` | `KC_HOSTNAME` |
| **Proxy Mode** | `PROXY_ADDRESS_FORWARDING` | `KC_PROXY: edge` |
| **HTTP Enabled** | Default enabled | `KC_HTTP_ENABLED: true` |

### **4. Custom Providers (Mappers)**

| Aspect | KC16 | KC18 |
|--------|------|------|
| **Provider Path** | `/opt/jboss/keycloak/standalone/deployments/` | `/opt/keycloak/providers/` |
| **Hot Deploy** | Yes (auto-deploy) | No (requires rebuild) |
| **Build Command** | Not needed | `kc.sh build --db=mysql` |
| **Deployment** | Drop JAR → auto-deploy | JAR + build → restart |

### **5. Startup Commands**

```bash
# Keycloak 16
# No command needed, uses default entrypoint

# Keycloak 18
args: ["start-dev"]  # Development mode (auto-downloads DB drivers)
args: ["start"]      # Production mode (requires pre-built image)
```

## **🔄 Migration Process**

### **Step 1: Backup Current Setup**

```bash
# Backup KC16 database
kubectl exec deployment/keycloak -- mysqldump \
  -h 172.28.174.197 -u keycloak_user -pkeycloak_password keycloak \
  > keycloak-kc16-backup.sql

# Backup KC16 manifests
cp -r k8s-manifests-rebuild k8s-manifests-kc16-backup
```

### **Step 2: Update ConfigMap**

**Before (KC16):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-config
data:
  DB_VENDOR: "MYSQL"
  DB_ADDR: "172.28.174.197"
  DB_PORT: "3306"
  DB_DATABASE: "keycloak"
  JDBC_PARAMS: "connectTimeout=30000"
```

**After (KC18):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-config
data:
  KC_DB: "mysql"
  KC_DB_URL: "jdbc:mysql://172.28.174.197:3306/keycloak"
  KC_HOSTNAME_STRICT: "false"
  KC_HTTP_ENABLED: "true"
  KC_PROXY: "edge"
  KC_HOSTNAME_STRICT_BACKCHANNEL: "false"
```

### **Step 3: Update Secret**

**Before (KC16):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-secret
type: Opaque
data:
  DB_USER: a2V5Y2xvYWtfdXNlcg==           # keycloak_user
  DB_PASSWORD: a2V5Y2xvYWtfcGFzc3dvcmQ=   # keycloak_password
  KEYCLOAK_USER: YWRtaW4=                 # admin
  KEYCLOAK_PASSWORD: YWRtaW5fcGFzc3dvcmQ= # admin_password
```

**After (KC18):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-secret
type: Opaque
data:
  KC_DB_USERNAME: a2V5Y2xvYWtfdXNlcg==          # keycloak_user
  KC_DB_PASSWORD: a2V5Y2xvYWtfcGFzc3dvcmQ=      # keycloak_password
  KEYCLOAK_ADMIN: YWRtaW4=                      # admin
  KEYCLOAK_ADMIN_PASSWORD: YWRtaW5fcGFzc3dvcmQ= # admin_password
```

### **Step 4: Update Deployment**

**Before (KC16):**
```yaml
spec:
  containers:
  - name: keycloak
    image: chucthien03/keycloak:16
    ports:
    - containerPort: 8080
    envFrom:
    - configMapRef:
        name: keycloak-config
    - secretRef:
        name: keycloak-secret
```

**After (KC18):**
```yaml
spec:
  containers:
  - name: keycloak
    image: chucthien03/keycloak:18-prod
    ports:
    - containerPort: 8080
    envFrom:
    - configMapRef:
        name: keycloak-config
    - secretRef:
        name: keycloak-secret
    args: ["start"]  # or "start-dev" for development
```

### **Step 5: Build KC18 Image with Custom Mappers**

```bash
cd 18-aje-keycloak-token-mapper

# Build production image
docker build -f Dockerfile.builtin -t chucthien03/keycloak:18-prod .

# Push to registry
docker push chucthien03/keycloak:18-prod
```

**Dockerfile changes:**
```dockerfile
# KC16: Deployed to /standalone/deployments/
COPY --from=builder /app/target/*.jar /opt/jboss/keycloak/standalone/deployments/

# KC18: Deployed to /providers/ + build step
COPY --from=builder /app/target/*.jar /opt/keycloak/providers/
RUN /opt/keycloak/bin/kc.sh build --db=mysql
```

### **Step 6: Deploy KC18**

```bash
# Delete old resources
kubectl delete secret keycloak-secret
kubectl delete configmap keycloak-config
kubectl delete deployment keycloak

# Apply new manifests
kubectl apply -f k8s-manifests-kc18/

# Watch migration
kubectl logs -f deployment/keycloak
```

### **Step 7: Verify Auto-Migration**

Keycloak automatically migrates database schema on first startup.

**Check migration logs:**
```bash
kubectl logs deployment/keycloak | grep -i "migration\|liquibase\|changelog"
```

**Verify in database:**
```bash
mysql -h 172.28.174.197 -u keycloak_user -pkeycloak_password keycloak \
  -e "SELECT ID, AUTHOR, DATEEXECUTED FROM DATABASECHANGELOG 
      WHERE ID LIKE '17.0.0%' OR ID LIKE '18.0.0%' 
      ORDER BY DATEEXECUTED;"
```

**Expected output:**
```
ID                                | AUTHOR   | DATEEXECUTED
----------------------------------|----------|-------------------
17.0.0-9562                       | keycloak | 2026-01-14 06:10:30
18.0.0-10625-IDX_ADMIN_EVENT_TIME | keycloak | 2026-01-14 06:10:30
```

### **Step 8: Verify Custom Mappers**

```bash
# Check mapper loading
kubectl logs deployment/keycloak | grep "oidc.*mapper"
```

**Expected output:**
```
KC-SERVICES0047: oidc-branch-property-mapper (BranchOIDCProtocolMapper)
KC-SERVICES0047: oidc-cif-property-mapper (CifOIDCProtocolMapper)
KC-SERVICES0047: oidc-user-level-property-mapper (UserLevelOIDCProtocolMapper)
KC-SERVICES0047: oidc-permissions-property-mapper (PermissionsOIDCProtocolMapper)
```

**Note:** `KC-SERVICES0047` warning is expected - mappers work correctly.

### **Step 9: Update Access URLs**

```bash
# Old KC16 URLs (will not work)
http://<node-ip>:30080/auth/admin
http://<node-ip>:30080/auth/realms/test-realm

# New KC18 URLs
http://<node-ip>:30080/admin
http://<node-ip>:30080/realms/test-realm
```

### **Step 10: Test Authentication**

```bash
# Get token (note: no /auth in URL)
curl -X POST http://<node-ip>:30080/realms/test-realm/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=test-client" \
  -d "username=customer1" \
  -d "password=test123"
```

## **🔧 Troubleshooting**

### **Issue 1: "No suitable driver found for jdbc:mysql"**

**Cause:** Using `start` command without pre-built MySQL driver.

**Solution:**
```yaml
# Option A: Use start-dev (auto-downloads driver)
args: ["start-dev"]

# Option B: Build image with driver
# In Dockerfile:
RUN /opt/keycloak/bin/kc.sh build --db=mysql
# In deployment:
args: ["start"]
```

### **Issue 2: Blank page when accessing console**

**Cause:** Hostname validation mismatch + HTTPS requirement in production mode.

**Solution:**
```yaml
# In ConfigMap - Add all three settings:
KC_HOSTNAME_STRICT: "false"              # Allow any hostname
KC_HOSTNAME_STRICT_HTTPS: "false"        # Allow HTTP in production mode (CRITICAL)
KC_HOSTNAME_STRICT_BACKCHANNEL: "false"  # Disable backchannel validation
```

**Why this happens:**
- Production mode (`args: ["start"]`) requires HTTPS by default
- Accessing via HTTP causes redirect loop → blank page
- `KC_HOSTNAME_STRICT_HTTPS: "false"` allows HTTP in production

**Apply fix:**
```bash
kubectl apply -f k8s-manifests-kc18/keycloak-configmap.yaml
kubectl rollout restart deployment/keycloak
```

### **Issue 3: "couldn't find key DB_USER in Secret"**

**Cause:** Old KC16 secret still deployed.

**Solution:**
```bash
kubectl delete secret keycloak-secret
kubectl apply -f k8s-manifests-kc18/keycloak-secret.yaml
kubectl rollout restart deployment/keycloak
```

### **Issue 4: Custom mappers not appearing**

**Cause:** JAR not in correct path or build step missing.

**Solution:**
```bash
# Check JAR location
kubectl exec deployment/keycloak -- ls -la /opt/keycloak/providers/

# Verify build step in Dockerfile
RUN /opt/keycloak/bin/kc.sh build --db=mysql
```

### **Issue 5: Migration failed**

**Cause:** Database connection issues or incompatible schema.

**Solution:**
```bash
# Check DB connectivity
kubectl exec deployment/keycloak -- curl -v telnet://172.28.174.197:3306

# Restore backup if needed
mysql -h 172.28.174.197 -u keycloak_user -pkeycloak_password keycloak \
  < keycloak-kc16-backup.sql
```

## **📋 Migration Checklist**

- [ ] Backup KC16 database
- [ ] Backup KC16 manifests
- [ ] Build KC18 image with custom mappers
- [ ] Update ConfigMap (KC_* variables)
- [ ] Update Secret (KC_DB_USERNAME, KEYCLOAK_ADMIN)
- [ ] Update Deployment (image + args)
- [ ] Delete old resources
- [ ] Apply new manifests
- [ ] Verify auto-migration in logs
- [ ] Check DATABASECHANGELOG table
- [ ] Verify custom mappers loaded
- [ ] Update client URLs (remove /auth)
- [ ] Test authentication flow
- [ ] Test custom mapper claims in tokens

## **🎯 Key Takeaways**

1. **Database migration is automatic** - Keycloak uses Liquibase to detect version and run changesets
2. **No /auth prefix** - KC18 removed the /auth path from all URLs
3. **Environment variables changed** - All DB/admin vars use KC_* prefix
4. **Build step required** - Production mode needs `kc.sh build --db=mysql`
5. **Provider path changed** - Mappers go to `/opt/keycloak/providers/` not `/standalone/deployments/`
6. **Hostname validation stricter** - Must disable for NodePort access
7. **Custom mappers work** - Same Java code, just different deployment path

## **📚 References**

- [Keycloak 18 Migration Guide](https://www.keycloak.org/docs/latest/upgrading/index.html)
- [Quarkus Distribution](https://www.keycloak.org/migration/migrating-to-quarkus)
- [Environment Variables](https://www.keycloak.org/server/all-config)
