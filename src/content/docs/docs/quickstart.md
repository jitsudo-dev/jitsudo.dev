---
title: Quickstart
description: Get jitsudo running locally in 5 minutes using Docker Compose.
---

import { Steps, Aside } from '@astrojs/starlight/components';

This quickstart runs jitsudo locally using Docker Compose. You'll have a fully functional control plane, a mock OIDC provider, and a PostgreSQL database — no cloud credentials required.

**Prerequisites:** Docker or Podman installed.

<Steps>

1. **Clone the repository**

   ```bash
   git clone https://github.com/jitsudo-dev/jitsudo
   cd jitsudo
   ```

2. **Start the local environment**

   ```bash
   make docker-up
   ```

   This starts:
   - `jitsudod` — the control plane on `localhost:8080`
   - `PostgreSQL` — the database
   - `dex` — a mock OIDC provider on `localhost:5556`

3. **Install the CLI**

   ```bash
   # macOS / Linux
   curl -fsSL https://jitsudo.dev/install.sh | sh

   # Or build from source
   make build && export PATH="$PWD/bin:$PATH"
   ```

4. **Log in**

   ```bash
   jitsudo login --provider http://localhost:5556/dex
   ```

   This opens a device flow. Visit the URL shown in the terminal and log in with a test user:
   - `alice@example.com` / `password`
   - `bob@example.com` / `password`

5. **Submit an elevation request**

   ```bash
   jitsudo request \
     --provider mock \
     --role test-role \
     --scope test-scope \
     --duration 1h \
     --reason "Testing jitsudo locally"
   ```

   Note the request ID (e.g., `req_01J8KZ...`).

6. **Approve the request (in another terminal)**

   ```bash
   jitsudo login --provider http://localhost:5556/dex  # log in as a different user
   jitsudo approve req_01J8KZ...
   ```

7. **Use the elevated credentials**

   ```bash
   jitsudo exec req_01J8KZ... -- env | grep MOCK
   ```

</Steps>

<Aside type="tip">
Run `make docker-down` to stop the local environment and clean up.
</Aside>

## Next steps

- [Install jitsudo](/docs/installation/) in a real environment
- Configure a real cloud provider (AWS, Azure, GCP, Kubernetes)
- Set up SSO with your identity provider (Okta, Entra ID, Google Workspace)
