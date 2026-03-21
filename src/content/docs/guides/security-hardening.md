---
title: Security Hardening Guide
description: Production security recommendations for jitsudo deployments — network architecture, TLS, PostgreSQL hardening, credential management, and audit integrity.
---

import { Aside } from '@astrojs/starlight/components';

<Aside type="caution">
jitsudod can grant admin-level access to every cloud provider it manages. Treat it as a Tier 0 control plane asset. A compromised jitsudod is an instant privilege escalation path to every provider in scope.
</Aside>

This guide covers the security controls required for a production jitsudo deployment. Implementing all recommendations in this guide is strongly advised before exposing jitsudo to production workloads.

## Network Architecture

### Do NOT expose jitsudod to the internet

jitsudod should run inside a private network segment, reachable only by:
- Engineers connecting through a VPN or zero-trust network access tool
- Automated clients (CI/CD pipelines, MCP agents) on private networks
- The cloud provider's internal network (for provider callbacks)

A public-facing jitsudod dramatically increases the attack surface. Even with mTLS, a public endpoint invites brute-force, DDoS, and credential stuffing attempts.

**Recommended architecture:**
```
Internet
    │
    ▼
  VPN / ZTNA (Tailscale, Teleport, Cloudflare Access)
    │
    ▼
Internal Load Balancer (private subnet)
    │
    ▼
jitsudod instances (private subnet, no public IP)
    │
    ▼
PostgreSQL (private subnet, jitsudo service account only)
```

### Firewall rules

Inbound to jitsudod:
- Allow TCP 443 (gRPC/REST) from VPN/ZTNA subnet only
- Allow TCP 8080 (health check endpoint) from internal monitoring only
- Deny all other inbound

Outbound from jitsudod:
- Allow HTTPS to cloud provider APIs (AWS STS, Azure ARM, GCP IAM, Kubernetes API)
- Allow TCP 5432 to PostgreSQL
- Allow HTTPS to IdP JWKS endpoint (for token verification)
- Allow HTTPS to Slack/webhook endpoints (for notifications)

## TLS and mTLS

### Enable mTLS for production

jitsudod supports three TLS modes. Use mTLS for any production deployment:

| Mode | Config | Use case |
|------|--------|----------|
| Insecure | No TLS config | Local development only |
| Server TLS | `cert_file` + `key_file` | Internal deployments with trusted CA |
| mTLS | `cert_file` + `key_file` + `ca_file` | **Recommended for production** |

With mTLS, the server verifies client certificates on every connection. Unauthorized clients — even those on the internal network — cannot communicate with jitsudod.

```yaml
# jitsudod.yaml
tls:
  cert_file: /etc/jitsudo/tls/server.crt
  key_file: /etc/jitsudo/tls/server.key
  ca_file: /etc/jitsudo/tls/ca.crt   # enables mTLS
```

See [Configuration Reference](/docs/reference/configuration/) for the full TLS configuration schema.

### Certificate management

- Use a private CA (Vault PKI, cert-manager, AWS ACM Private CA) — do not use a public CA for internal services
- Set certificate TTLs to 90 days or less; automate rotation
- Store private keys in a secrets manager (Vault, Kubernetes Secrets with encryption at rest, AWS Secrets Manager) — never on disk unencrypted

## PostgreSQL Hardening

PostgreSQL holds all jitsudo state: requests, policies, audit events, and credentials for connected providers. It must be treated as a high-value target.

### Access controls

Create a dedicated PostgreSQL role for jitsudo with the minimum required permissions:

```sql
-- Create dedicated role
CREATE ROLE jitsudo_app LOGIN PASSWORD '<strong-password>';

-- Grant access to the database
GRANT CONNECT ON DATABASE jitsudo TO jitsudo_app;
GRANT USAGE ON SCHEMA public TO jitsudo_app;

-- Grant SELECT + INSERT on all tables (normal operation)
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA public TO jitsudo_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO jitsudo_app;

-- Critical: explicitly deny UPDATE and DELETE on the audit log
-- This enforces append-only at the database layer
REVOKE UPDATE, DELETE ON audit_events FROM jitsudo_app;
```

<Aside type="tip">
Revoking UPDATE and DELETE on `audit_events` at the database layer provides a second line of defense for audit log integrity, independent of application-layer controls.
</Aside>

### Encryption

