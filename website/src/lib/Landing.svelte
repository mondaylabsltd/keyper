<script lang="ts">
	import type { Content } from './content';
	import Logo from './Logo.svelte';
	import { resolve } from '$app/paths';
	import { site, repoFile } from './site';

	let { c }: { c: Content } = $props();

	const spec = repoFile('SPEC.md');
	const security = repoFile('SECURITY.md');

	// 24-pixel line icons for the six protections, in the order of c.features.items, as path data.
	const icons = [
		'M4.5 6h15a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2zM6.5 10h.01M10 10h.01M14 10h.01M17.5 10h.01M7.5 14h9',
		'M2 8.8a15 15 0 0 1 4.2-2.6M9.5 5.2A15 15 0 0 1 22 8.8M5 12.5a10 10 0 0 1 3.5-2M12.5 9.6a10 10 0 0 1 6.5 2.9M8.5 16a5 5 0 0 1 7 0M12 19.5h.01M3 3l18 18',
		'M5 5.5a7 2.5 0 1 0 14 0a7 2.5 0 1 0-14 0M5 5.5v13c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5v-13M5 12c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5M3 3l18 18',
		'M3 3l18 18M10.6 6.1A10 10 0 0 1 12 6c5 0 9 4.5 10 6a17 17 0 0 1-3 3.6M6.6 6.6C4.4 8 2.8 10.3 2 12c1 1.5 5 6 10 6a9.5 9.5 0 0 0 4.4-1.1M9.9 9.9a3 3 0 0 0 4.2 4.2',
		'M17 2l3 3-3 3M4 11V9a4 4 0 0 1 4-4h12M7 22l-3-3 3-3M20 13v2a4 4 0 0 1-4 4H4',
		'M9 4.5H7a2 2 0 0 0-2 2V19a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V6.5a2 2 0 0 0-2-2h-2M9 3h6v3H9zM12 11v3l2 2'
	];
</script>

<a class="skip" href="#main">{c.lang === 'zh' ? '跳到正文' : 'Skip to content'}</a>

