---
title: Request Lifecycle
description: How elevation requests move through the jitsudo state machine, including the three-tier approval routing model.
---

import { Aside } from '@astrojs/starlight/components';

## State Machine

```
           ┌──────────┐
           │ PENDING  │  ← Request submitted, awaiting approval routing
           └────┬─────┘
                │
                │ OPA evaluates approver_tier
                │
  ┌─────────────┼──────────────┐
  │             │              │
  ▼             ▼              ▼
Tier 1       Tier 2         Tier 3
(auto)      (ai_review)    (human)
  │             │              │
  │         AI evaluates    Approver
  │         ┌──┤             action
  │         ▼  ▼
  │      approve / escalate ──→ Tier 3
  │
  ▼
┌─────────┐        ┌──────────┐
│APPROVED │        │ REJECTED │  (terminal)
└────┬────┘        └──────────┘
     │  Provider Grant() called
     ▼
┌─────────┐
│ ACTIVE  │  ← Credentials issued, elevation in effect
└────┬────┘
     │
┌────┴──────────────┐
▼                   ▼
┌──────────┐    ┌──────────┐
│ EXPIRED  │    │ REVOKED  │  ← Early revocation by admin or requester
│(terminal)│    │(terminal)│
└──────────┘    └──────────┘
```

## Approval Tiers

The OPA policy engine routes each request to one of three approval paths immediately after submission. The routing decision is based on the request attributes and the requesting principal's trust tier.

| Tier | Who decides | When used |
|------|------------|-----------|
| **Tier 1** | OPA policy (auto) | Low-risk operations, high-trust principals |
| **Tier 2** | AI agent via MCP | Medium-risk with active incident context |
| **Tier 3** | Policy-designated human | High-risk operations; Tier 2 escalations |

## Transition Rules

- No state can be skipped
- Terminal states (REJECTED, EXPIRED, REVOKED) cannot transition to any other state
- Every transition writes an immutable audit log entry **before** the state is updated (write-ahead audit log pattern)
- State transitions use database transactions with row-level locking to prevent race conditions

## Break-Glass Mode

Break-glass is a special request mode for emergency situations where waiting for approver action is not acceptable.

- Invoked with `jitsudo request --break-glass`
- Transitions directly from PENDING to ACTIVE (bypasses all approval tiers)
- Triggers immediate high-priority alerts to all configured notification channels
- Prominently flagged in audit reports
- Eligibility for break-glass is controlled by policy (not all users may invoke it)
- Full audit trail is preserved — break-glass does not bypass logging
