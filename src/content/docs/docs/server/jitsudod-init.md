---
title: jitsudod init
description: Bootstrap a new jitsudod control plane instance — tests database connectivity, runs migrations, and writes a starter config file.
---

One-time bootstrap command for a new jitsudod control plane. Tests database connectivity, runs schema migrations, and writes a starter configuration file.

## Synopsis

```
jitsudod init --db-url <url> --oidc-issuer <url> --oidc-client-id <id> [flags]
```

## Flags

| Flag | Required | Default | Environment Variable | Description |
|------|----------|---------|----------------------|-------------|
| `--db-url <url>` | **Yes*** | — | `JITSUDOD_DATABASE_URL` | PostgreSQL connection URL |
| `--oidc-issuer <url>` | **Yes*** | — | `JITSUDOD_OIDC_ISSUER` | OIDC issuer URL for JWT validation |
| `--oidc-client-id <id>` | **Yes*** | — | `JITSUDOD_OIDC_CLIENT_ID` | OIDC client ID registered for the server |
| `--http-addr <addr>` | No | `:8080` | — | HTTP (REST gateway) listen address |
| `--grpc-addr <addr>` | No | `:8443` | — | gRPC listen address |
| `--config-out <path>` | No | `jitsudo.yaml` | — | Path to write the generated config file |
| `--skip-migrations` | No | `false` | — | Skip database migrations (use if already migrated) |

\* The value may be set via the corresponding environment variable instead of the flag.

## What `init` does

1. Connects to PostgreSQL and verifies connectivity.
2. Runs embedded `golang-migrate` migrations to create the schema.
3. Writes a minimal `jitsudo.yaml` config file with the supplied values.

## Example

```bash
jitsudod init \
  --db-url "postgres://jitsudo:password@localhost:5432/jitsudo?sslmode=require" \
  --oidc-issuer https://your-org.okta.com \
  --oidc-client-id jitsudo-server \
  --config-out /etc/jitsudo/config.yaml
```

:::caution[Security: password in process list]
Passing a database URL with a password via `--db-url` exposes it in the process list (`ps aux`) to all users on the host. For provisioning scripts or CI pipelines, prefer environment variables instead — all three mandatory values can be supplied this way:

```bash
export JITSUDOD_DATABASE_URL="postgres://jitsudo:password@localhost:5432/jitsudo?sslmode=require"
export JITSUDOD_OIDC_ISSUER="https://your-org.okta.com"
export JITSUDOD_OIDC_CLIENT_ID="jitsudo-server"
jitsudod init --config-out /etc/jitsudo/config.yaml
```

`jitsudod init` honours `JITSUDOD_DATABASE_URL`, `JITSUDOD_OIDC_ISSUER`, and `JITSUDOD_OIDC_CLIENT_ID` with the same priority as their flag equivalents.

Note: the generated `jitsudo.yaml` will still contain the database URL. To avoid storing credentials in the config file for the running server, set `JITSUDOD_DATABASE_URL` at runtime — the server always overrides the config file value with the environment variable. See the [Security Hardening Guide](/guides/security-hardening/) for the recommended production setup.
:::

## Output

```
Connecting to database... OK
Running database migrations... OK

Configuration written to: /etc/jitsudo/config.yaml

Next steps:
  1. Edit /etc/jitsudo/config.yaml to enable providers and notifications
  2. Start the server: jitsudod --config /etc/jitsudo/config.yaml
  3. Log in from the CLI: jitsudo login --server localhost:8080
```

## Admin Bootstrap

`jitsudod init` does not create any administrator accounts. Admin authority in jitsudo is derived entirely from your identity provider: users who are members of the `jitsudo-admins` IdP group receive admin privileges when they authenticate.

### How `jitsudo-admins` works

`jitsudo-admins` is not a database concept — it is an IdP group, resolved from the `groups` claim in the OIDC token at request time. Like any group in jitsudo policies, membership is managed in your identity provider.

### Day-one enrollment

1. In your IdP, create a group named `jitsudo-admins` (exact name must match what is checked by the server).
2. Add the first administrator's account to that group.
3. The administrator logs in with `jitsudo login` — their token will now include `jitsudo-admins` in the groups claim.
4. The administrator can now call `SetPrincipalTrustTier` to assign trust tiers to other principals:

```bash
# Assign trust tier 3 to a senior SRE (admin only)
curl -X PUT https://jitsudod:8080/api/v1alpha1/principals/alice@example.com/trust-tier \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"trust_tier": 3}'
```

### Ongoing membership management

Add and remove members from `jitsudo-admins` in your IdP using the same process as any other group. Changes take effect at the next token issuance (typically within minutes, depending on your IdP's token lifetime).

Audit `jitsudo-admins` membership regularly. Treat it as a Tier 0 group — the same level of scrutiny as your cloud IAM admin roles.

### Recovery: all admins offboarded

If every member of `jitsudo-admins` has left the organization:

1. In your IdP, add a recovery identity (a break-glass admin account or a new employee) to the `jitsudo-admins` group.
2. Authenticate as that identity: `jitsudo login`.
3. Re-enroll other administrators and re-assign trust tiers as needed.

The recovery path does not require database access or server restart — it is purely an IdP group membership change.

See [Approval Model — Principal Trust Tiers](/docs/architecture/approval-model/#principal-trust-tiers) for trust tier values and their effect on approval routing.

## Related

- [`jitsudod`](/docs/server/jitsudod/) — running the control plane daemon
- [Single-Server Deployment guide](/guides/deployment/single-server/)
- [Kubernetes Deployment guide](/guides/deployment/kubernetes/)
- [Server Configuration reference](/reference/configuration/)
