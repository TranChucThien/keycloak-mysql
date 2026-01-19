#!/bin/bash

# Setup script for Keycloak 18+ (Quarkus) without /auth prefix
# Usage: ./setup-data-modern.sh [KEYCLOAK_URL]

KEYCLOAK_URL="${1:-http://192.168.10.142:30080}"
REALM_NAME="test-realm"
CLIENT_ID="test-client"

echo "🚀 Setup realm data for Keycloak Modern (KC18+)..."
echo "   URL: $KEYCLOAK_URL"

# Get admin token
echo "📝 Getting admin token..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin_password")

ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Failed to get admin token. Check if Keycloak is running at $KEYCLOAK_URL"
  echo "   Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Admin token obtained"

# Create realm (ignore if exists)
echo "📝 Creating realm: $REALM_NAME..."
curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"realm":"'$REALM_NAME'","enabled":true}' > /dev/null 2>&1

# Configure User Profile attributes (KC24+ requirement)
# NOTE: Keycloak 24+ uses Declarative User Profile (enabled by default in KC26+)
# All custom attributes MUST be defined in the schema before use
# Without this configuration, user attributes will be ignored/null
echo "📝 Configuring user profile attributes..."
curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users/profile" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": [
      {
        "name": "username",
        "validations": {"length": {"min": 3, "max": 255}},
        "permissions": {"view": ["admin", "user"], "edit": ["admin"]},
        "multivalued": false
      },
      {
        "name": "email",
        "permissions": {"view": ["admin", "user"], "edit": ["admin", "user"]},
        "multivalued": false
      },
      {
        "name": "cif",
        "displayName": "Customer Information File",
        "permissions": {"view": ["admin", "user"], "edit": ["admin"]},
        "multivalued": false
      },
      {
        "name": "branch",
        "displayName": "Branch",
        "permissions": {"view": ["admin", "user"], "edit": ["admin"]},
        "multivalued": false
      }
    ]
  }' > /dev/null 2>&1

# Create client (ignore if exists)
echo "📝 Creating client: $CLIENT_ID..."
curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId":"'$CLIENT_ID'",
    "enabled":true,
    "publicClient":true,
    "directAccessGrantsEnabled":true
  }' > /dev/null 2>&1

# Create users
echo "📝 Creating users..."
USERS=(
  'customer1:test123:CIF001234567:MAIN_BRANCH'
  'customer2:test123:CIF002345678:NORTH_BRANCH'
  'customer3:test123:CIF003456789:SOUTH_BRANCH'
  'customer4:test123:CIF004567890:EAST_BRANCH'
  'customer5:test123:CIF005678901:WEST_BRANCH'
)

for user_data in "${USERS[@]}"; do
  IFS=':' read -r username password cif branch <<< "$user_data"
  
  # Create user with attributes
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "username":"'$username'",
      "enabled":true,
      "attributes":{
        "cif":["'$cif'"],
        "branch":["'$branch'"]
      },
      "credentials":[{"type":"password","value":"'$password'","temporary":false}]
    }' > /dev/null 2>&1
done

# Get client UUID for mapper
echo "📝 Adding custom mappers..."
CLIENT_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

CLIENT_UUID=$(echo "$CLIENT_RESPONSE" | jq -r '.[0].id // empty')

if [ -z "$CLIENT_UUID" ] || [ "$CLIENT_UUID" = "null" ]; then
  echo "⚠️  Could not find client UUID, mappers may not be added"
else
  # Add custom mappers
  # NOTE: These custom mappers require JAR file in /opt/keycloak/providers/
  # If JAR is missing, mappers will not work and tokens will not contain custom claims
  # Build JAR: cd versions/kc26/mapper && mvn clean package
  
  # CIF Mapper - uses CifOIDCProtocolMapper (oidc-cif-property-mapper)
  CIF_RESULT=$(curl -s -w "\n%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients/$CLIENT_UUID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name":"cif-mapper",
      "protocol":"openid-connect",
      "protocolMapper":"oidc-cif-property-mapper",
      "config":{
        "id.token.claim":"true",
        "access.token.claim":"true",
        "userinfo.token.claim":"true"
      }
    }')
  HTTP_CODE=$(echo "$CIF_RESULT" | tail -n1)
  [ "$HTTP_CODE" = "201" ] && echo "   ✅ CIF mapper added" || echo "   ⚠️  CIF mapper: HTTP $HTTP_CODE"
  
  # Branch Mapper - uses BranchOIDCProtocolMapper (oidc-branch-property-mapper)
  BRANCH_RESULT=$(curl -s -w "\n%{http_code}" -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients/$CLIENT_UUID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "name":"branch-mapper",
      "protocol":"openid-connect",
      "protocolMapper":"oidc-branch-property-mapper",
      "config":{
        "id.token.claim":"true",
        "access.token.claim":"true",
        "userinfo.token.claim":"true"
      }
    }')
  HTTP_CODE=$(echo "$BRANCH_RESULT" | tail -n1)
  [ "$HTTP_CODE" = "201" ] && echo "   ✅ Branch mapper added" || echo "   ⚠️  Branch mapper: HTTP $HTTP_CODE"
fi

echo ""
echo "✅ Setup completed!"
echo "   Realm: $REALM_NAME"
echo "   Client: $CLIENT_ID"
echo "   Users: 5 users (customer1-5/test123)"
echo "   Mappers: CIF (oidc-cif-property-mapper), Branch (oidc-branch-property-mapper)"
echo ""
echo "⚠️  Important Notes:"
echo "   1. Custom mappers require JAR in /opt/keycloak/providers/"
echo "   2. KC24+ requires User Profile configuration (done automatically)"
echo "   3. Run verify script: ./4-verify-custom-mappers-modern.sh"
echo ""
echo "🔗 Access URLs:"
echo "   Admin Console: $KEYCLOAK_URL/admin"
echo "   Realm: $KEYCLOAK_URL/realms/$REALM_NAME"
