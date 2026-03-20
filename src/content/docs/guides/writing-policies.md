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

:::note
Approval policies currently gate whether the request is approvable. Automatic approval (auto-approve without approver action) is planned for a future release.
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
