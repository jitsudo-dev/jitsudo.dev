---
title: System Overview
description: Architecture overview of the jitsudo system.
---

jitsudo follows the same architectural principles as Kubernetes: a versioned API server (control plane) that all clients interact with through a stable, authenticated API.

## Components

```
REQUESTORS                              APPROVERS (Milestone 4)
──────────                              ────────────────────────
jitsudo CLI ──┐                         OPA (Tier 1, auto)
              │                         AI agent via MCP (Tier 2)
MCP server ───┤── gRPC / REST (mTLS) ──▶ Human via Slack/CLI (Tier 3)
  (requestor) │
Slack bot ────┘

┌──────────────────────────────────────────────────────────────┐
│                  jitsudod Control Plane                      │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ Auth/OIDC   │  │ Policy Engine│  │  Request Manager   │  │
│  │ (SSO bridge)│  │ (OPA) + Tier │  │  (state machine +  │  │
│  │             │  │   Router     │  │   approval routing)│  │
│  └─────────────┘  └──────────────┘  └────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐     │
│  │              Provider Adapter Layer                 │     │
│  │   [AWS]    [Azure]    [GCP]    [Kubernetes]         │     │
│  └─────────────────────────────────────────────────────┘     │
│  ┌──────────────┐  ┌──────────────────────────────────┐      │
│  │  Audit Log   │  │   Notification Dispatcher        │      │
│  │ (SHA-256     │  │  (Slack / email / webhook)       │      │
│  │  hash chain) │  │                                  │      │
│  └──────────────┘  └──────────────────────────────────┘      │
│  ┌───────────────────────────────────────────────────────┐   │
│  │                     PostgreSQL                        │   │
│  └───────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┬──────────────┐
        ▼              ▼              ▼              ▼
    AWS IAM         Azure RBAC     GCP IAM      K8s RBAC
```

The MCP server serves two distinct roles: as a **requestor** (agents submit elevation requests on their own behalf) and as an **approver** (AI agents evaluate pending requests and approve, deny, or escalate). See [Approval Model](/docs/architecture/approval-model/) for the full design and risk asymmetry between these roles.

## Kubernetes Analogy

| Kubernetes | jitsudo | Description |
|-----------|---------|-------------|
| `kube-apiserver` | `jitsudod` | The authoritative control plane |
| `kubectl` | `jitsudo` CLI | The primary human-operated client |
| Kubelet, operators | Approval bots, webhooks | Programmatic clients using the same API |
| RBAC | OPA policy engine | Defines who can do what |
| etcd | PostgreSQL | Persistent state store |

## Key Principle: CLI Has No Backdoors

The CLI interacts with the control plane exclusively through the public API. There are no internal RPCs, privileged endpoints, or out-of-band communication paths available to the CLI that are not also available to any other authenticated HTTP client.
