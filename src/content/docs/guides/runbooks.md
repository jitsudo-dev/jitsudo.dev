---
title: Operational Runbooks
description: Step-by-step runbooks for common jitsudo operational scenarios — emergency policy override, certificate rotation, database recovery, and break-glass procedures.
---

import { Aside } from '@astrojs/starlight/components';

## Runbook 1: Emergency Policy Override (All Users Locked Out)

**Symptom:** A policy change has locked out all users — every request returns `not authorized`. No one can submit requests or approve them.

**Cause:** A misconfigured eligibility policy with default `allow = false` that does not match any legitimate request.

### Recovery

```bash
# 1. Identify the broken policy
jitsudo policy list

# 2. Option A: Disable the broken policy
jitsudo policy update --name broken-policy --enabled false
jitsudo server reload-policies

# 3. Verify access is restored
jitsudo policy eval \
  --type eligibility \
  --input '{"user":{"email":"admin@example.com","groups":["sre"]},"request":{"provider":"aws","role":"prod-infra-admin","resource_scope":"123456789012","duration_seconds":3600}}'
```

If `jitsudo` CLI access is also broken (can't authenticate):

```bash
# 4. Option B: Direct database update (last resort)
# Set enabled = false on all eligibility policies temporarily
psql "$DATABASE_URL" << 'EOF'
UPDATE policies SET enabled = false WHERE type = 'ELIGIBILITY';
EOF

# 5. Restart jitsudod to pick up the change
kubectl rollout restart deployment/jitsudod

# 6. Re-apply the correct policy via CLI
jitsudo policy apply -f correct-eligibility.rego --type eligibility

# 7. Re-enable remaining policies
psql "$DATABASE_URL" << 'EOF'
UPDATE policies SET enabled = true WHERE type = 'ELIGIBILITY';
EOF
```

<Aside type="caution">
Direct database writes bypass the audit log. Document any manual database changes in an incident ticket and review them in a post-incident review.
</Aside>

---

## Runbook 2: TLS Certificate Rotation (Zero-Downtime)

**Trigger:** Certificate approaching expiry (automate a 30-day alert), CA rotation, or security incident requiring immediate certificate replacement.

### On Kubernetes (Helm)

```bash
# 1. Generate new certificate (example using cert-manager or openssl)
openssl req -x509 -newkey rsa:4096 \
  -keyout new-server.key \
  -out new-server.crt \
  -days 90 -nodes \
  -subj "/CN=jitsudo.internal"

# 2. Update the Kubernetes Secret
kubectl create secret tls jitsudo-tls \
  --cert=new-server.crt \
  --key=new-server.key \
  --dry-run=client -o yaml \
  | kubectl apply -f -

# 3. Rolling restart (reads new cert from mounted Secret)
kubectl rollout restart deployment/jitsudod

# 4. Verify new certificate is in use
echo | openssl s_client -connect jitsudo.internal:443 2>/dev/null \
  | openssl x509 -noout -dates

# 5. Update CLI clients with new CA if CA changed
# Distribute the new CA cert to engineers who need to update ~/.jitsudo/ca.crt
```

### On single-server deployment

```bash
# 1. Replace the cert and key files
cp new-server.crt /etc/jitsudo/tls/server.crt
cp new-server.key /etc/jitsudo/tls/server.key
chmod 600 /etc/jitsudo/tls/server.key

# 2. Restart jitsudod
systemctl restart jitsudod

# 3. Verify
systemctl status jitsudod
```

---

## Runbook 3: Database Recovery from Backup

**Trigger:** Database corruption, accidental data deletion, or migration failure.

```bash
# 1. Stop jitsudod to prevent writes during restore
kubectl scale deployment jitsudod --replicas=0
# Wait for all pods to terminate
kubectl wait --for=delete pod -l app=jitsudod --timeout=60s

# 2. Create a fresh database (if needed)
psql -U postgres -c "DROP DATABASE IF EXISTS jitsudo_restore;"
psql -U postgres -c "CREATE DATABASE jitsudo_restore;"

# 3. Restore from backup
gunzip -c backup-2026-03-21.sql.gz \
  | psql -U postgres jitsudo_restore

# 4. Verify the restore
psql -U postgres jitsudo_restore -c "SELECT COUNT(*) FROM audit_events;"
psql -U postgres jitsudo_restore -c "SELECT COUNT(*) FROM requests;"

# 5. Verify audit log hash chain integrity on the restored data
export DATABASE_URL="postgres://jitsudo_app:${DB_PASSWORD}@localhost:5432/jitsudo_restore"
jitsudo audit verify
# Expected: "Chain intact: N events verified"

# 6. If chain is intact, swap databases
psql -U postgres -c "ALTER DATABASE jitsudo RENAME TO jitsudo_old;"
psql -U postgres -c "ALTER DATABASE jitsudo_restore RENAME TO jitsudo;"

# 7. Restart jitsudod
kubectl scale deployment jitsudod --replicas=2

# 8. Verify jitsudod health
kubectl get pods -l app=jitsudod
curl https://jitsudo.internal/healthz
```

<Aside type="caution">
If the audit log hash chain fails verification after restore, entries were modified between the backup point and restore point. Do not bring jitsudod back online until you have investigated the discrepancy.
</Aside>

---

## Runbook 4: All Approvers Unavailable — Break-Glass Procedure

**Trigger:** P0/P1 incident at an unusual hour; all policy-designated approvers are unreachable.

```bash
# 1. Attempt to reach an approver first (Slack, phone, PagerDuty)
# Document the attempts in the incident ticket.

# 2. If no approver is reachable within your SLA window, invoke break-glass
jitsudo request \
  --provider aws \
  --role prod-infra-admin \
  --scope YOUR_ACCOUNT_ID \
  --duration 2h \
  --reason "P0 ECS crash - INC-4421. No approvers reachable. Break-glass invoked per runbook." \
  --break-glass

# 3. This triggers:
#    - Immediate ACTIVE grant (no approval needed)
#    - High-priority Slack alert to ALL configured channels
#    - Audit log entry with break_glass: true

# 4. After the incident is resolved, revoke the grant
jitsudo revoke req_01...

# 5. Post-incident: file a review covering:
#    - Why approvers were unavailable
#    - What access was taken and why
#    - Whether the policy-designated approver group needs updating
#    - Whether the break-glass eligibility policy should be tightened
```

<Aside type="tip">
Break-glass eligibility is controlled by policy. If too many engineers can invoke break-glass, tighten the eligibility policy to restrict it to `oncall` group members only. See [Writing Policies](/docs/guides/writing-policies/) for an example.
</Aside>

---

## Runbook 5: Revoking All Active Grants for a Compromised User

**Trigger:** Engineer's credentials are compromised; account takeover suspected; offboarding with active grants.

```bash
# 1. Immediately revoke IdP account or remove from all groups
# (Do this first — prevents new requests)
# Okta: deactivate user, Entra ID: disable account, etc.

# 2. Find all active grants for the user
jitsudo status \
  --user compromised-user@example.com \
  --state active

# 3. Revoke each active grant
# For each req_ID in the output:
jitsudo revoke req_01...
jitsudo revoke req_02...
# (repeat for all active grants)

# Or use xargs for automation:
jitsudo status \
  --user compromised-user@example.com \
  --state active \
  --output json \
  | jq -r '.[].id' \
  | xargs -I{} jitsudo revoke {}

# 4. Verify all grants are revoked
jitsudo status --user compromised-user@example.com --state active
# Should return empty list

# 5. Review the audit log for the user
jitsudo audit --user compromised-user@example.com --since 7d

# 6. Check for any unusual access patterns in the audit log:
#    - Requests at unusual hours
#    - Unusual providers or roles
#    - Short-duration grants that expired before you could revoke them
```

---

## Runbook 6: jitsudod Is Down — Restoring the Control Plane

**Trigger:** All jitsudod instances are returning errors; health checks failing.

```bash
# 1. Check pod status
kubectl get pods -l app=jitsudod
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous

# 2. Common causes and fixes:
#
# CrashLoopBackOff with "database connection refused":
#   → Check PostgreSQL connectivity
#   → Verify DATABASE_URL env var is set correctly
#   → Check network policy allows jitsudod → PostgreSQL
#
# CrashLoopBackOff with "TLS: failed to load certificate":
#   → Check TLS cert/key Secret is mounted correctly
#   → Verify cert has not expired
#
# OOMKilled:
#   → Increase memory limits in Helm values
#   → Check for runaway requests or policy eval loops

# 3. Force restart
kubectl rollout restart deployment/jitsudod

# 4. Monitor rollout
kubectl rollout status deployment/jitsudod

# 5. Verify health
curl https://jitsudo.internal/healthz
curl https://jitsudo.internal/readyz
```
