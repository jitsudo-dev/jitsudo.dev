---
title: What is jitsudo?
description: JIT privileged access management for AWS, Azure, GCP, and Kubernetes — built for security teams, SREs, and the AI agents that work alongside them.
---

## The Security Problem

Standing admin access is the single largest avoidable source of blast radius in cloud environments. When engineers hold persistent elevated permissions — even ones granted with good intentions — every compromised credential, phishing attack, or insider incident has immediate, unlimited scope.

Security teams know this. The principle of least privilege is a foundational control. The problem has never been the principle — it has been the operational friction of actually enforcing it. When granting temporary access takes longer than the incident demands, engineers route around the process.

**jitsudo makes the secure path the easy path.** Temporary, time-limited, approved, fully audited access — on every cloud, from a single CLI — fast enough to use in a P1 incident.

## What jitsudo Does

jitsudo is an open source, cloud-agnostic Just-In-Time (JIT) privileged access management (PAM) system. It replaces standing admin roles with on-demand elevation requests that:

- **Expire automatically** at a configured TTL (no forgotten role assignments)
- **Require approval** from a policy-designated approver before credentials are issued
- **Write a tamper-evident audit trail** of every request, approval, denial, and expiry
- **Work across all four major cloud providers** from a single control plane

```
SRE:       jitsudo request --provider aws --role prod-infra-admin --duration 2h \
             --reason "Investigating P1 ECS crash - INC-4421"

           ✓ Request submitted (ID: req_01J8KZ...)
           ⏳ Awaiting approval — notified: on-call SRE lead (sre-leads group)

Approver:  jitsudo approve req_01J8KZ...

           ✓ Approved. Credentials active for 2 hours.

SRE:       jitsudo exec req_01J8KZ... -- aws ecs describe-tasks --cluster prod

           # 2 hours later — credentials automatically revoked
           # Audit log entry written: grant.expired
```

Approvers are resolved dynamically by the OPA policy engine at request time — whoever currently satisfies the approval policy for this request type. Approval authority is a narrow, policy-governed privilege, not standing admin access.

## Who It's For

| Audience | Problem jitsudo solves |
|----------|----------------------|
| **Security teams / CISOs** | Eliminate standing admin as a persistent attack surface; enforce least privilege with full audit trail |
| **SREs / on-call engineers** | Get the access you need in seconds during an incident, without a manual IAM change request |
| **Multi-cloud infrastructure teams** | One access workflow across AWS, Azure, GCP, and Kubernetes |
| **AI/ML teams deploying agents** | Give AI agents cloud access with the same approval and audit controls as humans — no persistent credentials |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Elevation Request** | A request for temporary elevated access to a cloud resource |
| **Provider** | A cloud platform adapter (AWS, Azure, GCP, Kubernetes) |
| **Role** | An abstract permission set mapped to provider-specific roles |
| **Scope** | The resource boundary (AWS account ID, GCP project, K8s namespace) |
| **Eligibility Policy** | OPA/Rego policy: who can request which roles, for how long |
| **Approval Policy** | OPA/Rego policy: who must approve, and under what conditions |
| **Trust Tier** | A principal's trust level (0–4), used by policy to gate auto-approval and access scope |
| **Break-glass** | Emergency access that bypasses approval with immediate alerts and mandatory review |
| **Audit Log** | Tamper-evident, append-only record of every action (SHA-256 hash chain) |

## Current Status

jitsudo currently implements **Tier 3 human approval** and **break-glass** emergency access. The full three-tier approval model — including Tier 1 (OPA-driven auto-approve) and Tier 2 (AI-assisted review via MCP) — is the target architecture and is planned for [Milestone 4](/roadmap/).

| Tier | Decision maker | Status |
|------|---------------|--------|
| **Tier 1** | OPA policy (auto-approve for low-risk, high-trust requests) | Milestone 4 |
| **Tier 2** | AI agent via MCP (approve, deny, or escalate with reasoning) | Milestone 4 |
| **Tier 3** | Policy-designated human approver | **Available now** |
| **Break-glass** | Requester-initiated emergency bypass (immediate alerts) | **Available now** |

See [Approval Model](/docs/architecture/approval-model/) for the full architecture specification.

## What jitsudo is NOT

- **Not a secrets manager** — use HashiCorp Vault or your cloud provider's secrets manager for credential storage
- **Not a network access tool** — use Teleport or HashiCorp Boundary for VPN, SSH, or RDP access
- **Not an identity provider** — jitsudo delegates identity to your existing IdP (Okta, Entra ID, Keycloak, Google Workspace)
- **Not a compliance platform** — jitsudo produces the audit data; SIEM and compliance tools consume it
- **Not a session recorder** — jitsudo gates access; use your provider's native session logging or a dedicated session recording tool
- **Not a bastion host or jump server** — jitsudo manages permission grants, not network paths to resources
- **Not a VPN or zero-trust network access tool** — jitsudo manages cloud IAM, not network connectivity
