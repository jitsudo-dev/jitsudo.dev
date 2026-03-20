---
title: System Overview
description: Architecture overview of the jitsudo system.
---

jitsudo follows the same architectural principles as Kubernetes: a versioned API server (control plane) that all clients interact with through a stable, authenticated API.

## Components

```
┌─────────────────────────────────────────────────────────────┐
│                     jitsudo CLI                             │
│           (Go, distributed as a single binary)              │
└──────────────────────┬──────────────────────────────────────┘
                       │ gRPC / REST (mTLS)
┌──────────────────────▼──────────────────────────────────────┐
│                jitsudod Control Plane                       │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ Auth/OIDC   │  │ Policy Engine│  │  Request Manager  │  │
│  │ (SSO bridge)│  │    (OPA)     │  │  (state machine)  │  │
│  └─────────────┘  └──────────────┘  └───────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Provider Adapter Layer                 │    │
│  │   [AWS]    [Azure]    [GCP]    [Kubernetes]         │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌──────────────┐  ┌──────────────────────────────────┐     │
│  │  Audit Log   │  │   Notification Dispatcher        │     │
│  │ (append-only)│  │  (Slack / email / webhook)       │     │
│  └──────────────┘  └──────────────────────────────────┘     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                  PostgreSQL                          │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┬──────────────┐
        ▼              ▼              ▼              ▼
    AWS IAM         Azure RBAC     GCP IAM      K8s RBAC
```

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
