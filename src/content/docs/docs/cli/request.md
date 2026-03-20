---
title: jitsudo request
description: Submit a new elevation request for temporary elevated cloud permissions.
---

Submit a request for temporary elevated cloud permissions.

## Synopsis

```
jitsudo request --provider <provider> --role <role> --scope <scope> --duration <duration> --reason <reason> [flags]
```

## Description

`jitsudo request` submits a new elevation request to the jitsudo control plane. The request enters an approval workflow defined by your organization's OPA policies.

**Workflow after submission:**

1. jitsudo checks eligibility policies — if you are not eligible, the request is rejected immediately.
2. If eligible, the request enters `PENDING` state and approvers are notified.
3. Once an approver runs `jitsudo approve`, credentials are issued and the state transitions to `ACTIVE`.
4. At expiry, jitsudo automatically revokes the credentials (`EXPIRED`).

Use [`jitsudo status`](/docs/cli/status/) to track your request and [`jitsudo exec`](/docs/cli/exec/) or [`jitsudo shell`](/docs/cli/shell/) to use the granted credentials.

## Flags

| Flag | Required | Description |
|------|----------|-------------|
| `--provider <name>` | Yes | Cloud provider: `aws`, `azure`, `gcp`, `kubernetes` |
| `--role <name>` | Yes | Role or permission set to request (provider-specific) |
| `--scope <value>` | Yes | Resource scope: AWS account ID, GCP project ID, Azure subscription ID, or Kubernetes namespace |
| `--duration <duration>` | Yes | Elevation window, e.g. `1h`, `30m`, `2h30m` |
| `--reason <text>` | Yes | Justification for the request (logged in the audit trail) |
| `--break-glass` | No | Emergency break-glass mode: bypasses the approval workflow with immediate alerting |
| `--wait` | No | Block until the request reaches a terminal state (approved or denied) |

## Global Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--server <url>` | Stored credentials | Control plane URL |
| `--token <token>` | Stored credentials | Bearer token override |
| `-o, --output <format>` | `table` | Output format: `table`, `json`, `yaml` |
| `-q, --quiet` | `false` | Print only the request ID |
| `--debug` | `false` | Enable debug logging |

## Examples

```bash
# Request AWS admin access for an incident
jitsudo request \
  --provider aws \
  --role prod-infra-admin \
  --scope 123456789012 \
  --duration 2h \
  --reason "Investigating P1 ECS crash — INC-4421"

# Request a GCP role
jitsudo request \
  --provider gcp \
  --role roles/editor \
  --scope my-gcp-project \
  --duration 1h \
  --reason "Deploy hotfix to staging"

# Request Azure contributor on a subscription
jitsudo request \
  --provider azure \
  --role Contributor \
  --scope xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
  --duration 30m \
  --reason "Update AKS node pool"

# Request cluster-admin on Kubernetes (all namespaces)
jitsudo request \
  --provider kubernetes \
  --role cluster-admin \
  --scope "*" \
  --duration 15m \
  --reason "Debug CrashLoopBackOff in kube-system"

# Emergency break-glass (no approver required, sends alerts)
jitsudo request \
  --provider aws \
  --role break-glass-admin \
  --scope 123456789012 \
  --duration 30m \
  --reason "Production down, on-call not responding" \
  --break-glass
```

## Output

```
Request ID: req_01J8KZ4F2EMNQZ3V7XKQYBD4W
State:      PENDING
Provider:   aws
Role:       prod-infra-admin
Scope:      123456789012
```

## Provider-Specific Notes

| Provider | `--role` value | `--scope` value |
|----------|---------------|-----------------|
| `aws` | IAM role name (e.g. `prod-infra-admin`) | AWS account ID (12-digit number) |
| `gcp` | GCP role (e.g. `roles/editor`, `roles/viewer`) | GCP project ID |
| `azure` | Azure built-in role name (e.g. `Contributor`, `Reader`) | Subscription ID (UUID) |
| `kubernetes` | ClusterRole name (e.g. `cluster-admin`, `view`) | Namespace name, or `*` for cluster-wide |

## Break-Glass Mode

Break-glass bypasses the normal approval workflow for emergency scenarios. When `--break-glass` is set:

- The request transitions directly from `PENDING` to `ACTIVE` without approver action.
- All configured notification channels (Slack, email) are immediately alerted.
- The event is recorded in the audit log with `break_glass: true`.

Break-glass is subject to OPA policy enforcement — your organization can restrict which users and roles can use it.
