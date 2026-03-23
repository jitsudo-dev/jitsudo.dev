// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://jitsudo.dev',
	integrations: [
		starlight({
			title: 'jitsudo',
			description: 'sudo for your cloud. JIT privileged access management for AWS, Azure, GCP, and Kubernetes.',
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/jitsudo-dev/jitsudo' },
			],
			editLink: {
				baseUrl: 'https://github.com/jitsudo-dev/jitsudo.dev/edit/main/',
			},
			sidebar: [
				{
					label: 'Getting Started',
					items: [
						{ label: 'What is jitsudo?', slug: 'docs/what-is-jitsudo' },
						{ label: 'Quickstart (5 minutes)', slug: 'docs/quickstart' },
						{ label: 'Installation', slug: 'docs/installation' },
					],
				},
				{
					label: 'CLI Reference',
					items: [
						{ label: 'jitsudo login', slug: 'docs/cli/login' },
						{ label: 'jitsudo request', slug: 'docs/cli/request' },
						{ label: 'jitsudo status', slug: 'docs/cli/status' },
						{ label: 'jitsudo approve / deny', slug: 'docs/cli/approve-deny' },
						{ label: 'jitsudo exec', slug: 'docs/cli/exec' },
						{ label: 'jitsudo shell', slug: 'docs/cli/shell' },
						{ label: 'jitsudo revoke', slug: 'docs/cli/revoke' },
						{ label: 'jitsudo audit', slug: 'docs/cli/audit' },
						{ label: 'jitsudo policy', slug: 'docs/cli/policy' },
						{ label: 'jitsudo server', slug: 'docs/cli/server' },
					],
				},
				{
					label: 'Server Reference',
					items: [
						{ label: 'jitsudod', slug: 'docs/server/jitsudod' },
						{ label: 'jitsudod init', slug: 'docs/server/jitsudod-init' },
					],
				},
				{
					label: 'Architecture',
					items: [
						{ label: 'System Overview', slug: 'docs/architecture/overview' },
						{ label: 'Request Lifecycle', slug: 'docs/architecture/request-lifecycle' },
						{ label: 'Approval Model', slug: 'docs/architecture/approval-model' },
						{ label: 'Provider Interface', slug: 'docs/architecture/provider-interface' },
					],
				},
				{
					label: 'Guides',
					items: [
						{
							label: 'Deployment',
							items: [
								{ label: 'Docker Compose', slug: 'guides/deployment/docker-compose' },
								{ label: 'Kubernetes (Helm)', slug: 'guides/deployment/kubernetes' },
								{ label: 'Single-Server', slug: 'guides/deployment/single-server' },
							],
						},
						{
							label: 'Providers',
							items: [
								{ label: 'AWS', slug: 'guides/providers/aws' },
								{ label: 'Azure', slug: 'guides/providers/azure' },
								{ label: 'GCP', slug: 'guides/providers/gcp' },
								{ label: 'Kubernetes', slug: 'guides/providers/kubernetes' },
							],
						},
						{ label: 'OIDC Integration', slug: 'guides/oidc' },
						{ label: 'Writing Policies', slug: 'guides/writing-policies' },
						{ label: 'Security Hardening', slug: 'guides/security-hardening' },
						{ label: 'HA & Disaster Recovery', slug: 'guides/ha-dr' },
						{
							label: 'Quickstarts',
							items: [
								{ label: 'AWS', slug: 'guides/quickstart-aws' },
								{ label: 'GCP', slug: 'guides/quickstart-gcp' },
								{ label: 'Azure', slug: 'guides/quickstart-azure' },
								{ label: 'Kubernetes', slug: 'guides/quickstart-kubernetes' },
							],
						},
						{ label: 'Migration Guide', slug: 'guides/migration' },
						{ label: 'Comparison', slug: 'guides/comparison' },
						{ label: 'Runbooks', slug: 'guides/runbooks' },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'FAQ', slug: 'reference/faq' },
						{ label: 'Server Configuration', slug: 'reference/configuration' },
						{ label: 'REST API', slug: 'reference/api' },
						{ label: 'OPA Policy Schema', slug: 'reference/policy-schema' },
						{ label: 'Audit Log', slug: 'reference/audit-log' },
						{ label: 'Licensing FAQ', slug: 'reference/licensing' },
						{ label: 'Glossary', slug: 'reference/glossary' },
					],
				},
			],
			customCss: ['./src/styles/custom.css'],
		}),
	],
});
