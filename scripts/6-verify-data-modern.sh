#!/bin/bash

# Verify script for Keycloak 18+ (Quarkus) without /auth prefix
# Usage: ./verify-data-modern.sh [KEYCLOAK_URL]

KEYCLOAK_URL="${1:-http://192.168.10.142:30080}"
REALM_NAME="test-realm"
CLIENT_ID="test-client"

echo "🔍 Verify data for Keycloak Modern (KC18+)..."
echo "   URL: $KEYCLOAK_URL"
echo ""

# Get admin token
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin_password" | jq -r '.access_token // empty')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Failed to get admin token"
  exit 1
fi

# Check realm
echo "📝 Checking realm..."
REALM_CHECK=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
REALM_EXISTS=$(echo "$REALM_CHECK" | jq -e '.realm' > /dev/null 2>&1 && echo "✅" || echo "❌")
echo "   Realm '$REALM_NAME': $REALM_EXISTS"

# Check users
echo "📝 Checking users..."
USER_COUNT=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '. | length')
echo "   Total users: $USER_COUNT $([ "$USER_COUNT" -gt 0 ] && echo "✅" || echo "❌")"

# Check sample user
echo "📝 Checking sample user (customer1)..."
USER_CHECK=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users?username=customer1" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
CIF_ATTR=$(echo "$USER_CHECK" | jq -r '.[0].attributes.cif[0] // "missing"')
BRANCH_ATTR=$(echo "$USER_CHECK" | jq -r '.[0].attributes.branch[0] // "missing"')
echo "   CIF: $CIF_ATTR $([ "$CIF_ATTR" != "missing" ] && echo "✅" || echo "❌")"
echo "   Branch: $BRANCH_ATTR $([ "$BRANCH_ATTR" != "missing" ] && echo "✅" || echo "❌")"

# Test login
echo "📝 Testing login..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM_NAME/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "username=customer1" \
  -d "password=test123")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // "null"')
if [ "$ACCESS_TOKEN" = "null" ]; then
  echo "   Login: ❌ Failed"
  echo "   Response: $TOKEN_RESPONSE"
else
  echo "   Login: ✅ Success"
  
  # Check claims in token
  echo "📝 Checking token claims..."
  PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d. -f2)
  # Add padding for base64 decode
  while [ $((${#PAYLOAD} % 4)) -ne 0 ]; do
    PAYLOAD="${PAYLOAD}="
  done
  CLAIMS=$(echo "$PAYLOAD" | base64 -d 2>/dev/null | jq . 2>/dev/null || echo "{}")
  
  CIF_CLAIM=$(echo "$CLAIMS" | jq -r 'if (.cif | type) == "array" then .cif[0] else .cif end // "missing"')
  BRANCH_CLAIM=$(echo "$CLAIMS" | jq -r 'if (.branch | type) == "array" then .branch[0] else .branch end // "missing"')
  
  echo "   CIF claim: $CIF_CLAIM $([ "$CIF_CLAIM" != "missing" ] && echo "✅" || echo "❌")"
  echo "   Branch claim: $BRANCH_CLAIM $([ "$BRANCH_CLAIM" != "missing" ] && echo "✅" || echo "❌")"
fi

echo ""
echo "✅ Verification completed!"
echo ""
echo "🔗 Access URLs:"
echo "   Admin Console: $KEYCLOAK_URL/admin"
echo "   Realm: $KEYCLOAK_URL/realms/$REALM_NAME"
