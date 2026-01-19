#!/bin/bash

# Setup script for Keycloak 12-16 (WildFly) with /auth prefix
# Usage: ./setup-data-legacy.sh [KEYCLOAK_URL]
KEYCLOAK_URL="${1:-http://localhost:8080}"
# KEYCLOAK_URL="${1:-http://192.168.10.142:30080}"
REALM_NAME="test-realm"
CLIENT_ID="test-client"

echo "🚀 Setup realm data for Keycloak Legacy (KC12-16)..."
echo "   URL: $KEYCLOAK_URL"

# Get admin token
echo "📝 Getting admin token..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin_temp" \
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
curl -s -X POST "$KEYCLOAK_URL/auth/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"realm":"'$REALM_NAME'","enabled":true}' > /dev/null 2>&1

# Create client (ignore if exists)
echo "📝 Creating client: $CLIENT_ID..."
curl -s -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM_NAME/clients" \
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
  curl -s -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM_NAME/users" \
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
echo "📝 Adding mappers..."
CLIENT_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/auth/admin/realms/$REALM_NAME/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

CLIENT_UUID=$(echo "$CLIENT_RESPONSE" | jq -r '.[0].id // empty')

if [ -z "$CLIENT_UUID" ] || [ "$CLIENT_UUID" = "null" ]; then
  echo "⚠️  Could not find client UUID, mappers may not be added"
else
  # Add mappers
  MAPPERS=(
    'cif-mapper:cif:cif'
    'branch-mapper:branch:branch'
  )

  for mapper_data in "${MAPPERS[@]}"; do
    IFS=':' read -r name attr claim <<< "$mapper_data"
    curl -s -X POST "$KEYCLOAK_URL/auth/admin/realms/$REALM_NAME/clients/$CLIENT_UUID/protocol-mappers/models" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{
        "name":"'$name'",
        "protocol":"openid-connect",
        "protocolMapper":"oidc-usermodel-attribute-mapper",
        "config":{
          "user.attribute":"'$attr'",
          "claim.name":"'$claim'",
          "jsonType.label":"String",
          "id.token.claim":"true",
          "access.token.claim":"true"
        }
      }' > /dev/null 2>&1
  done
fi

echo ""
echo "✅ Setup completed!"
echo "   Realm: $REALM_NAME"
echo "   Client: $CLIENT_ID"
echo "   Users: 5 users (customer1-5/test123)"
echo "   Mappers: CIF, Branch"
echo ""
echo "🔗 Access URLs:"
echo "   Admin Console: $KEYCLOAK_URL/auth/admin"
echo "   Realm: $KEYCLOAK_URL/auth/realms/$REALM_NAME"
