---
title: Approval Model
description: The three-tier approval architecture, dynamic approver resolution, and MCP dual-role design.
---

## Dynamic Approver Resolution

A common misconception about approval workflows is that approvers are fixed — a named person, a specific manager, a standing "approver" role. In jitsudo, this is explicitly not the case.

**Approvers are resolved dynamically at request time by the OPA policy engine.** The policy engine evaluates the request and returns who — or what — should make the approval decision for this specific request, at this moment, given current group membership and context.

```rego
# For prod-infra-admin in AWS, require approval from the sre-leads group.
# Whoever is in that group tonight is the approver.
approver_group := "sre-leads" if {
    input.request.provider == "aws"
    input.request.role == "prod-infra-admin"
}
```

jitsudod resolves this policy to the current members of `sre-leads` and notifies them. If Alice is on call tonight, she gets the notification. If Bob takes over tomorrow, he does. **No one holds a standing "approver" title** — approval authority is itself a narrow, policy-governed privilege.

This is a critical security property: if approval authority were tied to a standing admin role, the persistent privilege problem would simply move one level up.

## Three-Tier Approval Model

All approval routing is governed by OPA policy. The policy engine assigns each request to one of three tiers based on the request attributes and the requesting principal's trust tier.

### Tier 1 — Auto-approve (OPA only)

| Attribute | Value |
|-----------|-------|
| Decision maker | OPA policy engine — no AI, no human |
| Latency | Milliseconds |
| Typical use | Read-only scoped operations, high-trust-tier principals, business hours |
| Example | Trust tier 3+ requesting `s3:GetObject` for 15 minutes during business hours |
| Policy signal | `approver_tier: "auto"` |

Tier 1 makes the "sudo for your cloud" promise real for low-risk workflows. A senior SRE requesting read-only access to an S3 bucket during business hours should not require a human approver — the policy engine can make that call in milliseconds.

### Tier 2 — AI-assisted review (MCP approver)

| Attribute | Value |
|-----------|-------|
| Decision maker | AI approval agent via MCP, with escalation path to Tier 3 |
| Latency | Seconds |
| Typical use | Medium-risk requests where context synthesis reduces approval toil |
| Example | SRE requesting `prod-db-readonly` during an active incident (linked ticket) |
| Policy signal | `approver_tier: "ai_review"` |
| AI inputs | Request details, linked incident tickets, principal trust history, blast radius, time context |
| AI outputs | `approve`, `deny`, or `escalate: {reason, recommendation}` |
| Failure posture | On uncertainty or model error → **always escalate to Tier 3**, never silently approve or deny |

The AI approver reduces approval toil for medium-risk requests by synthesizing context a human approver would need to evaluate manually. It surfaces that context with a recommendation — but a human can always override.

### Tier 3 — Human approval required

| Attribute | Value |
|-----------|-------|
| Decision maker | Policy-designated human approver |
| Latency | Minutes (async) |
| Typical use | High-risk operations; anything the AI tier escalated |
| Example | `cluster-admin` on prod Kubernetes, cross-account IAM changes, billing access |
| Policy signal | `approver_tier: "human"` |
| Notification | Slack DM + channel alert with full context; AI recommendation if escalated from Tier 2 |

### Break-glass

Break-glass is not a tier — it is an emergency bypass mechanism for situations where the approval workflow itself would cause harm (a P0 incident at 3 AM with no approvers reachable). Break-glass bypasses all tiers, issues credentials immediately, and fires high-priority alerts. See [Request Lifecycle](/docs/architecture/request-lifecycle/) for details.

## Tier Routing by OPA Policy

Approval policies return `approver_tier` as a first-class output, routing the request to the correct approval path:

