---
title: Licensing
description: How jitsudo's dual license model works, what you can do with each component, and frequently asked questions for enterprise evaluators.
---

## License Summary

jitsudo uses a dual-license model:

| Component | License | What it means |
|-----------|---------|---------------|
| `jitsudo` CLI | [Apache 2.0](https://github.com/jitsudo-dev/jitsudo/blob/main/LICENSE-APACHE) | Permissive open source — use, modify, distribute freely |
| `jitsudod` control plane | [Elastic License v2 (ELv2)](https://github.com/jitsudo-dev/jitsudo/blob/main/LICENSE-ELV2) | Source-available; self-hosted use is free; managed service use requires a commercial license |
| Provider packages (`pkg/providers/`) | Apache 2.0 | Permissive open source |
| Go client library (`pkg/client/`) | Apache 2.0 | Permissive open source |

## Frequently Asked Questions

### Can my company self-host jitsudo for internal use?

**Yes.** The Elastic License v2 explicitly permits using the software for your own internal business operations. You can run jitsudod on your infrastructure, connect it to your cloud providers, and use it for your engineering team — all at no cost under ELv2.

### Can a managed service provider or cloud vendor offer jitsudo as a hosted service?

**No, without a commercial agreement.** ELv2 prohibits offering the software (or a substantially similar product derived from it) as a managed service to third parties. If you are building a product where customers access jitsudo functionality without running it themselves, contact us for a commercial license.

### Can I modify jitsudod for internal use?

**Yes.** You can modify the source code for use within your own organization. You cannot distribute modified versions or offer them as a service without complying with ELv2.

### Can I use the jitsudo CLI in my own open source project?

**Yes.** The CLI, client library, and provider packages are Apache 2.0. You can use, fork, embed, or redistribute them freely, including in commercial products, as long as you include the Apache 2.0 license notice.

### Does the license affect how I connect jitsudo to my cloud providers?

**No.** ELv2 governs the jitsudod software itself. It does not restrict how you configure your cloud provider accounts, what IAM roles you create, or what access patterns you implement.

### I'm evaluating jitsudo for a proof of concept. Do I need a license?

**No.** A PoC, evaluation, or pilot deployment running for your own team is internal use and is fully covered by ELv2 at no cost.

## Why the Dual License?

The split exists to balance two goals:

1. **Open ecosystem**: The CLI and SDK components are Apache 2.0 so the developer ecosystem can build on jitsudo's interfaces freely — scripts, integrations, custom providers — without license friction.

2. **Sustainable development**: The control plane is ELv2 to prevent hosted-SaaS companies from offering jitsudo as a cloud service and competing with the project's commercial tier, which funds continued development.

This is the same model used by Elasticsearch, Grafana, and other infrastructure projects. It is not uncommon in the infrastructure tooling space and should not be a blocker for enterprise self-hosted use.

## Questions?

If your use case is unclear or you need a commercial license for managed service or OEM use, open an issue at [github.com/jitsudo-dev/jitsudo](https://github.com/jitsudo-dev/jitsudo) or contact the maintainers directly.
