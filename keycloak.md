Tài liệu cấu hình Keycloak cho môi trường production trên Kubernetes.

---

## **📋 Mục Lục**

1. [Database Configuration](#1-database-configuration)
2. [Distributed Caching](#2-distributed-caching)
3. [Thread Pools & Performance](#3-thread-pools--performance)
4. [Kubernetes Deployment](#4-kubernetes-deployment)
5. [Monitoring & Metrics](#5-monitoring--metrics)
6. [Resource Sizing & Capacity Planning](#6-resource-sizing--capacity-planning)
7. [Checklist Triển Khai Production](#7-checklist-triển-khai-production)

---

## **1. Database Configuration**

### **1.1. Connection Pool Best Practices**

Trong Keycloak, các kết nối tới database (MySQL) được quản lý bởi **connection pool**.

### **Cấu hình pool tối ưu**

Để đạt hiệu năng tốt nhất:

```
initial size = minimum size = maximum size
```

**Lý do:**

- ✅ Tránh tạo connection mới khi có request (tốn thời gian)
- ✅ Tránh resize pool trong runtime
- ✅ Tránh spike tài nguyên khi traffic tăng
- ✅ Tận dụng server-side statement caching

---

### **1.2. Connection Lifetime Configuration**

**Vấn đề:** Database có tham số `wait_timeout` - thời gian tối đa cho phép connection "idle". Nếu vượt quá → DB tự động đóng connection.

**Lỗi phổ biến:** `'No operations allowed after connection closed'`

**Nguyên nhân:**

```
Nếu: db-pool-max-lifetime >= wait_timeout
```

Thì:

1. DB đã tự đóng connection vì idle quá lâu
2. Keycloak vẫn nghĩ connection còn sống
3. Khi Keycloak sử dụng lại → xảy ra lỗi

**✅ Best Practice:**

```bash
db-pool-max-lifetime = wait_timeout - vài phút
```

**Ví dụ cấu hình:**

```bash
# MySQL default wait_timeout: 28800s (8 giờ)
KC_DB_POOL_MAX_LIFETIME=27000  # 7.5 giờ, nhỏ hơn wait_timeout
```

**Lưu ý:** Nếu cấu hình sai → Keycloak sẽ log warning khi startup.

---

### **1.3. Multi-Zone Database Requirement**

⚠️ **Quan trọng:** Khi triển khai Keycloak multi-zone để đạt HA, database cũng phải hỗ trợ multi-zone và chịu được zone failure.

**Lý do:** Keycloak phụ thuộc hoàn toàn vào database. Nếu DB không có HA theo zone, toàn bộ lợi ích multi-zone của Keycloak sẽ mất ý nghĩa.

---

## **2. Distributed Caching**

### **2.1. Enable Distributed Caching**

```bash
bin/kc.[sh|bat] start --cache=ispn
```

---

### **2.2. Authentication Sessions**

**Lifecycle:**

- Được tạo khi người dùng **bắt đầu đăng nhập**
- Bị xóa khi:
    - Đăng nhập hoàn tất
    - Hoặc hết thời gian hiệu lực

**Cache:** `authenticationSessions` distributed cache

**Lợi ích:**

- ✅ Authentication session có thể được truy cập từ bất kỳ node nào trong cluster
- ✅ Người dùng có thể được chuyển hướng sang node khác mà không mất trạng thái đăng nhập

**✅ Production Best Practice:** Sử dụng **session affinity (sticky session)** để:

- Tránh truyền trạng thái không cần thiết giữa các node
- Tối ưu CPU, memory và network

---

### **2.3. User Sessions & Client Sessions**

**User Sessions:**

Sau khi người dùng xác thực thành công:

- Một **user session** được tạo
- User session theo dõi:
    - Người dùng đang hoạt động
    - Trạng thái đăng nhập
- Nhờ đó người dùng có thể truy cập nhiều ứng dụng mà không cần nhập lại mật khẩu

**Client Sessions:**

Mỗi ứng dụng mà người dùng đăng nhập sẽ có một **client session** riêng, để theo dõi trạng thái đăng nhập theo từng ứng dụng.

**Lifecycle:**

User session và client session sẽ bị xóa khi:

- Người dùng logout
- Client revoke token
- Hoặc hết thời gian hiệu lực

**Storage:**

- Dữ liệu session mặc định được lưu trong **database**
- Khi cần sử dụng, chúng được load vào các cache:
    - `sessions`
    - `clientSessions`

**✅ Production Best Practice:** Vẫn nên dùng **session affinity** để:

- Giảm state transfer giữa nodes
- Giảm tải CPU, memory, network

---

### **2.4. Offline Sessions**

Khi hệ thống phát hành **offline token** (OpenID Connect):

- Tạo:
    - Offline user session
    - Offline client session

**Caches:**

- `offlineSessions`
- `offlineClientSessions`

**Giới hạn:** 10000 entries mỗi node (mặc định)

**Behavior:** Nếu entry bị evict khỏi memory → sẽ được load lại từ database khi cần

---

### **2.5. Cache Size Limits**

**Giới hạn mặc định:**

Cache in-memory cho user sessions và client sessions:

- **10000 entries mỗi node**
- Mỗi entry trong cache chỉ có **một owner duy nhất**

**Lợi ích:**

- ✅ Kiểm soát memory usage
- ✅ Phù hợp cho hệ thống lớn

---

### **2.6. Configuring Cache Maximum Size**

Có thể giới hạn số entry tối đa của một cache để giảm memory:

```bash
--cache-embedded-${CACHE_NAME}-max-count=VALUE
```

**Ví dụ:**

```bash
--cache-embedded-offline-sessions-max-count=1000
```

**Behavior:** Khi vượt quá giới hạn, entry cũ sẽ bị evict khỏi memory (và có thể load lại từ DB khi cần).

**⚠️ Không thể đặt giới hạn cho các cache:**

- `actionToken`
- `authenticationSessions`
- `loginFailures`
- `work`

---

### **2.7. Topology Aware Data Distribution**

Cấu hình topology giúp Keycloak (dùng Infinispan) phân bố replica dữ liệu hợp lý, tăng khả năng chịu lỗi phần cứng.

**Ví dụ:** Nếu `num_owners=2`, hệ thống sẽ cố gắng lưu 2 bản sao trên **khác node/rack/site** khi có thể.

**Lưu ý:** User/client sessions vẫn lưu DB nên không bị ảnh hưởng; các distributed cache khác sẽ áp dụng cấu hình này.

**Kubernetes:**

Keycloak Operator tự động đặt machine name theo Kubernetes node.

**✅ Best Practice:** Thêm **anti-affinity** hoặc **topology spread constraints** để tránh nhiều pod chạy cùng node, giảm rủi ro mất dữ liệu khi node chết.

---

## **3. Thread Pools & Performance**

### **3.1. JGroups Communications**

Dùng trong single-cluster để giao tiếp giữa các node.

**✅ Khuyến nghị:** Chạy trên **OpenJDK 21** với ít nhất 4 CPU cores:

- Sử dụng **virtual threads**
- Giảm memory usage
- Không cần cấu hình thread pool size

---

### **3.2. Quarkus Executor Pool**

**Xử lý:**

- HTTP requests
- Blocking probes

**Default max size:**

- 50 threads hoặc nhiều hơn tùy số CPU cores

**Behavior:**

- Threads tạo khi cần
- Tự kết thúc khi không còn cần

**Cấu hình:**

```bash
http-pool-max-threads
```

---

### **3.3. Load Shedding**

**Vấn đề mặc định:**

- Queue request **vô hạn**
- Có thể gây:
    - ❌ Tăng memory
    - ❌ Exhaust load balancer
    - ❌ Client timeout mà không biết request đã xử lý chưa

**✅ Giải pháp:** Giới hạn số lượng requests trong hàng đợi

```bash
http-max-queued-requests
```

**Behavior:**

- Bất kỳ request nào vượt qua ngưỡng này sẽ trả về lỗi `503 Server not Available`
- Log lỗi trong hệ thống

**Ví dụ tính toán:**

- Nếu pod xử lý ~200 req/s
- Queue 1000 → tối đa chờ ~5 giây

**Lợi ích:**

- ✅ Tự bảo vệ trước tình trạng quá tải
- ✅ Client nhận response nhanh (503) thay vì timeout
- ✅ Kiểm soát memory usage

---

### **3.4. HTTP Performance Optimization (Preview)**

Keycloak có **tính năng Preview** giúp tối ưu hiệu năng tầng HTTP bằng cách cải thiện cơ chế **serialize/deserialize JSON**.

**Lợi ích:**

- ✅ Tăng khoảng **~5% throughput**
- ✅ Response time ổn định hơn
- ✅ Giảm mức sử dụng tài nguyên hệ thống
- ✅ Hệ thống chạy mượt và predictable hơn ở quy mô lớn
- ✅ Giảm chi phí vận hành production

**Nhược điểm:**

- ❌ Thời gian build tăng ~6% (xử lý chuyển từ runtime sang build time)

**Cách bật:**

```bash
bin/kc.sh start --features=http-optimized-serializers
```

---

## **4. Kubernetes Deployment**

### **4.1. Topology Spread Constraints**

Cấu hình để phân tán pod theo zone và node:

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: "topology.kubernetes.io/zone"
    whenUnsatisfiable: "ScheduleAnyway"
    labelSelector:
      matchLabels:
        app: "keycloak"
        app.kubernetes.io/managed-by: "keycloak-operator"
        app.kubernetes.io/instance: "keycloak"
        app.kubernetes.io/component: "server"
  - maxSkew: 1
    topologyKey: "kubernetes.io/hostname"
    whenUnsatisfiable: "ScheduleAnyway"
    labelSelector:
      matchLabels:
        app: "keycloak"
        app.kubernetes.io/managed-by: "keycloak-operator"
        app.kubernetes.io/instance: "keycloak"
        app.kubernetes.io/component: "server"
```

**Giải thích:**

- `topology.kubernetes.io/zone` → phân tán theo zone
- `kubernetes.io/hostname` → phân tán theo node
- `maxSkew: 1` → đảm bảo phân bố cân bằng
- `ScheduleAnyway` → nếu không đạt điều kiện vẫn cho schedule

**Mục tiêu:** ✅ Giảm rủi ro khi 1 node hoặc 1 zone bị lỗi

---

## **5. Monitoring & Metrics**

### **5.1. Enable Cache Metrics**

Khi bật metrics, các **cache metrics** sẽ tự động được expose.

**Bật metrics:**

```bash
bin/kc.sh start --metrics-enabled=true
```

---

### **5.2. Cache Metrics Histograms**

**Bật thêm histogram cho cache metrics:**

```bash
bin/kc.sh start --metrics-enabled=true --cache-metrics-histograms-enabled=true
```

**Lợi ích:**

- ✅ Histogram giúp xem chi tiết phân bố latency

**⚠️ Lưu ý:**

- Có thể ảnh hưởng hiệu năng
- Không nên bật nếu hệ thống đang quá tải

---

## **6. Resource Sizing & Capacity Planning**

### **6.1. Performance Considerations**

**⚠️ Lưu ý quan trọng:**

- Performance **giảm khi scale ra nhiều Pod** do:
    - Overhead giao tiếp giữa các node
    - Traffic nội bộ tăng
- Performance **giảm khi dùng multi-cluster** do:
    - Tăng traffic replication
    - Tăng số operation đồng bộ
- Cache lớn hơn:
    - ✅ Giảm response time
    - ✅ Giảm IOPS database
    - ❌ Khi restart Pod → cache phải fill lại
    - ⚠️ Không sizing dựa trên trạng thái "cache đã warm"

---

### **6.2. Memory Sizing**

**Base memory cho 1 Pod:**
- **1250 MB RAM** (bao gồm realm cache + 10,000 sessions)

**Phân bổ trong container:**
- 70% memory limit → heap
- ~300 MB → non-heap

**Công thức tính memory limit:**
```
(memory cần thiết - 300MB) / 0.7
```

**Ví dụ:**
- Memory cần: 1250 MB
- Memory limit: (1250 - 300) / 0.7 = **1360 MB**

---

### **6.3. CPU Sizing theo Request Type**

| Request Type | vCPU Required | Tested Up To | Notes |
|--------------|---------------|--------------|-------|
| **Password login** | 1 vCPU / 15 req/s | 300 req/s | CPU dùng để hash password, tỷ lệ thuận với hash iterations |
| **Client credential grant** | 1 vCPU / 120 req/s | 2000 req/s | CPU dùng để tạo TLS connection mới |
| **Refresh token** | 1 vCPU / 120 req/s | 435 req/s | - |

**CPU Headroom:**
- Thêm **150% CPU headroom**
- Tránh CPU throttling (performance giảm mạnh khi bị throttled)
- Đảm bảo:
    - ✅ Xử lý spike traffic
    - ✅ Startup nhanh
    - ✅ Failover capacity

---

### **6.4. Cache Sizing cho Concurrent Clients**

**Khi > 2500 concurrent clients:**

- Standard cache: 10,000 entries
- ⚠️ Có thể không đủ → DB bottleneck

**✅ Khuyến nghị:**
```bash
users cache = 2 × số concurrent clients
realms cache = 4 × số concurrent clients
```

---

### **6.5. Database Requirements**

**Cho mỗi 100 login/logout/refresh per second:**
- **1400 Write IOPS**
- **0.35–0.7 vCPU**

**Lưu ý:**
- CPU DB thấp → response time tăng khi peak
- Cần response nhanh lúc peak → chọn CPU cao hơn

---

### **6.6. Monitoring Metrics**

**Metrics quan trọng:**

```bash
# Password-based và cookie-based logins
keycloak_user_events_total{event_type="login"}

# Password hashing validations
keycloak_credentials_password_hashing_validations_total
# Tags: realm, algorithm, hashing_strength, outcome

# Refresh token và client login
keycloak_user_events_total{event_type="refresh_token"}
keycloak_user_events_total{event_type="client_login"}
```

**Sử dụng để:**
- ✅ Theo dõi fluctuation theo ngày/tuần
- ✅ Dự báo nhu cầu resize
- ✅ Validate sizing calculation

---

### **6.7. Ví Dụ Tính Toán (Single Cluster)**

**Yêu cầu:**
- 45 password login/s
- 360 client credential/s
- 360 refresh token/s
- 3 Pods

**Tính toán CPU:**
```
Password login: 45/15 = 3 vCPU
Client credential: 360/120 = 3 vCPU
Refresh token: 360/120 = 3 vCPU
Tổng: 9 vCPU cho cluster
Mỗi Pod: 9/3 = 3 vCPU requested
CPU limit: 3 × 1.5 = 7.5 vCPU (với 150% headroom)
```

**Tính toán Memory:**
```
Memory requested: 1250 MB
Memory limit: (1250 - 300) / 0.7 = 1360 MB
```

**Tính toán Database:**
```
Total requests: (45 + 360 + 360) / 100 = 7.65 × 100 req/s
Write IOPS: 7.65 × 1400 = ~10,710 IOPS
vCPU DB: 7.65 × (0.35-0.7) = 2.7-5.4 vCPU
```

**Kết quả:**

| Resource | Value |
|----------|-------|
| **CPU requested per Pod** | 3 vCPU |
| **CPU limit per Pod** | 7.5 vCPU |
| **Memory requested per Pod** | 1250 MB |
| **Memory limit per Pod** | 1360 MB |
| **Database IOPS** | ~10,710 Write IOPS |
| **Database vCPU** | 2.7-5.4 vCPU |

**Gợi ý DB instance:**
- **db.t4g.large** (2 vCPU) → cost-effective, response cao hơn lúc peak
- **db.t4g.xlarge** (4 vCPU) → response nhanh hơn khi peak

---

## **7. Checklist Triển Khai Production**

### **Thông số cần xác định trước khi triển khai:**

**1. Thông số về tải (Để tính CPU):**

- **Password-based logins:** 
  - 📊 **Metric:** `keycloak_credentials_password_hashing_validations_total` (tags: realm, algorithm, hashing_strength, outcome)
  
- **Client credential grants:** 
  - 📊 **Metric:** `keycloak_user_events_total{event_type="client_login"}`
  
- **Refresh token requests:** 
  - 📊 **Metric:** `keycloak_user_events_total{event_type="refresh_token"}`
  
- **Tỷ lệ dự phòng (Headroom):** Mặc định thêm 150% để xử lý đột biến (spikes) và failover

**2. Thông số về người dùng và phiên (Để tính Memory/RAM):**

- **Số lượng Session dự kiến:** Mặc định tính trên 10,000 sessions (mốc 1250 MB RAM)
- **Số lượng Client hoạt động đồng thời (Concurrent Clients):** Nếu > 2,500 clients, cần tăng kích thước cache cho Realm và User
- **Cấu hình bộ nhớ đệm (Cache size):** Quyết định dựa trên số lượng client và user để tránh thắt nút cổ chai tại Database

**3. Thông số về Database (Để tính IOPS và vCPU DB):**

- **Tổng lưu lượng (Total Requests):** Tổng số Login + Logout + Refresh mỗi giây
- **Yêu cầu về độ trễ (Response Time):** Để quyết định chọn cấu hình DB tối thiểu (cost-effective) hay cấu hình cao để đảm bảo tốc độ lúc tải đỉnh

**4. Thông số triển khai:**

- **Số lượng Pods:** Để chia tổng tài nguyên cần thiết cho từng đơn vị chạy
- **Topology spread constraints:** Phân tán pod theo zone và node
- **Session affinity:** Cấu hình sticky session để tối ưu performance

---

### **Lưu ý về Metrics:**

- Metric `keycloak_user_events_total{event_type="login"}` bao gồm cả password-based và cookie-based logins
- Để tính chính xác password validations, dùng `keycloak_credentials_password_hashing_validations_total`
- Metrics giúp theo dõi fluctuation theo ngày/tuần, dự báo nhu cầu resize và validate sizing calculation

---

## **📚 Tham Khảo**

- [Keycloak Official Documentation](https://www.keycloak.org/documentation)
- [Red Hat Keycloak HA Guide](https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/26.4/html/high_availability_guide/index)
- [Infinispan Documentation](https://infinispan.org/documentation/)
- [Kubernetes Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)

---

**Happy Deploying! 🚀**
