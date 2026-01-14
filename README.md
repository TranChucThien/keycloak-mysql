# Keycloak 15 + MySQL 8 with Built-in Custom Mappers

## **🎯 Purpose**

Production-ready Keycloak 15 with MySQL 8 and custom token mappers built into the image.

## **📁 Project Structure**

```
keycloak-mysql/
├── aje-keycloak-token-mapper-k8s-prod/  # Custom mapper source
│   ├── src/main/java/                   # Mapper implementations
│   ├── Dockerfile.builtin               # Build Keycloak + mappers image
│   └── pom.xml                          # Maven config
├── k8s-manifests-rebuild/               # K8s deployment files
│   ├── keycloak-deployment.yaml         # Deployment + Service
│   ├── keycloak-configmap.yaml          # DB config
│   └── keycloak-secret.yaml             # Credentials
├── docker-compose.yml                   # Docker Compose setup
└── archive/                             # Old approaches (init-container, etc)
```

## **🔑 Credentials**

### **Keycloak Admin**
- **URL:** http://localhost:8080/auth
- **Username:** `admin`
- **Password:** `admin_password`

### **MySQL Database**
- **Host:** 172.28.174.197:3306
- **Database:** `keycloak`
- **User:** `keycloak_user`
- **Password:** `keycloak_password`

## **🚀 Quick Start**

### **Option 1: Kubernetes Deployment**

```bash
# Deploy to K8s
kubectl apply -f k8s-manifests-rebuild/

# Check status
kubectl get pods
kubectl logs -f deployment/keycloak

# Access Keycloak
# NodePort: http://<node-ip>:30080/auth
```

### **Option 2: Docker Compose**

```bash
# Start services
docker-compose up -d

# Check logs
docker logs -f keycloak

# Access: http://localhost:8080/auth
```

## **🔨 Build Custom Image**

```bash
cd aje-keycloak-token-mapper-k8s-prod

# Build image
docker build -f Dockerfile.builtin -t chucthien03/keycloak:15 .

# Push to registry
docker push chucthien03/keycloak:15
```

## **🧪 Custom Token Mappers**

### **Available Mappers**
- **BranchOIDCProtocolMapper** - Adds `branch` claim
- **CifOIDCProtocolMapper** - Adds `customer_id` claim  
- **UserLevelOIDCProtocolMapper** - Adds `user_level` claim
- **PermissionsOIDCProtocolMapper** - Adds `permissions` claim

### **How It Works**
1. Maven builds mapper JAR from source
2. Dockerfile copies JAR to `/opt/jboss/keycloak/standalone/deployments/`
3. Keycloak auto-deploys on startup
4. Mappers available in Admin Console

## **✅ Testing**

### **1. Create Test Realm**
1. Login: http://localhost:8080/auth (`admin`/`admin_password`)
2. Master → Add realm → Name: `test-realm`

### **2. Create Client**
1. Clients → Create → Client ID: `test-client`
2. Settings: Access Type = `public`, Direct Access Grants = `ON`

### **3. Create User**
1. Users → Add user → Username: `customer1`
2. Credentials → Set password: `test123`
3. Attributes → Add:
   - `cif`: `CIF001234567`
   - `branch`: `MAIN_BRANCH`

### **4. Add Mapper**
1. Clients → test-client → Mappers → Create
2. Mapper Type: `Customer Information File`
3. Token Claim Name: `cif`
4. Add to tokens: ON

### **5. Test Token**

```bash
curl -X POST http://localhost:8080/auth/realms/test-realm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=test-client" \
  -d "username=customer1" \
  -d "password=test123"
```

Decode token at https://jwt.io - should contain `cif` claim.

## **🔧 Troubleshooting**

### **Mapper Not Appearing**

```bash
# Check JAR deployed
kubectl exec deployment/keycloak -- ls -la /opt/jboss/keycloak/standalone/deployments/

# Check logs
kubectl logs deployment/keycloak | grep -i deploy
```

### **DB Connection Failed**

```bash
# Verify DB config
kubectl get configmap keycloak-config -o yaml

# Test DB connection
mysql -h 172.28.174.197 -u keycloak_user -p
```

### **Migration Error (12→15 upgrade)**

**Issue:** Old Dockerfile modified XML config causing migration failure

**Solution:** Current Dockerfile.builtin uses `deployments/` folder without XML modification

## **📝 Technical Details**

### **Why This Approach Works**

**Previous Issue (KC 12→15 upgrade):**
- JAR in `/opt/jboss/keycloak/providers/` 
- XML config modified with `sed` commands
- XML parsing failed → DB migration failed

**Current Solution:**
- JAR in `/opt/jboss/keycloak/standalone/deployments/`
- No XML modification
- Hot-deploy after DB migration completes

### **Deployment Order**
```
1. Parse XML config
2. Connect to DB
3. Run schema migration
4. Load deployments/ JARs
5. Start server
```

## **🎯 Version Info**

- **Keycloak:** 15.1.1
- **MySQL:** 8.0.23
- **Java:** 11
- **Maven:** 3.8.4

## **📚 Archive**

Old deployment approaches moved to `archive/`:
- Init container pattern
- Local mount approach
- Basic deployment without mappers
