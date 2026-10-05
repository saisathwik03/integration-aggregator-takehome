#!/usr/bin/env bash

set -euo pipefail

BASE_URL="http://127.0.0.1:8000"

echo "Checking application health..."

curl --fail --silent \
  "$BASE_URL/health"

echo

echo "Registering GitHub test provider..."

GITHUB_REGISTER_RESPONSE=$(
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

echo "$GITHUB_REGISTER_RESPONSE"

echo "$GITHUB_REGISTER_RESPONSE" \
  | grep -q '"status":"registered"'

echo "Checking GitHub OAuth connect flow..."

GITHUB_CONNECT_RESPONSE=$(
  curl --fail --silent \
    -X POST \
    "$BASE_URL/providers/ci-provider/users/ci-user/connect"
)

echo "$GITHUB_CONNECT_RESPONSE"

echo "$GITHUB_CONNECT_RESPONSE" \
  | grep -q '"authorization_url"'

echo "$GITHUB_CONNECT_RESPONSE" \
  | grep -q '"state"'

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

echo "Registering local OIDC provider..."

OIDC_REGISTER_RESPONSE=$(
  curl --fail --silent \
    -X POST "$BASE_URL/providers" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "ci-oidc",
      "provider": "oidc",
      "client_id": "ci-client-id",
      "client_secret": "ci-client-secret",
      "provider_options": {
        "issuer_url": "http://host.minikube.internal:8080/default"
      }
    }'
)

echo "$OIDC_REGISTER_RESPONSE"

echo "$OIDC_REGISTER_RESPONSE" \
  | grep -q '"status":"registered"'

echo "Starting local OIDC authorization flow..."

OIDC_CONNECT_RESPONSE=$(
  curl --fail --silent \
    -X POST \
    "$BASE_URL/providers/ci-oidc/users/ci-user/connect"
)

echo "$OIDC_CONNECT_RESPONSE"

echo "$OIDC_CONNECT_RESPONSE" \
  | grep -q '"authorization_url"'

OIDC_AUTH_URL=$(
  echo "$OIDC_CONNECT_RESPONSE" \
    | sed -n 's/.*"authorization_url":"\([^"]*\)".*/\1/p'
)

if [ -z "$OIDC_AUTH_URL" ]; then
  echo "OIDC authorization URL was not returned"
  exit 1
fi

echo "OIDC authorization URL received."

echo "Running programmatic OIDC consent..."

curl --fail \
  --silent \
  --show-error \
  --location \
  --data-urlencode "username=ci-user" \
  --data-urlencode 'claims={}' \
  --output /tmp/oidc-callback-response.html \
  "$OIDC_AUTH_URL"

echo "OIDC authorization flow completed."

echo "Checking asynchronous token retrieval..."

TOKEN_RESPONSE=$(
  curl --fail --silent \
    -D /tmp/token-headers.txt \
    "$BASE_URL/ci-oidc/ci-user"
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

echo "Polling token request..."

for i in {1..10}; do
  REQUEST_STATUS=$(
    curl --fail --silent \
      "$BASE_URL/requests/$REQUEST_ID"
  )

  echo "$REQUEST_STATUS"

  if echo "$REQUEST_STATUS" | grep -q '"status":"completed"'; then
    echo "Token retrieval completed."
    break
  fi

  if echo "$REQUEST_STATUS" | grep -q '"status":"failed"'; then
    echo "Token retrieval failed."
    exit 1
  fi

  sleep 1
done

echo "$REQUEST_STATUS" \
  | grep -q '"status":"completed"'

echo "Local OIDC end-to-end flow passed."

echo "Checking unknown async request..."

UNKNOWN_STATUS=$(
  curl --silent \
    -o /tmp/unknown-request.json \
    -w "%{http_code}" \
    "$BASE_URL/requests/does-not-exist"
)

if [ "$UNKNOWN_STATUS" != "404" ]; then
  echo "Expected unknown request HTTP 404, got $UNKNOWN_STATUS"
  exit 1
fi

echo "Unknown request check passed."

echo "E2E smoke test passed."