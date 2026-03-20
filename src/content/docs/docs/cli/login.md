---
title: jitsudo login
description: Authenticate with your identity provider using the OIDC Device Authorization Flow.
---

Authenticate with your identity provider using the OIDC Device Authorization Flow (RFC 8628).

## Synopsis

```
jitsudo login --provider <oidc-issuer-url> [flags]
```

## Description

`jitsudo login` starts an OIDC device flow against your configured identity provider. The flow works without a browser redirect on the same machine, making it suitable for headless terminals and SSH sessions.

**What happens:**

1. jitsudo requests a device code from your IdP's device authorization endpoint.
2. A verification URL (and short user code) is printed to your terminal.
3. You open the URL in any browser and authenticate.
4. jitsudo polls the token endpoint until you complete the browser step.
5. The issued ID token is verified against your IdP's JWKS and stored at `~/.jitsudo/credentials`.

**OIDC scopes requested:** `openid email profile groups offline_access`

**Credentials file:** `~/.jitsudo/credentials` (mode `0600`). Contains the server URL, raw ID token, expiry timestamp, and your email address.

:::note
When the token expires you must re-run `jitsudo login`. Silent refresh via refresh tokens is planned for a future release.
:::

## Flags

| Flag | Required | Description |
|------|----------|-------------|
| `--provider <url>` | Yes | OIDC issuer URL (e.g. `https://your-org.okta.com`, `https://login.microsoftonline.com/<tenant>/v2.0`) |

## Global Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--server <url>` | — | Control plane URL to save alongside credentials |
| `--config <path>` | `~/.jitsudo/config.yaml` | Config file path |
| `-q, --quiet` | `false` | Suppress non-essential output |
| `--debug` | `false` | Enable debug logging |

## Examples

```bash
# Log in against the local development dex instance
jitsudo login --provider http://localhost:5556/dex

# Log in and explicitly specify which server to use
jitsudo login \
  --provider https://your-org.okta.com \
  --server https://jitsudo.example.com:8443

# Log in with Entra ID (Azure AD)
jitsudo login --provider https://login.microsoftonline.com/<tenant-id>/v2.0
```

## Output

```
Open this URL to authenticate:
  https://your-idp.example.com/activate?user_code=ABCD-1234

Waiting for authorization...
Logged in as alice@example.com
Server:     https://jitsudo.example.com:8443
```

## Supported Identity Providers

Any OIDC provider that implements RFC 8628 (Device Authorization Grant) is supported, including:

| Provider | Notes |
|----------|-------|
| Okta | Full support |
| Microsoft Entra ID (Azure AD) | Full support |
| Google Workspace | Full support |
| Keycloak | Full support (self-hosted) |
| Dex | Used in the local dev environment |

See the [OIDC Integration guide](/guides/oidc/) for per-provider setup instructions.
