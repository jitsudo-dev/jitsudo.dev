---
title: jitsudo approve / deny
description: Approve or deny a pending elevation request.
---

Approve or deny a pending elevation request. These commands require an approver role as determined by your organization's OPA policies.

## Synopsis

```
jitsudo approve <request-id> [--comment <text>]
jitsudo deny   <request-id> --reason <text>
```

## Description

**`jitsudo approve`** transitions a `PENDING` request to `APPROVED`, which immediately triggers credential issuance. The requester's credentials become available as soon as they run `jitsudo exec` or `jitsudo shell`.

**`jitsudo deny`** transitions a `PENDING` request to `REJECTED`. The denial reason is recorded in the audit log and returned to the requester.

Both commands require exactly one positional argument: the request ID to act on. Use [`jitsudo status --pending`](/docs/cli/status/) to list requests awaiting action.

## Flags

### `jitsudo approve`

| Flag | Required | Description |
|------|----------|-------------|
| `--comment <text>` | No | Optional approval comment recorded in the audit log |

### `jitsudo deny`

| Flag | Required | Description |
|------|----------|-------------|
| `--reason <text>` | **Yes** | Reason for denial (recorded in audit log and visible to requester) |

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
# List requests waiting for your approval
jitsudo status --pending

# Approve a request with an optional comment
jitsudo approve req_01J8KZ4F2EMNQZ3V7XKQYBD4W
jitsudo approve req_01J8KZ4F2EMNQZ3V7XKQYBD4W --comment "Approved for INC-4421 response"

# Deny a request (reason is required)
jitsudo deny req_01J8KZ4F2EMNQZ3V7XKQYBD4W \
  --reason "Not authorized for production access outside change windows"
```

## Output

```
# approve
Request req_01J8KZ4F2EMNQZ3V7XKQYBD4W → APPROVED

# deny
Request req_01J8KZ4F2EMNQZ3V7XKQYBD4W → REJECTED
```

## Approver Workflow

A typical approver session:

```bash
# 1. See what needs approval
jitsudo status --pending

# 2. Review the specific request
jitsudo status req_01J8KZ4F2EMNQZ3V7XKQYBD4W

# 3. Approve or deny
jitsudo approve req_01J8KZ4F2EMNQZ3V7XKQYBD4W --comment "Looks good"
```

## Policy Enforcement

Whether a user can approve a request is governed by the `approval` OPA policy. The policy can:

- Restrict approval to specific groups (e.g. only `sre-oncall` can approve production access).
- Require multiple approvers.
- Auto-approve requests meeting certain criteria (short duration, low-risk role).

See the [Writing Policies guide](/guides/writing-policies/) for details on the approval policy input schema.
