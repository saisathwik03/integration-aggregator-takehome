# Real GitHub OAuth Flow Transcript

This transcript records a successful local OAuth flow against the real GitHub OAuth service. Secrets, authorization codes, access tokens, and other sensitive values are intentionally redacted.

## 1. Register GitHub provider

POST /providers

{ "name": "github-real", "provider": "github", "client_id": "<REDACTED>" }

Response:

{ "provider": "github-real", "status": "registered" }

## 2. Start GitHub OAuth flow

POST /providers/github-real/users/ci-user/connect

Response:

{ "authorization_url": "https://github.com/login/oauth/authorize?...", "state": "<REDACTED>" }

The authorization URL was opened in a browser and the GitHub OAuth application was authorized.
## 3. GitHub callback

GET /callback?code=<REDACTED>&state=<REDACTED>

Response:

{ "provider": "github-real", "user": "ci-user", "status": "connected" }

## 4. Request asynchronous credential retrieval

GET /github-real/ci-user

HTTP/1.1 202 Accepted
Location: /requests/<REQUEST_ID>

{ "request_id": "<REQUEST_ID>", "status": "pending" }

## 5. Poll asynchronous request

GET /requests/<REQUEST_ID>

Response:

{ "status": "completed", "result": { "data": { "access_token": "<REDACTED>", "server": "github-real", "type": "Bearer" } }, "error": null }

The credential was retrieved asynchronously from OpenBao.

## Result

The real GitHub authorization-code flow completed successfully:

GitHub authorization -> application callback -> OpenBao authorization-code exchange -> credential storage -> asynchronous retrieval -> completed request.
