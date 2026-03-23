---
title: jitsudod
description: Reference for the jitsudod control plane daemon.
---

`jitsudod` is the jitsudo control plane daemon. It is licensed under the [Elastic License 2.0 (ELv2)](/reference/licensing/).

## Synopsis

```
jitsudod [--config <path>]
```

## Flags

| Flag | Required | Default | Environment Variable | Description |
|------|----------|---------|----------------------|-------------|
| `--config <path>` | No | — | `JITSUDOD_CONFIG` | Path to YAML config file |

## Description

When run without a subcommand, `jitsudod` starts the control plane. It exposes a REST API (via grpc-gateway) and a native gRPC API, and runs until it receives SIGINT or SIGTERM.

Before starting for the first time, run [`jitsudod init`](/docs/server/jitsudod-init/) to test database connectivity, run migrations, and generate a starter config file.

## Related

- [`jitsudod init`](/docs/server/jitsudod-init/) — one-time bootstrap command
- [Server Configuration reference](/reference/configuration/) — full config file options
- [Single-Server Deployment guide](/guides/deployment/single-server/)
- [Kubernetes Deployment guide](/guides/deployment/kubernetes/)
