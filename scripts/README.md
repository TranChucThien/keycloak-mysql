# Keycloak Test Scripts

Utility scripts for setting up and testing Keycloak with custom token mappers.

## 📁 Scripts Overview

### Cleanup Script
Delete test-realm and all data.

| Script | Usage |
|--------|-------|
| `0-cleanup.sh` | `./0-cleanup.sh [URL] [legacy\|modern]` |

**Example**: `./0-cleanup.sh http://192.168.10.142:30080 modern`

### Setup Scripts
Create test realm, client, users, and custom mappers.

| Script | Version | URL Format | Usage |
|--------|---------|------------|-------|
| `1-setup-data-legacy.sh` | KC12-16 | With `/auth` | `./1-setup-data-legacy.sh [URL]` |
| `2-setup-data-modern.sh` | KC18+ | Without `/auth` | `./2-setup-data-modern.sh [URL]` |

**Default URL**: `http://192.168.10.142:30080`

**Creates**:
- Realm: `test-realm`
- Client: `test-client`
- Users: `customer1-5` (password: `test123`)
- Custom Mappers: CIF (oidc-cif-property-mapper), Branch (oidc-branch-property-mapper)
- User Profile: Defines `cif` and `branch` attributes (KC26+)

### Verify Custom Mappers Scripts
Verify custom mappers are installed and registered.

| Script | Version | URL Format | Usage |
|--------|---------|------------|-------|
| `3-verify-custom-mappers-legacy.sh` | KC12-16 | With `/auth` | `./3-verify-custom-mappers-legacy.sh [URL] [POD]` |
| `4-verify-custom-mappers-modern.sh` | KC18+ | Without `/auth` | `./4-verify-custom-mappers-modern.sh [URL] [POD]` |

**Checks**:
- 📦 JAR file exists in pod (optional)
- 🔌 Custom mappers registered in Keycloak
- 🎯 Mappers configured in test-realm client
- 🔧 Troubleshooting steps if issues found

### Verify Data Scripts
Verify realm, users, and token claims.

| Script | Version | URL Format | Usage |
|--------|---------|------------|-------|
| `5-verify-data-legacy.sh` | KC12-16 | With `/auth` | `./5-verify-data-legacy.sh [URL]` |
| `6-verify-data-modern.sh` | KC18+ | Without `/auth` | `./6-verify-data-modern.sh [URL]` |

**Checks**:
- ✅ Realm exists
- ✅ Users created
- ✅ User attributes (CIF, Branch)
- ✅ Login works
- ✅ Token claims present

## 🚀 Quick Start

### For KC12-16 (WildFly)
```bash
# 1. Setup
./1-setup-data-legacy.sh http://192.168.10.142:30080

# 2. Verify custom mappers
./3-verify-custom-mappers-legacy.sh http://192.168.10.142:30080

# 3. Verify data and token claims
./5-verify-data-legacy.sh http://192.168.10.142:30080
```

### For KC18+ (Quarkus)
```bash
# 1. Setup
./2-setup-data-modern.sh http://192.168.10.142:30080

# 2. Verify custom mappers
./4-verify-custom-mappers-modern.sh http://192.168.10.142:30080

# 3. Verify data and token claims
./6-verify-data-modern.sh http://192.168.10.142:30080
```

## 📝 Examples

### Setup with custom URL
```bash
./2-setup-data-modern.sh http://192.168.10.142:30080
```

### Verify mappers in K8s pod
```bash
./4-verify-custom-mappers-modern.sh http://192.168.10.142:30080 keycloak-pod-name
```

### Verify data and check claims
```bash
./6-verify-data-modern.sh http://192.168.10.142:30080
```

## 🔑 Test Users

| Username | Password | CIF | Branch |
|----------|----------|-----|--------|
| customer1 | test123 | CIF001234567 | MAIN_BRANCH |
| customer2 | test123 | CIF002345678 | NORTH_BRANCH |
| customer3 | test123 | CIF003456789 | SOUTH_BRANCH |
| customer4 | test123 | CIF004567890 | EAST_BRANCH |
| customer5 | test123 | CIF005678901 | WEST_BRANCH |

## 🎯 Custom Mappers

**Custom Java Mappers** (require JAR in `/opt/keycloak/providers/`):
- **CifOIDCProtocolMapper** (`oidc-cif-property-mapper`) - Adds `cif` claim
- **BranchOIDCProtocolMapper** (`oidc-branch-property-mapper`) - Adds `branch` claim

**Build JAR**:
```bash
# For KC12-16
cd versions/kc16/mapper && mvn clean package

# For KC26
cd versions/kc26/mapper && mvn clean package
```

## ⚠️ Important Notes

### KC26+ User Profile Requirement
Keycloak 26+ uses **Declarative User Profile** (enabled by default) which requires:
- All custom attributes must be defined in User Profile schema before use
- Arbitrary "unmanaged" attributes are ignored unless configured
- Script `2-setup-data-modern.sh` automatically configures `cif` and `branch` in User Profile

**What the script does for KC26:**
```bash
# 1. Creates realm
# 2. Configures User Profile with cif and branch attributes
# 3. Creates users with attributes (now works because schema is defined)
# 4. Adds custom mappers
```

**Manual configuration** (if needed):
1. Admin Console → Realm Settings → User Profile
2. Attributes tab → Create attribute
3. Define: name, displayName, permissions (view/edit)
4. Save and users can now have this attribute

### Version-Specific Behaviors

| Version | User Attributes | Requirement |
|---------|----------------|-------------|
| KC12-16 | Direct creation | No schema needed |
| KC18-21 | Direct creation | No schema needed |
| KC24+ | Schema required | Must define in User Profile |
| KC26+ | Schema required | User Profile enabled by default |

## ⚠️ Requirements

- `curl` - HTTP requests
- `jq` - JSON parsing
- `base64` - Token decoding
- `kubectl` - K8s pod access (optional)

## 🔗 URL Differences

| Version | Token Endpoint | Admin API |
|---------|----------------|-----------|
| KC12-16 | `/auth/realms/{realm}/protocol/openid-connect/token` | `/auth/admin/realms` |
| KC18+ | `/realms/{realm}/protocol/openid-connect/token` | `/admin/realms` |
