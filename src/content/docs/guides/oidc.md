---
title: OIDC Integration
description: Configure your identity provider to work with jitsudo.
---

jitsudo uses OpenID Connect (OIDC) for all authentication. The CLI authenticates users via the Device Authorization Flow (RFC 8628) and the server validates JWTs issued by your IdP.

## How Authentication Works

1. **CLI → IdP:** `jitsudo login` starts the device flow, directing the user to authenticate in any browser.
2. **IdP → CLI:** After browser authentication, the IdP issues an ID token (JWT).
3. **CLI → Server:** Every API request carries the ID token as a `Bearer` token in the `Authorization` header.
4. **Server → IdP:** jitsudod validates the token by fetching the IdP's JWKS from `{oidc_issuer}/.well-known/openid-configuration` and verifying the JWT signature, issuer (`iss`), audience (`aud`), and expiry (`exp`).

## Server Configuration

```yaml
auth:
  # Must match the `iss` claim in tokens issued by your IdP.
  oidc_issuer: "https://your-idp.example.com"

  # OIDC client ID registered with your IdP for the jitsudo server.
  client_id: "jitsudo-server"
```

You need **two** OIDC clients registered with your IdP:
- **`jitsudo-server`** — the server's resource server / audience
- **`jitsudo-cli`** — the CLI's public client (uses device flow, hardcoded in the CLI)

## Required Scopes

The CLI requests these scopes:

| Scope | Purpose |
|-------|---------|
| `openid` | Required for OIDC |
| `email` | Used as the user's identity in requests and audit log |
| `profile` | Display name |
| `groups` | Group membership (used in eligibility/approval policies) |
| `offline_access` | Refresh token (for future silent refresh support) |

Make sure your IdP includes the `groups` claim in the ID token.

---

## Okta

### Step 1: Create a Server Application

1. In Okta Admin Console: **Applications → Create App Integration → OIDC → Web Application**.
2. Set **Grant type**: Device Authorization.
3. Note the **Client ID** (`jitsudo-server`) — this is your `client_id`.
4. Set **Issuer** to your Okta org URL: `https://your-org.okta.com`.

### Step 2: Create a CLI Application

1. **Applications → Create App Integration → OIDC → Native Application**.
2. Set **Grant type**: Device Authorization.
3. Set **Client ID** to `jitsudo-cli` (or note the generated one and configure it in the CLI source if needed).

### Step 3: Add Groups Claim

In the **Sign-On** tab of the server app, edit the token settings:

1. Add a claim: Name `groups`, Include in `ID Token`, Value type `Groups`, Filter `Matches regex: .*`.

### Step 4: Configure jitsudod

```yaml
auth:
  oidc_issuer: "https://your-org.okta.com"
  client_id: "jitsudo-server"
```

### Step 5: Log In

```bash
jitsudo login --provider https://your-org.okta.com
```

---

## Microsoft Entra ID (Azure AD)

### Step 1: Register the Server Application

```bash
az ad app create \
  --display-name "jitsudo-server" \
  --identifier-uris "api://jitsudo-server"

# Note the appId — this is your client_id
az ad app show --display-name "jitsudo-server" --query appId -o tsv
```

Enable device flow on the registration:

```bash
# In Azure Portal: App registrations → your app → Authentication
# Add platform: Mobile and desktop applications
# Enable "Allow public client flows"
```

### Step 2: Add Groups Claim

1. **App registrations → your app → Token configuration → Add groups claim**.
2. Select **Security groups** and include in **ID Token**.

### Step 3: Register the CLI Application

```bash
az ad app create --display-name "jitsudo-cli"
# Enable device flow and "Allow public client flows"
# The appId becomes the CLI's client ID (must match "jitsudo-cli" constant in source)
```

### Step 4: Configure jitsudod

```yaml
auth:
  oidc_issuer: "https://login.microsoftonline.com/<TENANT_ID>/v2.0"
  client_id: "<SERVER_APP_CLIENT_ID>"
```

### Step 5: Log In

```bash
jitsudo login --provider "https://login.microsoftonline.com/<TENANT_ID>/v2.0"
```

---

## Keycloak

### Step 1: Create a Realm and Clients

1. In Keycloak Admin Console, create a realm (e.g. `jitsudo`).
2. Create a client: **Clients → Create → Client ID: `jitsudo-server`**.
   - Protocol: `openid-connect`
   - Access Type: `confidential` (or `public` for development)
   - Enable **Device Authorization Grant**.
3. Create a client: **Client ID: `jitsudo-cli`**.
   - Protocol: `openid-connect`
   - Access Type: `public`
   - Enable **Device Authorization Grant**.

### Step 2: Add Groups Mapper

For each client, add a mapper:
- **Mapper type**: Group Membership
- **Token Claim Name**: `groups`
- **Add to ID token**: ON

### Step 3: Configure jitsudod

```yaml
auth:
  oidc_issuer: "https://keycloak.example.com/realms/jitsudo"
  client_id: "jitsudo-server"
```

### Step 4: Log In

```bash
jitsudo login --provider https://keycloak.example.com/realms/jitsudo
```

---

## Google Workspace

### Step 1: Create OAuth Clients

In Google Cloud Console:
1. **APIs & Services → Credentials → Create Credentials → OAuth client ID**.
2. **Application type: Desktop app** (supports device flow via workaround).
3. Create one for the server (`jitsudo-server`) and one for the CLI (`jitsudo-cli`).

:::caution
Google Workspace does not natively support RFC 8628 device flow for standard OAuth clients. Consider using Dex as an OIDC bridge in front of Google Workspace for full support.
:::

### Dex as a Bridge

Dex federates to Google Workspace and provides standard RFC 8628 device flow:

```yaml
# dex-config.yaml
connectors:
  - type: google
    id: google
    name: Google
    config:
      clientID: <GOOGLE_CLIENT_ID>
      clientSecret: <GOOGLE_CLIENT_SECRET>
      redirectURI: https://dex.example.com/callback
      hostedDomains:
        - your-org.com
```

```yaml
auth:
  oidc_issuer: "https://dex.example.com"
  client_id: "jitsudo-server"
```

---

## Troubleshooting

### Token validation fails with `iss` mismatch

The `oidc_issuer` in your config must exactly match the `iss` claim in the JWT. Fetch a token and inspect it:

```bash
# Decode the JWT (base64 decode the middle segment)
jitsudo login --provider https://your-idp.example.com
cat ~/.jitsudo/credentials | python3 -c "
import json, base64, sys
token = json.load(sys.stdin)['Token']
payload = token.split('.')[1]
# Add padding
payload += '=' * (4 - len(payload) % 4)
print(json.dumps(json.loads(base64.b64decode(payload)), indent=2))
"
```

Check the `iss` field and make sure it matches your config exactly.

### `groups` claim missing

If eligibility policies use `input.user.groups` but the claim is empty, your IdP is not including groups in the ID token. Add the groups claim as described above for your IdP.

### Device flow not supported

Not all IdPs enable device flow by default. Check that:
- The client type is `Native` or `Public` (not `Web`).
- Device authorization grant is explicitly enabled.
- Your IdP's device authorization endpoint is reachable from the CLI machine.