```rego
package jitsudo.approval

import future.keywords.if
import future.keywords.in

read_only_roles := {"prod-read-only", "roles/viewer", "view", "s3-readonly"}

# Tier 1: auto-approve for low-risk, high-trust requests
approver_tier := "auto" if {
    input.context.trust_tier >= 3
    input.request.role in read_only_roles
    time_within_business_hours
    input.request.duration_seconds <= 1800
}

# Tier 2: AI review when an active incident is linked
approver_tier := "ai_review" if {
    not tier1_conditions
    not high_risk_role
    active_incident_linked(input.request.reason)
}

# Tier 3: human approval for everything else (catch-all)
approver_tier := "human" if {
    not tier1_conditions
    not tier2_conditions
}

high_risk_role if {
    input.request.role in {"prod-infra-admin", "cluster-admin", "billing-admin"}
}
```

## Tier Interaction at Runtime

```
Request submitted
      │
      ▼
   OPA evaluates eligibility + approver_tier
      │
  ┌───┴─────────────────────────────────┐
  │                                     │
  ▼                                     ▼
Tier 1 (auto)                     Tier 2 or Tier 3
PENDING → ACTIVE                  Route to approver
(milliseconds)
                        Tier 2: AI agent evaluates
                          ├── approve → APPROVED → ACTIVE
                          ├── deny    → REJECTED  (logged with reasoning)
                          └── escalate → Tier 3   (with recommendation)

                        Tier 3: human notified (Slack / CLI)
                          ├── approve → APPROVED → ACTIVE
                          └── deny    → REJECTED  (logged)
```

## Principal Trust Tiers

Trust tiers quantify how much a principal's identity and history is trusted by the policy engine. They are assigned during principal enrollment and exposed as `input.context.trust_tier` in all OPA policy evaluations.

| Tier | Description | Typical profile |
|------|-------------|----------------|
| 0 | Unknown or unverified identity | Service accounts pending review |
| 1 | Verified identity, newly enrolled | New employee, first 30 days |
| 2 | Established principal, standard risk | Regular team member |
| 3 | High-trust principal | Senior SRE, team lead; eligible for Tier 1 auto-approve on low-risk ops |
| 4 | Break-glass eligible; highest trust | On-call lead, security team; audited separately |

Trust tier assignment is managed by the jitsudo administrator via the `SetPrincipalTrustTier` API (requires the `jitsudo-admins` group). Tier values are durable per principal, stored in the `principals` table, and updated on enrollment or role change. The trust tier is automatically surfaced as `input.context.trust_tier` in every OPA eligibility and approval evaluation. See [Admin Bootstrap](/docs/cli/server/#admin-bootstrap) for how to enroll the first administrator.

```bash
# Set trust tier for a principal (admin only)
curl -X PUT https://jitsudod:8080/api/v1alpha1/principals/alice@example.com/trust-tier \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"trust_tier": 3}'
```

## MCP Server: Dual Role Architecture

The MCP (Model Context Protocol) server serves two distinct roles in the jitsudo architecture. This distinction matters for both security design and operational configuration.

### MCP as Requestor

An AI agent calls the jitsudo MCP server to submit an elevation request on its own behalf. The agent is the **principal** — it is requesting access, not granting it.

- The agent's identity is authenticated via OIDC (same as a human user)
- OPA evaluates eligibility and routes the request through the normal approval workflow
- A misbehaving agent can only submit a bad *request* — the approval workflow still gates it

### MCP as Approver

An AI agent acts as a **policy-execution and triage layer** between a pending request and a human approver. The agent evaluates the request against contextual signals and emits one of three outcomes: approve, deny, or escalate to human with a recommendation.

This is the Tier 2 path in the three-tier model.

### Risk Asymmetry

| Role | Failure mode | Blast radius |
|------|-------------|--------------|
| MCP as requestor | Submits a bad request | **Low** — OPA + approval workflow still gates it |
| MCP as approver | Approves a bad request | **High** — bypasses human safety layer |

Because of this asymmetry, the MCP approver has stricter requirements than the requestor:

1. **Failure posture**: On uncertainty or model error, always escalate to Tier 3 — never auto-approve or auto-deny silently
2. **Audit trail**: Every AI approval decision must include the model's reasoning, not just the outcome
3. **Override**: Humans must be able to revoke any AI-approved grant immediately
4. **Scope**: The MCP approver tool surface is separate from the requestor tool surface — these are not the same MCP server tools
