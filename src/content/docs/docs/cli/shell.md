---
title: jitsudo shell
description: Open an interactive shell with elevated credentials injected into the environment.
---

Open an interactive shell with elevated credentials injected into the environment.

## Synopsis

```
jitsudo shell <request-id> [--shell <shell-binary>]
```

## Description

`jitsudo shell` fetches the active credentials for an elevation request and drops you into an interactive shell subprocess with those credentials injected as environment variables.

**Key security property:** The parent shell never receives the credentials. They exist only in the child shell's environment and are discarded on exit.

When the shell opens, a warning banner is printed to stderr showing the request ID and credential expiry time:

```
*** jitsudo elevated shell — request req_01J8KZ... ***
*** Credentials expire at 2026-03-20T18:00:00+00:00 ***
*** Type 'exit' to leave the elevated context ***
```

Two additional variables are injected regardless of provider:

- `JITSUDO_ELEVATED=1` — marks the shell as elevated
- `JITSUDO_REQUEST_ID=<id>` — the active request ID

You can use these in your shell prompt (e.g. `PS1`) to visually indicate when you are in an elevated context.

## Arguments

| Argument | Description |
|----------|-------------|
| `<request-id>` | The ID of an active elevation request |

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--shell <path>` | `$SHELL` env var, then `/bin/sh` | Shell binary to launch |

## Global Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--server <url>` | Stored credentials | Control plane URL |
| `--token <token>` | Stored credentials | Bearer token override |
| `-q, --quiet` | `false` | Suppress non-essential output |
| `--debug` | `false` | Enable debug logging |

## Examples

```bash
# Open an elevated shell using your default shell
jitsudo shell req_01J8KZ4F2EMNQZ3V7XKQYBD4W

# Explicitly use zsh
jitsudo shell req_01J8KZ4F2EMNQZ3V7XKQYBD4W --shell zsh

# Verify credentials are injected
jitsudo shell req_01J8KZ4F2EMNQZ3V7XKQYBD4W
$ env | grep AWS_
AWS_ACCESS_KEY_ID=ASIA...
AWS_SECRET_ACCESS_KEY=...
AWS_SESSION_TOKEN=...
AWS_DEFAULT_REGION=us-east-1
$ exit
```

## Injected Environment Variables

In addition to the provider-specific variables, the shell always receives:

| Variable | Value |
|----------|-------|
| `JITSUDO_ELEVATED` | `1` |
| `JITSUDO_REQUEST_ID` | The active request ID |

Provider-specific variables:

| Provider | Variables injected |
|----------|-------------------|
| `aws` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_DEFAULT_REGION` |
| `gcp` | `GOOGLE_CLOUD_PROJECT` |
| `azure` | `AZURE_SUBSCRIPTION_ID` |
| `kubernetes` | `JITSUDO_K8S_ROLE`, `JITSUDO_K8S_NAMESPACE` |

## Shell Prompt Tip

Add this to your `.zshrc` or `.bashrc` to visually indicate an elevated context:

```bash
# Show [ELEVATED] in the prompt when inside a jitsudo shell
if [[ -n "$JITSUDO_ELEVATED" ]]; then
  PS1="[ELEVATED:$JITSUDO_REQUEST_ID] $PS1"
fi
```

## vs. `jitsudo exec`

| | `jitsudo shell` | `jitsudo exec` |
|---|---|---|
| Use case | Interactive investigation | Scripted / single command |
| Session | Stays open until you `exit` | Exits when the command completes |
| Best for | Debugging, exploration | CI pipelines, automation |
