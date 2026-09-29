#!/usr/bin/env bash

set -euo pipefail

BASE_URL="http://127.0.0.1:8000"

echo "Checking application health..."
curl --fail --silent "$BASE_URL/health"

echo
echo "Registering test OAuth provider..."

REGISTER_RESPONSE=$(
  curl --fail --silent \
    -X POST "$BASE_URL/providers" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "ci-provider",
      "provider": "github",
      "client_id": "ci-client-id",
      "client_secret": "ci-client-secret"
    }'
)

echo "$REGISTER_RESPONSE"

echo "$REGISTER_RESPONSE" | grep -q '"status":"registered"'

echo "Checking OAuth connect flow..."

CONNECT_RESPONSE=$(
  curl --fail --silent \
    -X POST \
    "$BASE_URL/providers/ci-provider/users/ci-user/connect"
)

echo "$CONNECT_RESPONSE"

echo "$CONNECT_RESPONSE" | grep -q '"authorization_url"'
echo "$CONNECT_RESPONSE" | grep -q '"state"'

echo "Checking invalid OAuth state..."

CALLBACK_STATUS=$(
  curl --silent \
    -o /tmp/callback-response.json \
    -w "%{http_code}" \
    "$BASE_URL/callback?code=fake-code&state=invalid-state"
)

if [ "$CALLBACK_STATUS" != "400" ]; then
  echo "Expected callback HTTP 400, got $CALLBACK_STATUS"
  exit 1
fi

echo "Checking asynchronous token retrieval..."

TOKEN_RESPONSE=$(
  curl --fail --silent \
    -D /tmp/token-headers.txt \
    "$BASE_URL/ci-provider/ci-user"
)

echo "$TOKEN_RESPONSE"

REQUEST_ID=$(
  echo "$TOKEN_RESPONSE" \
    | sed -n 's/.*"request_id":"\([^"]*\)".*/\1/p'
)

if [ -z "$REQUEST_ID" ]; then
  echo "Request ID was not returned"
  exit 1
fi

echo "Request ID: $REQUEST_ID"

echo "Checking request status..."

sleep 2

REQUEST_STATUS=$(
  curl --fail --silent \
    "$BASE_URL/requests/$REQUEST_ID"
)

echo "$REQUEST_STATUS"

echo "$REQUEST_STATUS" | grep -q '"status":"failed"'
echo "$REQUEST_STATUS" | grep -q '"error":"Credential not found"'

echo "E2E smoke test passed."