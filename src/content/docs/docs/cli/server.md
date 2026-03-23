---
title: jitsudo server
description: Control plane management commands for administering a running jitsudod instance.
---

Control plane management commands for administering a running jitsudod instance.

## Synopsis

```
jitsudo server <subcommand> [flags]
```

## Subcommands

| Subcommand | Description |
|------------|-------------|
| [`status`](#status) | Check control plane health |
| [`version`](#version) | Print server version and API compatibility |
| [`reload-policies`](#reload-policies) | Trigger the OPA engine to reload policies from the database |

:::note
Bootstrapping a new control plane is done with [`jitsudod init`](/docs/server/jitsudod-init/), a command on the `jitsudod` server binary.
:::

## Admin Bootstrap

After running `jitsudod init`, the next step is enrolling the first administrator. The `jitsudo-admins` group controls access to privileged control plane operations — most importantly, assigning principal trust tiers via the `SetPrincipalTrustTier` API.

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

- [`jitsudod init`](/docs/server/jitsudod-init/) — bootstrap command
- [Single-Server Deployment guide](/guides/deployment/single-server/) — using `jitsudod init` to bootstrap a production server
- [Server Configuration reference](/reference/configuration/) — full config file reference
