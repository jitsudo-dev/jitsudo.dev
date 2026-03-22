---
title: Server Configuration
description: Complete reference for all jitsudod configuration file fields and environment variable overrides.
---

jitsudod is configured via an optional YAML file and `JITSUDOD_*` environment variables. Environment variables always take precedence over the config file, making them suitable for Kubernetes Secrets and twelve-factor deployments.

## Loading Configuration

```bash
# Pass the config file path as a flag
jitsudod --config /etc/jitsudo/config.yaml

# Or via environment variable
JITSUDOD_CONFIG=/etc/jitsudo/config.yaml jitsudod

# Environment-only (no config file required)
JITSUDOD_DATABASE_URL=postgres://... jitsudod
```

## Full Reference

### `server`

Network listener addresses for the two APIs.

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| HTTP address | `server.http_addr` | `JITSUDOD_HTTP_ADDR` | `:8080` | REST gateway (grpc-gateway) listen address |
| gRPC address | `server.grpc_addr` | `JITSUDOD_GRPC_ADDR` | `:8443` | Native gRPC API listen address |

```yaml
server:
  http_addr: ":8080"
  grpc_addr: ":8443"
```

---

### `database`

PostgreSQL connection settings. jitsudo requires PostgreSQL — SQLite is not supported.

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| Connection URL | `database.url` | `JITSUDOD_DATABASE_URL` | Local dev default | PostgreSQL DSN (`postgres://user:pass@host:port/db?sslmode=require`) |

```yaml
database:
  url: "postgres://jitsudo:password@localhost:5432/jitsudo?sslmode=require"
```

:::tip
Supply the password via `JITSUDOD_DATABASE_URL` or a Kubernetes Secret rather than storing it in the config file.
:::

---

### `auth`

OIDC token validation settings.

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| OIDC issuer | `auth.oidc_issuer` | `JITSUDOD_OIDC_ISSUER` | `http://localhost:5556/dex` | Must match the `iss` claim in tokens issued by your IdP |
| Client ID | `auth.client_id` | `JITSUDOD_OIDC_CLIENT_ID` | `jitsudo-cli` | OIDC client ID registered with your IdP for the server |

```yaml
auth:
  oidc_issuer: "https://your-idp.example.com"
  client_id: "jitsudo-server"
```

**Token validation flow:** jitsudod fetches JWKS from `{oidc_issuer}/.well-known/openid-configuration`, verifies the JWT signature, and validates `iss`, `aud`, and `exp` claims.

---

### `tls`

TLS configuration for the gRPC listener.

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| Certificate file | `tls.cert_file` | `JITSUDOD_TLS_CERT_FILE` | `""` | Path to PEM-encoded TLS certificate |
| Key file | `tls.key_file` | `JITSUDOD_TLS_KEY_FILE` | `""` | Path to PEM-encoded TLS private key |
| CA file | `tls.ca_file` | `JITSUDOD_TLS_CA_FILE` | `""` | Path to CA certificate; non-empty enables mTLS |

**TLS modes:**

| `cert_file` | `key_file` | `ca_file` | Mode |
|------------|----------|---------|------|
| empty | empty | empty | Insecure (local development only) |
| set | set | empty | Server-only TLS |
| set | set | set | Mutual TLS (mTLS) |

```yaml
tls:
  cert_file: "/etc/jitsudo/tls.crt"
  key_file:  "/etc/jitsudo/tls.key"
  ca_file:   ""  # set to enable mTLS
```

---

### `providers`

Each provider is optional. Omit or comment out sections you don't use. A nil provider section means the provider is not registered at startup.

#### `providers.aws`

| Field | YAML key | Default | Description |
|-------|----------|---------|-------------|
| Mode | `providers.aws.mode` | `sts_assume_role` | `sts_assume_role` or `identity_center` |
| Region | `providers.aws.region` | `us-east-1` | Primary AWS region |
| Role ARN template | `providers.aws.role_arn_template` | — | ARN template with `{scope}` and `{role}` variables |
| Max duration | `providers.aws.max_duration` | no cap | Maximum elevation window (STS hard max: 12h) |
| Identity Center instance ARN | `providers.aws.identity_center_instance_arn` | — | Required for `identity_center` mode |
| Identity Center store ID | `providers.aws.identity_center_store_id` | — | Required for `identity_center` mode |
| Endpoint URL | `providers.aws.endpoint_url` | `""` | Override AWS endpoint (LocalStack testing only) |

