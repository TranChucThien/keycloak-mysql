# Keycloak 12 + MySQL Lab Environment

## 🎯 Mục đích
Lab environment để test Keycloak 12 với MySQL database, chuẩn bị cho việc upgrade lên version cao hơn (17/20/26).

## 🚀 Quick Start

### 1. Khởi động services
```bash
docker-compose up -d
```

### 2. Kiểm tra containers
```bash
docker ps
```
Kết quả mong đợi:
- `keycloak-mysql` → **Up**
- `keycloak` → **Up**

### 3. Truy cập Keycloak
- URL: http://localhost:8080/auth
- Admin: `admin` / `admin_password`

---

## 🔍 Testing Guide - Từ thấp đến cao

### 1️⃣ Kiểm tra Container Status

```bash
# Xem tất cả containers
docker ps

# Nếu Keycloak restart liên tục, xem log ngay
docker logs -f keycloak
```

**Kết quả mong đợi:**
- Cả 2 containers đều **Up**
- Không có restart loop

---

### 2️⃣ Kiểm tra Keycloak kết nối MySQL (QUAN TRỌNG NHẤT)

```bash
# Xem log Keycloak
docker logs -f keycloak
```

**✅ Dấu hiệu ĐÚNG trong log:**
```text
Using MySQL database
Driver: com.mysql.cj.jdbc.Driver
HHH000204: Processing PersistenceUnitInfo [name: keycloak-default]
Keycloak 12.0.4 (WildFly Core 13.0.3.Final) started
```

**❌ Dấu hiệu SAI (cần fix ngay):**
```text
Communications link failure
Access denied for user
Cannot create PoolableConnectionFactory
```

---

### 3️⃣ Kiểm tra Database thật sự có dữ liệu

```bash
# Vào MySQL container
docker exec -it keycloak-mysql mysql -u keycloak_user -p
# Password: keycloak_password
```

```sql
-- Kiểm tra database và tables
SHOW DATABASES;
USE keycloak;
SHOW TABLES;

-- Phải thấy nhiều bảng Keycloak:
-- REALM, USER_ENTITY, CLIENT, ROLE, MIGRATION_MODEL, etc.
```

**📌 Nếu có bảng → Keycloak đã dùng MySQL thật, không phải H2**

---

### 4️⃣ Test Keycloak UI

1. **Truy cập Admin Console:**
   ```
   http://localhost:8080/auth
   ```

2. **Đăng nhập:**
   - User: `admin`
   - Password: `admin_password`

**✅ Login thành công → Keycloak hoạt động chuẩn**

---

### 5️⃣ Test chức năng cơ bản (Quan trọng cho upgrade)

#### 🔹 5.1 Tạo Realm mới
1. Click **Master** dropdown
2. **Add realm**
3. Name: `test-realm`
4. **Create**

**✅ Realm tạo thành công → DB ghi OK**

#### 🔹 5.2 Tạo User
1. **Users** → **Add user**
2. Username: `user1`
3. **Save**
4. **Credentials** → Set password: `test123`

**✅ User tạo thành công → bảng USER_ENTITY OK**

#### 🔹 5.3 Tạo Client
1. **Clients** → **Create**
2. Client ID: `test-client`
3. Protocol: `openid-connect`
4. **Save**

**✅ Client tạo thành công → bảng CLIENT OK**

#### 🔹 5.4 Test Login Flow
```
http://localhost:8080/auth/realms/test-realm/account
```
- Login: `user1` / `test123`

**✅ Login thành công → Auth flow OK**

---

### 6️⃣ Test Restart (CỰC KỲ QUAN TRỌNG)

```bash
# Restart toàn bộ
docker-compose restart

# Đợi services up
docker ps
```

**Kiểm tra sau restart:**
1. Login lại admin console
2. Realm `test-realm` còn không?
3. User `user1` còn không?

**✅ Nếu còn hết → Volume MySQL OK, lab ổn định**

---

### 7️⃣ Test nâng cao - Schema Version

```sql
-- Kiểm tra version schema (quan trọng cho upgrade)
SELECT * FROM MIGRATION_MODEL;
```

**📌 Ghi nhớ kết quả này để so sánh sau upgrade**

---

## 🛠️ Troubleshooting

### Keycloak không start được
```bash
# Xem log chi tiết
docker logs keycloak

# Thường gặp: MySQL chưa ready
# Giải pháp: đợi thêm hoặc restart
docker-compose restart keycloak
```

### MySQL connection failed
```bash
# Kiểm tra MySQL có chạy không
docker exec -it keycloak-mysql mysql -u root -p
# Password: supersecretpassword

# Kiểm tra user keycloak_user
SELECT User, Host FROM mysql.user WHERE User = 'keycloak_user';
```

### Port conflict
```bash
# Nếu port 8080 hoặc 3306 bị chiếm
# Sửa trong docker-compose.yml:
# ports:
#   - "8081:8080"  # Keycloak
#   - "3307:3306"  # MySQL
```

---

## 📊 Additional Tests

### Test Performance
```bash
# Kiểm tra resource usage
docker stats

# Test concurrent connections
curl -I http://localhost:8080/auth
```

### Test Backup/Restore
```bash
# Backup MySQL data
docker exec keycloak-mysql mysqldump -u keycloak_user -p keycloak > backup.sql

# Test restore (trên container mới)
docker exec -i keycloak-mysql mysql -u keycloak_user -p keycloak < backup.sql
```

### Test Network Connectivity
```bash
# Test từ keycloak container đến mysql
docker exec keycloak ping mysql

# Test MySQL port từ host
telnet localhost 3306
```

---

## 🎯 Kết luận

Sau khi hoàn thành tất cả tests:

✅ **Lab Keycloak 12 + MySQL chuẩn production**  
✅ **Dữ liệu thật trong DB**  
✅ **Sẵn sàng cho upgrade testing**

### Next Steps:
1. **Đóng băng lab này** (backup volume)
2. **Clone DB** cho testing
3. **Test migration** từng chặng: 12 → 17 → 20 → 26

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

# Clean up (⚠️ Mất data)
docker-compose down -v
```