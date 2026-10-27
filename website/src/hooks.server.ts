import type { Handle } from '@sveltejs/kit/hooks';

/** The page's language on the <html> element: Chinese under /zh, English elsewhere. */
export const handle: Handle = ({ event, resolve }) => {
	const lang =
		event.url.pathname === '/zh' || event.url.pathname.startsWith('/zh/') ? 'zh-Hans' : 'en';
	return resolve(event, { transformPageChunk: ({ html }) => html.replace('%lang%', lang) });
};