- **Encryption at rest**: Enable PostgreSQL transparent data encryption, or use encrypted storage volumes (AWS EBS encryption, GCP Persistent Disk encryption). This protects against physical media theft.
- **Encryption in transit**: Always use TLS for the PostgreSQL connection. Set `sslmode=require` (or `verify-full` with a CA cert) in the jitsudod database connection string.
- **Credentials**: Never store the PostgreSQL password in the jitsudod config file. Use environment variables:

```bash
export JITSUDOD_DATABASE_URL="postgres://jitsudo_app:<password>@db-host:5432/jitsudo?sslmode=require"
```

### Backups

- Take daily snapshots of the PostgreSQL database
- Test restore procedures quarterly
- Encrypted backups should be stored in a separate account/project from the primary database
- After a restore, verify the audit log hash chain integrity:

```bash
jitsudo audit verify --from-backup
```

## Credential and Secret Management

### Provider credentials

jitsudo needs credentials to call cloud provider APIs (STS AssumeRole for AWS, ARM API for Azure, IAM API for GCP). These are high-privilege credentials.

**Never store provider credentials in the jitsudod config file.** Use environment variables or a secrets manager:

```bash
# AWS: prefer IAM roles for EC2/EKS (no static credentials needed)
# If static credentials are required:
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."

# Azure: prefer Workload Identity for AKS
# If client secret is required:
export AZURE_CLIENT_SECRET="..."

# GCP: prefer Workload Identity Federation
# If service account key is required:
export GOOGLE_APPLICATION_CREDENTIALS="/var/secrets/gcp-sa-key.json"
```

**Prefer workload identity over static credentials** wherever possible. IAM Roles for Service Accounts (IRSA) on EKS, Azure Workload Identity on AKS, and GCP Workload Identity Federation all eliminate the need to manage long-lived static credentials.

### Notification secrets

Slack webhook URLs and SMTP passwords should also be set via environment variables:

```bash
export JITSUDOD_NOTIFICATIONS_SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
export JITSUDOD_NOTIFICATIONS_EMAIL_SMTP_PASSWORD="..."
```

## Audit Log Integrity

The jitsudo audit log uses SHA-256 hash chaining: each entry includes the SHA-256 hash of the previous entry. This creates a tamper-evident chain that makes retroactive modification detectable.

### Database-layer enforcement

The `REVOKE UPDATE, DELETE ON audit_events` database permission (described above) enforces append-only at the storage layer, independent of the application.

### Verify the hash chain

```bash
# Verify the full audit log chain
jitsudo audit verify

# Export and verify offline
jitsudo audit export --output audit-backup.json
python3 verify_audit_chain.py audit-backup.json
```

See [Audit Log](/docs/reference/audit-log/) for the verification script and chain format.

### Current limitations

The hash chain protects against undetected modification of entries, but does not prevent deletion of entries (truncation). For stronger guarantees — write-once storage, cryptographic anchoring, WORM sinks — see the [roadmap](/roadmap/). In the interim, the combination of hash chaining, database role restrictions, and external SIEM forwarding provides defense in depth.

## Break-Glass Recovery

If jitsudod itself is compromised:

1. **Revoke all active provider credentials immediately** via the cloud provider's IAM console — do not wait for TTL expiry
2. **Rotate all provider credentials** used by jitsudod (AWS role, Azure client secret, GCP service account)
3. **Rotate the PostgreSQL password** and TLS certificates
4. **Restore from a known-good database backup** if the database was modified out-of-band
5. **Verify audit log integrity** on the restored database: `jitsudo audit verify`
6. **Review all audit log entries** since the last verified backup for unauthorized grants
7. **Rebuild jitsudod** from source or a verified container image before restarting

The hash chain in the audit log will reveal any entries that were modified or inserted out-of-band during the compromise window.

## Key Rotation

### TLS certificate rotation

jitsudod reads TLS certificates from disk at startup. To rotate without downtime on Kubernetes:

1. Update the Kubernetes Secret containing the TLS cert/key
2. Perform a rolling restart: `kubectl rollout restart deployment/jitsudod`
3. Verify the new certificate is in use: `openssl s_client -connect jitsudod:443`

### Database credential rotation

1. Create a new PostgreSQL role or update the password
2. Update the `JITSUDOD_DATABASE_URL` environment variable in the deployment (Kubernetes Secret or Vault)
3. Perform a rolling restart
4. Drop the old credential after confirming the new one works

### Provider credential rotation

Follow each cloud provider's credential rotation procedure, then update the corresponding environment variable and perform a rolling restart of jitsudod.
