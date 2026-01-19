#!/bin/bash

# Test token generation for Keycloak 12-16 (WildFly) with /auth prefix
# Usage: ./test-token-legacy.sh [KEYCLOAK_URL] [USERNAME]
KEYCLOAK_URL="${1:-http://localhost:8080}"

# KEYCLOAK_URL="${1:-http://192.168.10.142:30080}"
USERNAME="${2:-customer1}"
PASSWORD="test123"
REALM_NAME="test-realm"
CLIENT_ID="test-client"

echo "🔐 Testing token generation for Keycloak Legacy (KC12-16)..."
echo "   URL: $KEYCLOAK_URL"
echo "   User: $USERNAME"
echo ""

# Get token
echo "📝 Requesting token..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/auth/realms/$REALM_NAME/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "username=$USERNAME" \
  -d "password=$PASSWORD")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to get token"
  echo "   Response: $TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Token obtained successfully"
echo ""

# Decode token
echo "📝 Decoding token..."
PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d. -f2)
# Add padding for base64 decode
while [ $((${#PAYLOAD} % 4)) -ne 0 ]; do
  PAYLOAD="${PAYLOAD}="
done

CLAIMS=$(echo "$PAYLOAD" | base64 -d 2>/dev/null | jq . 2>/dev/null)

if [ -z "$CLAIMS" ]; then
  echo "❌ Failed to decode token"
  exit 1
fi

echo "✅ Token decoded successfully"
echo ""

# Extract key claims
echo "📋 Token Claims:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SUB=$(echo "$CLAIMS" | jq -r '.sub // "N/A"')
echo "   Subject (sub): $SUB"

CIF=$(echo "$CLAIMS" | jq -r 'if (.cif | type) == "array" then .cif[0] else .cif end // "N/A"')
echo "   CIF: $CIF $([ "$CIF" != "N/A" ] && echo "✅" || echo "❌")"

BRANCH=$(echo "$CLAIMS" | jq -r '.branch // "N/A"')
echo "   Branch: $BRANCH $([ "$BRANCH" != "N/A" ] && echo "✅" || echo "❌")"

USER_LEVEL=$(echo "$CLAIMS" | jq -r '.user_level // "N/A"')
echo "   User Level: $USER_LEVEL"

PERMISSIONS=$(echo "$CLAIMS" | jq -r '.permissions // "N/A"')
echo "   Permissions: $PERMISSIONS"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Full token payload
echo "📄 Full Token Payload:"
echo "$CLAIMS" | jq .
echo ""

# Summary
echo "📊 Summary:"
if [ "$CIF" != "N/A" ] && [ "$BRANCH" != "N/A" ]; then
  echo "   ✅ Custom mappers working correctly"
  echo "   ✅ CIF and Branch claims present in token"
else
  echo "   ⚠️  Custom mappers may not be configured"
  echo "   ⚠️  Missing CIF or Branch claims"
fi

echo ""
echo "🔗 Token Endpoint:"
echo "   $KEYCLOAK_URL/auth/realms/$REALM_NAME/protocol/openid-connect/token"
