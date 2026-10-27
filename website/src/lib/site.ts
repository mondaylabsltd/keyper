/** Site-wide settings. */
export const site = {
	url: 'https://getkeyper.app',
	/**
	 * The public source repository, e.g. 'https://github.com/owner/keyper'. While it is null, the
	 * links that need it (source, protocol, security policy) are left out rather than broken.
	 */
	repository: 'https://github.com/atshelchin/getkeyper' as string | null,
	/** Where security reports go (SECURITY.md). */
	securityEmail: 'hi@shelchin.com',
	/** The domain ID the official builds show in their footer (SPEC.md, Domain.kt, Domain.swift). */
	domainId: 'A248-7EAB',
	/** One price worldwide, paid once, on Google Play and the App Store; each store converts it. */
	price: 'US$29.99'
};

/** A file in the repository, or null while the repository is not public. */
export function repoFile(path: string): string | null {
	return site.repository ? `${site.repository}/blob/main/${path}` : null;
}
