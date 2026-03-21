---
title: Frequently Asked Questions
description: Answers to the most common questions from security teams, CISOs, and technical evaluators considering jitsudo.
---

## Licensing and Adoption

### Can we self-host jitsudo for free at our company?

**Yes.** jitsudod is licensed under the [Elastic License v2 (ELv2)](/docs/reference/licensing/), which explicitly permits self-hosted internal use at no cost. You can run jitsudod on your own infrastructure, connect it to your cloud providers, and use it for your engineering team without purchasing a license.

The CLI, client library, and provider packages are Apache 2.0 — fully permissive.

See [Licensing](/docs/reference/licensing/) for the full breakdown and FAQ, including the managed-service restriction.

---

## Security Architecture

### Should jitsudod be exposed to the internet?

**No.** jitsudod should run inside a private network segment, reachable only through a VPN or zero-trust network access tool. A public-facing jitsudod creates unnecessary attack surface for a service that holds the keys to your cloud IAM.

See [Security Hardening](/docs/guides/security-hardening/) for the recommended network architecture.

### What does "tamper-evident audit log" actually mean?

It means every audit log entry is linked to the previous one by a SHA-256 hash. Each entry stores the hash of its predecessor (`prev_hash`), forming a chain. If any historical entry is modified, deleted, or inserted out of order, the chain breaks — and the discrepancy is detectable by recomputing and comparing the hashes.

This is the same principle used in blockchain and certificate transparency logs. It is **not** write-once storage (WORM), but it provides a strong cryptographic guarantee that modifications cannot go undetected.

```bash
# Verify the full hash chain
jitsudo audit verify
```

See [Audit Log](/docs/reference/audit-log/) for the schema, chain format, and verification script.

### What IAM permissions does jitsudo need in my AWS account?

For the STS AssumeRole mode (default), jitsudod needs:

- `sts:AssumeRole` on each target role (granted via the role's trust policy)
- `iam:PutRolePolicy` on each target role (for revocation — attaches a deny policy on early revocation)

jitsudod does **not** need IAM admin permissions, `iam:CreateRole`, or `iam:AttachRolePolicy`. It only needs the specific permissions above on the specific roles it manages.

See the [AWS Provider guide](/docs/guides/providers/aws/) for trust policy format, IRSA setup, and full configuration details.

### How are approvers determined? Is it a fixed person or role?

Approvers are resolved **dynamically at request time** by the OPA policy engine. No person holds a standing "approver" title. The policy engine evaluates the request and returns which group or individual must approve — whoever currently satisfies the policy.

```rego
# Tonight it's whoever is in sre-leads. Tomorrow it might be someone else.
approver_group := "sre-leads" if {
    input.request.provider == "aws"
    input.request.role == "prod-infra-admin"
}
```

This is intentional: approval authority is a narrow, auditable privilege governed by policy — not a standing admin right.

See [Approval Model](/docs/architecture/approval-model/) for the full design.

---

## Availability and Operations

### What happens if jitsudod goes down?

jitsudod is **fail-closed** for new requests. If all instances are unavailable, engineers cannot submit new elevation requests or approve pending ones. This is intentional — an unreachable access control system should not silently grant access.

Existing active grants (credentials already issued by the cloud provider) are unaffected. They remain valid until their natural TTL expiry. The credentials are held by the cloud provider, not jitsudod.

For emergency access when the control plane is unavailable, engineers must use the cloud provider's IAM console directly. See [HA and Disaster Recovery](/docs/guides/ha-dr/) for the full failure mode analysis and break-glass procedure.

### Can jitsudo be deployed in a high-availability configuration?

**Yes, today.** jitsudod is stateless — all state lives in PostgreSQL. You can run multiple instances behind an internal load balancer, sharing the same database, right now. PostgreSQL advisory locks handle leader election for background jobs.

Formal HA engineering with HPA, PodDisruptionBudget, and documented PostgreSQL replication topology is on the [Milestone 4 roadmap](/roadmap/).

See [HA and Disaster Recovery](/docs/guides/ha-dr/) for current deployment guidance.

---

## Features and Roadmap

### Does jitsudo support auto-approval today?

**Not yet.** The current release implements **Tier 3 (human approval)** and **break-glass** emergency access. Policy-driven auto-approval (Tier 1) and AI-assisted review (Tier 2) are planned for [Milestone 4](/roadmap/).

The three-tier approval model is the locked architectural target — the design is complete, the implementation is scheduled.

See [Approval Model](/docs/architecture/approval-model/) for the design spec.

### Can AI agents use jitsudo?

**Yes — as requestors, today.** The MCP server interface lets AI agents submit elevation requests on their own behalf, subject to the same OPA eligibility and approval workflow as human users. An agent can only submit a request — a human or policy still gates the grant.

**As approvers, in Milestone 4.** The MCP approver interface will allow an AI agent to evaluate pending requests against contextual signals (linked incident tickets, trust history, blast radius) and approve, deny, or escalate to a human with a recommendation. The AI approver always fails to human escalation on uncertainty — it cannot silently auto-approve on model error.

### How does jitsudo compare to AWS IAM Identity Center / Azure PIM / GCP PAM?

Cloud-native JIT tools are excellent if you live in one cloud. jitsudo's key differentiators:

- **Cloud-agnostic**: single control plane across AWS, Azure, GCP, and Kubernetes
- **Policy-as-code**: OPA/Rego policies version-controlled in git — not GUI-only configuration
- **Self-hosted**: no SaaS dependency, no cloud vendor lock-in for your access control plane
- **Agent-native**: MCP interface for AI agents as first-class requestors and approvers
- **CLI-first**: `jitsudo exec` injects credentials directly — no console login required

See [How jitsudo Compares](/docs/guides/comparison/) for a full side-by-side analysis.

### Is jitsudo production-ready?

jitsudo has completed [Milestone 3](/roadmap/), which includes:
- Full provider coverage (AWS, Azure, GCP, Kubernetes)
- Production deployment options (Helm chart, single-server bootstrap)
- mTLS for gRPC
- Integration test suite
- Comprehensive documentation

What is not yet production-ready (and should be on your radar):
- **Auto-approval (Tier 1 and Tier 2)**: planned for Milestone 4
- **Formal HA engineering**: run multiple instances today; HPA/PDB documentation in Milestone 4
- **SIEM connectors**: JSON export available now; dedicated Splunk/Datadog connectors in Milestone 4

Teams evaluating jitsudo for production should read the [Security Hardening Guide](/docs/guides/security-hardening/) and the [HA and Disaster Recovery](/docs/guides/ha-dr/) page before deploying.
