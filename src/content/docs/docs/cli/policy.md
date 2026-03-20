---
title: jitsudo policy
description: Manage eligibility and approval OPA policies. Requires admin role.
---

Manage eligibility and approval OPA policies. Requires admin role.

## Synopsis

```
jitsudo policy <subcommand> [flags]
```

## Subcommands

| Subcommand | Description |
|------------|-------------|
| [`list`](#list) | List all stored policies |
| [`get`](#get) | Get a policy by ID |
| [`apply`](#apply) | Create or update a policy from a Rego file |
| [`delete`](#delete) | Delete a policy by ID |
| [`eval`](#eval) | Dry-run policy evaluation against the current policy set |

## `list`

List all policies stored in the control plane.

```
jitsudo policy list
```

**Output:**

```
ID          NAME              TYPE          ENABLED  UPDATED
pol_01...   sre-eligibility   eligibility   true     2026-03-01T10:00:00Z
pol_02...   prod-approval     approval      true     2026-03-01T10:05:00Z
pol_03...   break-glass       eligibility   false    2026-03-15T08:00:00Z
```

## `get`

Print the full details and Rego source of a policy.

```
jitsudo policy get <policy-id>
```

**Output:**

```
ID:          pol_01J8KZ4F2EMNQZ3V7XKQYBD4W
Name:        sre-eligibility
Type:        eligibility
Enabled:     true
Description: SRE team eligibility for production AWS access
Updated:     2026-03-01T10:00:00Z

--- Rego ---
package jitsudo.eligibility

default allow = false

allow {
    input.user.groups[_] == "sre"
    input.request.provider == "aws"
}
```

## `apply`

Create or update a policy from a Rego file (upsert by name).

```
jitsudo policy apply -f <file.rego> [flags]
```

**Flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `-f, --file <path>` | — | Path to the Rego policy file **(required)** |
| `--name <name>` | Filename without `.rego` | Policy name (used as the upsert key) |
| `--type <type>` | `eligibility` | Policy type: `eligibility` or `approval` |
| `--description <text>` | — | Human-readable description |
| `--disable` | `false` | Create the policy in disabled state |

**Examples:**

```bash
# Apply an eligibility policy
jitsudo policy apply -f sre-eligibility.rego

# Apply an approval policy with a name and description
jitsudo policy apply \
  -f prod-approval.rego \
  --name prod-approval \
  --type approval \
  --description "Require SRE lead approval for production access"

# Apply but leave disabled for testing
jitsudo policy apply -f new-policy.rego --disable
```

**Output:**

```
Policy sre-eligibility (eligibility) applied — id: pol_01J8KZ4F2EMNQZ3V7XKQYBD4W
```

## `delete`

Delete a policy by ID. This is irreversible — the Rego source is permanently removed.

```
jitsudo policy delete <policy-id>
```

**Output:**

```
Policy pol_01J8KZ4F2EMNQZ3V7XKQYBD4W deleted.
```

## `eval`

Dry-run policy evaluation without making any state changes. Useful for testing policies before applying them or debugging why a request was rejected.

```
jitsudo policy eval --input <json> [--type <type>]
```

**Flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `--input <json>` | — | JSON-encoded OPA input document **(required)** |
| `--type <type>` | `eligibility` | Policy type to evaluate: `eligibility` or `approval` |

**Input structure:**

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
    "duration_seconds": 3600
  }
}
```

**Examples:**

```bash
# Test eligibility for an AWS request
jitsudo policy eval \
  --input '{"user":{"email":"alice@example.com","groups":["sre"]},"request":{"provider":"aws","role":"prod-infra-admin","resource_scope":"123456789012","duration_seconds":3600}}'

# Test approval policy
jitsudo policy eval \
  --type approval \
  --input '{"user":{"email":"bob@example.com","groups":["sre-lead"]},"request":{"provider":"aws","role":"prod-infra-admin","resource_scope":"123456789012","duration_seconds":3600}}'
```

**Output:**

```
allowed: true

# or

allowed: false
reason:  user is not in the sre group
```

## Global Flags

All `jitsudo policy` subcommands accept these global flags:

| Flag | Default | Description |
|------|---------|-------------|
| `--server <url>` | Stored credentials | Control plane URL |
| `--token <token>` | Stored credentials | Bearer token override |
| `-o, --output <format>` | `table` | Output format: `table`, `json`, `yaml` |
| `-q, --quiet` | `false` | Suppress non-essential output |
| `--debug` | `false` | Enable debug logging |

## Policy Types

| Type | Purpose | Evaluated when |
|------|---------|----------------|
| `eligibility` | Is this user allowed to request this role/scope? | At request submission |
| `approval` | Who must approve? Can it be auto-approved? | At request review |

See the [Writing Policies guide](/guides/writing-policies/) for Rego examples and the full input/output schema.
