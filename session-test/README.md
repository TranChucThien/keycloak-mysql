# Keycloak Session Test

Flask app để test Keycloak session persistence khi restart pod.

## 🎯 Mục đích

Kiểm tra session persistence với MySQL backend:
1. User login qua Keycloak
2. Keycloak pod restart
3. Session vẫn tồn tại, user không cần login lại

## 📊 Kết quả

**Với MySQL (KC26):**
- ✅ Session persist sau restart
- ✅ User không cần login lại
- ✅ Access token vẫn valid

**Không có DB:**
- ❌ Session mất sau restart
- ❌ Phải login lại

## 🚀 Quick Start

### 1. Setup Keycloak
```bash
# Tạo realm và client
cd scripts
./2-setup-data-modern.sh http://192.168.10.142:30080

# Thêm redirect URIs
cd ../session-test
./add-redirect-uris.sh http://192.168.10.142:30080
```

**Config:**
- Realm: `test-realm`
- Client: `test-client` (public)
- Test User: customer1 / test123
- Redirect URIs: localhost:5000, 192.168.10.142:30500

### 2. Deploy

#### Kubernetes (Recommended)

```bash
kubectl apply -f k8s/deployment.yaml
kubectl logs -f deployment/session-test-app

# Access: http://192.168.10.142:30500
```

#### Docker Compose
```bash
docker-compose up -d
# Access: http://localhost:5000
```

#### Local Dev
```bash
cd app
pip install -r requirements.txt
python app.py
# Access: http://localhost:5000
```

## 🧪 Test Steps

1. **Login**: http://192.168.10.142:30500 → Login với customer1/test123
2. **Verify**: Click "Get User Info" → thấy user data
3. **Restart**: `kubectl delete pod -l app=keycloak`
4. **Test**: Refresh page → Click "Get User Info" → ✅ vẫn hoạt động

## 🔍 How It Works

Keycloak lưu session vào MySQL tables:
- `USER_SESSION`
- `CLIENT_SESSION`
- `AUTHENTICATION_SESSION`

Khi restart pod → session restore từ DB → user không cần login lại.

## ⏱️ Session Timeout
- SSO Session Idle: 30 phút
- SSO Session Max: 10 giờ
- Access Token: 5 phút

## 🛠️ Troubleshooting

**Invalid redirect_uri:**
```bash
./add-redirect-uris.sh http://192.168.10.142:30080
```

**Connection refused:**
```bash
# Sử dụng IP thực, không dùng localhost
export KEYCLOAK_URL=http://192.168.10.142:30080
```

## 🔑 Credentials

- Keycloak: http://192.168.10.142:30080
- Realm: test-realm
- Client: test-client
- Test User: customer1 / test123

Xem `CREDENTIALS.md` để biết chi tiết.

## 🧹 Cleanup

```bash
kubectl delete -f k8s/deployment.yaml
# hoặc
docker-compose down
```
