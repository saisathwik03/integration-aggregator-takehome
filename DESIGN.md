# Integration Aggregator Design

## Overview

The Integration Aggregator is a Python/FastAPI service that provides a common
API for OAuth provider registration, user authorization, and token retrieval.

The service deliberately does not implement OAuth token exchange or token
storage itself. OpenBao and its OAuth2 secrets plugin handle provider
credentials and OAuth tokens.

## Architecture

```text
                         +----------------------+
                         |       Client         |
                         +----------+-----------+
                                    |
                                    | HTTP
                                    v
                         +----------------------+
                         | FastAPI Application  |
                         |                      |
                         | /providers           |
                         | /connect             |
                         | /callback            |
                         | /{provider}/{user}   |
                         | /requests/{id}       |
                         +----+-------------+----+
                              |             |
                    OAuth     |             | Async worker
                    operations|             |
                              v             v
                     +-------------------------+
                     |        OpenBao          |
                     |                         |
                     | OAuth2 secrets engine   |
                     | oauthapp plugin         |
                     | provider configuration  |
                     | OAuth credentials/tokens|
                     +------------+------------+
                                  |
                                  | OAuth
                                  v
                         +----------------------+
                         |   OAuth Provider     |
                         |   GitHub / OIDC      |
                         +----------------------+

                    Kubernetes / Minikube
```

## Request Flow

### Provider Registration

1. Client sends provider name, provider type, client ID, and client secret.
2. FastAPI writes the provider configuration to OpenBao.
3. The client secret is not persisted by the application.

### User Connection

1. Client calls the provider/user connect endpoint.
2. The service generates a random OAuth state value.
3. The state is stored in application memory with the provider and user.
4. FastAPI asks OpenBao for the authorization URL.
5. The client redirects the user to the OAuth provider.
6. The OAuth callback validates the state.
7. The authorization code is passed to the OpenBao OAuth2 plugin.
8. The plugin performs the OAuth exchange and stores the resulting credential.

### Token Retrieval

1. Client requests a token through `/{provider}/{user}`.
2. The service immediately creates an asynchronous request record.
3. HTTP `202 Accepted` and a request ID are returned.
4. A background worker reads the credential from OpenBao.
5. The result is stored in in-memory request state.
6. The client polls `/requests/{id}` for completion.

The token retrieval endpoint intentionally does not block on OpenBao.

## Data Placement

| Data | Location |
|---|---|
| Provider client secrets | OpenBao |
| OAuth tokens | OpenBao |
| Provider names | Application memory |
| OAuth state | Application memory |
| Async request status | Application memory |
| Async request result | Application memory |
| Persistent application database | None |
| Application filesystem storage | None |

The application does not implement its own OAuth token refresh or token cache.
Those responsibilities remain with the OpenBao OAuth2 plugin.

## Kubernetes Deployment

The application is packaged as a Helm chart.

The deployment contains:

- FastAPI application
- ClusterIP service
- Kubernetes health probes
- Configurable CPU and memory resources
- OpenBao service address
- OpenBao authentication token supplied through Kubernetes configuration

OpenBao is installed using its Helm chart with the OAuth2 plugin installed by
an init container.

The OpenBao plugin binary is downloaded from the official release and verified
using its SHA-256 checksum before being installed into the plugin directory.

## Security

Secrets and OAuth tokens are stored in OpenBao rather than application
memory or files.

The repository excludes environment files, private keys, credentials, and
plugin archives.

OAuth state values are randomly generated and are deleted after successful
validation.

The Docker image runs the application as a non-root user.

The CI workflow does not commit secrets. GitHub's `GITHUB_TOKEN` is used for
GHCR publishing.

## Multi-Replica Limitation

The current service stores OAuth state and asynchronous request state in
process memory.

With multiple application replicas, a request could be handled by one
replica while the callback or polling request reaches another replica. That
would cause the second replica to be unable to find the OAuth state or async
request.

The current design therefore intentionally uses a single application replica.

### Production Fix

For multiple replicas, the in-memory state would be moved to a shared
durable store such as Redis.

The architecture would then become:

```text
FastAPI replicas
      |
      +---- Redis
      |
      +---- OpenBao
```

OAuth state and async request state would be stored in Redis with appropriate
expiration. A distributed work queue could also be introduced for background
token retrieval.

OpenBao would remain the authoritative store for OAuth credentials and
tokens.

## OpenBao Development Mode

The local/CI environment uses OpenBao development mode for simplicity.

Development mode uses in-memory storage and is not intended for production
persistence. A production deployment should use persistent storage,
appropriate initialization/unseal procedures, TLS, access policies, and
properly managed authentication credentials.

## Testing and CI

GitHub Actions performs:

1. Python unit tests.
2. Minikube startup.
3. OpenBao and OAuth plugin deployment.
4. Local OIDC provider startup using `navikt/mock-oauth2-server`.
5. Helm application deployment.
6. End-to-end OAuth/API smoke tests.
7. k6 performance testing at three concurrent virtual users.
8. Docker image publishing to GHCR.
9. Helm chart publishing to GHCR.

The CI end-to-end test registers the local OIDC provider through the same
`POST /providers` API used by other OAuth providers. The OIDC issuer is exposed
through OpenID Connect discovery, and the test exercises the authorization-code
flow before verifying asynchronous credential retrieval from OpenBao.

The performance test measures the asynchronous token-request submission
endpoint and reports p50, p95, throughput, and request failures.
