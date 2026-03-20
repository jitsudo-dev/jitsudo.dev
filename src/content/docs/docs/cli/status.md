---
title: jitsudo status
description: Check the status of one or more elevation requests.
---

Check the status of an elevation request, or list multiple requests.

## Synopsis

```
jitsudo status [request-id] [flags]
```

## Description

Without arguments, `jitsudo status` lists requests according to the supplied filter flags. With a request ID argument it prints the full details of that single request.

## Flags

| Flag | Description |
|------|-------------|
| `--mine` | List all requests submitted by the currently authenticated user |
| `--pending` | List all requests in `PENDING` state (for approvers) |

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
# Get the full details of a specific request
jitsudo status req_01J8KZ4F2EMNQZ3V7XKQYBD4W

# List all your own requests
jitsudo status --mine

# List all pending requests (approver workflow)
jitsudo status --pending

# Get a request in JSON format
jitsudo status req_01J8KZ4F2EMNQZ3V7XKQYBD4W --output json
```

## Output — Single Request

```
ID:        req_01J8KZ4F2EMNQZ3V7XKQYBD4W
State:     ACTIVE
Requester: alice@example.com
Provider:  aws
Role:      prod-infra-admin
Scope:     123456789012
Duration:  2h0m0s
Reason:    Investigating P1 ECS crash — INC-4421
Approver:  bob@example.com
Comment:   Approved for INC-4421 response
Expires:   2026-03-20T18:00:00Z
```

## Output — List View

```
ID                           STATE      REQUESTER                 REASON
---------------------------------------------------------------------------------
req_01J8KZ4F2EMNQZ3V7XK...  ACTIVE     alice@example.com         Investigating P1 ECS crash
req_01J8KZ5HMNPQS4X8...     PENDING    carol@example.com         Deploy hotfix to staging
```

## Request States

| State | Description |
|-------|-------------|
| `PENDING` | Submitted, waiting for approver action |
| `APPROVED` | Approved by an approver; credentials not yet fetched |
| `REJECTED` | Denied by an approver |
| `ACTIVE` | Credentials have been issued and are in use |
| `EXPIRED` | Elevation window elapsed; credentials automatically revoked |
| `REVOKED` | Manually revoked before expiry via `jitsudo revoke` |

## Next Steps

Once a request reaches `ACTIVE` state:

- Run `jitsudo exec <request-id> -- <command>` to execute a single command with elevated credentials.
- Run `jitsudo shell <request-id>` to open an interactive elevated shell.
- Run `jitsudo revoke <request-id>` to end the elevation early.
