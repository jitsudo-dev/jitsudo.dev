---
title: jitsudo exec
description: Execute a command with elevated credentials injected as environment variables.
---

Execute a single command in a subprocess with elevated credentials injected into its environment.

## Synopsis

```
jitsudo exec <request-id> -- <command> [args...]
```

## Description

`jitsudo exec` fetches the active credentials for an approved elevation request and executes the specified command in a subprocess with those credentials injected as environment variables.

**Key security property:** The parent shell never receives the credentials. They exist only in the child process's environment and are discarded when the child exits.

The subprocess inherits all environment variables from the parent, with the provider-specific credential variables appended. The child process's stdin, stdout, and stderr are connected directly to the terminal.

If the child exits with a non-zero code, `jitsudo exec` exits with the same code.

The request must be in `ACTIVE` state. If it is still `PENDING` or `APPROVED`, wait for the approver to act first.

## Arguments

| Argument | Description |
|----------|-------------|
| `<request-id>` | The ID of an active elevation request |
| `--` | Separator between jitsudo flags and the command to run |
| `<command> [args...]` | The command and its arguments to execute |

## Global Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--server <url>` | Stored credentials | Control plane URL |
| `--token <token>` | Stored credentials | Bearer token override |
| `-q, --quiet` | `false` | Suppress non-essential output |
| `--debug` | `false` | Enable debug logging |

## Examples

```bash
# Run an AWS CLI command with elevated credentials
jitsudo exec req_01J8KZ4F2EMNQZ3V7XKQYBD4W -- \
  aws ecs describe-tasks --cluster prod --tasks abc123

# Run kubectl against a production cluster
jitsudo exec req_01J8KZ4F2EMNQZ3V7XKQYBD4W -- \
  kubectl get pods -n production

# Inspect the injected environment variables
jitsudo exec req_01J8KZ4F2EMNQZ3V7XKQYBD4W -- env | grep AWS_

# Run a script
jitsudo exec req_01J8KZ4F2EMNQZ3V7XKQYBD4W -- ./scripts/rotate-keys.sh

# Run terraform with elevated AWS credentials
jitsudo exec req_01J8KZ4F2EMNQZ3V7XKQYBD4W -- \
  terraform apply -auto-approve -target=module.eks
```

## Injected Environment Variables

The variables injected depend on the provider:

| Provider | Variables injected |
|----------|-------------------|
| `aws` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_DEFAULT_REGION` |
| `gcp` | `GOOGLE_CLOUD_PROJECT` |
| `azure` | `AZURE_SUBSCRIPTION_ID` |
| `kubernetes` | `JITSUDO_K8S_ROLE`, `JITSUDO_K8S_NAMESPACE` |

## vs. `jitsudo shell`

| | `jitsudo exec` | `jitsudo shell` |
|---|---|---|
| Use case | Run a single known command | Explore interactively |
| Session | Short-lived subprocess | Interactive shell session |
| Audit trail | Single exec event | Shell open/close events |

Use `jitsudo exec` in scripts and CI pipelines. Use [`jitsudo shell`](/docs/cli/shell/) for interactive investigation.