<header class="bar">
	<nav class="wrap nav" aria-label="Keyper">
		<a class="brand" href={resolve(c.path)} aria-label="Keyper">
			<Logo size={32} />
			<span>Keyper</span>
		</a>
		<div class="links">
			<a href="#how">{c.nav.how}</a>
			<a href="#security">{c.nav.security}</a>
			<a href="#pricing">{c.nav.pricing}</a>
			<a href="#faq">{c.nav.faq}</a>
			{#if site.repository}<a href={site.repository} rel="external">{c.nav.source}</a>{/if}
			<a
				class="pill"
				href={resolve(c.other.path)}
				hreflang={c.other.hreflang}
				lang={c.other.hreflang}>{c.other.label}</a
			>
		</div>
	</nav>
</header>

<main id="main">
	<section class="hero wrap">
		<div class="hero-text">
			<p class="eyebrow">{c.hero.eyebrow}</p>
			<h1>{c.hero.title}</h1>
			<p class="lead">{c.hero.lead}</p>
			<div class="actions">
				<a class="button primary" href="#how">{c.hero.primary}</a>
				<a class="button tonal" href="#security">{c.hero.secondary}</a>
			</div>
			<p class="note">{c.hero.note}</p>
		</div>
		<div class="hero-phones">
			{#each c.shots as shot, i (shot.src)}
				<img
					class="phone phone-{i}"
					src={shot.src}
					alt={shot.alt}
					width="540"
					height="1205"
					loading={i ? 'lazy' : 'eager'}
				/>
			{/each}
		</div>
	</section>

	<ul class="facts wrap" aria-label="Keyper">
		{#each c.facts as fact (fact)}<li>{fact}</li>{/each}
	</ul>

	<section id="how" class="section wrap">
		<h2>{c.how.title}</h2>
		<p class="section-lead">{c.how.lead}</p>
		<div
			class="flow"
			role="img"
			aria-label="{c.how.flow.email} + {c.how.flow.sentence} → {c.how.flow.slow} → {c.how.flow
				.words}"
		>
			<div class="flow-inputs">
				<div class="chip">
					<span class="mono">alice@example.com</span><small>{c.how.flow.email}</small>
				</div>
				<div class="chip">
					<span class="mono">In 2009 Grandma Li…</span><small>{c.how.flow.sentence}</small
					>
				</div>
			</div>
			<div class="arrow" aria-hidden="true"></div>
			<div class="chip slow"><strong>{c.how.flow.slow}</strong><small>≈ 1 min</small></div>
			<div class="arrow" aria-hidden="true"></div>
			<div class="chip">
				<span class="mono">patch essay tiny fix …</span><small>{c.how.flow.words}</small>
			</div>
		</div>
		<ol class="steps">
			{#each c.how.steps as step, i (step.title)}
				<li>
					<span class="step-number">{i + 1}</span>
					<h3>{step.title}</h3>
					<p>{step.text}</p>
				</li>
			{/each}
		</ol>
	</section>

	<section id="security" class="section wrap">
		<h2>{c.cost.title}</h2>
		<p class="section-lead">{c.cost.lead}</p>
		<div class="card table-card">
			<table>
				<thead>
					<tr
						>{#each c.cost.head as cell (cell)}<th scope="col">{cell}</th>{/each}</tr
					>
				</thead>
				<tbody>
					{#each c.cost.rows as row, i (row[0])}
						<tr class:safe={i >= 2}>
							<th scope="row">{row[0]}</th>
							<td>{row[1]}</td>
							<td>{row[2]}</td>
						</tr>
					{/each}
				</tbody>
			</table>
			<p class="table-note">{c.cost.note}</p>
		</div>
		<p class="warning">{c.cost.warning}</p>
	</section>

	<section class="section wrap">
		<h2>{c.features.title}</h2>
		<p class="section-lead">{c.features.lead}</p>
		<ul class="features">
			{#each c.features.items as item, i (item.title)}
				<li class="card">
					<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"
						><path d={icons[i]} /></svg
					>
					<h3>{item.title}</h3>
					<p>{item.text}</p>
				</li>
			{/each}
		</ul>
	</section>

	<section class="section wrap">
		<h2>{c.model.title}</h2>
		<div class="card table-card">
			<table class="model">
				<thead>
					<tr
						><th scope="col">{c.model.head[0]}</th><th scope="col">{c.model.head[1]}</th
						></tr
					>
				</thead>
				<tbody>
					{#each c.model.rows as row (row[0])}
						<tr><th scope="row">{row[0]}</th><td>{row[1]}</td></tr>
					{/each}
				</tbody>
			</table>
		</div>
		<ul class="points">
			{#each c.model.points as point (point)}<li>{point}</li>{/each}
		</ul>
	</section>

	<section class="section wrap platforms">
		<div>
			<h2>{c.platforms.title}</h2>
			<p class="section-lead">{c.platforms.lead}</p>
			<p class="caption">{c.platforms.caption}</p>
		</div>
		<div class="pair">
			<figure>
				<img
					class="phone"
					src={c.lang === 'zh' ? '/screens/zh-result.png' : '/screens/en-result.png'}
					alt="Android"
					width="540"
					height="1205"
					loading="lazy"
				/>
				<figcaption>{c.platforms.android}</figcaption>
			</figure>
			<figure>
				<img
					class="phone"
					src="/screens/ios-result.png"
					alt="iPhone"
					width="540"
					height="1174"
					loading="lazy"
				/>
				<figcaption>{c.platforms.ios}</figcaption>
			</figure>
		</div>
	</section>

	<section class="section wrap">
		<h2>{c.open.title}</h2>
		<p class="section-lead">{c.open.lead}</p>
		<ul class="open">
			{#each c.open.items as item (item.title)}
				<li>
					<h3>{item.title}</h3>
					<p>{item.text}</p>
					{#if item.link && repoFile(item.link.path)}
						<a class="more" href={repoFile(item.link.path)} rel="external"
							>{item.link.label} →</a
						>
					{/if}
				</li>
			{/each}
		</ul>
		{#if site.repository}
			<div class="actions">
				{#if spec}<a class="button tonal" href={spec} rel="external">{c.open.spec}</a>{/if}
				{#if security}<a class="button tonal" href={security} rel="external"
						>{c.open.security}</a
					>{/if}
				<a class="button tonal" href={site.repository} rel="external">{c.open.source}</a>
			</div>
		{/if}
	</section>

	<section id="pricing" class="section wrap">
		<h2>{c.pricing.title}</h2>
		<p class="section-lead">{c.pricing.lead}</p>
		<div class="plans">
			<div class="card plan">
				<h3>{c.pricing.build.name}</h3>
				<p class="price">{c.pricing.build.price} <small>{c.pricing.build.per}</small></p>
				<ul>
					{#each c.pricing.build.points as point (point)}<li>{point}</li>{/each}
				</ul>
				{#if repoFile(c.pricing.build.guide)}
					<a class="button tonal" href={repoFile(c.pricing.build.guide)} rel="external"
						>{c.pricing.build.action}</a
					>
				{/if}
			</div>
			<div class="card plan featured">
				<h3>{c.pricing.store.name}</h3>
				<p class="price">{c.pricing.store.price} <small>{c.pricing.store.per}</small></p>
				<ul>
					{#each c.pricing.store.points as point (point)}<li>{point}</li>{/each}
				</ul>
				<span class="store" aria-disabled="true">{c.cta.soon}</span>
			</div>
		</div>
		<p class="caption">{c.pricing.note}</p>
	</section>

	<section id="faq" class="section wrap faq">
		<h2>{c.faq.title}</h2>
		<div class="questions">
			{#each c.faq.items as item (item.q)}
				<details>
					<summary>{item.q}</summary>
					<p>{item.a}</p>
				</details>
			{/each}
		</div>
	</section>

	<section class="cta wrap">
		<Logo size={64} />
		<h2>{c.cta.title}</h2>
		<p>{c.cta.text}</p>
		<div class="stores">
			<span class="store" aria-disabled="true">Google Play · {c.cta.soon}</span>
			<span class="store" aria-disabled="true">App Store · {c.cta.soon}</span>
		</div>
	</section>
</main>

<footer class="footer">
	<div class="wrap footer-inner">
		<div class="brand"><Logo size={24} /><span>Keyper</span></div>
		<p>{c.footer.license}</p>
		<p>
			<strong>{c.footer.check}</strong> <span class="mono">{site.domainId}</span> · {c.footer
				.checkHint}
		</p>
		<p>
			<a href="mailto:{site.securityEmail}?subject=Keyper%20security" rel="external"
				>{c.footer.security}</a
			>
			· <a href={resolve(c.other.path)} hreflang={c.other.hreflang}>{c.other.label}</a>
		</p>
		<p class="quiet">© 2026 Keyper</p>
	</div>
</footer>

<style>
	.wrap {
		width: min(var(--width), 100% - 2 * var(--gutter));
		margin-inline: auto;
	}

	.skip {
		position: absolute;
		left: -999px;
		top: 8px;
		background: var(--surface);
		padding: 8px 12px;
		border-radius: 8px;
		z-index: 10;
	}

	.skip:focus {
		left: 8px;
	}

	/* Header */
	.bar {
		position: sticky;
		top: 0;
		z-index: 5;
		background: color-mix(in srgb, var(--background) 82%, transparent);
		backdrop-filter: saturate(1.4) blur(12px);
		-webkit-backdrop-filter: saturate(1.4) blur(12px);
		border-bottom: 1px solid color-mix(in srgb, var(--outline) 70%, transparent);
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

	.links {
		display: flex;
		align-items: center;
		gap: 22px;
		font-size: 15px;
	}

	.links a {
		color: var(--text-secondary);
		text-decoration: none;
	}

	.links a:hover {
		color: var(--text);
	}

	.links a.pill {
		color: var(--text);
		border: 1px solid var(--outline);
		background: var(--surface);
		border-radius: 999px;
		padding: 5px 14px;
	}

	@media (max-width: 700px) {
		.links a:not(.pill) {
			display: none;
		}
	}

	/* Hero */
	.hero {
		display: grid;
		grid-template-columns: 1.05fr 1fr;
		gap: 48px;
		align-items: center;
		padding-block: 72px 40px;
	}

	.eyebrow {
		color: var(--accent);
		font-weight: 600;
		font-size: 14px;
		letter-spacing: 0.02em;
		margin-bottom: 16px;
	}

	h1 {
		text-wrap: balance;
		font-size: clamp(38px, 5.6vw, 64px);
		font-weight: 700;
		letter-spacing: -0.025em;
	}

	.lead {
		font-size: clamp(17px, 1.6vw, 20px);
		color: var(--text-secondary);
		margin-top: 20px;
		max-width: 36em;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: 12px;
		margin-top: 32px;
	}

	.button {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-height: 50px;
		padding: 0 24px;
		border-radius: 14px;
		font-weight: 600;
		font-size: 16px;
		text-decoration: none;
		transition:
			transform 0.15s ease,
			filter 0.15s ease;
	}

	.button:hover {
		transform: translateY(-1px);
		filter: brightness(1.03);
	}

	.primary {
		background: linear-gradient(135deg, var(--gold-start), var(--gold-end));
		color: var(--on-gold);
		box-shadow: 0 8px 24px rgb(246 164 0 / 30%);
	}

	.tonal {
		background: var(--accent-soft);
		color: var(--accent);
	}

	.note {
		margin-top: 16px;
		font-size: 14px;
		color: var(--text-tertiary);
	}

	.hero-phones {
		position: relative;
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
		align-items: start;
	}

	.hero-phones::before {
		content: '';
		position: absolute;
		inset: 10% -10% 0;
		background: radial-gradient(
			closest-side,
			color-mix(in srgb, var(--gold-start) 35%, transparent),
			transparent
		);
		z-index: -1;
	}

	.phone {
		width: 100%;
		height: auto;
		border-radius: 28px;
		border: 1px solid var(--outline);
		box-shadow: var(--shadow);
		background: var(--surface);
	}

	.phone-1 {
		margin-top: 56px;
	}

	@media (max-width: 860px) {
		.hero {
			grid-template-columns: 1fr;
			padding-block: 40px 24px;
			gap: 36px;
		}

		.hero-phones {
			max-width: 460px;
			margin-inline: auto;
		}

		/* The glow stays within the page, or it widens the page on a phone. */
		.hero-phones::before {
			inset: 10% 0 0;
		}
	}

	/* Facts */
	.facts {
		list-style: none;
		padding: 0;
		margin-block: 24px 0;
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: 10px;
	}

	.facts li {
		background: var(--surface);
		border: 1px solid var(--outline);
		border-radius: 999px;
		padding: 6px 16px;
		font-size: 14px;
		font-weight: 500;
		color: var(--text-secondary);
	}

	/* Sections */
	.section {
		padding-block: 88px 0;
	}

	h2 {
		text-wrap: balance;
		font-size: clamp(28px, 3.6vw, 40px);
		font-weight: 700;
		letter-spacing: -0.02em;
	}

	.section-lead {
		margin-top: 14px;
		color: var(--text-secondary);
		max-width: 44em;
		font-size: 18px;
	}

	h3 {
		font-size: 18px;
		font-weight: 600;
	}

	.card {
		background: var(--surface);
		border: 1px solid var(--outline);
		border-radius: var(--radius);
	}

	.mono {
		font-family: var(--mono);
	}

	/* Flow */
	.flow {
		display: grid;
		grid-template-columns: 1.2fr auto 1fr auto 1.2fr;
		align-items: center;
		gap: 16px;
		margin-top: 40px;
	}

	.flow-inputs {
		display: grid;
		gap: 12px;
	}

	.chip {
		display: grid;
		gap: 4px;
		background: var(--surface);
		border: 1px solid var(--outline);
		border-radius: 14px;
		padding: 14px 16px;
		min-width: 0;
	}

	.chip span {
		font-size: 15px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.chip small {
		color: var(--text-tertiary);
		font-size: 13px;
	}

	.chip.slow {
		background: linear-gradient(135deg, var(--gold-start), var(--gold-end));
		border: none;
		color: var(--on-gold);
		text-align: center;
	}

	.chip.slow small {
		color: color-mix(in srgb, var(--on-gold) 70%, transparent);
	}

	.arrow {
		width: 28px;
		height: 2px;
		background: var(--outline);
		position: relative;
	}

	.arrow::after {
		content: '';
		position: absolute;
		right: -1px;
		top: -4px;
		border: 5px solid transparent;
		border-left: 7px solid var(--outline);
		border-right: 0;
	}

	@media (max-width: 860px) {
		.flow {
			grid-template-columns: 1fr;
			justify-items: stretch;
		}

		.arrow {
			width: 2px;
			height: 24px;
			justify-self: center;
		}

		.arrow::after {
			right: -4px;
			top: auto;
			bottom: -1px;
			border: 5px solid transparent;
			border-top: 7px solid var(--outline);
			border-bottom: 0;
		}
	}

	.steps {
		list-style: none;
		padding: 0;
		margin: 40px 0 0;
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		gap: 20px;
	}

	.steps li {
		display: grid;
		align-content: start;
		gap: 10px;
	}

	.steps p {
		color: var(--text-secondary);
		font-size: 16px;
	}

	.step-number {
		display: inline-grid;
		place-items: center;
		width: 32px;
		height: 32px;
		border-radius: 50%;
		background: var(--accent-soft);
		color: var(--accent);
		font-weight: 700;
		font-size: 15px;
	}

	@media (max-width: 960px) {
		.steps {
			grid-template-columns: repeat(2, 1fr);
		}
	}

	@media (max-width: 560px) {
		.steps {
			grid-template-columns: 1fr;
		}
	}

	/* Tables */
	.table-card {
		margin-top: 32px;
		overflow-x: auto;
	}

	table {
		width: 100%;
		border-collapse: collapse;
		font-size: 16px;
	}

	th,
	td {
		text-align: left;
		padding: 16px 20px;
		border-bottom: 1px solid var(--outline);
	}

	thead th {
		font-size: 13px;
		font-weight: 600;
		color: var(--text-tertiary);
		text-transform: none;
		background: var(--surface-variant);
	}

	tbody th {
		font-weight: 600;
		white-space: nowrap;
	}

	table:not(.model) td {
		font-variant-numeric: tabular-nums;
		white-space: nowrap;
	}

	tbody tr:last-child th,
	tbody tr:last-child td {
		border-bottom: none;
	}

	tr.safe td:last-child {
		color: var(--strong);
		font-weight: 600;
	}

	.table-note {
		padding: 14px 20px;
		border-top: 1px solid var(--outline);
		color: var(--text-secondary);
		font-size: 15px;
	}

	.warning {
		margin-top: 20px;
		background: var(--danger-soft);
		color: var(--text);
		border-radius: 14px;
		padding: 18px 20px;
		font-size: 16px;
		border-left: 4px solid var(--danger);
	}

	.model th {
		white-space: normal;
	}

	@media (max-width: 560px) {
		th,
		td {
			padding: 12px 10px;
			font-size: 14px;
		}

		thead th {
			white-space: normal;
		}
	}

	/* Features */
	.features {
		list-style: none;
		padding: 0;
		margin: 36px 0 0;
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 20px;
	}

	.features li {
		padding: 24px;
		display: grid;
		align-content: start;
		gap: 10px;
	}

	.features p {
		color: var(--text-secondary);
		font-size: 16px;
	}

	.icon {
		width: 28px;
		height: 28px;
		fill: none;
		stroke: var(--accent);
		stroke-width: 1.7;
		stroke-linecap: round;
		stroke-linejoin: round;
	}

	@media (max-width: 960px) {
		.features {
			grid-template-columns: repeat(2, 1fr);
		}
	}

	@media (max-width: 600px) {
		.features {
			grid-template-columns: 1fr;
		}
	}

	.points {
		margin: 24px 0 0;
		padding-left: 1.2em;
		color: var(--text-secondary);
		display: grid;
		gap: 8px;
	}

	/* Platforms */
	.platforms {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 48px;
		align-items: center;
	}

	.caption {
		margin-top: 16px;
		color: var(--text-tertiary);
		font-size: 15px;
	}

	.pair {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
	}

	figure {
		margin: 0;
		display: grid;
		gap: 12px;
		justify-items: center;
	}

	figcaption {
		font-size: 14px;
		color: var(--text-secondary);
		font-weight: 500;
	}

	@media (max-width: 860px) {
		.platforms {
			grid-template-columns: 1fr;
		}

		.pair {
			max-width: 460px;
		}
	}

	/* Open */
	.open {
		list-style: none;
		padding: 0;
		margin: 36px 0 0;
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 28px 40px;
	}

	.open li {
		display: grid;
		gap: 8px;
		padding-left: 18px;
		border-left: 3px solid var(--gold-end);
	}

	.open p {
		color: var(--text-secondary);
		font-size: 16px;
	}

	.more {
		font-size: 15px;
		font-weight: 600;
		text-decoration: none;
	}

	.more:hover {
		text-decoration: underline;
	}

	@media (max-width: 700px) {
		.open {
			grid-template-columns: 1fr;
		}
	}

	/* Pricing */
	.plans {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 20px;
		margin-top: 36px;
	}

	.plan {
		padding: 28px;
		display: grid;
		align-content: start;
		gap: 16px;
	}

	.plan.featured {
		border: 2px solid var(--gold-end);
		background: linear-gradient(160deg, var(--accent-soft), var(--surface) 60%);
	}

	.price {
		font-size: 36px;
		font-weight: 700;
		letter-spacing: -0.02em;
	}

	.price small {
		font-size: 16px;
		font-weight: 500;
		color: var(--text-tertiary);
	}

	.plan ul {
		margin: 0;
		padding-left: 1.2em;
		display: grid;
		gap: 8px;
		color: var(--text-secondary);
		font-size: 16px;
	}

	.plan .button,
	.plan .store {
		justify-self: start;
	}

	@media (max-width: 760px) {
		.plans {
			grid-template-columns: 1fr;
		}
	}

	/* FAQ */
	.questions {
		margin-top: 28px;
		display: grid;
		gap: 12px;
		max-width: 820px;
	}

	details {
		background: var(--surface);
		border: 1px solid var(--outline);
		border-radius: 14px;
		padding: 0 20px;
	}

	summary {
		cursor: pointer;
		list-style: none;
		padding: 18px 28px 18px 0;
		font-weight: 600;
		position: relative;
	}

	summary::-webkit-details-marker {
		display: none;
	}

	summary::after {
		content: '+';
		position: absolute;
		right: 0;
		top: 50%;
		transform: translateY(-50%);
		color: var(--accent);
		font-size: 22px;
		font-weight: 400;
	}

	details[open] summary::after {
		content: '−';
	}

	details p {
		padding-bottom: 18px;
		color: var(--text-secondary);
	}

	/* CTA */
	.cta {
		margin-block: 104px 72px;
		padding: 56px 24px;
		text-align: center;
		display: grid;
		justify-items: center;
		gap: 16px;
		background: linear-gradient(160deg, var(--accent-soft), var(--surface));
		border: 1px solid var(--outline);
		border-radius: 28px;
	}

	.cta p {
		color: var(--text-secondary);
	}

	.stores {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: 12px;
		margin-top: 8px;
	}

	.store {
		border: 1px dashed var(--outline);
		background: var(--surface);
		border-radius: 12px;
		padding: 10px 18px;
		font-size: 15px;
		color: var(--text-secondary);
	}

	/* Footer */
	.footer {
		border-top: 1px solid var(--outline);
		padding-block: 36px 48px;
		font-size: 14px;
		color: var(--text-secondary);
	}

	.footer-inner {
		display: grid;
		gap: 8px;
	}

	.footer .brand {
		font-size: 16px;
		margin-bottom: 4px;
	}

	.quiet {
		color: var(--text-tertiary);
	}
</style>
