---
title: High Availability and Disaster Recovery
description: Deployment architecture for high availability, failure mode analysis, backup and restore, and disaster recovery procedures for jitsudo.
---

import { Aside } from '@astrojs/starlight/components';

## Architecture Overview

jitsudod is a **stateless binary** — all persistent state lives in PostgreSQL. This has an important implication: you can run multiple jitsudod instances behind a load balancer today, sharing the same database, without any additional configuration.

```
Internal Load Balancer (private, not internet-facing)
         │
    ┌────┴────┐
    ▼         ▼
jitsudod-1  jitsudod-2   (multiple instances, same image)
    │         │
    └────┬────┘
         ▼
    PostgreSQL
    (single source of truth for all state)
```

PostgreSQL advisory locks ensure that background jobs (the expiry sweeper, policy sync) run on exactly one instance at a time — no external leader election mechanism is needed.

## Failure Modes

### Control plane unavailable (all jitsudod instances down)

**Behavior: fail-closed for new requests.**

If all jitsudod instances are unavailable:
- Engineers **cannot** submit new elevation requests
- Pending requests **cannot** be approved or denied
- The `jitsudo` CLI will return connection errors

This is intentional. An unreachable access control system should not silently grant access.

**Existing active grants are unaffected.** Credentials already issued by the cloud provider (STS session tokens, Azure RBAC assignments, GCP IAM bindings, Kubernetes RBAC bindings) remain valid until their natural TTL expiry. The credentials are held by the cloud provider, not by jitsudod. A downed control plane does not immediately revoke active sessions.

**Exception: the expiry sweeper stops.** The background process that calls `Revoke` on expired grants will not run while jitsudod is down. Grants that expire during the outage will linger until the sweeper resumes. For providers with native TTL enforcement (GCP IAM conditions, Kubernetes TTL annotations), expiry is enforced by the provider regardless. For Azure RBAC, the sweeper is the enforcement mechanism — grants will overstay their TTL during a prolonged outage.

### Database unavailable

If PostgreSQL is unavailable, jitsudod cannot process any requests (all operations require database access). jitsudod instances will log errors and return 503 responses. Recovery is automatic once the database is restored.

### Single jitsudod instance failure

Behind a load balancer, the load balancer routes around failed instances. Active requests in flight may return errors, but clients can retry. The CLI retries transient errors automatically.

## Emergency Access When Control Plane Is Down

<Aside type="caution">
If jitsudod is completely unavailable and you need emergency access, you must use the cloud provider's IAM console directly. This is an out-of-band access event and **must be logged manually** and reviewed in a post-incident review.
</Aside>

Break-glass (`jitsudo request --break-glass`) requires a running jitsudod. If the control plane is truly unavailable:

1. Use the cloud provider's IAM console to grant the minimum required permissions directly
2. Document the access: timestamp, user, resource, justification, incident ticket
3. After jitsudod is restored, revoke the manual IAM change immediately
4. File a post-incident review noting the out-of-band access

Persistent out-of-band access events are audit gaps. Minimize them by monitoring jitsudod availability and having runbooks for rapid recovery.

## Production Deployment Recommendations

### Run multiple instances

```yaml
# helm/values.yaml
replicaCount: 2   # minimum for HA; 3 recommended for rolling updates without downtime

podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

### Use a managed PostgreSQL service

Self-managed PostgreSQL HA is operationally complex. Use a managed service for production:

| Cloud | Managed PostgreSQL |
|-------|--------------------|
| AWS | RDS Multi-AZ (automatic failover ~30–60s) |
| Azure | Azure Database for PostgreSQL - Flexible Server (HA mode) |
| GCP | Cloud SQL for PostgreSQL (HA with failover replica) |
| On-prem | Patroni + etcd, or Crunchy Data PGO |

All managed services above provide automatic failover, point-in-time recovery (PITR), and automated backups.

### Configure connection pooling

PostgreSQL has a hard limit on concurrent connections. Use PgBouncer (or pgpool-II) between jitsudod and PostgreSQL for connection efficiency, especially during rolling restarts:

```yaml
# In jitsudod config — point at PgBouncer, not PostgreSQL directly
database:
  url: "postgres://jitsudo_app:${DB_PASSWORD}@pgbouncer:5432/jitsudo?sslmode=require"
```

### Health checks

jitsudod exposes a health endpoint:

```
GET /healthz       → 200 OK if the server is healthy
GET /readyz        → 200 OK if the server is ready to serve traffic
```

Configure your load balancer to use `/readyz` for routing decisions. The ready check includes a database connectivity check.

## Backup and Restore

### Backup schedule

Take daily automated backups of the PostgreSQL database. Managed services (RDS, Cloud SQL, Azure Database) provide this by default.

For self-managed PostgreSQL:

```bash
# Daily pg_dump to S3 (example)
pg_dump -U jitsudo_app jitsudo \
  | gzip \
  | aws s3 cp - s3://your-backup-bucket/jitsudo/$(date +%Y-%m-%d).sql.gz
```

### Restore procedure

```bash
# 1. Stop jitsudod instances to prevent writes during restore
kubectl scale deployment jitsudod --replicas=0

# 2. Restore from backup
gunzip -c backup.sql.gz | psql -U postgres jitsudo

# 3. Verify audit log hash chain integrity
jitsudo audit verify

# 4. Restart jitsudod
kubectl scale deployment jitsudod --replicas=2
```

### Audit log verification after restore

After any restore, verify the audit log hash chain:

```bash
jitsudo audit verify
```

If the chain breaks, entries were modified or inserted out-of-band between the backup point and the restore point. Investigate before allowing the restored instance to serve traffic. See [Audit Log](/docs/reference/audit-log/) for the chain format and verification script.

## Milestone 4 HA Improvements

The following formal HA engineering is planned for [Milestone 4](/roadmap/):
- HPA (Horizontal Pod Autoscaler) configuration for automatic scaling
- PodDisruptionBudget documentation and Helm defaults
- Documented PostgreSQL replication topology recommendations per cloud provider
- Active/passive failover testing runbook