```yaml
providers:
  aws:
    mode: "sts_assume_role"
    region: "us-east-1"
    role_arn_template: "arn:aws:iam::{scope}:role/jitsudo-{role}"
    max_duration: "4h"
```

#### `providers.gcp`

| Field | YAML key | Default | Description |
|-------|----------|---------|-------------|
| Organization ID | `providers.gcp.organization_id` | — | GCP organization ID (numeric string) |
| Credentials source | `providers.gcp.credentials_source` | `application_default` | `workload_identity_federation`, `application_default`, or `service_account_key` |
| Max duration | `providers.gcp.max_duration` | no cap | Maximum elevation window |
| Condition title prefix | `providers.gcp.condition_title_prefix` | `jitsudo` | Prefix for IAM condition titles |

```yaml
providers:
  gcp:
    organization_id: "123456789012"
    credentials_source: "workload_identity_federation"
    max_duration: "8h"
    condition_title_prefix: "jitsudo"
```

#### `providers.azure`

| Field | YAML key | Default | Description |
|-------|----------|---------|-------------|
| Tenant ID | `providers.azure.tenant_id` | — | Entra ID (Azure AD) tenant ID |
| Default subscription ID | `providers.azure.default_subscription_id` | — | Fallback subscription for requests without a scope |
| Client ID | `providers.azure.client_id` | — | Service principal or managed identity client ID |
| Credentials source | `providers.azure.credentials_source` | `workload_identity` | `workload_identity` or `client_secret` |
| Max duration | `providers.azure.max_duration` | no cap | Maximum elevation window |

```yaml
providers:
  azure:
    tenant_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    default_subscription_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    client_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    credentials_source: "workload_identity"
    max_duration: "4h"
```

#### `providers.kubernetes`

| Field | YAML key | Default | Description |
|-------|----------|---------|-------------|
| Kubeconfig path | `providers.kubernetes.kubeconfig` | `""` (in-cluster) | Path to kubeconfig; empty uses in-cluster service account |
| Default namespace | `providers.kubernetes.default_namespace` | `""` | Default namespace for RoleBindings |
| Max duration | `providers.kubernetes.max_duration` | no cap | Maximum elevation window |
| Managed label | `providers.kubernetes.managed_label` | `jitsudo.dev/managed` | Label applied to all managed bindings |

```yaml
providers:
  kubernetes:
    kubeconfig: ""
    default_namespace: "default"
    max_duration: "1h"
    managed_label: "jitsudo.dev/managed"
```

---

### `notifications`

#### `notifications.slack`

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| Webhook URL | `notifications.slack.webhook_url` | `JITSUDOD_SLACK_WEBHOOK_URL` | — | Slack incoming webhook URL |
| Channel | `notifications.slack.channel` | — | `""` | Override the webhook's default channel |
| Break-glass mention | `notifications.slack.mention_on_break_glass` | — | `""` | Prepended to break-glass alerts (e.g. `<!channel>`) |

```yaml
notifications:
  slack:
    webhook_url: "https://hooks.slack.com/services/..."
    channel: "#sre-access-requests"
    mention_on_break_glass: "<!channel>"
```

#### `notifications.smtp`

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| Host | `notifications.smtp.host` | `JITSUDOD_SMTP_HOST` | — | SMTP server hostname |
| Port | `notifications.smtp.port` | — | `587` | SMTP port (587=STARTTLS, 465=TLS) |
| Username | `notifications.smtp.username` | — | — | SMTP auth username |
| Password | `notifications.smtp.password` | `JITSUDOD_SMTP_PASSWORD` | — | SMTP auth password |
| From | `notifications.smtp.from` | — | — | Sender email address |
| To | `notifications.smtp.to` | — | — | List of recipient email addresses |

