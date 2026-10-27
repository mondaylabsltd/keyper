# getkeyper.app

The landing page of Keyper, in English (`/`) and Chinese (`/zh`). SvelteKit, prerendered to static
files and served by Cloudflare Workers.

The pages use system fonts and no third-party scripts, fonts or images; the end-to-end test fails if
a page requests anything from another host.

## Develop

```sh
bun install
bun run dev
```

The words live in [`src/lib/content.ts`](src/lib/content.ts), one object per language; a unit
test keeps the two in step. Site settings are in [`src/lib/site.ts`](src/lib/site.ts): set
`repository` once the source is public, and the links to the source, the protocol and the
security policy appear.

## Check, test, build

```sh
bun run check        # types
bun run lint         # Prettier and ESLint
bun run test         # unit tests, then end-to-end tests against a production build
bun run build        # .svelte-kit/cloudflare
```

## Deploy

```sh
bun run deploy       # build, then wrangler deploy
```

`wrangler.jsonc` names the Worker; point the getkeyper.app route at it in the Cloudflare
dashboard. The screenshots in `static/screens/` are copies of `../docs/images/`.
