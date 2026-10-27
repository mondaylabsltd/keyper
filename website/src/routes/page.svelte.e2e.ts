import { expect, test } from '@playwright/test';

for (const [path, lang, heading] of [
	['/', 'en', 'A recovery phrase you keep in your head.'],
	['/zh', 'zh-Hans', '记在脑子里的助记词。']
] as const) {
	test(`${path} renders in ${lang} and loads nothing from elsewhere`, async ({
		page,
		baseURL
	}) => {
		const elsewhere: string[] = [];
		page.on('request', (request) => {
			if (!request.url().startsWith(baseURL!)) elsewhere.push(request.url());
		});
		await page.goto(path, { waitUntil: 'networkidle' });
		await expect(page.locator('html')).toHaveAttribute('lang', lang);
		await expect(page.locator('h1')).toHaveText(heading);
		await expect(page.locator('#how')).toBeVisible();
		await expect(page.locator('#faq details')).toHaveCount(8);
		expect(elsewhere).toEqual([]);
	});
}
