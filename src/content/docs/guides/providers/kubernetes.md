---
title: Kubernetes Provider
description: Set up jitsudo to grant temporary elevated access on Kubernetes via RBAC bindings.
---

The Kubernetes provider grants temporary elevated access by creating a `ClusterRoleBinding` or `RoleBinding` with a TTL annotation. The jitsudo expiry sweeper deletes bindings when they expire.

:::tip[Prerequisites at a glance]
Before configuring the Kubernetes provider, jitsudod's ServiceAccount needs RBAC permission to:
- `create`, `get`, `delete` `ClusterRoleBindings` and `RoleBindings`
- `list`, `watch` `ClusterRoleBindings` and `RoleBindings` (for expiry sweeper)
- The target `ClusterRoles` being granted must already exist in the cluster

The Helm chart creates the necessary RBAC resources automatically when the Kubernetes provider is enabled. See [Prerequisites](#prerequisites) below.
:::

## How It Works

1. jitsudod creates a `ClusterRoleBinding` (cluster-wide) or `RoleBinding` (namespaced) binding the requester's user identity to the requested ClusterRole.
2. The binding is named `jitsudo-<requestID>` and labelled with `jitsudo.dev/managed: "true"`.
3. An annotation `jitsudo.dev/expires-at` records the expiry time.
4. On revocation or expiry, jitsudod deletes the binding.
5. The `IsActive` check queries whether the binding still exists in the cluster — catching out-of-band `kubectl delete` operations.

:::note[Scope → Binding type]
- **Empty scope or `*`**: Creates a `ClusterRoleBinding` (all namespaces).
- **Namespace name**: Creates a namespaced `RoleBinding`.
:::

## Prerequisites

### jitsudod RBAC Permissions

The jitsudo ServiceAccount needs permission to manage RBAC bindings. The Helm chart creates this automatically when the Kubernetes provider is enabled:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jitsudo-rbac-manager
rules:
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterrolebindings", "rolebindings"]
    verbs: ["create", "get", "delete", "list"]
```

For non-Helm deployments, apply this manually and create a `ClusterRoleBinding` for the jitsudo ServiceAccount.

### Target ClusterRoles

Users request access to existing ClusterRoles. Make sure the roles you want jitsudo to grant exist in your cluster. Common built-in roles:

| ClusterRole | Access level |
|-------------|-------------|
| `view` | Read-only (no secrets) |
| `edit` | Read/write (no RBAC) |
| `admin` | Full namespace admin |
| `cluster-admin` | Full cluster admin |

You can also create custom ClusterRoles for more granular access.

## Configuration

```yaml
providers:
  kubernetes:
    # Path to kubeconfig file.
    # Leave empty to use in-cluster service account credentials (recommended).
    kubeconfig: ""

    # Default namespace for namespaced RoleBindings when ResourceScope is empty.
    # If also empty, a ClusterRoleBinding is created instead.
    default_namespace: "default"

    # Maximum elevation window
    max_duration: "1h"

    # Label key applied to all jitsudo-managed bindings.
    # The expiry sweeper uses this label for cleanup queries.
    managed_label: "jitsudo.dev/managed"
```

### Configuration Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `kubeconfig` | No | `""` (in-cluster) | Path to kubeconfig file |
| `default_namespace` | No | `""` | Default namespace for RoleBindings |
| `max_duration` | No | no cap | Maximum elevation window |
| `managed_label` | No | `jitsudo.dev/managed` | Label applied to all managed bindings |

## Request Examples

```bash
# Cluster-wide admin (ClusterRoleBinding)
jitsudo request \
  --provider kubernetes \
  --role cluster-admin \
  --scope "*" \
  --duration 15m \
  --reason "Debug kube-system CrashLoopBackOff"

# Namespaced edit access (RoleBinding)
jitsudo request \
  --provider kubernetes \
  --role edit \
  --scope production \
  --duration 30m \
  --reason "Scale deployment for traffic spike"

# Read-only access to a namespace
jitsudo request \
  --provider kubernetes \
  --role view \
  --scope staging \
  --duration 1h \
  --reason "Audit staging environment for compliance review"
```

**`--scope`:** Kubernetes namespace name, or `*` / empty string for cluster-wide.

**`--role`:** Name of an existing `ClusterRole` (e.g. `cluster-admin`, `edit`, `view`).

## Injected Credentials

```
JITSUDO_K8S_ROLE=cluster-admin
JITSUDO_K8S_NAMESPACE=production
```

The user's own Kubernetes identity (as configured in their `kubeconfig`) is used for actual API calls — the binding grants them the role using their existing identity.

```bash
jitsudo exec req_01J8KZ... -- kubectl get pods -n production
jitsudo shell req_01J8KZ...
$ kubectl delete pod crashed-pod-abc123 -n production
$ exit
```

## Expiry Enforcement

The binding's annotation `jitsudo.dev/expires-at` (RFC3339) is set at creation time. The jitsudo expiry sweeper periodically:

1. Lists all bindings with label `jitsudo.dev/managed=true`.
2. Checks `jitsudo.dev/expires-at` against the current time.
3. Calls `Revoke` on any expired binding.

If a binding is deleted out-of-band (e.g. by a cluster admin with `kubectl delete`), the `IsActive` check detects this and marks the request as expired.

## External kubeconfig (Multi-Cluster)

To manage a remote cluster from jitsudod:

```yaml
providers:
  kubernetes:
    kubeconfig: "/etc/jitsudo/kubeconfig-prod.yaml"
```

Mount the kubeconfig as a Kubernetes Secret:

```yaml
volumes:
  - name: kubeconfig
    secret:
      secretName: jitsudo-kubeconfig-prod
volumeMounts:
  - name: kubeconfig
    mountPath: /etc/jitsudo/kubeconfig-prod.yaml
    subPath: kubeconfig
```
