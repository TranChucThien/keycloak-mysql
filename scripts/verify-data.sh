#!/bin/bash

set -e

KEYCLOAK_URL="http://192.168.10.142:30080/auth"
REALM_NAME="test-realm"
CLIENT_ID="test-client"

echo "🔍 Verify data..."

# Get admin token
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin_password" | jq -r '.access_token')

# Check realm
REALM_CHECK=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
echo "Realm: $(echo "$REALM_CHECK" | jq -e '.realm' > /dev/null 2>&1 && echo "✅" || echo "❌")"

# Check users
USER_COUNT=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '. | length')
echo "Users: $([ "$USER_COUNT" -gt 0 ] && echo "✅ ($USER_COUNT users)" || echo "❌")"

# Check sample user
USER_CHECK=$(curl -s -X GET "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users?username=customer1" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
CIF_ATTR=$(echo "$USER_CHECK" | jq -r '.[0].attributes.cif[0] // "missing"')
BRANCH_ATTR=$(echo "$USER_CHECK" | jq -r '.[0].attributes.branch[0] // "missing"')
echo "Sample User: customer1 (CIF: $CIF_ATTR, Branch: $BRANCH_ATTR)"

# Test login
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM_NAME/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "username=customer1" \
  -d "password=test123")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // "null"')
echo "Login: $([ "$ACCESS_TOKEN" != "null" ] && echo "✅" || echo "❌")"

# Check claims in token
if [ "$ACCESS_TOKEN" != "null" ]; then
  PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d. -f2)
  # Add padding for base64 decode
  while [ $((${#PAYLOAD} % 4)) -ne 0 ]; do
    PAYLOAD="${PAYLOAD}="
  done
  CLAIMS=$(echo "$PAYLOAD" | base64 -d 2>/dev/null | jq . 2>/dev/null || echo "{}")
  CIF_CLAIM=$(echo "$CLAIMS" | jq -r 'if (.cif | type) == "array" then .cif[0] else .cif end // "missing"')
  BRANCH_CLAIM=$(echo "$CLAIMS" | jq -r '.branch // "missing"')
  echo "Claims: CIF=$([ "$CIF_CLAIM" != "missing" ] && echo "✅" || echo "❌") Branch=$([ "$BRANCH_CLAIM" != "missing" ] && echo "✅" || echo "❌")"
fi

echo "✅ Verify completed!"