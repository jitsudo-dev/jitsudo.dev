---
title: Provider Interface
description: How jitsudo's provider abstraction enables multi-cloud JIT access.
---

The `Provider` interface is the most important architectural abstraction in jitsudo. It defines the contract every cloud provider adapter must satisfy, enabling new providers to be added without modifying core logic.

## Interface Definition

```go
// Provider is the interface all cloud provider adapters must implement.
type Provider interface {
    // Name returns the canonical provider identifier (e.g., "aws", "azure").
    Name() string

    // ValidateRequest checks whether the requested role and scope are valid
    // before the request enters the approval workflow. Must not modify state.
    ValidateRequest(ctx context.Context, req ElevationRequest) error

    // Grant issues temporary elevated credentials after approval.
    // Must be idempotent — calling Grant twice with the same RequestID
    // must not create duplicate bindings.
    Grant(ctx context.Context, req ElevationRequest) (*ElevationGrant, error)

    // Revoke terminates an active grant before its natural expiry.
    Revoke(ctx context.Context, grant ElevationGrant) error

    // IsActive checks whether a grant is still valid and active.
    // Used by the expiry sweeper and status checks.
    IsActive(ctx context.Context, grant ElevationGrant) (bool, error)
}
```

## Built-in Providers

| Provider | Mechanism | Resource Scope |
|----------|-----------|----------------|
| AWS | STS AssumeRole + IAM Identity Center permission set assignment | AWS Account ID |
| Azure | Azure RBAC role assignment via Microsoft Graph API | Subscription / Resource Group |
| GCP | IAM conditional role binding with expiry condition | GCP Project ID |
| Kubernetes | ClusterRoleBinding or RoleBinding with TTL | Cluster / Namespace |

## Contract Tests

A shared test suite (`internal/providers/contract_test.go`) defines behavioral expectations all providers must satisfy:

- `ValidateRequest` rejects empty RequestID, UserIdentity, or zero Duration
- `Grant` returns a valid `ElevationGrant` with a future `ExpiresAt`
- `Grant` is idempotent (calling twice with the same RequestID is safe)
- `IsActive` returns `true` for a just-granted elevation
- `Revoke` succeeds for an active grant
- `Revoke` is idempotent (calling twice doesn't error)
- `IsActive` returns `false` after `Revoke`

Any new provider implementation must pass all contract tests before merging.

## Adding a New Provider

1. Create a new package under `internal/providers/<name>/`
2. Implement the `Provider` interface
3. Add a factory function to `providerFactories` in `contract_test.go`
4. Pass all contract tests: `go test ./internal/providers/... -short`
5. Add integration tests tagged `//go:build integration`
6. Add documentation under `docs/providers/<name>.md`
