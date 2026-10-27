<script lang="ts">
	/** The app icon: the white key of ic_key on the gold gradient, cropped as a launcher shows it. */
	let { size = 36 }: { size?: number } = $props();
	const id = $props.id();
</script>

<svg width={size} height={size} viewBox="18 18 72 72" aria-hidden="true">
	<defs>
		<linearGradient
			id="gold-{id}"
			x1="18"
			y1="18"
			x2="90"
			y2="90"
			gradientUnits="userSpaceOnUse"
		>
			<stop offset="0" stop-color="#ffd45c" />
			<stop offset="1" stop-color="#f39200" />
		</linearGradient>
	</defs>
	<rect x="18" y="18" width="72" height="72" rx="17" fill="url(#gold-{id})" />
	<g fill="#a35a00" fill-opacity="0.2" transform="translate(0 2.5)">
		<path
			fill-rule="evenodd"
			d="M23,54a15,15 0 1 0 30 0a15,15 0 1 0 -30 0zM32,54a6,6 0 1 0 12 0a6,6 0 1 0 -12 0z"
		/>
		<path
			d="M50,50h30a4,4 0 0 1 0 8h-30zM66,57h6v7a2,2 0 0 1 -2 2h-2a2,2 0 0 1 -2 -2zM75,57h5v5a2,2 0 0 1 -2 2h-1a2,2 0 0 1 -2 -2z"
		/>
	</g>
	<g fill="#fff">
		<path
			fill-rule="evenodd"
			d="M23,54a15,15 0 1 0 30 0a15,15 0 1 0 -30 0zM32,54a6,6 0 1 0 12 0a6,6 0 1 0 -12 0z"
		/>
		<path
			d="M50,50h30a4,4 0 0 1 0 8h-30zM66,57h6v7a2,2 0 0 1 -2 2h-2a2,2 0 0 1 -2 -2zM75,57h5v5a2,2 0 0 1 -2 2h-1a2,2 0 0 1 -2 -2z"
		/>
	</g>
</svg>
