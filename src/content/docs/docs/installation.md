---
title: Installation
description: How to install the jitsudo CLI and deploy the jitsudod control plane.
---

## jitsudo CLI

The CLI is a single statically linked binary for Linux, macOS, and Windows.

### macOS / Linux (install script)

```bash
curl -fsSL https://jitsudo.dev/install.sh | sh
```

### Homebrew (macOS / Linux)

```bash
brew install jitsudo-dev/tap/jitsudo
```

### GitHub Releases

Download the binary for your platform from the [GitHub Releases page](https://github.com/jitsudo-dev/jitsudo/releases).

```bash
# Linux amd64
curl -LO https://github.com/jitsudo-dev/jitsudo/releases/latest/download/jitsudo_linux_amd64
chmod +x jitsudo_linux_amd64
sudo mv jitsudo_linux_amd64 /usr/local/bin/jitsudo
```

### Build from source

```bash
git clone https://github.com/jitsudo-dev/jitsudo
cd jitsudo
make build
# Binaries are in ./bin/
```

---

## jitsudod Control Plane

### Docker Compose (local / evaluation)

```bash
make docker-up
```

See the [Quickstart](/docs/quickstart/) for a full walkthrough.

### Single server (bootstrap command)

For a single VM or bare metal server:

```bash
jitsudod init \
  --db-url postgres://jitsudo:password@localhost:5432/jitsudo \
  --oidc-issuer https://your-idp.okta.com \
  --oidc-client-id jitsudo-server
```

### Kubernetes (Helm chart)

```bash
helm repo add jitsudo https://jitsudo-dev.github.io/helm-charts
helm install jitsudo jitsudo/jitsudo \
  --set auth.oidcIssuer=https://your-idp.okta.com \
  --set auth.clientId=jitsudo-server \
  --set database.url=postgres://...
```

### Terraform modules

Terraform modules for EKS, AKS, and GKE are available in the [`terraform-modules`](https://github.com/jitsudo-dev/terraform-modules) repository.
