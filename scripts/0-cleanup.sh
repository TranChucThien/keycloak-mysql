#!/bin/bash

# Cleanup test-realm
# Usage: ./0-cleanup.sh [KEYCLOAK_URL] [legacy|modern]

KEYCLOAK_URL="${1:-http://192.168.10.142:30080}"
MODE="${2:-modern}"
REALM_NAME="test-realm"

if [ "$MODE" = "legacy" ]; then
  AUTH_PREFIX="/auth"
else
  AUTH_PREFIX=""
fi

echo "🗑️  Cleaning up test-realm..."
echo "   URL: $KEYCLOAK_URL"
echo "   Mode: $MODE"

# Get admin token
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL${AUTH_PREFIX}/realms/master/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin_password" | jq -r '.access_token // empty')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Failed to get admin token"
  exit 1
fi

# Delete realm
HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE "$KEYCLOAK_URL${AUTH_PREFIX}/admin/realms/$REALM_NAME" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if [ "$HTTP_CODE" = "204" ]; then
  echo "✅ Realm '$REALM_NAME' deleted successfully"
elif [ "$HTTP_CODE" = "404" ]; then
  echo "⚠️  Realm '$REALM_NAME' not found (already deleted)"
else
  echo "❌ Failed to delete realm (HTTP $HTTP_CODE)"
  exit 1
fi