```yaml
notifications:
  smtp:
    host: "smtp.example.com"
    port: 587
    username: "jitsudo@example.com"
    password: ""    # supply via JITSUDOD_SMTP_PASSWORD
    from: "jitsudo@example.com"
    to:
      - "sre-team@example.com"
      - "security@example.com"
```

#### `notifications.webhooks`

A list of generic outbound webhooks. Each entry POSTs a structured JSON payload to the configured URL whenever an event occurs. Multiple entries are supported — each is an independent notifier.

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| URL | `notifications.webhooks[].url` | `JITSUDOD_WEBHOOK_URL`* | — | HTTP(S) endpoint to POST to |
| Headers | `notifications.webhooks[].headers` | — | `{}` | Custom HTTP headers added to every request (e.g. `Authorization`) |
| Secret | `notifications.webhooks[].secret` | — | `""` | HMAC-SHA256 signing key. When set, a `X-Jitsudo-Signature-256: sha256=<hex>` header is included so receivers can verify authenticity |
| Events | `notifications.webhooks[].events` | — | `[]` (all) | Allowlist of event types to forward. Empty means all events are forwarded |

\* `JITSUDOD_WEBHOOK_URL` injects a single no-auth, no-filter webhook entry when no `webhooks:` block is defined in the YAML config. Useful for simple Docker / Kubernetes Secret deployments.

**Payload fields**

Each POST body is a JSON object:

```json
{
  "type": "approved",
  "request_id": "01JF4...",
  "actor": "approver@example.com",
  "provider": "aws",
  "role": "ReadOnly",
  "scope": "123456789012",
  "reason": "incident investigation",
  "expires_at": "2025-01-15T18:00:00Z",
  "timestamp": "2025-01-15T17:00:00Z"
}
```

`expires_at` is omitted when not applicable. `timestamp` is the UTC time the event was dispatched.

**Event types:** `request_created`, `approved`, `auto_approved`, `ai_approved`, `ai_denied`, `ai_escalated`, `denied`, `expired`, `revoked`, `break_glass`.

**Signature verification example (Go):**

```go
mac := hmac.New(sha256.New, []byte(secret))
mac.Write(body)
expected := "sha256=" + hex.EncodeToString(mac.Sum(nil))
ok := hmac.Equal([]byte(r.Header.Get("X-Jitsudo-Signature-256")), []byte(expected))
```

```yaml
notifications:
  webhooks:
    - url: "https://hooks.example.com/jitsudo"
      secret: ""          # supply via a mounted secret; leave empty to skip signing
      events: []          # empty = all events
      headers:
        Authorization: "Bearer <token>"
    - url: "https://other.example.com/hook"
      events: ["break_glass", "approved"]
```

#### `notifications.siem`

Real-time SIEM integration. Events are forwarded as they occur, independent of the audit log. The `siem` block has two optional sub-sections; configure either or both.

##### `notifications.siem.json`

POSTs each event as a self-contained JSON document to an HTTP ingest endpoint (Splunk HEC, Elasticsearch, Datadog Logs, or any compatible receiver). Richer than the generic webhook: includes a `source`, `schema_version`, and a per-event UUID (`event_id`) for deduplication.

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| URL | `notifications.siem.json.url` | `JITSUDOD_SIEM_JSON_URL` | — | HTTP(S) ingest endpoint |
| Headers | `notifications.siem.json.headers` | — | `{}` | Custom HTTP headers (e.g. `Authorization: Bearer <token>`) |
| Events | `notifications.siem.json.events` | — | `[]` (all) | Allowlist of event types to forward. Empty means all events |

**Payload fields** (superset of the generic webhook payload):

```json
{
  "source": "jitsudo",
  "schema_version": "1",
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "type": "approved",
  "request_id": "01JF4...",
  "actor": "approver@example.com",
  "provider": "aws",
  "role": "ReadOnly",
  "scope": "123456789012",
  "reason": "incident investigation",
  "expires_at": "2025-01-15T18:00:00Z",
  "timestamp": "2025-01-15T17:00:00Z"
}
```

