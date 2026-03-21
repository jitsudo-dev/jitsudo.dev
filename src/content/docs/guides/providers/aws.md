---
title: AWS Provider
description: Set up jitsudo to grant temporary elevated access on AWS via STS AssumeRole or IAM Identity Center.
---

The AWS provider grants temporary elevated access using AWS STS AssumeRole (the default) or IAM Identity Center account assignment. Credentials are returned as standard AWS environment variables and work with any AWS SDK or CLI.

:::tip[Prerequisites at a glance]
Before configuring the AWS provider, jitsudod needs:
- An IAM role (or EC2/EKS instance role) with `sts:AssumeRole` on each target role
- `iam:PutRolePolicy` on each target role (for early revocation)
- Each target role's **trust policy** must allow jitsudod's identity to assume it
- For Kubernetes deployments: IRSA (IAM Roles for Service Accounts) is supported — no static credentials required

See [Prerequisites](#prerequisites) below for exact IAM policy documents.
:::

## How It Works

### STS AssumeRole mode (default)

1. jitsudod calls `sts:AssumeRole` with the role ARN constructed from your `role_arn_template`.
2. Session tags (`jitsudo:RequestID`, `jitsudo:UserIdentity`, `jitsudo:Reason`) are attached for traceability in AWS CloudTrail.
3. Temporary credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) are returned to the requester.
4. On revocation, jitsudod attaches an inline IAM deny policy with a `DateLessThanEquals` condition on `aws:TokenIssueTime`, immediately blocking the session without affecting newer sessions.

### IAM Identity Center mode

Manages AWS IAM Identity Center account assignments. Grant/Revoke create and delete account assignments for the user in the specified permission set.

## Prerequisites

### IAM Role for jitsudod

Create an IAM role for jitsudod with these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::*:role/jitsudo-*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PutRolePolicy",
      "Resource": "arn:aws:iam::*:role/jitsudo-*"
    }
  ]
}
```

`iam:PutRolePolicy` is required for session revocation. Scope it to `jitsudo-*` roles to limit blast radius.

### Target Roles

Each role that jitsudo can assume must have a trust policy allowing jitsudod's IAM role to assume it:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::JITSUDOD_ACCOUNT_ID:role/jitsudo-control-plane"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "jitsudo"
        }
      }
    }
  ]
}
```

### On EKS (IRSA)

Annotate the jitsudo ServiceAccount with the IAM role ARN:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/jitsudo-control-plane"
```

## Configuration

Add the `aws` section to your jitsudod config file:

```yaml
providers:
  aws:
    # Grant mechanism: "sts_assume_role" (default) or "identity_center"
    mode: "sts_assume_role"

    # Primary AWS region
    region: "us-east-1"

    # Role ARN template. Variables:
    #   {scope} — ResourceScope from the request (AWS account ID)
    #   {role}  — RoleName from the request
    role_arn_template: "arn:aws:iam::{scope}:role/jitsudo-{role}"

    # Maximum elevation duration (STS hard max is 12h)
    max_duration: "4h"
```

### Identity Center mode

```yaml
providers:
  aws:
    mode: "identity_center"
    region: "us-east-1"
    identity_center_instance_arn: "arn:aws:sso:::instance/ssoins-xxxxxxxxxxxxxxxxx"
    identity_center_store_id: "d-xxxxxxxxxx"
    max_duration: "4h"
```

### Configuration Fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `mode` | No | `sts_assume_role` | Grant mechanism: `sts_assume_role` or `identity_center` |
| `region` | No | `us-east-1` | Primary AWS region |
| `role_arn_template` | STS mode only | — | ARN template with `{scope}` and `{role}` variables |
| `max_duration` | No | no cap | Maximum elevation window (STS hard max is 12 hours) |
| `identity_center_instance_arn` | Identity Center only | — | IAM Identity Center instance ARN |
| `identity_center_store_id` | Identity Center only | — | Identity Center identity store ID |
| `endpoint_url` | No | — | Override AWS endpoint URL (LocalStack for testing) |

## Credential Chain

jitsudod uses the standard AWS credential chain in order:

1. Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
2. `~/.aws/credentials` and `~/.aws/config`
3. EC2 Instance Metadata Service (IMDS)
4. ECS task role
5. EKS IRSA (recommended for Kubernetes deployments)

No credentials are stored in the jitsudo config file.

## Using Elevated Credentials

After approval:

```bash
# Execute a single AWS CLI command
jitsudo exec req_01J8KZ... -- aws s3 ls s3://my-bucket

# Open an elevated shell
jitsudo shell req_01J8KZ...
$ aws sts get-caller-identity
```

The injected variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_DEFAULT_REGION`) are recognized by all AWS SDKs and tools.

## Duration Limits

| Constraint | Limit |
|------------|-------|
| STS minimum | 15 minutes |
| STS maximum | 12 hours |
| `max_duration` config | Configurable server-side cap |

## Request Examples

```bash
# Assume prod-infra-admin role in account 123456789012
jitsudo request \
  --provider aws \
  --role prod-infra-admin \
  --scope 123456789012 \
  --duration 2h \
  --reason "Investigating P1 ECS crash"

# Assume a role in a different account (cross-account)
jitsudo request \
  --provider aws \
  --role staging-deployer \
  --scope 987654321098 \
  --duration 30m \
  --reason "Deploy hotfix to staging"
```

## Testing with LocalStack

For integration testing, set `endpoint_url` to your LocalStack endpoint:

```yaml
providers:
  aws:
    mode: "sts_assume_role"
    region: "us-east-1"
    role_arn_template: "arn:aws:iam::{scope}:role/jitsudo-{role}"
    endpoint_url: "http://localhost:4566"
```
