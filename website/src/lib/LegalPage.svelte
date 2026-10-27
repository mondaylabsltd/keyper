<script lang="ts">
	import type { Legal, LegalKind } from './legal';
	import Logo from './Logo.svelte';
	import { resolve } from '$app/paths';
	import { site } from './site';

	let { l, kind }: { l: Legal; kind: LegalKind } = $props();

	const doc = $derived(l[kind]);
	const enPath = $derived(l.lang === 'en' ? l.paths[kind] : l.other.paths[kind]);
	const zhPath = $derived(l.lang === 'zh' ? l.paths[kind] : l.other.paths[kind]);
</script>

<svelte:head>
	<title>{doc.title} · Keyper</title>
	<meta name="description" content={doc.description} />
	<link rel="canonical" href="{site.url}{l.paths[kind]}" />
	<link rel="alternate" hreflang="en" href="{site.url}{enPath}" />
	<link rel="alternate" hreflang="zh-Hans" href="{site.url}{zhPath}" />
	<link rel="alternate" hreflang="x-default" href="{site.url}{enPath}" />
	<meta name="theme-color" content="#fbf8f3" media="(prefers-color-scheme: light)" />
	<meta name="theme-color" content="#14110d" media="(prefers-color-scheme: dark)" />
</svelte:head>

<header class="bar">
	<nav class="wrap nav" aria-label="Keyper">
		<a class="brand" href={resolve(l.home)} aria-label="Keyper">
			<Logo size={32} />
			<span>Keyper</span>
		</a>
		<a
			class="pill"
			href={resolve(l.other.paths[kind])}
			hreflang={l.other.hreflang}
			lang={l.other.hreflang}>{l.other.label}</a
		>
	</nav>
</header>

<main class="wrap doc">
	<h1>{doc.title}</h1>
	<p class="updated">{l.updatedLabel}: {l.updated}</p>
	<p>{l.intro}</p>
	{#each doc.sections as section (section.heading)}
		<h2>{section.heading}</h2>
		{#each section.paragraphs as paragraph, i (i)}
			<p>{paragraph}</p>
		{/each}
	{/each}
	<p class="contact">
		{doc.contact}
		<a href="mailto:{site.email}" rel="external">{site.email}</a>
	</p>
</main>

<footer class="footer">
	<div class="wrap footer-inner">
		<a href={resolve(l.home)}>Keyper</a>
		·
		<a href={resolve(l.paths.privacy)} aria-current={kind === 'privacy' ? 'page' : undefined}
			>{l.privacy.title}</a
		>
		·
		<a href={resolve(l.paths.terms)} aria-current={kind === 'terms' ? 'page' : undefined}
			>{l.terms.title}</a
		>
	</div>
</footer>

<style>
	.wrap {
		width: min(var(--width), 100% - 2 * var(--gutter));
		margin-inline: auto;
	}

	.bar {
		border-bottom: 1px solid var(--outline);
	}

	.nav {
		display: flex;
		align-items: center;
		justify-content: space-between;
		height: 64px;
		gap: 16px;
	}

	.brand {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		color: var(--text);
		text-decoration: none;
		font-weight: 600;
		font-size: 19px;
	}

	.pill {
		color: var(--text);
		text-decoration: none;
		font-size: 15px;
		border: 1px solid var(--outline);
		background: var(--surface);
		border-radius: 999px;
		padding: 5px 14px;
	}

	.doc {
		max-width: 720px;
		padding-block: 56px 96px;
	}

	h1 {
		font-size: clamp(32px, 5vw, 44px);
	}

	.updated {
		margin-top: 8px;
		color: var(--text-tertiary);
		font-size: 15px;
	}

	h2 {
		font-size: 21px;
		margin-top: 40px;
	}

	p {
		margin-top: 14px;
		color: var(--text-secondary);
	}

	.doc > p:first-of-type + p {
		margin-top: 28px;
	}

	.contact {
		margin-top: 40px;
	}

	.footer {
		border-top: 1px solid var(--outline);
		padding-block: 28px 40px;
		font-size: 14px;
		color: var(--text-tertiary);
	}

	.footer a {
		color: var(--text-secondary);
	}

	.footer a[aria-current='page'] {
		color: var(--text);
		text-decoration: none;
	}
</style>
