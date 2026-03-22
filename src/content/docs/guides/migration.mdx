---
title: Migrating to jitsudo
description: Guidance for teams migrating from manual IAM workflows, AWS IAM Identity Center, Azure PIM, or other JIT access tools.
---

import { Aside } from '@astrojs/starlight/components';

## Migration Strategy: Run in Parallel

The safest migration approach is to run jitsudo alongside your existing access mechanisms for an initial period. This lets your team build confidence in the workflow before removing standing permissions.

**Recommended phases:**
1. **Deploy jitsudo** alongside existing access mechanisms (no changes to existing IAM)
2. **Run in parallel** — use jitsudo for new access requests while existing standing permissions remain
3. **Validate** — confirm jitsudo works reliably for your team's actual use cases
4. **Cut over** — remove standing permissions, jitsudo becomes the access path
5. **Decommission** — remove old access mechanisms (SSO integrations, manual IAM workflows)

Phase 1–3 are low-risk. Phase 4 is the transition that requires planning.

---

## Migrating from Manual IAM Workflows

**Current state:** Engineers have standing IAM roles or role assignments that they use directly. Access changes are handled via IAM console, Terraform, or a ticketing system.

### Phase 1–3: Deploy jitsudo alongside existing IAM

```bash
# 1. Deploy jitsudod (see Quickstart or Helm deployment guide)
# 2. Configure providers (see provider guides for AWS/Azure/GCP/K8s)
# 3. Write initial eligibility and approval policies
# 4. Train the team: engineers can request access via jitsudo, but existing
#    standing permissions still work as a fallback
```

During this phase, engineers experience the jitsudo workflow without any disruption risk. Standing permissions remain as a safety net.

### Phase 4: Remove standing permissions

Once the team is comfortable with jitsudo:

```bash
# For each engineer/service account with standing admin access:
# 1. Confirm they have a working jitsudo policy that covers their use cases
# 2. Remove the standing IAM role/policy

# AWS example: detach the standing admin policy
aws iam detach-user-policy \
  --user-name sre-engineer \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Or remove the role assignment from the group/user
```

### Workflow comparison

| Step | Manual IAM | jitsudo |
|------|-----------|---------|
| Need elevated access | File ticket or use console | `jitsudo request --provider aws --role prod-admin --duration 2h` |
| Wait for approval | Email thread, ITSM ticket | Slack notification to approver; `jitsudo approve req_...` |
| Get credentials | Console login or CLI profile switch | `jitsudo exec req_... -- aws ...` |
| Access expires | Manual cleanup (often forgotten) | Automatic expiry at TTL |
| Audit trail | CloudTrail (partial) | jitsudo audit log (every request, approval, expiry) |

---

## Migrating from AWS IAM Identity Center

**Current state:** Using AWS IAM Identity Center (SSO) for console and CLI access. Permission sets control what users can do.

### Key mapping

| IAM Identity Center | jitsudo |
|--------------------|---------|
| Permission set | Role (maps to a target IAM role or permission set) |
| Account assignment | Elevation request + grant |
| Group membership | OPA eligibility policy `user.groups` |
| Session duration | `--duration` on request (TTL) |
| CloudTrail | jitsudo audit log (unified across all providers) |

### Configuration

jitsudo supports IAM Identity Center mode in the AWS provider:

```yaml
providers:
  aws:
    mode: identity_center
    identity_store_id: d-1234567890
    instance_arn: arn:aws:sso:::instance/ssoins-1234567890abcdef
```

With this mode, jitsudo creates and deletes account assignments in IAM Identity Center, rather than assuming roles directly. The user's existing SSO session is used for console access after the grant is issued.

### Running in parallel

jitsudo and IAM Identity Center can run simultaneously. During the transition:
- Use IAM Identity Center for existing standing assignments
- Use jitsudo for new on-demand access requests
- Gradually move permission sets to jitsudo-governed roles

### What jitsudo adds over native IAM Identity Center

- **Multi-cloud**: manage Azure, GCP, and Kubernetes with the same workflow
- **Policy-as-code**: OPA/Rego policies in git, not GUI-only configuration
- **Unified audit log**: single audit trail across all providers
- **Break-glass**: emergency bypass with immediate alerting
- **CLI-first**: `jitsudo exec` injects credentials directly — no console login required
- **Agent-native**: AI agents can request access via MCP

---

## Migrating from Azure PIM

**Current state:** Using Azure AD Privileged Identity Management for role activations.

### Key mapping

| Azure PIM | jitsudo |
|-----------|---------|
| Eligible role | OPA eligibility policy |
| Role activation request | jitsudo request |
| Approver | Policy-designated approver (resolved dynamically) |
| Activation duration | TTL (jitsudo `--duration`) |
| Activation justification | `--reason` |
| PIM audit log | jitsudo audit log |

### Important difference: expiry enforcement

Azure PIM enforces time-bounded assignments natively via PIM APIs. The jitsudo Azure provider creates standard RBAC role assignments and enforces expiry via the expiry sweeper. This means:

- Grants will linger if the jitsudo expiry sweeper is down (unlike PIM which enforces natively)
- This is documented behavior — see [HA and Disaster Recovery](/docs/guides/ha-dr/) for implications

For critical roles, consider setting shorter TTLs in jitsudo to minimize the window of any sweeper delay.

### Running in parallel

Run jitsudo and PIM simultaneously during migration. jitsudo uses different role assignments (created by jitsudo) from PIM (managed by PIM). They do not conflict.

---

## Migrating from GCP JIT Access

**Current state:** Using Google's open source JIT Access tool (deployed as Cloud Run).

### Key differences

| GCP JIT Access | jitsudo |
|---------------|---------|
| GCP-only | Multi-cloud (AWS, Azure, GCP, Kubernetes) |
| Web UI for requests | CLI (`jitsudo request`) + MCP |
| Manual approvals via email/console | Slack notifications + `jitsudo approve` |
| Basic audit | Tamper-evident hash-chain audit log |
| No policy-as-code | OPA/Rego policies in git |

### Configuration

jitsudo's GCP provider uses IAM conditional role bindings — the same mechanism as GCP JIT Access. Native time-bounded expiry via CEL conditions is supported.

```yaml
providers:
  gcp:
    credentials_source: workload_identity_federation  # or service_account_key
    condition_title_prefix: "jitsudo"
```

### Running in parallel

Both tools create conditional IAM bindings. They do not conflict — they use different condition titles to identify their bindings.

---

## Checklist: Ready to Cut Over?

Before removing standing permissions or decommissioning existing tools, verify:

- [ ] jitsudod is running in a production-grade deployment (see [Security Hardening](/docs/guides/security-hardening/))
- [ ] mTLS is enabled
- [ ] PostgreSQL is on a managed HA service with automated backups
- [ ] All provider configurations have been validated with real requests
- [ ] Eligibility and approval policies cover all existing access patterns
- [ ] The team is trained on `jitsudo request`, `jitsudo approve`, and `jitsudo exec`
- [ ] Break-glass procedure is documented and tested
- [ ] Monitoring is in place for jitsudod health
- [ ] Runbooks are reviewed (see [Runbooks](/docs/guides/runbooks/))
