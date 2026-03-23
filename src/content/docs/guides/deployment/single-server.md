---
title: Single-Server Bootstrap
description: Deploy jitsudo on a single Linux server using jitsudo server init.
---

Deploy jitsudo on a single Linux server. This setup is suitable for small teams or organizations that do not run Kubernetes.

## Prerequisites

- A Linux server (Ubuntu 22.04+ or similar)
- PostgreSQL 14+ (can be on the same server or a managed service)
- An OIDC provider — see [OIDC Integration](/guides/oidc/)
- A reverse proxy (nginx or Caddy) for TLS termination

## 1. Install the Binaries

Download the latest release from GitHub:

```bash
# Set the version
VERSION=0.1.0
ARCH=linux_amd64

# Download jitsudo CLI and jitsudod server
curl -LO "https://github.com/jitsudo-dev/jitsudo/releases/download/v${VERSION}/jitsudo_${VERSION}_${ARCH}.tar.gz"
curl -LO "https://github.com/jitsudo-dev/jitsudo/releases/download/v${VERSION}/jitsudod_${VERSION}_${ARCH}.tar.gz"

tar -xzf jitsudo_${VERSION}_${ARCH}.tar.gz
tar -xzf jitsudod_${VERSION}_${ARCH}.tar.gz

sudo mv jitsudo jitsudod /usr/local/bin/
sudo chmod +x /usr/local/bin/jitsudo /usr/local/bin/jitsudod
```

## 2. Create the Database

```bash
# As the postgres superuser
createuser jitsudo
createdb -O jitsudo jitsudo
psql -c "ALTER USER jitsudo WITH PASSWORD 'STRONG_PASSWORD';"
```

## 3. Bootstrap the Control Plane

```bash
sudo mkdir -p /etc/jitsudo

jitsudo server init \
  --db-url "postgres://jitsudo:STRONG_PASSWORD@localhost:5432/jitsudo?sslmode=require" \
  --oidc-issuer https://your-idp.example.com \
  --oidc-client-id jitsudo-server \
  --http-addr :8080 \
  --grpc-addr :8443 \
  --config-out /etc/jitsudo/config.yaml
```

This will:
1. Test the database connection.
2. Run schema migrations.
3. Write a starter config to `/etc/jitsudo/config.yaml`.

## 4. Edit the Configuration

Edit `/etc/jitsudo/config.yaml` to enable providers and notifications. See the [Server Configuration reference](/reference/configuration/) for all options.

Minimal production config:

```yaml
server:
  http_addr: ":8080"
  grpc_addr: ":8443"

database:
  # Supply via JITSUDOD_DATABASE_URL env var instead of inlining credentials
  url: ""

auth:
  oidc_issuer: "https://your-idp.example.com"
  client_id: "jitsudo-server"

tls:
  cert_file: "/etc/jitsudo/tls.crt"
  key_file:  "/etc/jitsudo/tls.key"

log:
  level: "info"
  format: "json"
```

## 5. Create a systemd Unit

Create `/etc/systemd/system/jitsudod.service`:

```ini
[Unit]
Description=jitsudo control plane
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=jitsudo
Group=jitsudo
ExecStart=/usr/local/bin/jitsudod --config /etc/jitsudo/config.yaml
Restart=on-failure
RestartSec=5

# Supply sensitive values via environment variables
# so they don't appear in the config file
Environment=JITSUDOD_DATABASE_URL=postgres://jitsudo:STRONG_PASSWORD@localhost:5432/jitsudo?sslmode=require
EnvironmentFile=-/etc/jitsudo/env

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/log/jitsudo

[Install]
WantedBy=multi-user.target
```

Create the jitsudo system user and directories:

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin jitsudo
sudo mkdir -p /var/log/jitsudo
sudo chown jitsudo:jitsudo /var/log/jitsudo /etc/jitsudo
sudo chmod 700 /etc/jitsudo
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now jitsudod
sudo systemctl status jitsudod
```

## 6. Reverse Proxy (nginx + TLS)

Install nginx and certbot, then create `/etc/nginx/sites-available/jitsudo`:

```nginx
server {
    listen 443 ssl;
    server_name jitsudo.example.com;

    ssl_certificate     /etc/letsencrypt/live/jitsudo.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/jitsudo.example.com/privkey.pem;

    # REST API gateway
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Health endpoints
    location ~ ^/(healthz|readyz|version) {
        proxy_pass http://127.0.0.1:8080;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name jitsudo.example.com;
    return 301 https://$host$request_uri;
}
```

```bash
sudo ln -s /etc/nginx/sites-available/jitsudo /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

For gRPC, clients connect directly to port `8443`. Configure TLS for the gRPC listener in `/etc/jitsudo/config.yaml`:

```yaml
tls:
  cert_file: "/etc/letsencrypt/live/jitsudo.example.com/fullchain.pem"
  key_file:  "/etc/letsencrypt/live/jitsudo.example.com/privkey.pem"
```

## 7. Verify

```bash
# From the server
curl https://jitsudo.example.com/healthz   # → ok
curl https://jitsudo.example.com/version   # → {"version":"0.1.0",...}

# From your workstation
jitsudo login \
  --provider https://your-idp.example.com \
  --server https://jitsudo.example.com:8443
jitsudo server status --server-url https://jitsudo.example.com
```

## 8. Enroll the First Administrator

`server init` does not create any administrator accounts. Admin authority in jitsudo is derived entirely from your identity provider: users who are members of the `jitsudo-admins` IdP group receive admin privileges when they authenticate.

**Day-one steps:**

1. In your IdP, create a group named exactly `jitsudo-admins`.
2. Add the first administrator's account to that group.
3. That user logs in: `jitsudo login --server https://jitsudo.example.com:8443`

The administrator can now assign [principal trust tiers](/docs/architecture/approval-model/#principal-trust-tiers) and perform other privileged control plane operations.

See [Admin Bootstrap](/docs/cli/server/#admin-bootstrap) for the full procedure, including ongoing membership management and the recovery path if all administrators are offboarded.

---

## Updates

To update jitsudod:

```bash
# Download new binary
sudo mv /usr/local/bin/jitsudod /usr/local/bin/jitsudod.bak
# Install new binary...
sudo systemctl restart jitsudod
```

Migrations run automatically on startup. The `--skip-migrations` flag is available if you need to run them separately.
