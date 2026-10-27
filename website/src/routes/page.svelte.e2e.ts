import { expect, test } from '@playwright/test';

/** The visit counter, the only other host a page may load; blocked so tests are not counted. */
const analytics = 'https://tj.appsdata.org/';

test.beforeEach(async ({ page }) => {
	await page.route(`${analytics}**`, (route) => route.abort());
});

for (const [path, lang, heading] of [
	['/', 'en', 'A recovery phrase you keep in your head.'],
	['/zh', 'zh-Hans', '记在脑子里的助记词。']
] as const) {
	test(`${path} renders in ${lang} and loads nothing else from elsewhere`, async ({
		page,
		baseURL
	}) => {
		const elsewhere: string[] = [];
		page.on('request', (request) => {
			const url = request.url();
			if (!url.startsWith(baseURL!) && !url.startsWith(analytics)) elsewhere.push(url);
		});
		await page.goto(path, { waitUntil: 'networkidle' });
		await expect(page.locator('html')).toHaveAttribute('lang', lang);
		await expect(page.locator('h1')).toHaveText(heading);
		await expect(page.locator('#how')).toBeVisible();
		await expect(page.locator('#faq details')).toHaveCount(5);
		await expect(page.locator(`script[src^="${analytics}"]`)).toHaveCount(1);
		expect(elsewhere).toEqual([]);
	});
}

for (const [path, lang, heading] of [
	['/privacy', 'en', 'Privacy Policy'],
	['/terms', 'en', 'Terms of Service'],
	['/zh/privacy', 'zh-Hans', '隐私政策'],
	['/zh/terms', 'zh-Hans', '服务条款']
] as const) {
	test(`${path} renders in ${lang}`, async ({ page }) => {
		await page.goto(path);
		await expect(page.locator('html')).toHaveAttribute('lang', lang);
		await expect(page.locator('h1')).toHaveText(heading);
	});
}
