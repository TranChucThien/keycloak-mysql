# Hướng Dẫn Tính Toán Resource cho Keycloak

Tài liệu này hướng dẫn cách tính toán số lượng Pod và resource (CPU, Memory) cho Keycloak dựa trên yêu cầu thực tế.

---

## 📋 Mục Lục

1. [Thu Thập Thông Số Đầu Vào](#1-thu-thập-thông-số-đầu-vào)
2. [Công Thức Tính Toán](#2-công-thức-tính-toán)
3. [Quy Trình Tính Toán](#3-quy-trình-tính-toán)
4. [Ví Dụ Thực Tế](#4-ví-dụ-thực-tế)
5. [Xác Định Số Lượng Pod](#5-xác-định-số-lượng-pod)
6. [Checklist Triển Khai](#6-checklist-triển-khai)

---

## 1. Thu Thập Thông Số Đầu Vào

### 1.1. Thông Số về Traffic (Bắt buộc)

| Thông số | Đơn vị | Cách lấy |
|----------|--------|----------|
| **Password login** | req/s | Metric: `keycloak_credentials_password_hashing_validations_total` |
| **Client credential** | req/s | Metric: `keycloak_user_events_total{event_type="client_login"}` |
| **Refresh token** | req/s | Metric: `keycloak_user_events_total{event_type="refresh_token"}` |

### 1.2. Thông Số về Users & Sessions

| Thông số | Đơn vị | Ghi chú |
|----------|--------|---------|
| **Total sessions** | số lượng | Tổng số session trong hệ thống |
| **Concurrent users (peak)** | số lượng | Số user đồng thời tại thời điểm cao điểm |

### 1.3. Thông Số về HA & Performance

| Thông số | Giá trị | Ghi chú |
|----------|---------|---------|
| **Số Availability Zones** | 2-3 | Để đảm bảo HA |
| **Failover capacity** | 1 Pod | Dự phòng khi 1 pod chết |
| **CPU headroom** | 150% | Mặc định (CPU limit = request × 1.5) |

---

## 2. Công Thức Tính Toán

### 2.1. Tính CPU cho Cluster

**Bước 1: Tính CPU theo từng loại request**

```
CPU_password   = password_login_per_sec ÷ 15 (15 req/s per vCPU)
CPU_client     = client_credential_per_sec ÷ 120 (120 req/s per vCPU)
CPU_refresh    = refresh_token_per_sec ÷ 120 (120 req/s per vCPU)
```

**Bước 2: Tổng CPU cho cluster**

```
Total_CPU_cluster = CPU_password + CPU_client + CPU_refresh
```

### 2.2. Tính Memory cho 1 Pod

**Base memory:**
```
Base = 1250 MB (cho 10,000 sessions)
```

**Nếu concurrent users > 2500:**
```
Memory_request = Base + (concurrent_users ÷ 2500) × 500 MB
```

**Memory limit:**
```
Memory_limit = (Memory_request - 300) ÷ 0.7
```

---

## 3. Quy Trình Tính Toán

### Bước 1: Tính Tổng CPU Cluster

```
Total_CPU_cluster = (password÷15) + (client÷120) + (refresh÷120)
```

### Bước 2: Xác Định Số Pod Tối Thiểu

**Dựa trên HA requirement:**

| Số AZ | Số Pod tối thiểu | Lý do |
|-------|------------------|-------|
| 1 AZ | 2 Pods | Failover trong cùng AZ |
| 2 AZ | 4 Pods | 2 pods/AZ, chịu được 1 AZ chết |
| 3 AZ | 6 Pods | 2 pods/AZ, chịu được 1 AZ chết |

**Công thức:**
```
Min_Pods = Số_AZ × 2
```

### Bước 3: Tính CPU Request cho Mỗi Pod

```
CPU_request_per_pod = Total_CPU_cluster ÷ Số_Pods
CPU_limit_per_pod = CPU_request_per_pod × 1.5
```

### Bước 4: Làm Tròn và Điều Chỉnh

- Làm tròn CPU request lên bội số của 100m (0.1 vCPU)
- Đảm bảo CPU request ≥ 500m (0.5 vCPU)
- CPU limit = CPU request × 1.5

---

## 4. Ví Dụ Thực Tế

**Input:**
```
Password login:    10 req/s
Client credential: 500 req/s
Refresh token:     200 req/s
Total sessions:    4,000,000
Concurrent users:  500 (peak)
Số AZ:             2
```

**Tính toán:**

**Bước 1: Tính CPU cluster**
```
CPU_password  = 10 ÷ 15   = 0.67 vCPU
CPU_client    = 500 ÷ 120 = 4.17 vCPU
CPU_refresh   = 200 ÷ 120 = 1.67 vCPU
────────────────────────────────────
Total         = 6.51 vCPU
```

**Bước 2: Số Pod tối thiểu**
```
Min_Pods = 2 AZ × 2 = 4 Pods
```

**Bước 3: CPU mỗi Pod**
```
CPU_request = 6.51 ÷ 4 = 1.63 vCPU → làm tròn: 1.7 vCPU (1700m)
CPU_limit   = 1.7 × 1.5 = 2.55 vCPU → làm tròn: 2.6 vCPU (2600m)
```

**Bước 4: Memory**
```
Concurrent users = 500 < 2500 → dùng base memory
Memory_request = 1250 MB
Memory_limit   = (1250 - 300) ÷ 0.7 = 1357 MB → làm tròn: 1400 MB
```

**Bước 5: Connection Pool**
```
Total requests = 710 req/s
Concurrent connections = 710 × 0.02 × 3 = 42.6
Per pod = 42.6 ÷ 4 = 10.65 → làm tròn: 20
```

**Kết quả:**

```yaml
replicas: 4

resources:
  requests:
    cpu: "1700m"
    memory: "1250Mi"
  limits:
    cpu: "2600m"
    memory: "1400Mi"

env:
  KC_DB_POOL_INITIAL_SIZE: "20"
  KC_DB_POOL_MIN_SIZE: "20"
  KC_DB_POOL_MAX_SIZE: "20"
  KC_SPI_CACHE_EMBEDDED_DEFAULT_SESSIONS_OWNERS: "2"
```

**Lưu ý:**
- Total sessions: 4M sessions được lưu trong **database**, không ảnh hưởng memory Pod
- Concurrent users (500) < 2500 → cache mặc định đủ
- 4 Pods đảm bảo HA với 2 AZ (2 pods/AZ)
- DB cần `max_connections` ≥ 100 (4 pods × 20 = 80)

---

## 5. Connection Pool & Caching

### 5.1. Database Connection Pool

**Tính toán concurrent connections:**

```
Total requests = 10 + 500 + 200 = 710 req/s
DB transaction time = ~20ms (trung bình)
Concurrent connections = 710 × 0.02 = 14.2
Safety margin (×3) = 14.2 × 3 = 42.6
Per pod (4 pods) = 42.6 ÷ 4 = 10.65 → làm tròn: 20
```

**Khuyến nghị:**
```yaml
KC_DB_POOL_INITIAL_SIZE: "20"
KC_DB_POOL_MIN_SIZE: "20"
KC_DB_POOL_MAX_SIZE: "20"
KC_DB_POOL_MAX_LIFETIME: "27000"  # 7.5 giờ
```

**Database requirements:**
- Total cluster connections: 4 pods × 20 = 80
- MySQL `max_connections` ≥ 200 (khuyến nghị)

### 5.2. Distributed Cache Owners

**Với 4 Pods + 2 AZ:**

```
owners = 2
```

**Lý do:**
- Mất 1 pod → vẫn còn bản sao
- Mất 1 AZ (2 pods) → vẫn còn data
- Memory impact: ×2 entry (chấp nhận được)
- Production safe cho HA

**Cấu hình cache owners:**
```yaml
# Sessions (bắt buộc cho HA)
KC_SPI_CACHE_EMBEDDED_DEFAULT_SESSIONS_OWNERS: "2"
```

---

## 6. Xác Định Số Lượng Pod

### 6.1. Công Thức Tổng Quát

```
Số_Pod = MAX(
    Min_Pods_for_HA,
    CEILING(Total_CPU_cluster ÷ Max_CPU_per_Pod)
)
```

Trong đó:
- `Min_Pods_for_HA` = Số AZ × 2
- `Max_CPU_per_Pod` = 8 vCPU (khuyến nghị, tùy node capacity)

### 6.2. Decision Tree

```
1. Tính Total_CPU_cluster
   ↓
2. Xác định Min_Pods dựa trên số AZ
   ↓
3. Tính CPU_per_Pod = Total_CPU ÷ Min_Pods
   ↓
4. Nếu CPU_per_Pod > 8 vCPU:
   → Tăng số Pod
   → Recalculate CPU_per_Pod
   ↓
5. Nếu CPU_per_Pod < 0.5 vCPU:
   → Giữ Min_Pods (để đảm bảo HA)
   ↓
6. Apply CPU headroom (× 1.5)
```

---

## 📊 Template Tính Toán

```markdown
## Input
- Password login: ___ req/s
- Client credential: ___ req/s
- Refresh token: ___ req/s
- Concurrent users: ___
- Total sessions: ___
- Số AZ: ___

## Calculation

### CPU
Password:  ___ ÷ 15   = ___ vCPU
Client:    ___ ÷ 120  = ___ vCPU
Refresh:   ___ ÷ 120  = ___ vCPU
────────────────────────────────
Total CPU cluster:     ___ vCPU

### Pods
Min Pods (HA):         ___ Pods
CPU per Pod:           ___ vCPU
CPU request:           ___ m
CPU limit:             ___ m (× 1.5)

### Memory
Base memory:           1250 MB
Cache overhead:        ___ MB
Memory request:        ___ MB
Memory limit:          ___ MB

## Result
```yaml
replicas: ___

resources:
  requests:
    cpu: "___m"
    memory: "___Mi"
  limits:
    cpu: "___m"
    memory: "___Mi"
```
```

---

## 📚 Tham Khảo

- [keycloak.md](./keycloak.md) - Tài liệu cấu hình chi tiết
- [Red Hat Keycloak HA Guide](https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/26.4/html/high_availability_guide/index)
- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

---

**Happy Calculating! 🧮**
