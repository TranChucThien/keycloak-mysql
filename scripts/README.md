# Keycloak Test Scripts

Utility scripts for setting up and testing Keycloak with custom token mappers.

## 📁 Scripts Overview

### Setup Scripts
Create test realm, client, users, and mappers.

| Script | Version | URL Format | Usage |
|--------|---------|------------|-------|
| `setup-data-legacy.sh` | KC12-16 | With `/auth` | `./setup-data-legacy.sh [URL]` |
| `setup-data-modern.sh` | KC18+ | Without `/auth` | `./setup-data-modern.sh [URL]` |

**Default URL**: `http://localhost:8080`

**Creates**:
- Realm: `test-realm`
- Client: `test-client`
- Users: `customer1-5` (password: `test123`)
- Mappers: CIF, Branch

### Verify Scripts
Verify realm, users, and token claims.

| Script | Version | URL Format | Usage |
|--------|---------|------------|-------|
| `verify-data-legacy.sh` | KC12-16 | With `/auth` | `./verify-data-legacy.sh [URL]` |
| `verify-data-modern.sh` | KC18+ | Without `/auth` | `./verify-data-modern.sh [URL]` |

**Checks**:
- ✅ Realm exists
- ✅ Users created
- ✅ User attributes (CIF, Branch)
- ✅ Login works
- ✅ Token claims present

### Token Test Scripts
Test token generation and decode claims.

| Script | Version | URL Format | Usage |
|--------|---------|------------|-------|
| `test-token-legacy.sh` | KC12-16 | With `/auth` | `./test-token-legacy.sh [URL] [USER]` |
| `test-token-modern.sh` | KC18+ | Without `/auth` | `./test-token-modern.sh [URL] [USER]` |

**Default User**: `customer1`

**Shows**:
- 🔐 Token request
- 📋 Key claims (sub, CIF, branch, user_level, permissions)
- 📄 Full token payload (JSON)
- ✅ Mapper validation

## 🚀 Quick Start

### For KC12-16 (WildFly)
```bash
# Setup
./setup-data-legacy.sh http://localhost:8080

# Verify
./verify-data-legacy.sh http://localhost:8080

# Test token
./test-token-legacy.sh http://localhost:8080 customer1
```

### For KC18+ (Quarkus)
```bash
# Setup
./setup-data-modern.sh http://192.168.10.142:30080

# Verify
./verify-data-modern.sh http://192.168.10.142:30080

# Test token
./test-token-modern.sh http://192.168.10.142:30080 customer2
```

## 📝 Examples

### Setup with custom URL
```bash
./setup-data-modern.sh http://192.168.10.142:30080
```

### Test specific user
```bash
./test-token-modern.sh http://192.168.10.142:30080 customer3
```

### Verify and check claims
```bash
./verify-data-modern.sh http://192.168.10.142:30080
```

## 🔑 Test Users

| Username | Password | CIF | Branch |
|----------|----------|-----|--------|
| customer1 | test123 | CIF001234567 | MAIN_BRANCH |
| customer2 | test123 | CIF002345678 | NORTH_BRANCH |
| customer3 | test123 | CIF003456789 | SOUTH_BRANCH |
| customer4 | test123 | CIF004567890 | EAST_BRANCH |
| customer5 | test123 | CIF005678901 | WEST_BRANCH |

## ⚠️ Requirements

- `curl` - HTTP requests
- `jq` - JSON parsing
- `base64` - Token decoding

## 🔗 URL Differences

| Version | Token Endpoint | Admin API |
|---------|----------------|-----------|
| KC12-16 | `/auth/realms/{realm}/protocol/openid-connect/token` | `/auth/admin/realms` |
| KC18+ | `/realms/{realm}/protocol/openid-connect/token` | `/admin/realms` |
