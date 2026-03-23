# jitsudo.dev

Marketing website and documentation for [jitsudo](https://github.com/jitsudo-dev/jitsudo) — JIT privileged access management for AWS, Azure, GCP, and Kubernetes.

**Live site:** [jitsudo.dev](https://jitsudo.dev)
**Deployed on:** Cloudflare Pages

## Stack

- [Astro](https://astro.build) — static site generator
- [Starlight](https://starlight.astro.build) — documentation framework (powers `/docs/`)
- Custom Astro landing page at `/` — dark charcoal + orange design
- Inter font via `@fontsource/inter`
- Deployed to Cloudflare Pages

## Structure

```
src/
  pages/
    index.astro          # Custom landing page (standalone, no Starlight layout)
  components/
    Nav.astro            # Site navigation
    Hero.astro           # Split hero with terminal demo
    Terminal.astro       # Styled CLI demo window
    ArchDiagram.astro    # Architecture diagram (Requestors → jitsudod → Providers)
    FeatureCards.astro   # 3×2 feature grid
    CtaBanner.astro      # Bottom CTA section
    Footer.astro         # Rich link footer
  content/docs/          # Starlight-managed documentation
    docs/                # Getting started, CLI reference, architecture
    guides/              # Deployment and provider guides
    reference/           # Config, API, policy schema, audit log
  styles/
    custom.css           # Brand color overrides for Starlight
```

## Development

```bash
npm install
npm run dev        # localhost:4321
npm run build      # production build to ./dist/
npm run preview    # preview production build locally
```

## Content

- **Landing page** — edit `src/pages/index.astro` and components in `src/components/`
- **Docs** — add/edit `.md` or `.mdx` files in `src/content/docs/`; update the sidebar in `astro.config.mjs`

## License

Documentation: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

## Copyright

Copyright © 2026 Yu Technology Group, LLC d/b/a jitsudo. All rights reserved.
