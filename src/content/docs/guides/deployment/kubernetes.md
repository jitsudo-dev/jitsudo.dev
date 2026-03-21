---
title: Kubernetes (Helm)
description: Deploy jitsudo to Kubernetes using the official Helm chart.
---

Deploy jitsudo to Kubernetes using the official Helm chart. The chart includes an optional PostgreSQL subchart (bitnami) and supports external managed databases for production.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.10+
- An OIDC provider (Okta, Entra ID, Keycloak, etc.) — see [OIDC Integration](/guides/oidc/)
- A PostgreSQL database (use the subchart for testing, an external RDS/Cloud SQL for production)

## Add the Helm Repository

:::note
The chart is currently distributed from the main repository. A dedicated Helm repository will be published in Milestone 5.
:::

```bash
# Clone the repo and install from the local chart
git clone https://github.com/jitsudo-dev/jitsudo.git
cd jitsudo
```

## Minimal Installation

```bash
helm upgrade --install jitsudo ./helm/jitsudo \
  --namespace jitsudo \
  --create-namespace \
  --set config.auth.oidcIssuer=https://your-idp.example.com \
  --set config.auth.clientId=jitsudo-server
```

This uses the bundled PostgreSQL subchart with default credentials. **Do not use this in production.**

## Production Installation

For production, disable the bundled PostgreSQL and supply your own database credentials via a Kubernetes Secret:

```bash
# 1. Create a secret with the database URL
kubectl create secret generic jitsudo-db \
  --namespace jitsudo \
  --from-literal=DATABASE_URL="postgres://jitsudo:STRONG_PASSWORD@your-db.example.com:5432/jitsudo?sslmode=require"

# 2. Install the chart
helm upgrade --install jitsudo ./helm/jitsudo \
  --namespace jitsudo \
  --create-namespace \
  --values values-prod.yaml
```

**`values-prod.yaml`:**

```yaml
config:
  auth:
    oidcIssuer: "https://your-idp.example.com"
    clientId: "jitsudo-server"

  database:
    existingSecret: "jitsudo-db"  # Secret with DATABASE_URL key

  providers:
    aws:
      enabled: true
      region: "us-east-1"
      roleArnTemplate: "arn:aws:iam::{scope}:role/jitsudo-{role}"
      maxDuration: "4h"

  log:
    level: "info"
    format: "json"

# Disable bundled PostgreSQL — use external managed database
postgresql:
  enabled: false

# Enable ingress for the REST gateway
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: jitsudo.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: jitsudo-tls
      hosts:
        - jitsudo.example.com

# Production resource sizing
resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    memory: 512Mi

# Enable horizontal autoscaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

# Enable pod disruption budget for rolling updates
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

## Key Values Reference

### `config` section

The `config` block maps directly to the jitsudod configuration file. See the [Server Configuration reference](/reference/configuration/) for all options.

| Value | Default | Description |
|-------|---------|-------------|
| `config.auth.oidcIssuer` | `""` | OIDC issuer URL **(required)** |
| `config.auth.clientId` | `jitsudo-server` | OIDC client ID |
| `config.database.url` | `""` | Inline PostgreSQL URL (use `existingSecret` in production) |
| `config.database.existingSecret` | `""` | Name of Secret with `DATABASE_URL` key |
| `config.tls.enabled` | `false` | Enable TLS for gRPC |
| `config.tls.secretName` | `""` | Kubernetes TLS secret name |
| `config.log.level` | `info` | Log level: `debug`, `info`, `warn`, `error` |

### Provider toggles

Each provider is disabled by default. Enable with `config.providers.<name>.enabled: true`.

```yaml
config:
  providers:
    aws:
      enabled: true
      region: "us-east-1"
      roleArnTemplate: "arn:aws:iam::{scope}:role/jitsudo-{role}"
    gcp:
      enabled: true
      organizationId: "123456789012"
      credentialsSource: "workload_identity_federation"
    azure:
      enabled: true
      tenantId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      clientId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      credentialsSource: "workload_identity"
    kubernetes:
      enabled: true
      defaultNamespace: "default"
      maxDuration: "1h"
```

### Notification channels

```yaml
config:
  notifications:
    slack:
      enabled: true
      existingSecret: "jitsudo-slack"  # Secret with JITSUDOD_SLACK_WEBHOOK_URL
      channel: "#sre-access-requests"
      mentionOnBreakGlass: "<!channel>"
    smtp:
      enabled: true
      host: "smtp.example.com"
      port: 587
      username: "jitsudo@example.com"
      existingSecret: "jitsudo-smtp"   # Secret with JITSUDOD_SMTP_PASSWORD
      from: "jitsudo@example.com"
      to:
        - "sre-team@example.com"
```

## RBAC for the Kubernetes Provider

If you enable the Kubernetes provider, the chart creates a `ClusterRole` and `ClusterRoleBinding` granting the jitsudo ServiceAccount permission to manage RBAC bindings:

```yaml
# Automatically created by the chart when kubernetes provider is enabled
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
rules:
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterrolebindings", "rolebindings"]
    verbs: ["create", "get", "delete", "list"]
```

## Workload Identity (AWS IRSA / GCP Workload Identity)

For AWS, annotate the ServiceAccount with the IAM role ARN:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/jitsudo-control-plane"
```

For GCP, annotate with the service account email:

```yaml
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: "jitsudo@my-project.iam.gserviceaccount.com"
```

## Bootstrap After Installation

After installing the chart, run `server init` to run migrations:

```bash
kubectl exec -n jitsudo deployment/jitsudo -- \
  jitsudo server init \
    --db-url "$DATABASE_URL" \
    --oidc-issuer https://your-idp.example.com \
    --oidc-client-id jitsudo-server \
    --skip-migrations  # chart runs migrations on startup
```

## Verify Deployment

```bash
# Check pod status
kubectl get pods -n jitsudo

# Check health endpoints
kubectl port-forward -n jitsudo svc/jitsudo-http 8080:8080
curl http://localhost:8080/healthz   # → ok
curl http://localhost:8080/readyz    # → ok
curl http://localhost:8080/version   # → {"version":"0.1.0","api_versions":["v1alpha1"]}
```
