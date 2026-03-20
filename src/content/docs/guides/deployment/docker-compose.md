---
title: Docker Compose (Local Development)
description: Run jitsudo locally using Docker Compose with a mock OIDC provider.
---

The fastest way to run jitsudo is with Docker Compose. The provided compose file starts jitsudod, PostgreSQL, and dex (a mock OIDC provider) so you can exercise the full workflow without any cloud credentials.

This setup is for local development and testing. For production deployment see [Kubernetes (Helm)](/guides/deployment/kubernetes/) or [Single-Server](/guides/deployment/single-server/).

## Prerequisites

- Docker (or Podman) with Compose support
- The `jitsudo` CLI — see [Installation](/docs/installation/)

## Services

The compose stack at `deploy/docker-compose.yaml` starts three services:

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `postgres` | `postgres:16-alpine` | `5432` | PostgreSQL database |
| `dex` | `ghcr.io/dexidp/dex:v2.41.1` | `5556` | Mock OIDC provider |
| `jitsudod` | Built from repo | `8080` (HTTP), `8443` (gRPC) | Control plane |

## Quick Start

Clone the repo and start the stack:

```bash
git clone https://github.com/jitsudo-dev/jitsudo.git
cd jitsudo

# Start only the dependencies (recommended — run jitsudod on the host)
docker compose -f deploy/docker-compose.yaml up postgres dex -d

# Run jitsudod on the host (avoids OIDC issuer URL mismatch)
go run ./cmd/jitsudod
```

:::tip[Why run jitsudod on the host?]
dex issues tokens with `iss=http://localhost:5556/dex`. When jitsudod runs inside Docker it cannot resolve `localhost:5556`, causing token validation to fail. Running jitsudod on the host avoids this mismatch. If you need the full Docker stack, update `JITSUDOD_OIDC_ISSUER` in the compose file to use a hostname reachable from inside the container (e.g. `host.docker.internal`).
:::

Alternatively, start the full stack (jitsudod included):

```bash
docker compose -f deploy/docker-compose.yaml up -d
```

## Log In

```bash
# Point the CLI at the local dex OIDC issuer
jitsudo login \
  --provider http://localhost:5556/dex \
  --server http://localhost:8080
```

dex's default static user credentials are:

| Field | Value |
|-------|-------|
| Email | `admin@example.com` |
| Password | `password` |

## Submit a Request

The mock provider is registered by default in the local environment:

```bash
jitsudo request \
  --provider mock \
  --role admin \
  --scope test \
  --duration 1h \
  --reason "Testing the local dev environment"
```

## Approve and Execute

```bash
# In another terminal (or the same), approve the request
jitsudo approve <request-id>

# Execute a command with the mock credentials
jitsudo exec <request-id> -- env | grep MOCK_
```

## Useful Make Targets

The repo Makefile provides convenience targets:

```bash
make docker-up    # Start all services (full Docker stack)
make docker-down  # Stop all services and remove containers
make docker-logs  # Tail logs from all services
make dev-deps     # Start only postgres + dex (use with make dev-server)
make dev-server   # Run jitsudod on the host
```

## Environment Variables

The compose file sets these environment variables for jitsudod:

| Variable | Value |
|----------|-------|
| `JITSUDOD_HTTP_ADDR` | `:8080` |
| `JITSUDOD_GRPC_ADDR` | `:8443` |
| `JITSUDOD_DATABASE_URL` | `postgres://jitsudo:jitsudo@postgres:5432/jitsudo?sslmode=disable` |
| `JITSUDOD_OIDC_ISSUER` | `http://dex:5556/dex` |
| `JITSUDOD_OIDC_CLIENT_ID` | `jitsudo-server` |

## Stopping

```bash
docker compose -f deploy/docker-compose.yaml down
# To also remove the postgres volume:
docker compose -f deploy/docker-compose.yaml down -v
```
