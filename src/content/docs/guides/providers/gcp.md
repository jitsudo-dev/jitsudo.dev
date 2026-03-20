---
title: GCP Provider
description: Set up jitsudo to grant temporary elevated access on GCP via IAM conditional role bindings.
---

The GCP provider grants temporary elevated access by creating IAM conditional role bindings on GCP projects. The binding includes a CEL expiry expression that natively limits the effective duration at the GCP IAM layer.

## How It Works

1. jitsudod calls `GetIamPolicy` on the target project to fetch the current policy.
2. A new binding is added with the requested role, user, and a CEL condition: `request.time < timestamp("EXPIRY")`.
3. The binding is identified by a unique condition title (`jitsudo-<requestID>`).
4. `SetIamPolicy` is called with optimistic concurrency (ETag); retries on HTTP 409 conflict.
5. The credential returned is the `GOOGLE_CLOUD_PROJECT` environment variable.
6. On revocation or expiry, the binding is removed from the policy.

:::tip[Native time bounds]
Unlike Azure RBAC, GCP IAM conditions natively enforce the expiry at the IAM evaluation layer. Even if the jitsudo expiry sweeper is delayed, the CEL condition ensures the access stops at the scheduled time.
:::

## Prerequisites

### Service Account for jitsudod

Grant the jitsudod service account these permissions on each project it manages:

| Permission | Purpose |
|------------|---------|
| `resourcemanager.projects.getIamPolicy` | Read the current IAM policy |
| `resourcemanager.projects.setIamPolicy` | Write updated IAM policies |

These are included in the `roles/resourcemanager.projectIamAdmin` predefined role.

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:jitsudo@JITSUDO_PROJECT.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"
```

:::caution
`roles/resourcemanager.projectIamAdmin` is a powerful role. Scope it to specific projects that jitsudo manages, not your entire organization.
:::

## Credential Sources

### GKE Workload Identity (recommended)

```bash
# Create the GCP service account
gcloud iam service-accounts create jitsudo-control-plane \
  --project=JITSUDO_PROJECT

# Grant IAM permissions
gcloud projects add-iam-policy-binding TARGET_PROJECT \
  --member="serviceAccount:jitsudo-control-plane@JITSUDO_PROJECT.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"

# Bind the Kubernetes ServiceAccount to the GCP service account
gcloud iam service-accounts add-iam-policy-binding \
  jitsudo-control-plane@JITSUDO_PROJECT.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:JITSUDO_PROJECT.svc.id.goog[jitsudo/jitsudo]"
```

Annotate the Helm ServiceAccount:

```yaml
serviceAccount:
  annotations:
    iam.gke.io/gcp-service-account: "jitsudo-control-plane@JITSUDO_PROJECT.iam.gserviceaccount.com"
```

### Application Default Credentials

On a GCE VM or Cloud Run, ADC is automatically available via the instance's service account.

### Service Account Key

For non-GCP deployments (not recommended for production):

```bash
gcloud iam service-accounts keys create key.json \
  --iam-account=jitsudo-control-plane@JITSUDO_PROJECT.iam.gserviceaccount.com
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
```

## Configuration

```yaml
providers:
  gcp:
    # GCP organization ID (numeric string).
    # Used when resource_scope targets the organization level.
    organization_id: "123456789012"

    # Credential source:
    # "workload_identity_federation" — GKE Workload Identity (recommended)
    # "application_default"          — ADC (GCE, Cloud Run, local gcloud auth)
    # "service_account_key"          — GOOGLE_APPLICATION_CREDENTIALS env var
    credentials_source: "workload_identity_federation"

    # Maximum elevation window
    max_duration: "8h"

    # Prefix for IAM condition titles. Defaults to "jitsudo".
    # Resulting title: "jitsudo-<requestID>"
    condition_title_prefix: "jitsudo"
```

### Configuration Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `organization_id` | No | — | GCP organization ID for org-level scope requests |
| `credentials_source` | No | `application_default` | `workload_identity_federation`, `application_default`, or `service_account_key` |
| `max_duration` | No | no cap | Maximum elevation window |
| `condition_title_prefix` | No | `jitsudo` | Prefix for IAM condition titles |

## Request Examples

```bash
# Request editor access on a GCP project
jitsudo request \
  --provider gcp \
  --role roles/editor \
  --scope my-gcp-project \
  --duration 1h \
  --reason "Deploy hotfix"

# Request viewer access
jitsudo request \
  --provider gcp \
  --role roles/viewer \
  --scope my-gcp-project \
  --duration 2h \
  --reason "Audit resource usage for SOC 2 review"

# Request a custom role
jitsudo request \
  --provider gcp \
  --role projects/my-project/roles/customDataAnalyst \
  --scope my-gcp-project \
  --duration 4h \
  --reason "Run quarterly data pipeline"
```

**`--scope`:** GCP project ID (e.g. `my-gcp-project`).

**`--role`:** GCP role name. Accepts:
- Predefined roles: `roles/editor`, `roles/viewer`, `roles/storage.admin`
- Custom roles: `projects/PROJECT_ID/roles/ROLE_ID`

## Injected Credentials

```
GOOGLE_CLOUD_PROJECT=my-gcp-project
```

The injected variable sets the default project for the `gcloud` CLI and GCP SDKs. The user's own identity is used for actual API calls — jitsudo only grants the role binding, not credentials.

```bash
jitsudo exec req_01J8KZ... -- gcloud compute instances list
```

## IAM Condition Details

The condition written to the IAM policy:

```
Title:      jitsudo-req_01J8KZ4F2EMNQZ3V7XKQYBD4W
Expression: request.time < timestamp("2026-03-20T18:00:00Z")
```

This is a standard GCP IAM condition. You can verify it in the GCP Console under **IAM & Admin → IAM** by checking the project's policy.

## Concurrency Safety

The provider uses optimistic concurrency with ETags and retries (up to 5 attempts on HTTP 409 conflict). This is safe to use in multi-instance jitsudod deployments.
