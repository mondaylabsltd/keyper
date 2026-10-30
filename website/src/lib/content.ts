/** Everything the landing page says, in English and Chinese. Facts come from SPEC.md and the READMEs. */

import { site } from './site';

/** The site's two pages. */
export type Route = '/' | '/zh';

export interface Content {
	lang: 'en' | 'zh';
	htmlLang: string;
	path: Route;
	other: { path: Route; label: string; hreflang: string };
	meta: { title: string; description: string };
	nav: { how: string; security: string; pricing: string; faq: string; source: string };
	hero: {
		eyebrow: string;
		title: string;
		lead: string;
		primary: string;
		secondary: string;
		note: string;
	};
	shots: { src: string; alt: string }[];
	facts: string[];
	how: {
		title: string;
		steps: { title: string; text: string }[];
		flow: { email: string; sentence: string; slow: string; words: string };
	};
	security: {
		title: string;
		lead: string;
		head: [string, string, string];
		rows: [string, string, string][];
		note: string;
		/** `path` is a file in the repository, with an optional #anchor. */
		model: { label: string; path: string };
		warning: string;
		/** One per icon in Landing.svelte, in order. */
		items: { title: string; text: string }[];
	};
	open: {
		title: string;
		/** `link.path` is a file in the repository, with an optional #anchor. */
		items: { title: string; text: string; link?: { label: string; path: string } }[];
		requirements: string;
		spec: string;
		security: string;
		source: string;
	};
	pricing: {
		title: string;
		lead: string;
		/** `guide` is a file in the repository, with an optional #anchor. */
		build: {
			name: string;
			price: string;
			per: string;
			points: string[];
			action: string;
			guide: string;
		};
		store: {
			name: string;
			price: string;
			per: string;
			status: string;
			googlePlay: string;
			appStore: string;
		};
		note: string;
	};
	faq: { title: string; items: { q: string; a: string }[] };
	footer: { license: string; security: string; privacy: string; terms: string };
}

