---
title: jitsudo revoke
description: Revoke an active elevation before its natural expiry.
---

Revoke an active elevation before its natural expiry.

## Synopsis

```
jitsudo revoke <request-id> [--reason <text>]
```

## Description

`jitsudo revoke` terminates an active elevation before its scheduled expiry. It calls the provider to immediately invalidate the issued credentials and transitions the request state to `REVOKED`.

**When to revoke:**

- Incident resolved — access is no longer needed.
- Credentials may have been exposed.
- Reducing the blast radius of an ongoing incident.

Revocation is idempotent — revoking an already-revoked or expired request is a no-op.

**Provider revocation mechanisms:**

| Provider | How credentials are revoked |
|----------|-----------------------------|
| `aws` | An IAM inline deny policy is attached to the role using `DateLessThanEquals` on `aws:TokenIssueTime`, blocking the session without affecting newer sessions |
| `gcp` | The IAM conditional binding is deleted from the project policy |
| `azure` | The RBAC role assignment is deleted |
| `kubernetes` | The ClusterRoleBinding or RoleBinding is deleted |

## Arguments

| Argument | Description |
|----------|-------------|
| `<request-id>` | The ID of an active elevation request to revoke |

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--reason <text>` | — | Optional reason for early revocation (recorded in the audit log) |

## Global Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--server <url>` | Stored credentials | Control plane URL |
| `--token <token>` | Stored credentials | Bearer token override |
| `-o, --output <format>` | `table` | Output format: `table`, `json`, `yaml` |
| `-q, --quiet` | `false` | Suppress non-essential output |
| `--debug` | `false` | Enable debug logging |

## Examples

```bash
# Revoke an active elevation (no reason required)
jitsudo revoke req_01J8KZ4F2EMNQZ3V7XKQYBD4W

# Revoke with a reason for the audit log
jitsudo revoke req_01J8KZ4F2EMNQZ3V7XKQYBD4W \
  --reason "Incident resolved, access no longer needed"
```

## Output

```
Request req_01J8KZ4F2EMNQZ3V7XKQYBD4W → REVOKED
```

## Notes

- Only `ACTIVE` requests can be revoked. Attempting to revoke a `PENDING` or `REJECTED` request returns an error.
- The revocation reason is stored in the audit log alongside the request ID, actor identity, and timestamp.
- After revocation, any in-progress `jitsudo shell` session will find its credentials no longer valid when the next API call is made.
