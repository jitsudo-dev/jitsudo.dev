---
title: Azure Provider
description: Set up jitsudo to grant temporary elevated access on Azure via RBAC role assignments.
---

The Azure provider grants temporary elevated access by creating Azure RBAC role assignments via the ARM Authorization API. User principal IDs are resolved automatically from Entra ID (Azure AD) via the Microsoft Graph API.

:::tip[Prerequisites at a glance]
Before configuring the Azure provider, jitsudod needs an Entra ID service principal or managed identity with:
- `Microsoft.Authorization/roleAssignments/write` and `read/delete` on target scopes (ARM)
- `User.Read.All` on Microsoft Graph (to resolve user principal IDs from email)
- For AKS deployments: Azure Workload Identity is supported — no client secrets required

See [Prerequisites](#prerequisites) below for exact role assignment and Graph permission setup.
:::

## How It Works

1. jitsudod resolves the user's Azure object ID from their UPN (email) via Microsoft Graph.
2. jitsudod looks up the role definition ID for the requested role name.
3. A role assignment is created with a deterministic GUID derived from the request ID (enables idempotency).
4. The credential returned is the `AZURE_SUBSCRIPTION_ID` of the target subscription.
5. On revocation or expiry, jitsudod deletes the role assignment.

:::note
Azure RBAC does not natively support time-bounded role assignments without Azure AD PIM. Expiry is enforced by the jitsudo expiry sweeper, which calls `Revoke` when `ExpiresAt` is reached.
:::

## Prerequisites

### Service Principal / Managed Identity

jitsudod needs an Entra ID identity (service principal or managed identity) with these permissions:

| Permission | Purpose |
|------------|---------|
| `Microsoft.Authorization/roleAssignments/write` | Create role assignments |
| `Microsoft.Authorization/roleAssignments/delete` | Delete role assignments on revocation |
| `Microsoft.Authorization/roleDefinitions/read` | Look up role definition IDs |
| `Microsoft.Graph/User.Read.All` (API permission) | Resolve user UPN → object ID |

Assign these at the subscription scope (or narrower if you want to restrict to specific subscriptions).

### AKS Workload Identity (recommended)

On AKS, use workload identity to avoid storing credentials:

```bash
# Create a managed identity
az identity create \
  --name jitsudo-control-plane \
  --resource-group my-resource-group

# Get the client ID
CLIENT_ID=$(az identity show \
  --name jitsudo-control-plane \
  --resource-group my-resource-group \
  --query clientId -o tsv)

# Grant it the required permissions
az role assignment create \
  --assignee "$CLIENT_ID" \
  --role "User Access Administrator" \
  --scope "/subscriptions/SUBSCRIPTION_ID"

# Grant Microsoft Graph permission (requires Entra admin)
az ad app permission add \
  --id "$CLIENT_ID" \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions df021288-bdef-4463-88db-98f22de89214=Role  # User.Read.All
```

Annotate the Helm ServiceAccount:

```yaml
serviceAccount:
  annotations:
    azure.workload.identity/client-id: "<managed-identity-client-id>"
```

### Client Secret (non-Kubernetes)

For non-Kubernetes deployments, use a service principal with a client secret:

```bash
# Create the service principal
az ad sp create-for-rbac \
  --name jitsudo-control-plane \
  --role "User Access Administrator" \
  --scopes "/subscriptions/SUBSCRIPTION_ID"
```

Supply the secret via the `AZURE_CLIENT_SECRET` environment variable (do not put it in the config file).

## Configuration

```yaml
providers:
  azure:
    # Entra ID (Azure AD) tenant ID
    tenant_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

    # Default subscription ID when no resource scope is provided in requests
    default_subscription_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

    # Client ID of the service principal or managed identity used by jitsudod
    client_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

    # Credential source:
    # "workload_identity" — AKS managed identity or workload identity (recommended)
    # "client_secret"     — service principal with AZURE_CLIENT_SECRET env var
    credentials_source: "workload_identity"

    # Maximum elevation window
    max_duration: "4h"
```

### Configuration Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `tenant_id` | Yes | — | Entra ID tenant ID |
| `default_subscription_id` | Yes | — | Fallback subscription when request scope is empty |
| `client_id` | Yes | — | Service principal or managed identity client ID |
| `credentials_source` | No | `workload_identity` | `workload_identity` or `client_secret` |
| `max_duration` | No | no cap | Maximum elevation window |

## Security Considerations

### Azure RBAC expiry is enforced by jitsudod, not by Azure

Azure RBAC does not support time-bound role assignments without Azure AD PIM. This means **expiry is entirely managed by the jitsudo expiry sweeper** — there is no cloud-side safety net.

Compare this to:
- **AWS**: STS session tokens have a hard expiry enforced by AWS. Even if jitsudod is down, credentials expire.
- **GCP**: IAM conditions with TTL are enforced by GCP at grant time. No sweeper required.
- **Azure**: RBAC assignments have no native TTL. If jitsudod is down and the sweeper stops, Azure grants persist until jitsudod recovers.

**Recommended mitigations:**
- Use shorter TTLs for Azure grants (30–60 minutes rather than multi-hour windows). This limits the exposure window if jitsudod becomes unavailable.
- Monitor jitsudod uptime closely. A prolonged outage means Azure RBAC grants are not being revoked.
- Consider using Azure PIM for your highest-sensitivity scopes as a secondary TTL enforcement layer.
- Create an Azure Monitor alert on role assignments made by jitsudod's service principal that exceed your maximum permitted TTL.

See [HA & DR — Control Plane Unavailable](/docs/guides/ha-dr/#control-plane-unavailable-all-jitsudod-instances-down) for the full failure mode analysis.

## Request Examples

```bash
# Request Contributor access on a subscription
jitsudo request \
  --provider azure \
  --role Contributor \
  --scope xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
  --duration 1h \
  --reason "Update AKS node pool autoscaling"

# Request Reader access on a resource group
jitsudo request \
  --provider azure \
  --role Reader \
  --scope /subscriptions/xxx/resourceGroups/my-rg \
  --duration 30m \
  --reason "Audit resource usage"
```

**`--scope` values:**
- Subscription ID (UUID) — creates the assignment at subscription scope
- Full ARM scope path (e.g. `/subscriptions/xxx/resourceGroups/my-rg`) — creates at that scope

## Injected Credentials

```
AZURE_SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Use with the Azure CLI:

```bash
jitsudo exec req_01J8KZ... -- az vm list --subscription "$AZURE_SUBSCRIPTION_ID"
```

## Built-in Role Names

Common Azure built-in roles:

| Role | Description |
|------|-------------|
| `Owner` | Full access including RBAC management |
| `Contributor` | Full access except RBAC management |
| `Reader` | Read-only access |
| `User Access Administrator` | Manage RBAC assignments |
| `Storage Blob Data Contributor` | Read/write Azure Blob Storage |
| `AcrPull` | Pull images from Container Registry |

Custom role definitions are also supported — use the exact role display name.