export const en: Content = {
	lang: 'en',
	htmlLang: 'en',
	path: '/',
	other: { path: '/zh', label: '中文', hreflang: 'zh-Hans' },
	meta: {
		title: 'Keyper: a recovery phrase you keep in your head',
		description:
			'On an offline phone, Keyper turns your email and a sentence only you know into a standard BIP39 recovery phrase. The same inputs always give the same phrase. Open source, for Android and iPhone.'
	},
	nav: {
		how: 'How it works',
		security: 'Security',
		pricing: 'Pricing',
		faq: 'FAQ',
		source: 'Source'
	},
	hero: {
		eyebrow: 'For Android and iPhone',
		title: 'A recovery phrase you keep in your head.',
		lead: 'Keyper derives a standard BIP39 recovery phrase from your email and a sentence only you know, on an offline phone. The derivation is deterministic, so there is nothing to write down or store.',
		primary: 'Get Keyper',
		secondary: 'How it works',
		note: `${site.price}, paid once. Or build it yourself for free.`
	},
	shots: [
		{ src: '/screens/en-input.png', alt: 'Typing the sentence on Keyper’s own keyboard' },
		{ src: '/screens/en-result.png', alt: 'A 12-word recovery phrase' }
	],
	facts: ['Works only offline', 'Stores nothing you type', 'Open source'],
	how: {
		title: 'How it works',
		steps: [
			{
				title: 'Go offline',
				text: 'Turn on airplane mode and turn off Wi-Fi and Bluetooth. Keyper accepts no input while the phone has a network connection.'
			},
			{
				title: 'Type two things',
				text: 'Your email, then your sentence, on Keyper’s own keyboard. In the sentence, capitals, symbols and the spaces between words all count.'
			},
			{
				title: 'Get your phrase',
				text: 'About a minute later: 12 or 24 words for any BIP39 wallet. Copy them, or scan the QR code.'
			}
		],
		flow: {
			email: 'Your email',
			sentence: 'Your sentence',
			slow: 'Argon2id · 1 GiB × 128',
			words: '12 or 24 BIP39 words'
		}
	},
	security: {
		title: 'Security',
		lead: 'Every guess costs one full Argon2id run. Assuming 1000 data-centre GPUs, each at 20 guesses a second and 40 J per guess, and electricity at US$0.05 per kWh, searching half the space takes:',
		head: ['Entropy', 'Time', 'Electricity'],
		rows: [
			['30 bits', '7.5 hours', 'US$300'],
			['40 bits', '320 days', 'US$305,000'],
			['50 bits', '890 years', 'US$313 million'],
			['60 bits', '910,000 years', 'US$320 billion']
		],
		note: 'Hardware not included. Keyper estimates the entropy as you type and warns below US$100 million.',
		model: { label: 'How these figures are derived', path: 'SPEC.md#4-security-model' },
		warning:
			'Length doesn’t make a sentence hard to guess: famous lines, lyrics and “my cat is called…” fall for a few dollars, and the estimate can’t recognise them. Use details only you know.',
		items: [
			{
				title: 'Its own keyboard',
				text: 'The fields never connect to the system keyboard, so no keyboard app can log or sync input.'
			},
			{
				title: 'Offline gate',
				text: 'Going online wipes the sentence, the phrase and the clipboard.'
			},
			{
				title: 'Nothing stored',
				text: 'Nothing is written to storage. Leaving the app wipes the sentence and the phrase.'
			},
			{
				title: 'No screenshots',
				text: 'Screenshots, recordings and the app switcher show nothing.'
			},
			{
				title: 'Recovery drill',
				text: 'Re-type both inputs from memory and check they give the same phrase.'
			},
			{
				title: 'Clipboard cleared',
				text: 'A copied phrase is cleared after 60 seconds. The QR code avoids the clipboard.'
			}
		]
	},
	open: {
		title: 'Open, and recoverable without the app',
		items: [
			{
				title: 'Android and iPhone',
				text: 'The same inputs give the same phrase on both.'
			},
			{
				title: 'A frozen protocol',
				text: 'Published, pinned by tests and never changing, so every version gives the same phrases.'
			},
			{
				title: 'Recover on a computer',
				text: 'An independent Python implementation, on argon2-cffi and Trezor’s mnemonic, gives the same phrase on an offline computer.',
				link: { label: 'How to recover', path: 'README.md#recovering-without-the-app' }
			}
		],
		requirements: 'Android 8.1 or iOS 17 and later, 4 GB of RAM. English and Chinese.',
		spec: 'Read the protocol',
		security: 'Security policy',
		source: 'Browse the source'
	},
	pricing: {
		title: 'Pricing',
		lead: 'The store version and a build from source are the same app. Buying saves you the build and pays for Keyper’s upkeep.',
		build: {
			name: 'Build it yourself',
			price: 'Free',
			per: 'forever',
			points: [
				'Needs Android Studio, or Xcode on a Mac',
				'On iPhone, a free Apple account means reinstalling every 7 days'
			],
			action: 'How to build',
			guide: 'README.md#building-and-maintaining'
		},
		store: {
			name: 'Google Play and the App Store',
			price: site.price,
			per: 'once',
			status: 'Coming soon',
			googlePlay: 'Google Play',
			appStore: 'App Store'
		},
		note: 'One price worldwide. Android and iPhone are bought separately.'
	},
	faq: {
		title: 'Questions',
		items: [
			{
				q: 'Isn’t this a brain wallet?',
				a: 'It is one, built against what broke the old ones. Those used a single unsalted SHA-256, so one guess could be checked against every address at once, millions of times a second. Keyper salts with your email, so each person is attacked separately, and runs Argon2id over 1 GiB, 128 times: about 20 guesses a second even on a data-centre GPU. It still can’t save a sentence someone can guess.'
			},
			{
				q: 'Is Keyper a wallet?',
				a: 'No. It only makes the recovery phrase; use it in any BIP39 wallet. Keyper never holds or moves funds.'
			},
			{
				q: 'Why does it need my email?',
				a: 'So the same sentence gives different phrases for different people, and an attacker has to guess one person at a time. Only its letters and digits count, so Alice@Example.com and alice@example.com are the same. A phone number works too.'
			},
			{
				q: 'What if someone learns my email?',
				a: 'The email isn’t a secret. They would still have to guess your sentence, at the cost above. Someone with both has your phrase, so use the sentence for Keyper only.'
			},
			{
				q: 'What if I forget the sentence?',
				a: 'The phrase is gone; nobody can recover it. Pick a sentence you will remember for years and keep its spelling the same.'
			},
			{
				q: 'How do I know my copy is genuine?',
				a: 'Install it only from Google Play or the App Store, or build it from source, and turn off automatic updates for it. A tampered copy could show a phrase its maker knows, so check your phrase once with the recovery script on an offline computer.'
			},
			{
				q: 'Why must the phone be offline?',
				a: 'So the sentence and the phrase only exist on a phone that can’t send them anywhere. Keyper itself never connects; on Android it doesn’t even hold the network permission. It can’t protect you from malware already on the phone, so use one you trust.'
			}
		]
	},
	footer: {
		license: 'Open source under the MIT License.',
		security: 'Report a vulnerability',
		privacy: 'Privacy Policy',
		terms: 'Terms of Service'
	}
};

