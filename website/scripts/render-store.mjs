// Renders the framed store screenshots and the feature graphic into ../store from the raw
// screenshots there. Run from website/: node scripts/render-store.mjs
import { chromium } from '@playwright/test';
import { existsSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const store = fileURLToPath(new URL('../../store/', import.meta.url));
const captions = {
	en: [
		[
			'01-input',
			'Your email and a sentence only you know',
			'Typed on Keyper’s own keyboard. Nothing is saved.'
		],
		[
			'02-phrase',
			'The same BIP39 phrase, every time',
			'Nothing to write down. Use it in any wallet.'
		],
		['03-offline-gate', 'Works only offline', 'Going back online wipes everything.']
	],
	zh: [
		['01-input', '你的邮箱，加一句只有你知道的话', '用 Keyper 自带的键盘输入，什么都不保存。'],
		['02-phrase', '每次都得到同一组 BIP39 助记词', '不用抄写，任何钱包都能用。'],
		['03-offline-gate', '只在离线时工作', '一联网，所有内容立即清除。']
	]
};
// App Store 6.9-inch, and Google Play (aspect ratio at most 2:1).
const targets = [
	{ dir: 'app-store', width: 1320, height: 2868 },
	{ dir: 'google-play', width: 1080, height: 2160 }
];

const browser = await chromium.launch();
for (const { dir, width, height } of targets) {
	const page = await browser.newPage({ viewport: { width, height } });
	for (const [lang, list] of Object.entries(captions)) {
		for (const [name, title, sub] of list) {
			const raw = `${store}${dir}/screenshots/${lang}/${name}.png`;
			if (!existsSync(raw)) {
				console.log('missing', raw);
				continue;
			}
			const out = `${store}${dir}/framed/${lang}`;
			mkdirSync(out, { recursive: true });
			const query = new URLSearchParams({ img: `file://${raw}`, title, sub, lang });
			await page.goto(`file://${store}screenshot-frame.html?${query}`);
			await page.waitForLoadState('networkidle');
			await page.screenshot({ path: `${out}/${name}.png` });
		}
	}
	await page.close();
}
const graphic = await browser.newPage({ viewport: { width: 1024, height: 500 } });
for (const lang of ['en', 'zh']) {
	await graphic.goto(`file://${store}feature-graphic.html#${lang}`);
	await graphic.reload();
	await graphic.screenshot({ path: `${store}google-play/feature-graphic-${lang}.png` });
}
await browser.close();
