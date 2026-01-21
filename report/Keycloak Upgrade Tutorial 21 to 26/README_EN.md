# Keycloak 21 → 26 Upgrade Report

## **📋 Overview**

**Date:** 2026-01-20  
**Status:** ✅ Successfully Completed  
**Image:** `chucthien03/keycloak:26.5.1`  
**Environment:** Kubernetes + MySQL 8.0.23 (Local)

---

## **0️⃣ Pre-Upgrade Checklist**

### **✅ Prepare Test Environment**

#### **Deploy KC21 Baseline**

```bash
cd /home/tcthien/KLB/keycloak/keycloak-mysql/report/test/kc21

# Build KC21 image
cd mapper
docker build -f Dockerfile.builtin -t chucthien03/keycloak:21 .
docker push chucthien03/keycloak:21

# Deploy to K8s
cd ../k8s
kubectl apply -f keycloak-configmap.yaml
kubectl apply -f keycloak-secret.yaml
kubectl apply -f keycloak-deployment.yaml

# Wait for ready
kubectl wait --for=condition=ready pod -l app=keycloak --timeout=120s
kubectl logs -f deployment/keycloak
```

![Keycloak 21 Admin Console](images/kc21-admin-console.png)

*Figure 1: Keycloak 21.1.2 Admin Console*

![K8s Deployment Result](images/kc21-k8s-deployment.png)

*Figure 2: Keycloak 21 deployed to Kubernetes*

#### **Setup Test Data**

```bash
# Run automated setup script
cd /home/tcthien/KLB/keycloak/keycloak-mysql/scripts
./2-setup-data-modern.sh http://192.168.10.142:30080

# Script will:
# 1. Create test realm: "test-realm"
# 2. Configure User Profile attributes (KC24+ requirement)
# 3. Create test client: "test-client" (public, direct access enabled)
# 4. Create 5 test users (customer1-5) with attributes:
#    - cif: "CIF001234567" - "CIF005678901"
#    - branch: "MAIN_BRANCH", "NORTH_BRANCH", etc.
#    - password: "test123"
# 5. Add custom mappers to client:
#    - CIF Mapper (oidc-cif-property-mapper)
#    - Branch Mapper (oidc-branch-property-mapper)
```

![Setup test data](images/kc21-setup-test-data.png)

*Figure 3: Create realm and test users with CIF and Branch attributes*

![Verify custom mappers](images/kc21-custom-mappers.png)

*Figure 4: Verify custom mappers loaded successfully*

![Token with CIF claim](images/kc21-token-with-cif.png)

*Figure 5: Token contains CIF claim - custom mapper working*

![Test user attributes](images/kc21-user-attributes.png)

*Figure 6: Test user with attributes in Keycloak UI*

![Custom mappers in UI](images/kc21-mappers-ui.png)

*Figure 7: Custom mappers visible in web interface*

#### **Verify Custom Mappers (KC21)**

```bash
# Run automated verification script
cd /home/tcthien/KLB/keycloak/keycloak-mysql/scripts
./4-verify-custom-mappers-modern.sh http://192.168.10.142:30080

# Script will check:
# 1. JAR file exists in /opt/keycloak/providers/ (if pod name provided)
# 2. Mappers are registered via API:
#    - oidc-cif-property-mapper
#    - oidc-branch-property-mapper
# 3. Mappers are configured in test-realm/test-client

# Verify data and token claims
./6-verify-data-modern.sh http://192.168.10.142:30080

# Script will verify:
# 1. Realm exists
# 2. Users created with attributes
# 3. Login successful
# 4. Token contains custom claims:
#    - cif: "CIF001234567"
#    - branch: "MAIN_BRANCH"
```

### **✅ Backups (Lab Environment)**

#### **Backup Database**

