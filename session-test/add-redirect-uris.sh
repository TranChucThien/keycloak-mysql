#!/bin/bash

# Script to add redirect URIs to test-client
# Usage: ./add-redirect-uris.sh [KEYCLOAK_URL]

KEYCLOAK_URL="${1:-http://192.168.10.142:30080}"
REALM_NAME="test-realm"
CLIENT_ID="test-client"

echo "🔧 Adding redirect URIs to test-client..."

# Get admin token
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin_password")

ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')

if [ -z "$ADMIN_TOKEN" ]; then
  echo "❌ Failed to get admin token"
  exit 1
fi

# Get client UUID
CLIENT_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients?clientId=$CLIENT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

CLIENT_UUID=$(echo "$CLIENT_RESPONSE" | jq -r '.[0].id // empty')

if [ -z "$CLIENT_UUID" ]; then
  echo "❌ Client not found: $CLIENT_ID"
  exit 1
fi

# Update client with redirect URIs and post logout redirect URIs
curl -s -X PUT "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients/$CLIENT_UUID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "redirectUris": [
      "http://localhost:5000/callback",
      "http://192.168.10.142:30500/callback",
      "http://127.0.0.1:5000/callback"
    ],
    "webOrigins": [
      "http://localhost:5000",
      "http://192.168.10.142:30500",
      "http://127.0.0.1:5000"
    ],
    "attributes": {
      "post.logout.redirect.uris": "http://localhost:5000##http://192.168.10.142:30500##http://127.0.0.1:5000"
    }
  }'

echo "✅ Redirect URIs added:"
echo "   - http://localhost:5000/callback"
echo "   - http://192.168.10.142:30500/callback"
echo "   - http://127.0.0.1:5000/callback"
echo ""
echo "✅ Post Logout Redirect URIs added:"
echo "   - http://localhost:5000"
echo "   - http://192.168.10.142:30500"
echo "   - http://127.0.0.1:5000"
