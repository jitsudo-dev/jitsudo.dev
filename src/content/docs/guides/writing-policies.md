---
title: Writing OPA Policies
description: Write eligibility and approval policies in Rego to control who can request what access and who can approve it.
---

jitsudo uses [Open Policy Agent (OPA)](https://www.openpolicyagent.org/) embedded as a Go library to evaluate access decisions. Policies are written in [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) and stored in the jitsudo database.

## Policy Types

| Type | When evaluated | Controls |
|------|---------------|----------|
| `eligibility` | At request submission | "Is this user allowed to request this role/scope?" |
| `approval` | At request review | "Who must approve? Can it be auto-approved?" |

## Policy Lifecycle

```bash
# Apply a policy (create or update by name)
jitsudo policy apply -f sre-eligibility.rego --type eligibility

# List all policies
jitsudo policy list

# Test a policy without making changes
jitsudo policy eval \
  --type eligibility \
  --input '{"user":{"email":"alice@example.com","groups":["sre"]},"request":{"provider":"aws","role":"prod-admin","resource_scope":"123456789012","duration_seconds":3600}}'

# Delete a policy
jitsudo policy delete pol_01J8KZ...
```

## Input Schema

All policies receive the same input document:

```json
{
  "user": {
    "email": "alice@example.com",
    "groups": ["sre", "oncall"]
  },
  "request": {
    "provider": "aws",
    "role": "prod-infra-admin",
    "resource_scope": "123456789012",
    "duration_seconds": 3600,
    "reason": "Investigating P1 ECS crash",
    "break_glass": false,
    "metadata": {}
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `user.email` | string | The requester's email (IdP subject claim) |
| `user.groups` | string[] | Groups from the `groups` claim in the OIDC token |
| `request.provider` | string | Cloud provider: `aws`, `azure`, `gcp`, `kubernetes` |
| `request.role` | string | The requested role name |
| `request.resource_scope` | string | Provider-specific scope (account ID, project ID, etc.) |
| `request.duration_seconds` | number | Requested elevation duration in seconds |
| `request.reason` | string | Justification text from the requester |
| `request.break_glass` | boolean | Whether break-glass mode was requested |
| `request.metadata` | object | Provider-specific additional parameters |

## Eligibility Policies

### Expected Output

```python
package jitsudo.eligibility

# allowed: bool — whether the request is allowed
# reason: string — explanation (shown on denial)
default allow = false
default reason = "not authorized"
```

The policy engine evaluates `allow` and `reason` from the `jitsudo.eligibility` package.

### Example: SRE Group Access

```python
package jitsudo.eligibility

default allow = false
default reason = "user must be in the sre group"

allow {
    input.user.groups[_] == "sre"
}

reason = "access allowed for SRE team" {
    allow
}
```

### Example: Provider-Scoped Eligibility

```python
package jitsudo.eligibility

default allow = false
default reason = "not authorized for this provider/role combination"

# SRE can request any AWS role
allow {
    input.user.groups[_] == "sre"
    input.request.provider == "aws"
}

# Developers can only request read-only GCP access
allow {
    input.user.groups[_] == "developer"
    input.request.provider == "gcp"
    input.request.role == "roles/viewer"
}

# Ops can request Kubernetes view in non-production namespaces
allow {
    input.user.groups[_] == "ops"
    input.request.provider == "kubernetes"
    input.request.role == "view"
    not startswith(input.request.resource_scope, "prod")
}
```

### Example: Duration Limits

```python
package jitsudo.eligibility

default allow = false
default reason = "not authorized"

allow {
    input.user.groups[_] == "sre"
    # SRE can request up to 4 hours
    input.request.duration_seconds <= 14400
}

allow {
    input.user.groups[_] == "sre-lead"
    # SRE leads can request up to 12 hours
    input.request.duration_seconds <= 43200
}
```

### Example: Break-Glass Restriction

```python
package jitsudo.eligibility

default allow = false
default reason = "not authorized"

# Only oncall users can use break-glass
allow {
    not input.request.break_glass
    input.user.groups[_] == "sre"
}

allow {
    input.request.break_glass
    input.user.groups[_] == "oncall"
}
```

## Approval Policies

### Expected Output

```python
package jitsudo.approval

# allowed: bool — whether this request can proceed to approval
# reason: string — explanation
default allow = false
```

:::note[Tier routing]
Approval policies can return `approver_tier` to route requests to Tier 1 (OPA auto-approve), Tier 2 (AI-assisted review via MCP), or Tier 3 (human). Policies without an `approver_tier` rule default to `"human"`. See [Three-Tier Approval Routing](#three-tier-approval-routing) below and [Approval Model](/docs/architecture/approval-model/) for the full design.
:::

### Example: Require SRE Lead Approval for Production

```python
package jitsudo.approval

default allow = false
default reason = "requires SRE lead approval"

# SRE leads can approve production AWS requests
allow {
    input.user.groups[_] == "sre-lead"
    input.request.provider == "aws"
}

# Anyone can approve non-production requests
allow {
    not endswith(input.request.resource_scope, "prod")
}
```

### Example: Business Hours Only

```python
package jitsudo.approval

import future.keywords.in

default allow = false
default reason = "requests outside business hours require manager approval"

# Standard requests: allowed during business hours (Mon-Fri, 09:00-18:00 UTC)
allow {
    day := time.weekday(time.now_ns())
    day in [1, 2, 3, 4, 5]  # Monday through Friday
    hour := time.clock(time.now_ns())[0]
    hour >= 9
    hour < 18
}

# Break-glass: always allowed (emergency)
allow {
    input.request.break_glass
}
```

## Testing Policies

Use `jitsudo policy eval` to test without applying:

```bash
# Test eligibility
jitsudo policy eval \
  --type eligibility \
  --input '{
    "user": {"email": "alice@example.com", "groups": ["sre"]},
    "request": {
      "provider": "aws",
      "role": "prod-infra-admin",
      "resource_scope": "123456789012",
      "duration_seconds": 7200
    }
  }'

