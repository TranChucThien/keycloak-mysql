#!/bin/bash

# Verify custom mappers are installed and registered in Keycloak
# Usage: ./verify-custom-mappers.sh [KEYCLOAK_URL] [POD_NAME]
KEYCLOAK_URL="${1:-http://192.168.10.142:30080}"
POD_NAME="${2}"  # Optional: for K8s deployments

echo "🔍 Verifying Custom Mappers Installation..."
echo "   URL: $KEYCLOAK_URL"
echo ""

# Check 1: Verify JAR file exists (K8s only)
if [ -n "$POD_NAME" ]; then
  echo "📦 Checking JAR file in pod: $POD_NAME"
  JAR_CHECK=$(kubectl exec "$POD_NAME" -- ls -lh /opt/keycloak/providers/*.jar 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo "✅ JAR file found:"
    echo "$JAR_CHECK"
  else
    echo "❌ No JAR file found in /opt/keycloak/providers/"
    echo "   Build and deploy: cd versions/kc{12,15,16}/mapper && mvn clean package"
  fi
  echo ""
fi

# Check 2: Verify mappers are registered via API
echo "🔌 Checking registered protocol mappers..."

# Get admin token
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin_password")

ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" = "null" ]; then
  echo "❌ Failed to get admin token"
  exit 1
fi

# Get server info to check available mappers
SERVER_INFO=$(curl -s -X GET "$KEYCLOAK_URL/auth/admin/serverinfo" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

# Check for custom mappers
CIF_MAPPER=$(echo "$SERVER_INFO" | jq -r '.protocolMapperTypes."openid-connect"[] | select(.id=="oidc-cif-property-mapper") | .id // empty')
BRANCH_MAPPER=$(echo "$SERVER_INFO" | jq -r '.protocolMapperTypes."openid-connect"[] | select(.id=="oidc-branch-property-mapper") | .id // empty')

if [ -n "$CIF_MAPPER" ]; then
  CIF_NAME=$(echo "$SERVER_INFO" | jq -r '.protocolMapperTypes."openid-connect"[] | select(.id=="oidc-cif-property-mapper") | .name')
  echo "✅ CIF Mapper registered: $CIF_MAPPER ($CIF_NAME)"
else
  echo "❌ CIF Mapper NOT registered (oidc-cif-property-mapper)"
fi

if [ -n "$BRANCH_MAPPER" ]; then
  BRANCH_NAME=$(echo "$SERVER_INFO" | jq -r '.protocolMapperTypes."openid-connect"[] | select(.id=="oidc-branch-property-mapper") | .name')
  echo "✅ Branch Mapper registered: $BRANCH_MAPPER ($BRANCH_NAME)"
else
  echo "❌ Branch Mapper NOT registered (oidc-branch-property-mapper)"
fi

echo ""

# Check 3: Verify mappers are configured in test-realm client
echo "🎯 Checking client configuration in test-realm..."

CLIENT_RESPONSE=$(curl -s -X GET "$KEYCLOAK_URL/auth/admin/realms/test-realm/clients?clientId=test-client" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

CLIENT_UUID=$(echo "$CLIENT_RESPONSE" | jq -r '.[0].id // empty')

if [ -z "$CLIENT_UUID" ] || [ "$CLIENT_UUID" = "null" ]; then
  echo "⚠️  test-realm/test-client not found. Run setup-data-legacy.sh first"
else
  MAPPERS=$(curl -s -X GET "$KEYCLOAK_URL/auth/admin/realms/test-realm/clients/$CLIENT_UUID/protocol-mappers/models" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
  
  CIF_CONFIGURED=$(echo "$MAPPERS" | jq -r '.[] | select(.name=="cif-mapper") | .name // empty')
  BRANCH_CONFIGURED=$(echo "$MAPPERS" | jq -r '.[] | select(.name=="branch-mapper") | .name // empty')
  
  if [ -n "$CIF_CONFIGURED" ]; then
    echo "✅ CIF Mapper configured: $CIF_CONFIGURED"
  else
    echo "❌ CIF Mapper NOT configured in client"
  fi
  
  if [ -n "$BRANCH_CONFIGURED" ]; then
    echo "✅ Branch Mapper configured: $BRANCH_CONFIGURED"
  else
    echo "❌ Branch Mapper NOT configured in client"
  fi
fi

echo ""

# Summary
if [ -n "$CIF_MAPPER" ] && [ -n "$BRANCH_MAPPER" ]; then
  echo "✅ All custom mappers are registered and working!"
  echo ""
  echo "🧪 Test token generation:"
  echo "   curl -X POST '$KEYCLOAK_URL/auth/realms/test-realm/protocol/openid-connect/token' \\"
  echo "     -d 'grant_type=password' \\"
  echo "     -d 'client_id=test-client' \\"
  echo "     -d 'username=customer1' \\"
  echo "     -d 'password=test123' | jq -r '.access_token' | cut -d. -f2 | base64 -d | jq"
else
  echo "❌ Custom mappers are NOT working properly"
  echo ""
  echo "🔧 Troubleshooting:"
  echo "   1. Check JAR file: kubectl exec <pod> -- ls /opt/keycloak/providers/"
  echo "   2. Check logs: kubectl logs <pod> | grep -i mapper"
  echo "   3. Rebuild image: cd versions/kc{12,15,16}/mapper && docker build -f Dockerfile.builtin ."
  echo "   4. Restart Keycloak after deploying JAR"
fi
