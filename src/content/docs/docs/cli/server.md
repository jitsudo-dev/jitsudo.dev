---
title: jitsudo server
description: Control plane management commands for bootstrapping and administering jitsudod.
---

Control plane management commands for bootstrapping and administering jitsudod.

## Synopsis

```
jitsudo server <subcommand> [flags]
```

## Subcommands

| Subcommand | Description |
|------------|-------------|
| [`init`](#init) | Bootstrap a new control plane instance |
| [`status`](#status) | Check control plane health |
| [`version`](#version) | Print server version and API compatibility |
| [`reload-policies`](#reload-policies) | Trigger the OPA engine to reload policies from the database |

## `init`

Bootstrap a new jitsudod control plane. Tests database connectivity, runs schema migrations, and writes a starter configuration file.

```
jitsudo server init --db-url <url> --oidc-issuer <url> --oidc-client-id <id> [flags]
```

**Flags:**

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--db-url <url>` | **Yes** | — | PostgreSQL connection URL |
| `--oidc-issuer <url>` | **Yes** | — | OIDC issuer URL for JWT validation |
| `--oidc-client-id <id>` | **Yes** | — | OIDC client ID registered for the server |
| `--http-addr <addr>` | No | `:8080` | HTTP (REST gateway) listen address |
| `--grpc-addr <addr>` | No | `:8443` | gRPC listen address |
| `--config-out <path>` | No | `jitsudo.yaml` | Path to write the generated config file |
| `--skip-migrations` | No | `false` | Skip database migrations (use if already migrated) |

**What `init` does:**

1. Connects to PostgreSQL and verifies connectivity.
2. Runs embedded `golang-migrate` migrations to create the schema.
3. Writes a minimal `jitsudo.yaml` config file with the supplied values.

**Example:**

```bash
jitsudo server init \
  --db-url "postgres://jitsudo:password@localhost:5432/jitsudo?sslmode=require" \
  --oidc-issuer https://your-org.okta.com \
  --oidc-client-id jitsudo-server \
  --config-out /etc/jitsudo/config.yaml
```

**Output:**

```
Connecting to database... OK
Running database migrations... OK

Configuration written to: /etc/jitsudo/config.yaml

Next steps:
  1. Edit /etc/jitsudo/config.yaml to enable providers and notifications
  2. Start the server: jitsudod --config /etc/jitsudo/config.yaml
  3. Log in from the CLI: jitsudo login --server localhost:8080
```

## `status`

Check the health of a running jitsudod instance by polling its health endpoints.

```
jitsudo server status [--server-url <url>]
```

**Flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `--server-url <url>` | `http://localhost:8080` | jitsudod HTTP base URL |

**Output:**

```
Component   Status   Detail
---------   ------   ------
liveness    UP       jitsudod is running
readiness   UP       database connection ok
version     UP       0.1.0 (API: v1alpha1)
```

**Exit code:** Non-zero if any health check fails.

## `version`

Print the server version and supported API versions.

```
jitsudo server version [--server-url <url>]
```

**Flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `--server-url <url>` | `http://localhost:8080` | jitsudod HTTP base URL |

**Output:**

```
Server version: 0.1.0
API version:    v1alpha1
```

## `reload-policies`

Trigger the embedded OPA policy engine to reload all enabled policies from the database. Use this after applying policy changes if you don't want to wait for the automatic reload interval.

```
jitsudo server reload-policies
```

**Output:**

```
Policy engine reloaded. Active policies: 3
```

This command uses the gRPC API and requires the caller to be authenticated.

## Global Flags

All `jitsudo server` subcommands accept these global flags:

| Flag | Default | Description |
|------|---------|-------------|
| `--server <url>` | Stored credentials | Control plane gRPC URL (for subcommands that use the API) |
| `--token <token>` | Stored credentials | Bearer token override |
| `-q, --quiet` | `false` | Suppress non-essential output |
| `--debug` | `false` | Enable debug logging |

## Related

- [Single-Server Deployment guide](/guides/deployment/single-server/) — using `server init` to bootstrap a production server
- [Server Configuration reference](/reference/configuration/) — full config file reference