# Expected output:
# allowed: true
```

```bash
# Test a denial case
jitsudo policy eval \
  --type eligibility \
  --input '{
    "user": {"email": "dev@example.com", "groups": ["developer"]},
    "request": {
      "provider": "aws",
      "role": "prod-infra-admin",
      "resource_scope": "123456789012",
      "duration_seconds": 7200
    }
  }'

# Expected output:
# allowed: false
# reason:  user must be in the sre group
```

## Policy Evaluation Semantics

- **Multiple eligibility policies:** All enabled eligibility policies are evaluated. A request is allowed if **any** policy returns `allow = true`.
- **Multiple approval policies:** All enabled approval policies are evaluated. The same "any" semantics apply.
- **Disabled policies:** Policies with `enabled: false` are not loaded into the OPA engine and have no effect.

## Reloading Policies

After applying or deleting policies, the OPA engine reloads automatically on a periodic schedule. To reload immediately:

```bash
jitsudo server reload-policies
```

## Policy Packages

All eligibility policies must use the package `jitsudo.eligibility`.
All approval policies must use the package `jitsudo.approval`.

Any Rego that is valid within these packages is supported, including imports, helper rules, and `future.keywords`.

---

## Identity, Groups, and Principal Lifecycle

### Groups come from your IdP — jitsudo trusts them

The `user.groups` field in the policy input is sourced directly from the `groups` claim in the OIDC ID token. jitsudo does not manage group membership — it reads it from your identity provider at request time.

**This means group membership security is your IdP's responsibility.** Ensure your IdP is the authoritative source of group assignments, and that group membership changes propagate promptly (most IdPs include group claims in the next token after a membership change).

:::caution
Compromised IdP group claims would allow an attacker to impersonate group membership and potentially satisfy approval policies. Secure your IdP, audit group membership regularly, and use short JWT lifetimes (60–120 minutes recommended) to limit the replay window.
:::

### Offboarding a principal

When an engineer leaves the team or company:

1. **Revoke their IdP account or remove them from all jitsudo-relevant groups.** This blocks new elevation requests immediately — the next request will fail eligibility evaluation.
2. **Revoke any active grants**: `jitsudo revoke --user alice@example.com --all`
3. **Active grants do not expire automatically on offboarding** — they only expire at their natural TTL. Always explicitly revoke on offboarding.

```bash
# List all active grants for a user
jitsudo status --user alice@example.com --state active

# Revoke each active grant
jitsudo revoke req_01J8KZ...
```

### Token lifetime and replay

jitsudo validates JWT expiry on every API call. There are no long-lived API tokens or session tokens beyond the JWT TTL. Use short JWT lifetimes (60–120 minutes) in your IdP configuration to minimize the replay window.

A stolen but unexpired JWT can be used to submit requests until it expires. Short lifetimes + IdP session revocation are the primary mitigations.

---

## Three-Tier Approval Routing

Approval policies return `approver_tier` to route each request to the correct approval path. Policies without an `approver_tier` rule default to `"human"` — fully backwards-compatible.

The complete three-tier policy shape:

```rego
package jitsudo.approval

import future.keywords.if
import future.keywords.in

read_only_roles := {"prod-read-only", "roles/viewer", "view"}

# Tier 1: auto-approve for low-risk, high-trust requests
approver_tier := "auto" if {
    input.context.trust_tier >= 3
    input.request.role in read_only_roles
    input.request.duration_seconds <= 1800
}

# Tier 2: AI review when an active incident is linked
approver_tier := "ai_review" if {
    not tier1_conditions
    regex.match(`INC-\d+`, input.request.reason)
}

# Tier 3: human approval (catch-all)
approver_tier := "human" if {
    not tier1_conditions
    not tier2_conditions
}
```

All three tiers are available. When `approver_tier := "ai_review"`, the request sits PENDING and is surfaced to the configured AI agent via the MCP approver endpoint (`POST /mcp`). The agent calls `approve_request`, `deny_request`, or `escalate_to_human` — any uncertainty routes to Tier 3 human review. The agent's full reasoning is stored in the audit log.

See [Approval Model](/docs/architecture/approval-model/) for the full three-tier design and `input.context.trust_tier` reference.
