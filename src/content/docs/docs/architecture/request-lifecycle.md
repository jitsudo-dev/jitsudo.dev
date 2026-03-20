---
title: Request Lifecycle
description: How elevation requests move through the jitsudo state machine.
---

## State Machine

```
           ┌──────────┐
           │ PENDING  │  ← Request submitted, awaiting approval
           └────┬─────┘
                │
       ┌────────┴────────┐
       ▼                 ▼
  ┌─────────┐       ┌──────────┐
  │APPROVED │       │ REJECTED │  (terminal)
  └────┬────┘       └──────────┘
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

## Transition Rules

- No state can be skipped
- Terminal states (REJECTED, EXPIRED, REVOKED) cannot transition to any other state
- Every transition writes an immutable audit log entry **before** the state is updated (write-ahead audit log pattern)
- State transitions use database transactions with row-level locking to prevent race conditions

## Break-Glass Mode

Break-glass is a special request mode for emergency situations where waiting for approver action is not acceptable.

- Invoked with `jitsudo request --break-glass`
- Transitions directly from PENDING to ACTIVE (bypasses approval)
- Triggers immediate high-priority alerts to all configured notification channels
- Prominently flagged in audit reports
- Eligibility for break-glass is controlled by policy (not all users may invoke it)
