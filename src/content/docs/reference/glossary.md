---
title: Glossary
description: Definitions of key terms used throughout the jitsudo documentation.
---

## A

**Approval Policy**
An OPA/Rego policy in the `jitsudo.approval` package that determines how a request is routed: to OPA auto-approval (Tier 1), AI-assisted review (Tier 2), or a human approver (Tier 3). Policies without an `approver_tier` rule default to `"human"`. See [Writing Policies](/docs/guides/writing-policies/).

**Approver**
The entity that approves an elevation request. Resolved dynamically at request time by the OPA policy engine — not a fixed person or standing role. See [Approval Model](/docs/architecture/approval-model/).

**Audit Log**
The append-only, tamper-evident record of every jitsudo action. Each entry is linked to the previous by a SHA-256 hash chain, making retroactive modification detectable. See [Audit Log Reference](/docs/reference/audit-log/).

## B

**Break-glass**
An emergency access mechanism that bypasses the normal approval workflow and issues credentials immediately. Triggers high-priority alerts to all configured notification channels. Full audit trail is preserved. Eligibility for break-glass is controlled by policy. See [Request Lifecycle](/docs/architecture/request-lifecycle/).

## E

**Eligibility Policy**
An OPA/Rego policy in the `jitsudo.eligibility` package that answers: "Is this user allowed to request this role in this scope, for this duration?" See [Writing Policies](/docs/guides/writing-policies/).

**Elevation Request**
A request submitted by a principal to temporarily assume a role in a cloud provider. Moves through states: PENDING → APPROVED → ACTIVE → EXPIRED (or REVOKED). See [Request Lifecycle](/docs/architecture/request-lifecycle/).

**ELv2**
[Elastic License v2](https://www.elastic.co/licensing/elastic-license). The license for the jitsudod control plane binary. Permits self-hosted use by companies for their own internal operations at no cost. Prohibits offering the software as a managed service to third parties. See [Licensing](/docs/reference/licensing/).

## G

**Grant**
An approved, active elevation — credentials have been issued by the cloud provider and are in effect. A grant transitions to EXPIRED at its TTL or to REVOKED if explicitly terminated early.

**Groups**
Collections of principals managed in the IdP. Group membership is read from the `groups` claim in the OIDC ID token. jitsudo does not manage groups — it trusts the IdP as the authoritative source.

## I

**IdP (Identity Provider)**
The system that authenticates users and issues OIDC tokens. jitsudo supports Okta, Entra ID (Azure AD), Keycloak, Google Workspace (via Dex), and any OIDC-compliant IdP. See [OIDC Integration](/docs/guides/oidc/).

## J

**jitsudo**
The CLI binary (Apache 2.0). Used by humans and agents to submit requests, approve/deny, execute with credentials, and query the audit log.

**jitsudod**
The control plane daemon (ELv2). Authenticates users, evaluates policies, manages the request state machine, issues credentials via provider adapters, and writes the audit log.

## M

**MCP (Model Context Protocol)**
An open protocol for AI agents to interact with external tools. jitsudo exposes an MCP server with two roles: agents can submit elevation requests on their own behalf (MCP as requestor), and agents can evaluate and decide on pending requests (MCP as approver). See [Approval Model](/docs/architecture/approval-model/).

## O

**OPA (Open Policy Agent)**
The embedded policy engine used by jitsudo. Policies are written in the Rego language and evaluated by the OPA library embedded in jitsudod. See [Writing Policies](/docs/guides/writing-policies/).

## P

**Principal**
Any authenticated entity that can submit an elevation request — a human engineer, a CI/CD pipeline, or an AI agent.

**Provider**
A cloud platform adapter that implements the jitsudo Provider interface: `Grant()`, `Revoke()`, `IsActive()`. Current providers: AWS, Azure, GCP, Kubernetes. See [Provider Interface](/docs/architecture/provider-interface/).

## R

**Rego**
The policy language used by OPA. jitsudo policies are Rego files stored in the jitsudo database and evaluated at request time. See [Writing Policies](/docs/guides/writing-policies/).

**Role**
An abstract permission set defined in jitsudo that maps to a provider-specific role (e.g., an AWS IAM role, an Azure RBAC role, a GCP IAM role, or a Kubernetes ClusterRole). The role name in jitsudo requests is resolved to a provider-specific ARN/role definition by the provider configuration.

## S

**Scope**
The resource boundary within which a role applies. Provider-specific:
- AWS: account ID (e.g., `123456789012`)
- Azure: subscription ID or resource group (ARM scope)
- GCP: project ID (e.g., `my-project`)
- Kubernetes: namespace name, or `*` for cluster-wide

## T

**Tier 1 / Tier 2 / Tier 3**
The three approval tiers in the jitsudo approval model:
- **Tier 1**: OPA auto-approve — millisecond approval for low-risk, high-trust requests
- **Tier 2**: AI-assisted review via MCP — AI agent evaluates context, approves, denies, or escalates with reasoning captured in the audit log
- **Tier 3**: Human approval — policy-designated approver; receives any request Tier 2 escalates

See [Approval Model](/docs/architecture/approval-model/).

**Trust Tier**
A numeric value (0–4) assigned to a principal reflecting their identity assurance and access history. Stored in the `principals` table and passed to every OPA policy evaluation as `input.context.trust_tier`. Used by policies to gate Tier 1 auto-approval eligibility and access scope. Administrators set trust tiers via the `SetPrincipalTrustTier` API.

**TTL (Time-To-Live)**
The duration of an elevation grant. After the TTL expires, the grant moves to the EXPIRED state and the provider revokes the credentials.

## Z

**Zero persistent elevation**
The core security property jitsudo enforces: no user or agent holds standing admin access. All elevated access is granted on-demand, time-limited, and automatically revoked at expiry.
