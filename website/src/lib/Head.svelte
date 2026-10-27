<script lang="ts">
	import type { Content } from './content';
	import { site } from './site';

	let { c }: { c: Content } = $props();
	const url = $derived(site.url + (c.path === '/' ? '/' : c.path));
</script>

<svelte:head>
	<title>{c.meta.title}</title>
	<meta name="description" content={c.meta.description} />
	<link rel="canonical" href={url} />
	<link rel="alternate" hreflang="en" href="{site.url}/" />
	<link rel="alternate" hreflang="zh-Hans" href="{site.url}/zh" />
	<link rel="alternate" hreflang="x-default" href="{site.url}/" />
	<meta property="og:type" content="website" />
	<meta property="og:site_name" content="Keyper" />
	<meta property="og:title" content={c.meta.title} />
	<meta property="og:description" content={c.meta.description} />
	<meta property="og:url" content={url} />
	<meta property="og:image" content="{site.url}/screens/{c.lang}-result.png" />
	<meta name="twitter:card" content="summary_large_image" />
	<meta name="theme-color" content="#fbf8f3" media="(prefers-color-scheme: light)" />
	<meta name="theme-color" content="#14110d" media="(prefers-color-scheme: dark)" />
</svelte:head>
