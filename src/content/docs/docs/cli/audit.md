---
title: jitsudo audit
description: Query the tamper-evident audit log.
---

Query the tamper-evident audit log.

## Synopsis

```
jitsudo audit [flags]
```

## Description

`jitsudo audit` queries the append-only audit log stored in the jitsudo control plane. Every significant action — request submission, approval, denial, credential issuance, revocation, and policy changes — is recorded as an immutable audit event.

Each event includes a SHA-256 hash of the previous entry, forming a tamper-evident hash chain. Any modification to a historical event breaks the chain and is detectable.

Without filters, the most recent events are returned (newest first, default page size 100).

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--user <email>` | — | Filter by actor identity (the email address of the user who performed the action) |
| `--provider <name>` | — | Filter by cloud provider (`aws`, `gcp`, `azure`, `kubernetes`) |
| `--request <id>` | — | Filter by request ID (shows all events associated with that request) |
| `--since <duration\|timestamp>` | — | Return events after this point in time. Accepts a Go duration (e.g. `24h`, `7d`) or RFC3339 timestamp (e.g. `2026-01-01T00:00:00Z`) |
| `--until <timestamp>` | — | Return events before this RFC3339 timestamp |
| `--output <format>` | `table` | Output format: `table`, `json`, `csv` |

## Global Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--server <url>` | Stored credentials | Control plane URL |
| `--token <token>` | Stored credentials | Bearer token override |
| `-q, --quiet` | `false` | Suppress non-essential output |
| `--debug` | `false` | Enable debug logging |

## Examples

```bash
# Show all recent audit events
jitsudo audit

# Show everything done by alice in the last 24 hours
jitsudo audit --user alice@example.com --since 24h

# Show all events for a specific request
jitsudo audit --request req_01J8KZ4F2EMNQZ3V7XKQYBD4W

# Show all AWS events from the past week in JSON
jitsudo audit --provider aws --since 168h --output json

# Export a time-bounded CSV for SIEM ingestion
jitsudo audit \
  --since 2026-01-01T00:00:00Z \
  --until 2026-02-01T00:00:00Z \
  --output csv > january-audit.csv
```

## Output — Table Format

```
TIMESTAMP              ACTOR                  ACTION               REQUEST ID                   OUTCOME
2026-03-20T16:00:00Z  alice@example.com      request.created      req_01J8KZ4F2EMNQ...        success
2026-03-20T16:01:00Z  bob@example.com        request.approved     req_01J8KZ4F2EMNQ...        success
2026-03-20T16:01:00Z  system                 grant.issued         req_01J8KZ4F2EMNQ...        success
2026-03-20T18:00:00Z  system                 grant.expired        req_01J8KZ4F2EMNQ...        success
```

## Output — JSON Format

```json
[
  {
    "id": 1042,
    "timestamp": "2026-03-20T16:00:00Z",
    "actor": "alice@example.com",
    "action": "request.created",
    "request_id": "req_01J8KZ4F2EMNQZ3V7XKQYBD4W",
    "provider": "aws",
    "resource_scope": "123456789012",
    "outcome": "success"
  }
]
```

## Output — CSV Format

```
timestamp,actor,action,request_id,provider,outcome
2026-03-20T16:00:00Z,alice@example.com,request.created,req_01J8KZ...,aws,success
```

## Audit Event Actions

| Action | Description |
|--------|-------------|
| `request.created` | A new elevation request was submitted |
| `request.approved` | A request was approved by an approver |
| `request.denied` | A request was denied by an approver |
| `grant.issued` | Credentials were issued to the requester |
| `grant.revoked` | An active grant was manually revoked |
| `grant.expired` | A grant expired at its natural expiry time |
| `policy.created` | A new OPA policy was applied |
| `policy.updated` | An existing OPA policy was updated |
| `policy.deleted` | An OPA policy was deleted |

See the [Audit Log reference](/reference/audit-log/) for the full event schema and hash-chain verification details.