`event_id` is a UUID v4 generated per-event and is unique across all deliveries, making it safe to use as a deduplication key in idempotent SIEM ingest pipelines. `expires_at` is omitted when not applicable.

##### `notifications.siem.syslog`

Forwards events via the syslog protocol to a remote syslog server or the local Unix socket. Messages use a structured `key=value` format parseable by any SIEM that consumes syslog (rsyslog, syslog-ng, Splunk Universal Forwarder, etc.).

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| Network | `notifications.siem.syslog.network` | — | `""` | `"tcp"`, `"udp"`, or `""` for the local Unix socket |
| Address | `notifications.siem.syslog.address` | `JITSUDOD_SIEM_SYSLOG_ADDRESS` | `""` | `"host:port"` for a remote server; empty uses the OS default local socket |
| Tag | `notifications.siem.syslog.tag` | — | `"jitsudo"` | Syslog process identifier |
| Facility | `notifications.siem.syslog.facility` | — | `"auth"` | Syslog facility: `"auth"`, `"daemon"`, or `"local0"`–`"local7"` |

**Severity mapping:**

| Event type | Syslog severity |
|-----------|----------------|
| `break_glass` | `WARNING` |
| `denied`, `ai_denied` | `NOTICE` |
| All others | `INFO` |

**Message format** (structured `key=value`, space-separated):

```
type=approved request_id=01JF4... actor=alice@example.com provider=aws role=ReadOnly scope=123456789012 reason="incident investigation" expires_at=2025-01-15T18:00:00Z
```

:::note
`log/syslog` is not available on Windows. The syslog notifier is a no-op on Windows builds; use the JSON notifier for cross-platform deployments.
:::

```yaml
notifications:
  siem:
    json:
      url: "https://siem.example.com/api/v1/ingest"
      events: []         # empty = all events
      headers:
        Authorization: "Bearer <token>"
    syslog:
      network: "tcp"
      address: "syslog.example.com:514"
      tag: "jitsudo"
      facility: "auth"
```

---

### `mcp`

Configuration for the MCP approver endpoint (`POST /mcp`). The endpoint is disabled when `token` is empty.

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| Token | `mcp.token` | `JITSUDOD_MCP_TOKEN` | `""` | Bearer token AI agents must present. Empty = endpoint returns 404 (disabled). Generate with `openssl rand -hex 32`. |
| Agent identity | `mcp.agent_identity` | `JITSUDOD_MCP_AGENT_IDENTITY` | `"mcp-agent"` | Name recorded in the audit log for every AI approval decision. Use a descriptive name per deployment. |

```yaml
mcp:
  token: ""           # supply via JITSUDOD_MCP_TOKEN — never commit this value
  agent_identity: "claude-approver-prod"
```

:::tip
Always supply `mcp.token` via the `JITSUDOD_MCP_TOKEN` environment variable or a Kubernetes Secret — not inline in the config file. The token grants approval authority over elevation requests.
:::

---

### `log`

| Field | YAML key | Env var | Default | Description |
|-------|----------|---------|---------|-------------|
| Level | `log.level` | `JITSUDOD_LOG_LEVEL` | `info` | Minimum log level: `debug`, `info`, `warn`, `error` |
| Format | `log.format` | — | `json` | Output format: `json` (structured) or `text` (human-readable) |

```yaml
log:
  level: "info"
  format: "json"
```

---

## Annotated Example

A full annotated config file is available in the repository at [`deploy/config/config.example.yaml`](https://github.com/jitsudo-dev/jitsudo/blob/main/deploy/config/config.example.yaml).

Additional example configs:
- [`config.minimal.yaml`](https://github.com/jitsudo-dev/jitsudo/blob/main/deploy/config/config.minimal.yaml) — minimal setup
- [`config.aws-only.yaml`](https://github.com/jitsudo-dev/jitsudo/blob/main/deploy/config/config.aws-only.yaml) — AWS-only configuration
- [`config.kubernetes.yaml`](https://github.com/jitsudo-dev/jitsudo/blob/main/deploy/config/config.kubernetes.yaml) — Kubernetes-focused setup
