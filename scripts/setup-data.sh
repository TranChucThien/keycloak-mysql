#!/bin/bash

KEYCLOAK_URL="http://192.168.10.142:30080/auth"
REALM_NAME="test-realm"
CLIENT_ID="test-client"

echo "🚀 Setup realm data mẫu..."

# Get admin token
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin_password" | jq -r '.access_token')

# Create realm (ignore if exists)
curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"realm":"'$REALM_NAME'","enabled":true}' > /dev/null 2>&1

# Create client (ignore if exists)
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
USERS=(
  'customer1:test123:CIF001234567:MAIN_BRANCH'
  'customer2:test123:CIF002345678:NORTH_BRANCH'
  'customer3:test123:CIF003456789:SOUTH_BRANCH'
  'customer4:test123:CIF004567890:EAST_BRANCH'
  'customer5:test123:CIF005678901:WEST_BRANCH'
)

for user_data in "${USERS[@]}"; do
  IFS=':' read -r username password cif branch <<< "$user_data"
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
CLIENT_UUID=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id')

# Add mappers
MAPPERS=(
  'cif-mapper:cif:cif'
  'branch-mapper:branch:branch'
)

for mapper_data in "${MAPPERS[@]}"; do
  IFS=':' read -r name attr claim <<< "$mapper_data"
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients/$CLIENT_UUID/protocol-mappers/models" \
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

echo "✅ Setup completed!"
echo "   Realm: $REALM_NAME"
echo "   Client: $CLIENT_ID"
echo "   Users: 5 users (customer1-5/test123)"
echo "   Mappers: CIF, Branch"