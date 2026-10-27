/** Site-wide settings. */
export const site = {
	url: 'https://getkeyper.app',
	/**
	 * The public source repository, e.g. 'https://github.com/owner/keyper'. While it is null, the
	 * links that need it (source, protocol, security policy) are left out rather than broken.
	 */
	repository: 'https://github.com/mondaylabsltd/keyper' as string | null,
	/** The company address: security reports (SECURITY.md) and questions about the policies. */
	email: 'hello@mondaylabs.ltd',
	/** One price worldwide, paid once, on Google Play and the App Store; each store converts it. */
	price: 'US$29.99',
	/** Store listings; while a link is null, the pricing card says the app is coming soon. */
	googlePlay: null as string | null,
	appStore: null as string | null
};

/** A file in the repository, or null while the repository is not public. */
export function repoFile(path: string): string | null {
	return site.repository ? `${site.repository}/blob/main/${path}` : null;
}
