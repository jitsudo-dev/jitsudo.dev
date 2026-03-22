---
title: Audit Log Reference
description: Complete reference for the jitsudo audit log — event types, field schema, hash chain structure, and verification.
---

jitsudo maintains an append-only audit log in PostgreSQL. Every significant action produces an `AuditEvent` record with a SHA-256 hash of the previous entry, forming a tamper-evident hash chain.

## AuditEvent Schema

```json
{
  "id": 1042,
  "timestamp": "2026-03-20T16:00:00Z",
  "actor_identity": "alice@example.com",
  "action": "request.created",
  "request_id": "req_01J8KZ4F2EMNQZ3V7XKQYBD4W",
  "provider": "aws",
  "resource_scope": "123456789012",
  "outcome": "success",
  "details_json": "{\"duration_seconds\":7200,\"role\":\"prod-infra-admin\"}",
  "prev_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "hash": "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
}
```

### Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `id` | int64 | Sequential event ID. Monotonically increasing, never reused. |
| `timestamp` | RFC3339 (UTC) | When the event occurred. |
| `actor_identity` | string | The user who performed the action — the IdP email. `system` for automated actions (expiry sweeper, etc.). |
| `action` | string | The action that occurred. See [Action Types](#action-types) below. |
| `request_id` | string | The associated elevation request ID, or empty if not applicable. |
| `provider` | string | The cloud provider involved (`aws`, `gcp`, `azure`, `kubernetes`), or empty. |
| `resource_scope` | string | The provider-specific scope (account ID, project ID, namespace), or empty. |
| `outcome` | string | `success` or `failure`. |
| `details_json` | string | JSON object with additional context. Schema varies by action type. |
| `prev_hash` | string | SHA-256 of the previous audit entry. `""` for the first entry. |
| `hash` | string | SHA-256 of this entry (see [Hash Chain](#hash-chain) below). |

## Action Types

### Request lifecycle

| Action | Actor | Description |
|--------|-------|-------------|
| `request.created` | User | A new elevation request was submitted |
| `request.approved` | User | A request was approved by an approver |
| `request.denied` | User | A request was denied by an approver |
| `request.revoked` | User | An active request was manually revoked |

### Grant lifecycle

| Action | Actor | Description |
|--------|-------|-------------|
| `grant.issued` | `system` | Credentials were issued after approval |
| `grant.expired` | `system` | A grant reached its natural expiry time |
| `grant.revoked` | `system` | A grant was revoked (triggered by `request.revoked`) |

### Policy management

| Action | Actor | Description |
|--------|-------|-------------|
| `policy.created` | User | A new OPA policy was applied |
| `policy.updated` | User | An existing OPA policy was updated |
| `policy.deleted` | User | An OPA policy was deleted |

## `details_json` Schemas

### `request.created`

```json
{
  "provider": "aws",
  "role": "prod-infra-admin",
  "resource_scope": "123456789012",
  "duration_seconds": 7200,
  "reason": "Investigating P1 ECS crash",
  "break_glass": false
}
```

### `request.approved` / `request.denied`

```json
{
  "comment": "Approved for INC-4421 response"
}
```

### `grant.issued`

```json
{
  "expires_at": "2026-03-20T18:00:00Z"
}
```

### `policy.created` / `policy.updated`

```json
{
  "policy_name": "sre-eligibility",
  "policy_type": "eligibility"
}
```

## Hash Chain

The audit log uses a SHA-256 hash chain to detect tampering. Each event's `hash` field covers the event's content and links to the previous event.

### Hash computation

The `hash` of each event is computed as:

```
SHA-256(prev_hash + "|" + id + "|" + timestamp + "|" + actor_identity + "|" + action + "|" + request_id + "|" + outcome + "|" + details_json)
```

Where `prev_hash` is the `hash` of the immediately preceding event (empty string for the first event).

### Verification

To verify the hash chain is intact, compute the expected hash for each event and compare it to the stored `hash` field. Any modification to a historical event — including the `prev_hash` field — will cause all subsequent hashes to mismatch.

**Example verification script (Python):**

```python
import hashlib, json, sys

def compute_hash(event):
    parts = "|".join([
        event.get("prev_hash", ""),
        str(event["id"]),
        event["timestamp"],
        event["actor_identity"],
        event["action"],
        event.get("request_id", ""),
        event["outcome"],
        event.get("details_json", ""),
    ])
    return hashlib.sha256(parts.encode()).hexdigest()

events = json.load(sys.stdin)  # list of AuditEvent objects
for event in events:
    expected = compute_hash(event)
    if expected != event["hash"]:
        print(f"TAMPERED: event id={event['id']} hash mismatch")
        print(f"  expected: {expected}")
        print(f"  stored:   {event['hash']}")
        sys.exit(1)
print(f"Chain intact: {len(events)} events verified")
```

**Usage:**

```bash
# Export events as JSON
jitsudo audit --output json > audit-export.json

# Verify the chain
python3 verify-chain.py < audit-export.json
```

## Querying the Audit Log

### CLI

```bash
# All events for the last 24 hours
jitsudo audit --since 24h

# All events for a specific request
jitsudo audit --request req_01J8KZ4F2EMNQZ3V7XKQYBD4W

# All events by a specific user in JSON
jitsudo audit --user alice@example.com --output json

# Export a date range as CSV
jitsudo audit \
  --since 2026-01-01T00:00:00Z \
  --until 2026-02-01T00:00:00Z \
  --output csv > january-2026-audit.csv
```

See [`jitsudo audit`](/docs/cli/audit/) for the full CLI reference.

### REST API

```bash
curl "https://jitsudo.example.com/api/v1alpha1/audit?\
actor_identity=alice@example.com&\
since=2026-03-01T00:00:00Z" \
  -H "Authorization: Bearer $TOKEN"
```

## Tamper-Evidence: What the Hash Chain Guarantees

The SHA-256 hash chain means that **any modification to a historical entry — including the `prev_hash` field — will break all subsequent hashes**. An attacker cannot silently edit or delete an audit record without the discrepancy being detectable by the verification script.

What the hash chain does **not** provide:
- **Truncation protection**: An attacker with database write access could truncate the table (delete all rows). The chain would verify as intact on the remaining entries, but entries would be missing. Pair with row count monitoring or an external log drain for truncation detection.
- **WORM (write-once) storage**: PostgreSQL tables are not inherently write-once. The `REVOKE UPDATE, DELETE ON audit_events` permission (see [Security Hardening](/docs/guides/security-hardening/)) provides a second layer of protection, but a database superuser could still bypass it.
- **Cryptographic anchoring**: There is no external timestamp authority or blockchain anchor for the chain. For regulatory or legal evidence requirements, export and archive signed snapshots externally.

For stronger audit integrity guarantees, forward the audit log to an external SIEM or write-once log store.

## SIEM Integration

jitsudo provides two real-time SIEM forwarding mechanisms built into the notification dispatcher, plus the existing periodic export path.

### Real-time JSON streaming

Configure `notifications.siem.json` to POST each event as a JSON document to any HTTP ingest endpoint (Splunk HEC, Elasticsearch, Datadog Logs, etc.) the moment it occurs:

```yaml
notifications:
  siem:
    json:
      url: "https://siem.example.com/api/v1/ingest"
      headers:
        Authorization: "Bearer <token>"
```

Each POST includes a UUID `event_id` for deduplication, making it safe to use with idempotent SIEM ingest pipelines. See [Server Configuration](/reference/configuration/#notificationssiem) for the full payload schema and field reference.

### Real-time syslog forwarding

Configure `notifications.siem.syslog` to forward events to a remote syslog server or the local syslog socket:

```yaml
notifications:
  siem:
    syslog:
      network: "tcp"
      address: "syslog.example.com:514"
      facility: "auth"
```

Messages use structured `key=value` format and severity is mapped by event type (`break_glass` → WARNING, `denied`/`ai_denied` → NOTICE, others → INFO).

### Periodic export (batch)

For batch SIEM ingestion, export via the CLI or REST API:

```bash
# Export all events since last export as JSON
jitsudo audit \
  --since 2026-03-01T00:00:00Z \
  --output json > audit-2026-03.json
```

The JSON output matches the `AuditEvent` schema above.

### REST API polling

For automated batch ingestion, poll the REST API on a schedule:

```bash
# Fetch events since a cursor timestamp
curl "https://jitsudo.example.com/api/v1alpha1/audit?\
since=${LAST_SYNC_TIMESTAMP}&output=json" \
  -H "Authorization: Bearer $TOKEN" \
  | jq '.events[]' \
  | your-siem-ingest-script
```

### Dedicated SIEM connectors (Milestone 6)

Native connectors for Splunk, Datadog, and Elastic — with verified delivery guarantees and native field mapping — are on the [Milestone 6 roadmap](/roadmap/).

See the [REST API reference](/reference/api/) for query parameters and response schema.

## Append-Only Guarantee

The audit log is append-only at the database layer. jitsudo uses serializable transactions to:
1. Read the latest event's `hash` field.
2. Compute the new event's `hash` using the latest as `prev_hash`.
3. Insert the new event atomically.

No `UPDATE` or `DELETE` operations are ever performed on the audit table. Database-level permissions on the jitsudo role should enforce this (`REVOKE UPDATE, DELETE ON audit_events FROM jitsudo`).
