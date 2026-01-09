# Keycloak 12 + MySQL 8 Lab Environment

## 🎯 Purpose
Lab environment to test Keycloak 12 with MySQL 8 database, preparing for upgrade to higher versions (17/20/26).

## 🚀 Quick Start

### 1. Start services
```bash
docker-compose up -d
```

### 2. Check containers
```bash
docker ps
```
Expected result:
- `keycloak-mysql` → **Up**
- `keycloak` → **Up**

### 3. Access Keycloak
- URL: http://localhost:8080/auth
- Admin: `admin` / `admin_password`

---

## 🔍 Testing Guide - From Basic to Advanced

### 1️⃣ Check Container Status

```bash
# View all containers
docker ps

# If Keycloak keeps restarting, check logs immediately
docker logs -f keycloak
```

**Expected result:**
- Both containers are **Up**
- No restart loops

---

### 2️⃣ Verify Keycloak MySQL Connection (MOST IMPORTANT)

```bash
# View Keycloak logs
docker logs -f keycloak
```

**✅ CORRECT signs in logs:**
```text
Using MySQL database
Driver: com.mysql.cj.jdbc.Driver
HHH000204: Processing PersistenceUnitInfo [name: keycloak-default]
Keycloak 12.0.4 (WildFly Core 13.0.3.Final) started
```

**❌ WRONG signs (need immediate fix):**
```text
Communications link failure
Access denied for user
Cannot create PoolableConnectionFactory
```

---

### 3️⃣ Verify Database Actually Contains Data

```bash
# Enter MySQL container
docker exec -it keycloak-mysql mysql -u keycloak_user -p
# Password: keycloak_password
```

```sql
-- Check database and tables
SHOW DATABASES;
USE keycloak;
SHOW TABLES;

-- Should see many Keycloak tables:
-- REALM, USER_ENTITY, CLIENT, ROLE, MIGRATION_MODEL, etc.
```

**📌 If tables exist → Keycloak is using MySQL, not H2**

---

### 4️⃣ Test Keycloak UI

1. **Access Admin Console:**
   ```
   http://localhost:8080/auth
   ```

2. **Login:**
   - User: `admin`
   - Password: `admin_password`

**✅ Successful login → Keycloak working properly**

---

### 5️⃣ Test Basic Functions (Important for upgrade)

#### 🔹 5.1 Create New Realm
1. Click **Master** dropdown
2. **Add realm**
3. Name: `test-realm`
4. **Create**

**✅ Realm created successfully → DB write OK**

#### 🔹 5.2 Create User
1. **Users** → **Add user**
2. Username: `user1`
3. **Save**
4. **Credentials** → Set password: `test123`

**✅ User created successfully → USER_ENTITY table OK**

#### 🔹 5.3 Create Client
1. **Clients** → **Create**
2. Client ID: `test-client`
3. Protocol: `openid-connect`
4. **Save**

**✅ Client created successfully → CLIENT table OK**

#### 🔹 5.4 Test Login Flow
```
http://localhost:8080/auth/realms/test-realm/account
```
- Login: `user1` / `test123`

**✅ Login successful → Auth flow OK**

---

### 6️⃣ Test Restart (EXTREMELY IMPORTANT)

```bash
# Restart everything
docker-compose restart

# Wait for services to come up
docker ps
```

**Check after restart:**
1. Login to admin console again
2. Is `test-realm` still there?
3. Is user `user1` still there?

**✅ If everything persists → MySQL volume OK, lab is stable**

---

### 7️⃣ Advanced Test - Schema Version

```sql
-- Check schema version (important for upgrade)
SELECT * FROM MIGRATION_MODEL;
```

**📌 Remember this result to compare after upgrade**

---

## 🛠️ Troubleshooting

### Keycloak won't start
```bash
# View detailed logs
docker logs keycloak

# Common issue: MySQL not ready yet
# Solution: wait longer or restart
docker-compose restart keycloak
```

### MySQL connection failed
```bash
# Check if MySQL is running
docker exec -it keycloak-mysql mysql -u root -p
# Password: supersecretpassword

# Check keycloak_user exists
SELECT User, Host FROM mysql.user WHERE User = 'keycloak_user';
```

### Port conflict
```bash
# If port 8080 or 3306 is occupied
# Edit docker-compose.yml:
# ports:
#   - "8081:8080"  # Keycloak
#   - "3307:3306"  # MySQL
```

---

## 📊 Additional Tests

### Test Performance
```bash
# Check resource usage
docker stats

# Test concurrent connections
curl -I http://localhost:8080/auth
```

### Test Backup/Restore
```bash
# Backup MySQL data
docker exec keycloak-mysql mysqldump -u keycloak_user -p keycloak > backup.sql

# Test restore (on new container)
docker exec -i keycloak-mysql mysql -u keycloak_user -p keycloak < backup.sql
```

### Test Network Connectivity
```bash
# Test from keycloak container to mysql
docker exec keycloak ping mysql

# Test MySQL port from host
telnet localhost 3306
```

---

## 🎯 Conclusion

After completing all tests:

✅ **Production-ready Keycloak 12 + MySQL 8 lab**  
✅ **Real data in database**  
✅ **Ready for upgrade testing**

### Next Steps:
1. **Freeze this lab** (backup volume)
2. **Clone DB** for testing
3. **Test migration** step by step: 12 → 17 → 20 → 26

---

## 📝 Configuration Details

### Database Connection
- **Host:** mysql (container name)
- **Port:** 3306
- **Database:** keycloak
- **User:** keycloak_user
- **Password:** keycloak_password
- **MySQL Version:** 8.0.23
- **Root Password:** supersecretpassword
- **Authentication:** mysql_native_password

### Keycloak Admin
- **URL:** http://localhost:8080/auth
- **Username:** admin
- **Password:** admin_password
- **Keycloak Version:** 12.0.4 (WildFly-based)
- **Image:** quay.io/keycloak/keycloak:12.0.4

### Volumes
- **MySQL Data:** `mysql_data` (persistent)
- **Location:** Docker managed volume
- **Network:** `keycloak-net` (bridge driver)

---

## 🔧 Commands Cheat Sheet

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# Logs
docker logs -f keycloak
docker logs -f keycloak-mysql

# MySQL CLI
docker exec -it keycloak-mysql mysql -u keycloak_user -p

# MySQL CLI as root
docker exec -it keycloak-mysql mysql -u root -p

# Clean up (⚠️ Data loss)
docker-compose down -v
```

---

## 🔄 MySQL 8 Specific Notes

### Authentication Plugin
- Uses `mysql_native_password` for compatibility with Keycloak 12
- Binds to `0.0.0.0` for container networking
- Root access from any host (`MYSQL_ROOT_HOST: '%'`)

### Compatibility
- MySQL 8.0.23 is fully compatible with Keycloak 12 WildFly
- Uses `com.mysql.cj.jdbc.Driver` (Connector/J 8.x)
- UTF8MB4 charset support for full Unicode compatibility