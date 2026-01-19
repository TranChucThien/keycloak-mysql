# Keycloak 15 (WildFly)

## 📊 Version Info
- **Keycloak**: 15.0.2
- **Java**: 11
- **Runtime**: WildFly (Java EE)
- **Database**: MySQL 8.0.23
- **Image**: `chucthien03/keycloak:15`

## 🔑 Key Features
- Stable WildFly-based version
- Hot-deploy pattern for custom mappers
- Environment variables: `DB_*`, `KEYCLOAK_*`
- URL structure: Includes `/auth` prefix
- Improved deployment strategy vs KC12

## 📁 Structure
```
kc15/
├── mapper/           # Custom token mappers
│   ├── src/         # Java source code
│   ├── pom.xml      # Maven dependencies
│   ├── Dockerfile.builtin   # Build image with mappers
│   ├── Dockerfile.export    # Export JAR only
│   └── Dockerfile.registry  # Separate mapper image
├── k8s/             # Kubernetes manifests
│   ├── keycloak-deployment.yaml
│   ├── keycloak-secret.yaml
│   └── README.md
└── docker-compose/  # Docker Compose setup
    └── docker-compose.yml
```

## 🚀 Quick Start

### Docker Compose
```bash
cd docker-compose
docker-compose up -d

# Check logs
docker logs -f keycloak-kc15
```

### Kubernetes
```bash
cd k8s
kubectl apply -f .

# Check status
kubectl logs -f deployment/keycloak
```

### Build Custom Image
```bash
cd mapper
docker build -f Dockerfile.builtin -t chucthien03/keycloak:15 .
docker push chucthien03/keycloak:15
```

## 🧪 Custom Token Mappers

### Available Mappers
- **BranchOIDCProtocolMapper** - Adds `branch` claim
- **CifOIDCProtocolMapper** - Adds `cif` claim
- **UserLevelOIDCProtocolMapper** - Adds `user_level` claim
- **PermissionsOIDCProtocolMapper** - Adds `permissions` claim

### Deployment Path
```
/opt/jboss/keycloak/standalone/deployments/
└── aje-keycloak-token-mapper-1.0-SNAPSHOT.jar
```

### Deployment Strategy
KC15 uses improved hot-deploy pattern:
1. Database migration completes first
2. Custom mappers deployed after migration
3. Clean separation of concerns
4. No XML configuration modifications

## 🔗 Access

### URLs
- **Base URL**: http://localhost:8080/auth (Docker)
- **Base URL**: http://<node-ip>:30080/auth (K8s)
- **Admin Console**: http://localhost:8080/auth/admin
- **Realms**: http://localhost:8080/auth/realms/{realm-name}

### Credentials
- **Admin**: admin / admin_password
- **Database**: keycloak_user / keycloak_password

## ⚙️ Configuration

### Environment Variables
```yaml
DB_VENDOR: MYSQL
DB_ADDR: 172.28.174.197
DB_PORT: 3306
DB_DATABASE: keycloak
DB_USER: keycloak_user
DB_PASSWORD: keycloak_password
KEYCLOAK_USER: admin
KEYCLOAK_PASSWORD: admin_password
```

### Docker Compose Example
```yaml
services:
  keycloak:
    image: chucthien03/keycloak:15
    environment:
      DB_VENDOR: MYSQL
      DB_ADDR: mysql
      DB_DATABASE: keycloak
      DB_USER: keycloak_user
      DB_PASSWORD: keycloak_password
      KEYCLOAK_USER: admin
      KEYCLOAK_PASSWORD: admin_password
    ports:
      - "8080:8080"
```

## 🔧 Development

### Build Mapper JAR
```bash
cd mapper
mvn clean package

# Output: target/aje-keycloak-token-mapper-1.0-SNAPSHOT.jar
```

### Test Locally
```bash
# Run with local JAR
docker run -d -p 8080:8080 \
  -e KEYCLOAK_USER=admin \
  -e KEYCLOAK_PASSWORD=admin \
  -v $(pwd)/target/aje-keycloak-token-mapper-1.0-SNAPSHOT.jar:/opt/jboss/keycloak/standalone/deployments/mapper.jar \
  jboss/keycloak:15.0.2
```

## ✅ Verify Mappers

### Check Logs
```bash
# Docker
docker logs keycloak-kc15 | grep -i mapper

# Kubernetes
kubectl logs deployment/keycloak | grep -i mapper
```

### Admin Console
1. Login to Admin Console
2. Select Realm → Clients → Select Client
3. Go to Mappers tab
4. Click "Add Mapper"
5. Verify custom mappers appear in dropdown

### Test Token
```bash
# Get token
TOKEN=$(curl -s -X POST \
  http://localhost:8080/auth/realms/test-realm/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=test-client" \
  -d "username=customer1" \
  -d "password=test123" | jq -r '.access_token')

# Decode token
echo $TOKEN | cut -d. -f2 | base64 -d | jq .
```

## 📝 Improvements from KC12

### Deployment Strategy
- **KC12**: XML config modifications caused migration errors
- **KC15**: Clean hot-deploy after DB migration completes

### Configuration
- **KC12**: Used `sed` commands to modify XML
- **KC15**: No XML modifications needed

### Reliability
- **KC12**: Migration conflicts with custom code
- **KC15**: Separated migration and custom code loading

## 🔄 Migration Notes

### From KC12 to KC15
- ✅ Seamless upgrade
- ✅ No code changes required
- ✅ Database auto-migration
- ✅ Custom mappers work without modification

### From KC15 to KC16
- ✅ Seamless upgrade
- ✅ No breaking changes
- ✅ Last WildFly version

### From KC15 to KC18
- ⚠️ Major migration (WildFly → Quarkus)
- Environment variables change (`DB_*` → `KC_*`)
- URL structure change (remove `/auth`)
- Deployment path change
- See KC18 migration guide

## 📊 Comparison

| Feature | KC12 | KC15 | KC16 |
|---------|------|------|------|
| **Runtime** | WildFly | WildFly | WildFly |
| **Deployment** | Basic | Improved | Improved |
| **XML Config** | Modified | Clean | Clean |
| **Migration** | Issues | Stable | Stable |
| **Hot Deploy** | Yes | Yes | Yes |

## ⚠️ Important

KC15 is a stable WildFly version. Consider:
- **Stay on KC15**: If you need stability and WildFly
- **Upgrade to KC16**: Last WildFly version before Quarkus
- **Upgrade to KC18+**: For better performance with Quarkus

## 📚 References

- [Keycloak 15 Documentation](https://www.keycloak.org/docs/15.0/)
- [WildFly Documentation](https://docs.wildfly.org/)
- [Custom SPI Development](https://www.keycloak.org/docs/15.0/server_development/)
- [Migration Guide](../../UPGRADE_NOTES.md)
