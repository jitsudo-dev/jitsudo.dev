---
title: How jitsudo Compares
description: How jitsudo fits in the JIT PAM landscape — cloud-native tools, commercial PAM, and why multi-cloud teams need a different approach.
---

## The JIT Access Landscape

JIT (Just-In-Time) privileged access tools exist in three broad categories:

1. **Cloud-native JIT** — built by cloud providers for their own IAM systems
2. **Commercial PAM** — enterprise products with JIT as one feature among many
3. **Open source, self-hosted** — jitsudo

Each has a different design center, and the right tool depends on your environment.

---

## Cloud-Native JIT: Great for One Cloud

Cloud providers offer native JIT tools:

| Tool | Provider | License |
|------|----------|---------|
| IAM Identity Center (temporary elevations) | AWS | Proprietary |
| Privileged Identity Management (PIM) | Azure | Requires Entra ID P2 |
| Privileged Access Manager (PAM) | GCP | Proprietary |

These tools are excellent if you live in a single cloud. They're tightly integrated with that provider's IAM model, audit trail, and console experience.

**The problem**: most infrastructure teams don't live in one cloud.

If your team runs on AWS for production, GCP for ML workloads, and Kubernetes for internal tools, you have three separate access workflows, three audit trails, and three sets of approval processes. There is no unified view of who has elevated access to what, across all environments.

jitsudo is designed for this reality:
- Single control plane across AWS, Azure, GCP, and Kubernetes
- Unified audit log for every request, approval, and expiry — regardless of provider
- One CLI, one policy language, one approval workflow

---

## Commercial PAM: Powerful but Heavy

Enterprise PAM platforms (CyberArk, BeyondTrust, StrongDM, Teleport) are powerful, comprehensive tools. They cover session recording, bastion host functionality, credential vaulting, compliance reporting, and JIT access — all in one product.

**The trade-offs:**

- **SaaS dependency**: most commercial PAM tools are cloud-hosted. Your access control plane lives outside your infrastructure.
- **Proprietary configuration**: policies and workflows are configured through GUI or proprietary DSLs, not code.
- **Cost**: enterprise PAM is typically per-seat or per-resource licensed, with costs that scale significantly.
- **Complexity**: full PAM suites are multi-week implementations. jitsudo can be operational in a day.
- **Not agent-native**: none of these tools were designed with AI agents as first-class requestors or approvers.

**A note on Teleport.** Teleport deserves specific mention because it is open source, has a strong CLI (`tsh`), and is widely used in infrastructure teams. It is an excellent tool — for a different problem. Teleport is primarily a **network access and session recording** platform: it manages access to servers, databases, Kubernetes clusters, and internal web apps via its proxy model. It does not manage cloud IAM role assignments (AWS IAM roles, Azure RBAC, GCP IAM). If your threat model centers on audited network access and session recording, Teleport is a good choice. If it centers on temporary cloud IAM privilege elevation with policy-as-code approval workflows, that is jitsudo's problem space. Many teams use both.

jitsudo's position: **not a full PAM suite**. jitsudo does JIT access management well. It does not do session recording, VPN, credential vaulting, or bastion host functionality — those are separate tools with separate jobs. See [What jitsudo is NOT](/docs/what-is-jitsudo/#what-jitsudo-is-not).

---

## HashiCorp Vault Dynamic Secrets

Vault's dynamic secrets engine generates short-lived credentials on demand for databases, cloud providers, and other systems. It solves a related but different problem.

| Dimension | Vault dynamic secrets | jitsudo |
|-----------|----------------------|---------|
| What it manages | Credentials / secrets | IAM role assignments / permission grants |
| Approval workflow | None (policy-gated issuance) | Optional human or AI approval step |
| Audit trail | Vault audit log | jitsudo tamper-evident audit log |
| Multi-cloud | Yes (via plugins) | Yes (native AWS/Azure/GCP/K8s) |
| Break-glass | N/A | Built-in with alerting |

Vault and jitsudo are complementary. Vault manages the credentials jitsudod uses to call cloud provider APIs. jitsudo manages the human (and agent) approval workflow for elevated access grants.

---

## Why jitsudo for Multi-Cloud Teams

jitsudo's design decisions favor teams that:

| Need | jitsudo approach |
|------|-----------------|
| Multi-cloud coverage | Native AWS, Azure, GCP, Kubernetes providers; one control plane |
| Self-hosted, no SaaS | Deploy on your own infrastructure; no external dependency |
| Policy-as-code | OPA/Rego policies in git; version-controlled, reviewable, testable |
| CLI-first workflows | `jitsudo exec` injects credentials into any subprocess |
| AI agent access | MCP interface for agents as first-class requestors and approvers |
| Audit integrity | SHA-256 hash chain; tamper-evident; exportable to SIEM |
| Open source | Apache 2.0 CLI/SDK; ELv2 control plane (free for self-hosted use) |

---

## The Agentic Access Gap

In 2026, every infrastructure team is grappling with AI agents that need cloud access. The existing tool landscape was not designed for this.

**The problem with persistent credentials for AI agents:**
- An agent with standing admin access has unlimited blast radius on any model error, prompt injection, or unexpected behavior
- Audit trails for agent actions are inconsistent — who approved this? what reasoning was used?
- Existing PAM tools have no concept of an AI agent as a principal or approver

**jitsudo's approach:**
- **Agents as requestors**: the MCP server interface lets any AI agent request JIT elevation on its own behalf, subject to the same OPA eligibility and approval workflow as humans. A misbehaving agent can only submit a request — the approval workflow still gates it.
- **Agents as approvers**: the MCP approver interface lets an AI agent evaluate pending requests against contextual signals and approve, deny, or escalate. Every AI approval includes the model's reasoning in the audit log. Uncertainty always routes to human escalation.

No existing open source JIT PAM tool was built with AI agents as first-class participants in the access workflow. This is jitsudo's differentiated position.

---

## Summary Table

| Dimension | jitsudo | AWS IAM Identity Center | Azure PIM | GCP PAM | Teleport | CyberArk / BeyondTrust |
|-----------|---------|------------------------|-----------|---------|----------|----------------------|
| Multi-cloud IAM JIT | ✓ | AWS only | Azure only | GCP only | ✗ (network access) | ✓ |
| Self-hosted | ✓ | ✗ (AWS-managed) | ✗ (Azure-managed) | ✗ (GCP-managed) | ✓ | ✓ (on-prem) |
| Open source | ✓ | ✗ | ✗ | ✗ | ✓ (Apache 2.0) | ✗ |
| Policy-as-code | ✓ (OPA/Rego) | Limited | GUI only | Limited | Partial (YAML RBAC) | GUI/proprietary |
| AI agent native | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| CLI-first | ✓ | Partial | ✗ | Partial | ✓ (tsh) | ✗ |
| Session recording | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Bastion host | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |
| License | ELv2 (free self-hosted) | Included with AWS | Requires Entra P2 | Usage-based | Apache 2.0 / Enterprise | Per-seat enterprise |
