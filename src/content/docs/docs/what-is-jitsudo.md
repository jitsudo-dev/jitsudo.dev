---
title: What is jitsudo?
description: An introduction to jitsudo — cloud-agnostic JIT privileged access management.
---

**jitsudo** is an open source, cloud-agnostic, CLI-first Just-In-Time (JIT) privileged access management tool for infrastructure administrators and SREs.

The name combines **JIT** (Just-In-Time) and **sudo** — the Unix privilege escalation utility familiar to every engineer in the target audience. The martial arts connotation reinforces the project's philosophy: controlled, precise, defensive access — not blunt, always-on permissions.

## The Problem

Modern cloud environments operate on the principle of least privilege. In practice, this principle is routinely violated because:

- Granting temporary elevated access is operationally painful — manual IAM changes that are often forgotten and never revoked
- Engineers in on-call rotations need access *now*, not after a multi-step IAM workflow
- Standing admin permissions accumulate over time through role assignment and permission creep
- Each cloud provider has its own native JIT tooling, creating fragmented workflows for multi-cloud teams

The result: engineers end up with broad standing admin permissions "just in case," dramatically expanding the blast radius of credential compromise, insider threats, and human error.

## The Solution

jitsudo makes the secure path — time-limited, approved, audited elevation — as frictionless as running `sudo` on a Linux system.

```
SRE:    jitsudo request --provider aws --role prod-infra-admin --duration 2h \
          --reason "Investigating P1 ECS crash - INC-4421"

        ✓ Request submitted (ID: req_01J8KZ...)
        ⏳ Awaiting approval from: @alice (eng-lead)

Alice:  jitsudo approve req_01J8KZ...

SRE:    jitsudo exec req_01J8KZ... -- aws ecs describe-tasks --cluster prod

        # 2 hours later, credentials are automatically revoked
```

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Elevation Request** | A request for temporary elevated access to a cloud resource |
| **Provider** | A cloud platform adapter (AWS, Azure, GCP, Kubernetes) |
| **Role** | An abstract permission set mapped to provider-specific roles |
| **Scope** | The resource boundary (AWS account ID, GCP project, K8s namespace) |
| **Eligibility Policy** | Who can request which roles, for how long |
| **Approval Policy** | Who must approve, and under what conditions auto-approval is permitted |
| **Break-glass** | Emergency access that bypasses approval with immediate alerts |
| **Audit Log** | Tamper-evident, append-only record of every action |

## What jitsudo is NOT

- **Not a secrets manager** — use HashiCorp Vault or your cloud provider's secrets manager
- **Not a network access tool** — use Teleport or HashiCorp Boundary for VPN/SSH/RDP
- **Not an identity provider** — jitsudo delegates identity to your existing IdP
- **Not a compliance platform** — jitsudo integrates with SIEM tools rather than replacing them