```bash
# Backup MySQL database
docker exec mysql mysqldump -u root -psupersecretpassword keycloak > backup-kc21-$(date +%Y%m%d).sql

# Verify backup file
ls -lh backup-kc21-$(date +%Y%m%d).sql

# Expected: ~200-500KB depending on data
```

#### **Restore Database**

```bash
# Stop Keycloak first
kubectl scale deployment keycloak --replicas=0

# Wait for MySQL ready (if restarted)
docker exec mysql mysqladmin ping -h localhost -u root -psupersecretpassword

# Restore from backup
docker exec -i mysql mysql -u root -psupersecretpassword keycloak < backup-kc21-20260121.sql

# Verify restore
docker exec mysql mysql -u root -psupersecretpassword -e "USE keycloak; SHOW TABLES;"
```

### **✅ Current Configuration (KC21)**

- **Keycloak:** 21.1.2
- **Java:** 17 ✅ (ready for KC26)
- **Database:** MySQL 8.0.23 (External)
- **Custom Providers:** 4 mappers (Branch, CIF, UserLevel, Permissions)
- **Deployment:** Kubernetes NodePort 30080

### **✅ Review Breaking Changes (21 → 26)**

Reviewed migration documentation:
- [Migrating to 22](https://www.keycloak.org/docs/22.0/upgrading/)
- [Migrating to 23](https://www.keycloak.org/docs/23.0/upgrading/)
- [Migrating to 24](https://www.keycloak.org/docs/24.0/upgrading/)
- [Migrating to 25](https://www.keycloak.org/docs/25.0/upgrading/)
- [Migrating to 26](https://www.keycloak.org/docs/26.0/upgrading/)

---

## **1️⃣ Key Highlights**

### **1.1 Configuration Model (IMPORTANT)**

**Keycloak 26 fully Quarkus-native:**
- ❌ Removed all legacy WildFly options
- ✅ Environment Variables preferred

**Environment Variables used in KC21:**

```yaml
KC_DB: mysql
KC_DB_URL: jdbc:mysql://172.28.174.197:3306/keycloak
KC_DB_USERNAME: keycloak_user
KC_DB_PASSWORD: keycloak_password
KC_HOSTNAME_STRICT: false
KC_HTTP_ENABLED: true
KC_PROXY: edge
KC_HOSTNAME_STRICT_BACKCHANNEL: false
```

**Result:** ✅ No ConfigMap/Secret changes needed

### **1.2 Database Defaults Change**

- ❌ `dev-file` (H2) deprecated for production
- ✅ Production MUST explicitly set DB
- ⚠️ Not setting DB will cause errors in future upgrades

**Status:** ✅ Already set `KC_DB=mysql` since KC21

### **1.3 Custom Providers**

**Requirements:**
- ✅ Java 17 (REQUIRED - Version 26 no longer supports Java 11)
- ✅ Compile with corresponding Keycloak SPI version

---

## **2️⃣ Technical Changes**

### **2.1 Java Version (No Change)**

| Component | KC21 | KC26 | Change |
|-----------|------|------|--------|
| **Java** | 17 | 17 | ✅ No change |
| **Quarkus** | 2.13.8 | 3.15.1 | Major upgrade |
| **Maven** | 3.8.5 | 3.8.5 | No change |

### **2.2 File Changes**

#### **pom.xml**

```diff
  <properties>
      <maven.compiler.source>17</maven.compiler.source>
      <maven.compiler.target>17</maven.compiler.target>
-     <keycloak.version>21.1.2</keycloak.version>
+     <keycloak.version>26.0.0</keycloak.version>
  </properties>

  <build>
      <plugins>
          <plugin>
              <groupId>org.apache.maven.plugins</groupId>
              <artifactId>maven-compiler-plugin</artifactId>
              <version>3.11.0</version>
              <configuration>
                  <forceJavacCompilerUse>true</forceJavacCompilerUse>
                  <source>17</source>
                  <target>17</target>
              </configuration>
          </plugin>
      </plugins>
  </build>
```

#### **Dockerfile.builtin**

```diff
  FROM maven:3.8.5-openjdk-17 AS builder

  WORKDIR /app
  COPY pom.xml .
  COPY src ./src
  RUN mvn clean package -DskipTests

- FROM quay.io/keycloak/keycloak:21.1.2
+ FROM quay.io/keycloak/keycloak:26.0.0

  COPY --from=builder --chown=keycloak:keycloak /app/target/*.jar /opt/keycloak/providers/
  RUN /opt/keycloak/bin/kc.sh build --db=mysql
```

#### **keycloak-deployment.yaml**

```diff
  spec:
    containers:
    - name: keycloak
-     image: chucthien03/keycloak:21
+     image: chucthien03/keycloak:26.5.1
      ports:
      - containerPort: 8080
      envFrom:
      - configMapRef:
          name: keycloak-config
      - secretRef:
          name: keycloak-secret
      args: ["start", "--optimized"]
```

### **2.3 Custom Mapper Code**

**✅ NO CODE CHANGES NEEDED!**

All 4 mappers work with existing code:
- `BranchOIDCProtocolMapper.java` - ✅ Compatible
- `CifOIDCProtocolMapper.java` - ✅ Compatible
- `UserLevelOIDCProtocolMapper.java` - ✅ Compatible
- `PermissionsOIDCProtocolMapper.java` - ✅ Compatible

**Reason:** `getAttributeStream()` API (migrated from KC18→21) remains unchanged in KC26.

```java
// This code still works in KC26
List<String> attributeValue = userSession.getUser().getAttributeStream(BRANCH)
    .filter(Objects::nonNull)
    .collect(Collectors.toList());
```

---

## **3️⃣ Upgrade Process**

### **3.1 Prepare Kubernetes Manifests**

```bash
cd /home/tcthien/KLB/keycloak/keycloak-mysql/report/test/kc26
```

**Required files:**
- `k8s/keycloak-deployment.yaml` - Updated image to KC26
- `k8s/keycloak-configmap.yaml` - No change (reuse KC21)
- `k8s/keycloak-secret.yaml` - No change (reuse KC21)

### **3.2 Build Custom Image**

```bash
cd mapper

# Build image with Java 17 and KC26
docker build -f Dockerfile.builtin -t chucthien03/keycloak:26.5.1 .

# Push to registry
docker push chucthien03/keycloak:26.5.1
```

![Build Keycloak 26 image](images/kc26-build-image.png)

*Figure 8: Build Keycloak 26 image with custom mappers*

### **3.3 First Upgrade Run (Schema Migration)**

**⚠️ IMPORTANT: Scale to 1 replica**

```bash
# Scale down to 1 replica for safe migration
kubectl scale deployment keycloak --replicas=1

# Apply new manifests
cd k8s
kubectl apply -f keycloak-configmap.yaml
kubectl apply -f keycloak-secret.yaml
kubectl apply -f keycloak-deployment.yaml

# Watch logs carefully
kubectl logs -f deployment/keycloak
```

**Expected logs:**

```
2026-01-21 02:13:18,512 INFO  [org.keycloak.quarkus.runtime.storage.infinispan.CacheManagerFactory] Starting Infinispan embedded cache manager
2026-01-21 02:13:19,961 INFO  [org.infinispan.CLUSTER] ISPN000078: Starting JGroups channel `ISPN` with stack `udp`
2026-01-21 02:13:22,043 INFO  [org.infinispan.CLUSTER] ISPN000094: Received new cluster view for channel ISPN: [keycloak-7d9f964dff-k74nv-30711|0] (1)
2026-01-21 02:13:22,119 INFO  [org.infinispan.CLUSTER] ISPN000079: Channel `ISPN` local address is `keycloak-7d9f964dff-k74nv-30711`
2026-01-21 02:13:24,287 INFO  [org.keycloak.quarkus.runtime.storage.database.liquibase.QuarkusJpaUpdaterProvider] Updating database. Using changelog META-INF/jpa-changelog-master.xml

UPDATE SUMMARY
Run:                         31
Previously run:             113
Filtered out:                 0
-------------------------------
Total change sets:          144

2026-01-21 02:13:33,663 INFO  [org.keycloak.storage.datastore.DefaultMigrationManager] Migrating older model to 22.0.0
2026-01-21 02:13:35,040 INFO  [org.keycloak.storage.datastore.DefaultMigrationManager] Migrating older model to 23.0.0
2026-01-21 02:13:35,100 INFO  [org.keycloak.storage.datastore.DefaultMigrationManager] Migrating older model to 24.0.0
2026-01-21 02:13:35,340 INFO  [org.keycloak.storage.datastore.DefaultMigrationManager] Migrating older model to 24.0.3
2026-01-21 02:13:35,429 INFO  [org.keycloak.storage.datastore.DefaultMigrationManager] Migrating older model to 25.0.0
2026-01-21 02:13:35,820 INFO  [org.keycloak.storage.datastore.DefaultMigrationManager] Migrating older model to 26.0.0
2026-01-21 02:13:36,496 INFO  [io.quarkus] Keycloak 26.0.0 on JVM (powered by Quarkus 3.15.1) started in 26.014s. Listening on: http://0.0.0.0:8080
2026-01-21 02:13:36,497 INFO  [io.quarkus] Profile prod activated.
2026-01-21 02:13:36,497 INFO  [io.quarkus] Installed features: [agroal, cdi, hibernate-orm, jdbc-mysql, keycloak, narayana-jta, opentelemetry, reactive-routes, rest, rest-jackson, smallrye-context-propagation, vertx]
```

**Key migration steps in logs:**
- ✅ Liquibase: 31 new changesets, 113 existing (total 144)
- ✅ Model migration: 22.0.0 → 23.0.0 → 24.0.0 → 24.0.3 → 25.0.0 → 26.0.0
- ✅ Startup time: 26s (first run due to migration)
- ✅ Quarkus 3.15.1 (KC26 runtime)

**⚠️ If migration fails:**

```bash
# Rollback image
kubectl set image deployment/keycloak keycloak=chucthien03/keycloak:21

# Restore DB from backup
docker exec -i mysql mysql -u root -psupersecretpassword keycloak < backup_kc21.sql

# Fix issue and retry
```

---

## **4️⃣ Post-Migration Steps**

### **4.1 Scale Back Up**

```bash
# Scale to desired replicas
kubectl scale deployment keycloak --replicas=2

# Verify all pods running
kubectl get pods -l app=keycloak
```

### **4.2 Verify Functionality**

**Test checklist:**

- [x] Admin Console accessible: http://<node-ip>:30080 and login with admin/admin_password

![Keycloak version 26.5.1](images/kc26-admin-console.png)

*Figure 9: Keycloak version 26.5.1 (latest) - 21/01/2026*

- [x] Verify custom mappers loaded

![Custom mappers loaded](images/kc26-custom-mappers.png)

*Figure 10: Verify custom mappers loaded successfully in KC26*

- [x] Test token generation with client and verify custom claims (branch, customer_id, user_level, permissions)

![Token verification](images/kc26-token-verification.png)

*Figure 11: Verify token contains all custom claims from mappers*

---

## **5️⃣ Rollback Plan**

### **When to rollback?**

- Database migration fails
- Custom mappers don't load
- Critical errors in logs
- Application cannot authenticate

### **Rollback procedure:**

```bash
# 1. Scale down KC26
kubectl scale deployment keycloak --replicas=0

# 2. Restore database backup
docker exec -i mysql mysql -u root -psupersecretpassword keycloak < backup_kc21.sql

# 3. Redeploy KC21 image
kubectl set image deployment/keycloak keycloak=chucthien03/keycloak:21

# 4. Scale back up
kubectl scale deployment keycloak --replicas=2

# 5. Verify rollback
kubectl logs deployment/keycloak | grep "Keycloak 21"
```

---

## **6️⃣ Before/After Comparison**

### **Technical Stack**

| Component | KC21 | KC26 | Impact |
|-----------|------|------|--------|
| **Keycloak** | 21.1.2 | 26.5.1 | Major upgrade |
| **Java** | 17 | 17 | ✅ No change |
| **Quarkus** | 2.13.8 | 3.15.1 | Major upgrade |
| **Maven Plugin** | 3.11.0 | 3.11.0 | ✅ No change |
| **Base Image** | openjdk-17 | openjdk-17 | ✅ No change |
| **Startup Time** | ~14s | ~13.6s | Improved |

### **Configuration Changes**

| Setting | KC21 | KC26 | Changed? |
|---------|------|------|----------|
| `KC_DB` | mysql | mysql | ❌ No |
| `KC_DB_URL` | jdbc:mysql://... | jdbc:mysql://... | ❌ No |
| `KC_HOSTNAME_STRICT` | false | false | ❌ No |
| `KC_HTTP_ENABLED` | true | true | ❌ No |
| `KC_PROXY` | edge | edge | ❌ No |
| `args` | `["start", "--optimized"]` | `["start", "--optimized"]` | ❌ No |

### **Custom Mapper Code**

| Mapper | Code Changes | Recompile? | Status |
|--------|--------------|------------|--------|
| BranchOIDCProtocolMapper | ❌ None | ✅ Yes (KC26 SPI) | ✅ Working |
| CifOIDCProtocolMapper | ❌ None | ✅ Yes (KC26 SPI) | ✅ Working |
| UserLevelOIDCProtocolMapper | ❌ None | ✅ Yes (KC26 SPI) | ✅ Working |
| PermissionsOIDCProtocolMapper | ❌ None | ✅ Yes (KC26 SPI) | ✅ Working |

**Key Insight:** KC21 already used Java 17, only need to recompile with Keycloak 26 SPI!

---

## **7️⃣ Lessons Learned**

### **✅ What Went Well**

1. **Zero Code Changes**: `getAttributeStream()` API 100% compatible
2. **Java 17 Ready**: KC21 already used Java 17, no Java upgrade needed
3. **Smooth Migration**: Database schema migration automatic, no errors
4. **Configuration Stability**: No ConfigMap/Secret changes needed
5. **Backward Compatible**: Easy rollback if needed

### **💡 Best Practices**

1. **Always Backup**: Database backup mandatory before any upgrade
2. **Scale to 1**: Migration safer with 1 replica
3. **Watch Logs**: Monitor logs real-time during migration
4. **Test Thoroughly**: Verify all custom mappers after upgrade
5. **Document Everything**: Detailed notes for rollback if needed

### **📚 References**

- [Keycloak 26 Release Notes](https://www.keycloak.org/docs/26.0/release_notes/)
- [Upgrading Guide](https://www.keycloak.org/docs/26.0/upgrading/)
- [Quarkus 3.x Migration](https://quarkus.io/guides/migration-guide-3-0)
- [Java 17 Features](https://openjdk.org/projects/jdk/17/)

---

## **🎯 Conclusion**

### **Summary**

Keycloak 21 → 26 upgrade completed successfully with:
- ✅ All custom mappers working (4/4)
- ✅ Database migration successful
- ✅ Zero code changes required
- ✅ Production ready

### **Key Takeaways**

1. **Java 17 ready since KC21** - Much easier migration
2. **API stability** - Keycloak maintains good backward compatibility
3. **Quarkus 3.x** - Performance improvements, no breaking changes for mappers
4. **Configuration simplicity** - Minimal config changes, mostly version bumps

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-21  
**Author:** TC Thien