export const zh: Content = {
	lang: 'zh',
	htmlLang: 'zh-Hans',
	path: '/zh',
	other: { path: '/', label: 'English', hreflang: 'en' },
	meta: {
		title: 'Keyper：记在脑子里的助记词',
		description:
			'在一台离线手机上，Keyper 用你的邮箱和一句只有你知道的话，生成标准 BIP39 助记词。同样的输入总是得到同样的助记词。开源，支持 Android 和 iPhone。'
	},
	nav: { how: '原理', security: '安全', pricing: '定价', faq: '常见问题', source: '源码' },
	hero: {
		eyebrow: 'Android 与 iPhone',
		title: '记在脑子里的助记词。',
		lead: 'Keyper 在离线手机上，用你的邮箱和一句只有你知道的话推导出标准 BIP39 助记词。推导是确定性的，所以不用抄写，也不用存储。',
		primary: '获取 Keyper',
		secondary: '看看原理',
		note: `${site.price}，一次买断。也可以自己免费编译。`
	},
	shots: [
		{ src: '/screens/zh-input.png', alt: '用 Keyper 自带键盘输入那句话' },
		{ src: '/screens/zh-result.png', alt: '12 个词的助记词' }
	],
	facts: ['只在离线时工作', '不保存你的输入', '开源'],
	how: {
		title: '原理',
		steps: [
			{
				title: '先断网',
				text: '打开飞行模式，关闭 Wi-Fi 和蓝牙。手机还有网络连接时，Keyper 不接受输入。'
			},
			{
				title: '输入两样东西',
				text: '用 Keyper 自带的键盘输入邮箱和那句话。那句话里，大小写、符号和词之间的空格都算数。'
			},
			{
				title: '拿到助记词',
				text: '约一分钟后得到 12 或 24 个词，任何 BIP39 钱包都能用。可以复制，也可以扫二维码。'
			}
		],
		flow: {
			email: '你的邮箱',
			sentence: '你的那句话',
			slow: 'Argon2id · 1 GiB × 128',
			words: '12 或 24 个 BIP39 词'
		}
	},
	security: {
		title: '安全',
		lead: '每猜一次都要完整跑一遍 Argon2id。假设攻击者有 1000 张数据中心级显卡，每张每秒猜 20 次、每次耗电 40 焦耳，电价每度 0.05 美元，平均搜完一半空间需要：',
		head: ['熵', '时间', '电费'],
		rows: [
			['30 位', '7.5 小时', '300 美元'],
			['40 位', '320 天', '30 万美元'],
			['50 位', '890 年', '3.1 亿美元'],
			['60 位', '91 万年', '3200 亿美元']
		],
		note: '不含硬件成本。你输入时 Keyper 会估算熵，低于 1 亿美元会提醒。',
		model: { label: '这些数字怎么算的', path: 'SPEC.md#4-security-model' },
		warning:
			'字多不等于难猜：名句、歌词、“我的猫叫某某”，几块钱电费就能猜中，而且估算认不出它们。要用只有你知道的细节。',
		items: [
			{ title: '自带键盘', text: '输入框从不连接系统输入法，任何输入法都无法记录或同步。' },
			{ title: '断网门禁', text: '一联网，那句话、助记词和剪贴板立即清除。' },
			{ title: '什么都不保存', text: '不写入任何存储。离开 App，那句话和助记词立即清除。' },
			{ title: '防截屏', text: '截屏、录屏和多任务界面都看不到内容。' },
			{ title: '恢复演练', text: '凭记忆再输一遍，核对结果是否一致。' },
			{
				title: '剪贴板自动清除',
				text: '复制的助记词 60 秒后清除。用二维码则完全不经过剪贴板。'
			}
		]
	},
	open: {
		title: '开源，不靠 App 也能恢复',
		items: [
			{ title: 'Android 和 iPhone', text: '同样的输入，两个平台得到同样的助记词。' },
			{
				title: '协议已冻结',
				text: '算法公开，由测试锁定，永不改变，所以每个版本结果都一样。'
			},
			{
				title: '用电脑恢复',
				text: '独立的 Python 实现（基于 argon2-cffi 和 Trezor 的 mnemonic）能在断网的电脑上算出同一组助记词。',
				link: { label: '怎样在电脑上恢复', path: 'README-zh.md#脱离-app-恢复' }
			}
		],
		requirements: 'Android 8.1 或 iOS 17 及以上，4 GB 以上内存。中英双语。',
		spec: '阅读协议规范',
		security: '安全政策',
		source: '浏览源码'
	},
	pricing: {
		title: '定价',
		lead: '商店版和自己编译的是同一个 App。买商店版省去编译，也支持 Keyper 的持续维护。',
		build: {
			name: '自己编译',
			price: '免费',
			per: '永久',
			points: [
				'需要 Android Studio，或 Mac 上的 Xcode',
				'iPhone 上用免费 Apple 账户签名，每 7 天要重装一次'
			],
			action: '怎样编译',
			guide: 'README-zh.md#构建与维护'
		},
		store: {
			name: 'Google Play 与 App Store',
			price: site.price,
			per: '一次性',
			status: '即将推出',
			googlePlay: 'Google Play',
			appStore: 'App Store'
		},
		note: '全球统一价。Android 和 iPhone 需要分别购买。'
	},
	faq: {
		title: '常见问题',
		items: [
			{
				q: '这不就是脑钱包吗？',
				a: '是，但针对旧脑钱包被攻破的原因做了设计。旧的脑钱包只做一次不加盐的 SHA-256，猜一次就能同时核对所有地址，每秒能试数百万次。Keyper 用邮箱作盐，攻击者只能逐个人攻击；再用 1 GiB 内存跑 128 遍 Argon2id，即使是数据中心级显卡，每秒也只能猜约 20 次。但如果那句话能被猜到，它也保不住。'
			},
			{
				q: 'Keyper 是钱包吗？',
				a: '不是。它只生成助记词，导入任何 BIP39 钱包即可。Keyper 从不持有或转移资产。'
			},
			{
				q: '为什么要填邮箱？',
				a: '让同一句话在不同人那里得到不同的助记词，攻击者只能一个人一个人地猜。只取邮箱里的字母和数字，不分大小写，所以 Alice@Example.com 和 alice@example.com 是同一个。也可以用手机号。'
			},
			{
				q: '别人知道了我的邮箱怎么办？',
				a: '邮箱不是秘密。对方还得猜出那句话，代价见上表。邮箱和那句话都被拿到，助记词就暴露了，所以那句话只用在 Keyper 上。'
			},
			{
				q: '忘了那句话怎么办？',
				a: '助记词就找不回来了，任何人都帮不了你。选一句多年后还记得的话，拼写保持一致。'
			},
			{
				q: '怎么确认装的是正版？',
				a: '只从 Google Play 或 App Store 安装，或自己从源码编译，并关掉它的自动更新。篡改版可能显示一组作者早就知道的助记词，所以使用前请用恢复脚本在断网的电脑上核对一次。'
			},
			{
				q: '为什么必须断网？',
				a: '这样那句话和助记词只存在于一台发不出任何东西的手机上。Keyper 本身从不联网，在 Android 上连网络权限都没有；但它防不住手机上已有的恶意软件，所以请用你信任的手机。'
			}
		]
	},
	footer: {
		license: '以 MIT 许可证开源。',
		security: '报告安全漏洞',
		privacy: '隐私政策',
		terms: '服务条款'
	}
};
