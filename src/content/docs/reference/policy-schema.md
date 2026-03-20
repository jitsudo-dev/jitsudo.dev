---
title: OPA Policy Schema
description: Formal reference for the OPA input and output schemas used in jitsudo eligibility and approval policies.
---

jitsudo embeds OPA (Open Policy Agent) as a Go library. This page documents the exact input document structure and expected output for each policy type.

## Input Schema

All policy types receive the same input document. The structure is stable across jitsudo versions.

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
    "duration_seconds": 7200,
    "reason": "Investigating P1 ECS crash — INC-4421",
    "break_glass": false,
    "metadata": {}
  }
}
```

### `user` object

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `user.email` | string | OIDC `email` claim | The requester's email address. Used as the primary identity in audit logs and bindings. |
| `user.groups` | string[] | OIDC `groups` claim | Group memberships from the IdP token. Empty if the IdP does not include a `groups` claim. |

### `request` object

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `request.provider` | string | `jitsudo request --provider` | Cloud provider: `aws`, `azure`, `gcp`, `kubernetes` |
| `request.role` | string | `jitsudo request --role` | Provider-specific role name |
| `request.resource_scope` | string | `jitsudo request --scope` | Provider-specific scope (AWS account ID, GCP project, K8s namespace) |
| `request.duration_seconds` | number | `jitsudo request --duration` | Requested elevation duration, converted to seconds |
| `request.reason` | string | `jitsudo request --reason` | Human-readable justification text |
| `request.break_glass` | boolean | `jitsudo request --break-glass` | `true` if the request uses break-glass mode |
| `request.metadata` | object | Provider-specific | Additional provider parameters (currently empty for built-in providers) |

## Eligibility Policy Output

Package: `jitsudo.eligibility`

| Output variable | Type | Default | Description |
|----------------|------|---------|-------------|
| `allow` | boolean | `false` | Whether the request is allowed to proceed to the approval queue |
| `reason` | string | `""` | Human-readable explanation shown to the requester on denial |

**Evaluation semantics:**
- All enabled eligibility policies are evaluated.
- The request proceeds if **any** policy returns `allow = true`.
- The `reason` from the first denying policy (where `allow = false`) is shown to the requester.

**Minimal policy:**

```python
package jitsudo.eligibility

default allow = false
default reason = "not authorized"

allow {
    input.user.groups[_] == "sre"
}
```

## Approval Policy Output

Package: `jitsudo.approval`

| Output variable | Type | Default | Description |
|----------------|------|---------|-------------|
| `allow` | boolean | `false` | Whether the request is approvable by the actor |
| `reason` | string | `""` | Explanation if not approvable |

**Evaluation semantics:**
- All enabled approval policies are evaluated.
- An approver action succeeds if **any** policy returns `allow = true`.

**Minimal policy:**

```python
package jitsudo.approval

default allow = false
default reason = "requires SRE lead approval"

allow {
    input.user.groups[_] == "sre-lead"
}
```

## Duration Reference

`request.duration_seconds` is an integer. Common conversions:

| Human duration | Seconds |
|---------------|---------|
| 15 minutes | 900 |
| 30 minutes | 1800 |
| 1 hour | 3600 |
| 2 hours | 7200 |
| 4 hours | 14400 |
| 8 hours | 28800 |
| 12 hours | 43200 |

Example policy that limits duration:

```python
package jitsudo.eligibility

default allow = false

allow {
    input.user.groups[_] == "sre"
    input.request.duration_seconds <= 14400  # max 4 hours
}
```

## Metadata Field

`request.metadata` is a `map<string, string>` for provider-specific parameters. Currently empty for all built-in providers. Future providers may populate this field for provider-specific eligibility rules.

## Guaranteed Invariants

The following invariants hold for all requests reaching the policy engine:

- `user.email` is non-empty (validated during token verification).
- `request.provider` is one of `aws`, `azure`, `gcp`, `kubernetes`, `mock`.
- `request.role` is non-empty.
- `request.duration_seconds` is positive.
- `request.reason` may be empty only if the server does not require it.

## Testing Policies

Use `jitsudo policy eval` to test policies against the live policy set:

```bash
jitsudo policy eval \
  --type eligibility \
  --input '{
    "user": {"email": "alice@example.com", "groups": ["sre"]},
    "request": {
      "provider": "aws",
      "role": "prod-infra-admin",
      "resource_scope": "123456789012",
      "duration_seconds": 7200,
      "reason": "Test",
      "break_glass": false,
      "metadata": {}
    }
  }'
```

The response includes `allowed`, `reason`, and the full OPA `result_json` for debugging.

## OPA Built-ins Available

All standard OPA built-in functions are available, including:

- String: `startswith`, `endswith`, `contains`, `upper`, `lower`
- Time: `time.now_ns()`, `time.weekday()`, `time.clock()`
- Sets and comprehensions: `{x | ...}`, `count()`, `any()`, `all()`
- `future.keywords` for `in`, `every`, `contains`, `if`

See the [OPA Policy Language documentation](https://www.openpolicyagent.org/docs/latest/policy-language/) for the complete reference.
