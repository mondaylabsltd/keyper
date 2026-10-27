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
		lead: string;
		steps: { title: string; text: string }[];
		flow: { email: string; sentence: string; slow: string; words: string };
	};
	cost: {
		title: string;
		lead: string;
		head: [string, string, string];
		rows: [string, string, string][];
		note: string;
		warning: string;
	};
	features: { title: string; lead: string; items: { title: string; text: string }[] };
	model: { title: string; head: [string, string]; rows: [string, string][]; points: string[] };
	platforms: { title: string; lead: string; android: string; ios: string; caption: string };
	open: {
		title: string;
		lead: string;
		/** `link.path` is a file in the repository, with an optional #anchor. */
		items: { title: string; text: string; link?: { label: string; path: string } }[];
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
		store: { name: string; price: string; per: string; points: string[] };
		note: string;
	};
	faq: { title: string; items: { q: string; a: string }[] };
	cta: { title: string; text: string; soon: string };
	/** `check` names the code every official build shows at the bottom of its screen; `checkHint` explains it. */
	footer: { license: string; security: string; check: string; checkHint: string };
}

export const en: Content = {
	lang: 'en',
	htmlLang: 'en',
	path: '/',
	other: { path: '/zh', label: '中文', hreflang: 'zh-Hans' },
	meta: {
		title: 'Keyper: a recovery phrase you keep in your head',
		description:
			'On an offline phone, Keyper turns your email and a sentence only you know into a standard BIP39 recovery phrase. Same inputs, same phrase, forever. Open source, no permissions, Android and iPhone.'
	},
	nav: {
		how: 'How it works',
		security: 'Security',
		pricing: 'Pricing',
		faq: 'FAQ',
		source: 'Source'
	},
	hero: {
		eyebrow: 'Open source · Offline only · Android & iPhone',
		title: 'A recovery phrase you keep in your head.',
		lead: 'On an offline phone, Keyper turns your email and a sentence only you know into a standard BIP39 recovery phrase. The same inputs give the same phrase, forever. Nothing to write down, nothing stored.',
		primary: 'See how it works',
		secondary: 'Read the security model',
		note: 'Coming to Google Play and the App Store.'
	},
	shots: [
		{ src: '/screens/en-input.png', alt: 'Typing the sentence on Keyper’s own keyboard' },
		{ src: '/screens/en-result.png', alt: 'A 12-word recovery phrase' }
	],
	facts: [
		'No permissions',
		'Nothing stored',
		'Works only offline',
		'Protocol frozen',
		'MIT licence'
	],
	how: {
		title: 'How it works',
		lead: 'Your email and your sentence go in. A standard recovery phrase comes out, usable with any wallet. Keyper keeps nothing: next time, type the same two things again.',
		steps: [
			{
				title: 'Go offline',
				text: 'Turn on airplane mode and switch off Wi-Fi and Bluetooth. Keyper will not let you type your sentence until the phone is offline, and forgets everything the moment it is back online.'
			},
			{
				title: 'Type two things',
				text: 'Your email, then a sentence only you know, both on Keyper’s own keyboard. No system or third-party keyboard ever sees them.'
			},
			{
				title: 'Wait a minute',
				text: 'Keyper runs Argon2id over 1 GiB of memory, 128 times. About a minute on a phone: deliberately slow, so that guessing is slow too.'
			},
			{
				title: 'Use the phrase',
				text: '12 or 24 standard BIP39 words. Copy them into a wallet on the same phone or show them as a QR code. A recovery drill checks you can type it all again.'
			}
		],
		flow: {
			email: 'Email (only a salt)',
			sentence: 'Your sentence',
			slow: 'Argon2id · 1 GiB × 128',
			words: '12 or 24 BIP39 words'
		}
	},
	cost: {
		title: 'Expensive to guess, if your sentence is yours',
		lead: 'Every guess costs an attacker the same minute of memory-hard work you spent once. With assumptions that favour the attacker, here is what a search costs:',
		head: ['How unguessable the sentence is', '1000 top GPUs', 'Electricity alone'],
		rows: [
			['30 bits', '7.5 hours', 'US$300'],
			['40 bits', '320 days', 'US$305,000'],
			['50 bits', '890 years', 'US$313 million'],
			['60 bits', '910,000 years', 'US$320 billion']
		],
		note: 'From about 48 bits on, the electricity alone passes US$100 million. Keyper estimates this while you type.',
		warning:
			'Long is not the same as hard to guess. Famous lines, lyrics, proverbs and “my cat is called…” are an attacker’s first tries and fall for a few dollars. Use details only you know: names, years, places, numbers, a symbol or two.'
	},
	features: {
		title: 'Built to stay offline and leave nothing behind',
		lead: 'Everything around the derivation exists to keep your sentence on your phone and in your head.',
		items: [
			{
				title: 'Its own keyboard',
				text: 'A fixed keyboard with exactly the characters a sentence may use. The system keyboard never connects, so nothing learns, syncs or uploads what you type. Paste and injected keys are blocked.'
			},
			{
				title: 'An offline gate',
				text: 'You can only type and generate offline. Going back online wipes the sentence and the phrase at once.'
			},
			{
				title: 'Nothing stored',
				text: 'No account, no files, no backups, no network. Leave the app and the sentence and the phrase are gone.'
			},
			{
				title: 'No screenshots',
				text: 'Screenshots and screen recordings see nothing, and the app switcher shows a blank page.'
			},
			{
				title: 'A recovery drill',
				text: 'Before you move any funds, type both inputs again from memory. Keyper tells you at once whether they match.'
			},
			{
				title: 'A short-lived clipboard',
				text: 'A copied phrase is marked sensitive and leaves the clipboard after 60 seconds. On iPhone it never reaches your other devices.'
			}
		]
	},
	model: {
		title: 'What protects you, honestly',
		head: ['If someone has…', 'What still protects the phrase'],
		rows: [
			[
				'only your sentence',
				'your email, and the domain constant if the app was never published'
			],
			[
				'the app and your email',
				'how hard your sentence is to guess: every guess costs 1 GiB × 128 passes'
			],
			['the app, your email and your sentence', 'nothing: together they are the phrase']
		],
		points: [
			'Keyper is an algorithm, not a vault. Its security is your sentence and the cost of each guess.',
			'Use the sentence for Keyper only, and do the recovery drill before you rely on it.',
			'The phone you use should be clean: Keyper cannot protect you from malware already on it.'
		]
	},
	platforms: {
		title: 'Android and iPhone, the same phrase',
		lead: 'Two native apps that follow one frozen specification. They are tested against the same vectors: the same email and sentence give the same words on either phone.',
		android: 'Android 8.1 or later',
		ios: 'iOS 17 or later',
		caption: 'Both need 4 GB of RAM or more. English and Chinese.'
	},
	open: {
		title: 'Open, frozen, and recoverable without us',
		lead: 'You should never need Keyper the company, or even Keyper the app, to get your phrase back.',
		items: [
			{
				title: 'A frozen protocol',
				text: 'Protocol v1 is written down exactly and will never change. Tests pin every constant, so no update can alter a phrase you already have.'
			},
			{
				title: 'Independent implementations',
				text: 'Kotlin on Android, Swift on iPhone and an independent Python reference all reproduce the same test vectors, checked against standard libraries.'
			},
			{
				title: 'No phone? Use a computer',
				text: 'Lost the phone, or the app is gone? Run the open-source recovery script on any computer, type the same email and sentence, and get the same phrase in about half a minute. No Keyper app needed.',
				link: {
					label: 'How to recover on a computer',
					path: 'README.md#recovering-without-the-app'
				}
			},
			{
				title: 'Open source',
				text: 'Under the MIT License. Anyone may read, build and verify every line, and build on it.'
			}
		],
		spec: 'Read the protocol',
		security: 'Security policy',
		source: 'Browse the source'
	},
	pricing: {
		title: 'One price, paid once. Or free.',
		lead: 'The app is the same either way: the same features and the same phrases. What the store version adds is convenience.',
		build: {
			name: 'Build it yourself',
			price: 'Free',
			per: 'forever',
			points: [
				'The complete source, under the MIT License',
				'The same app and the same phrases as the store version',
				'Needs Android Studio or Xcode, and an afternoon'
			],
			action: 'How to build',
			guide: 'README.md#building-and-maintaining'
		},
		store: {
			name: 'Google Play and the App Store',
			price: site.price,
			per: 'once',
			points: [
				'Official signed builds, published only on these two stores',
				'Updates through the store, which you can turn off on the offline phone',
				'No subscription, no in-app purchases, no ads, no account',
				'Supports the continued development of Keyper'
			]
		},
		note: 'One price worldwide; each store shows it in your currency. Android and iPhone are bought separately, as the two stores require.'
	},
	faq: {
		title: 'Questions',
		items: [
			{
				q: 'If it is open source, why pay?',
				a: 'You do not have to. Anyone can build Keyper from the source for free. Buying it from a store gets you a signed build and updates without setting up a build, and keeps the project maintained.'
			},
			{
				q: 'Is Keyper a wallet?',
				a: 'No. Keyper only produces the recovery phrase. Put it into any wallet that accepts a standard 12- or 24-word BIP39 phrase. Keyper never holds or moves funds.'
			},
			{
				q: 'Why does it need my email?',
				a: 'It is a salt, not a secret: it makes the same sentence give unrelated phrases for different people, so an attacker has to attack one person at a time. Case, dots and spaces do not matter, and a phone number works too.'
			},
			{
				q: 'What if I forget the sentence?',
				a: 'Then the phrase is gone. Nobody can recover it, which is the point. Choose a sentence you will remember for years, keep its spelling consistent, and do the recovery drill.'
			},
			{
				q: 'What if Keyper disappears?',
				a: 'The protocol is public and the Python reference runs anywhere. Keep a copy of the source and of the app you used: with them, your phrase can always be derived again.'
			},
			{
				q: 'Can I use Chinese?',
				a: 'Write it in pinyin, for example “Wo de di yi zhi mao jiao MiMi!”. The sentence uses letters, digits and 18 unambiguous symbols, so it can be typed the same way on any phone or computer, years from now.'
			},
			{
				q: 'How do I know my copy is genuine?',
				a: 'By where it came from: install Keyper only from its official Google Play and App Store listings, or build it yourself from the source. The compatibility code at the bottom of the screen only tells you that the phrases will match; a tampered copy could show it too. Keep the phone offline for good and turn off automatic updates: offline, even a tampered copy cannot send anything.'
			},
			{
				q: 'Why must the phone be offline?',
				a: 'So that your sentence and phrase only ever exist on a phone that cannot send them anywhere. Keyper itself has no network access at all; the gate keeps you from using it on a connected phone by mistake.'
			}
		]
	},
	cta: {
		title: 'Keep your phrase where no one can find it.',
		text:
			'Keyper is finishing its first release for Android and iPhone: ' +
			site.price +
			' once from the stores, or free to build.',
		soon: 'Coming soon'
	},
	footer: {
		license: 'Open source under the MIT License.',
		security: 'Report a vulnerability',
		check: 'Compatibility code',
		checkHint:
			'Shown at the bottom of every official Keyper. Apps with the same code give the same phrases; it cannot prove an app is genuine.'
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
			'在一台离线手机上，Keyper 用你的邮箱和一句只有你知道的话，生成标准 BIP39 助记词。同样的输入，永远得到同样的助记词。开源、零权限，支持 Android 和 iPhone。'
	},
	nav: { how: '原理', security: '安全', pricing: '定价', faq: '常见问题', source: '源码' },
	hero: {
		eyebrow: '开源 · 只在离线时工作 · Android 与 iPhone',
		title: '记在脑子里的助记词。',
		lead: '在一台离线手机上，Keyper 用你的邮箱和一句只有你知道的话，生成标准 BIP39 助记词。同样的输入，永远得到同样的助记词：不用抄写，什么也不存。',
		primary: '看看原理',
		secondary: '安全模型',
		note: '即将上架 Google Play 和 App Store。'
	},
	shots: [
		{ src: '/screens/zh-input.png', alt: '用 Keyper 自带键盘输入记忆文本' },
		{ src: '/screens/zh-result.png', alt: '12 个词的助记词' }
	],
	facts: ['零权限', '什么都不存', '只在离线时工作', '协议已冻结', 'MIT 许可证'],
	how: {
		title: '原理',
		lead: '输入邮箱和一句话，得到一组标准助记词，任何钱包都能用。Keyper 什么都不保存：下次再输入同样的两样东西即可。',
		steps: [
			{
				title: '先断网',
				text: '打开飞行模式，关闭 Wi-Fi 和蓝牙。手机没断网，Keyper 就不让你输入那句话；一旦重新联网，它立即忘掉一切。'
			},
			{
				title: '输入两样东西',
				text: '先输入邮箱，再输入只有你知道的一句话，都用 Keyper 自带的键盘。系统和第三方输入法完全接触不到。'
			},
			{
				title: '等一分钟',
				text: 'Keyper 用 1 GiB 内存跑 128 遍 Argon2id，手机上约一分钟。故意算得慢，别人猜起来也就慢。'
			},
			{
				title: '使用助记词',
				text: '12 或 24 个标准 BIP39 词。复制到同一台手机的钱包，或用二维码给另一台设备扫描。恢复演练会确认你能再完整输入一遍。'
			}
		],
		flow: {
			email: '邮箱（只作盐）',
			sentence: '你的那句话',
			slow: 'Argon2id · 1 GiB × 128',
			words: '12 或 24 个 BIP39 词'
		}
	},
	cost: {
		title: '只要那句话真是你自己的，就很难猜',
		lead: '你算一次花的那一分钟，攻击者每猜一次都要花。按偏向攻击者的假设，暴力搜索的代价是：',
		head: ['那句话有多难猜', '一千张顶级显卡', '光电费'],
		rows: [
			['30 位', '7.5 小时', '300 美元'],
			['40 位', '320 天', '30 万美元'],
			['50 位', '890 年', '3.1 亿美元'],
			['60 位', '91 万年', '3200 亿美元']
		],
		note: '约 48 位熵起，光电费就超过 1 亿美元。输入时 Keyper 会按这个模型估算。',
		warning:
			'字多不等于难猜。名句、歌词、俗语、“我的猫叫某某”这类模板，攻击者最先试，几块钱电费就能命中。要用只有你知道的细节：人名、年份、地点、数字，再加一两个符号。'
	},
	features: {
		title: '只在离线时工作，什么也不留下',
		lead: '围绕计算的每一处设计，都是为了让那句话只存在于你的手机和你的脑子里。',
		items: [
			{
				title: '自带键盘',
				text: '固定布局，只提供那句话允许的字符。系统输入法从不连接，没有谁能学习、同步或上传你输入的内容；粘贴和注入的按键都会被拦截。'
			},
			{
				title: '断网门禁',
				text: '只有断网时才能输入和生成。一旦联网，记忆文本和助记词立即清除。'
			},
			{
				title: '什么都不存',
				text: '没有账户、没有文件、没有备份、不联网。离开 App，记忆文本和助记词就没了。'
			},
			{
				title: '防截屏',
				text: '截屏和录屏都看不到内容，多任务界面里也是空白。'
			},
			{
				title: '恢复演练',
				text: '在往钱包转钱之前，凭记忆把两样输入再打一遍，Keyper 当场告诉你是否一致。'
			},
			{
				title: '短命的剪贴板',
				text: '复制的助记词标记为敏感，60 秒后离开剪贴板；在 iPhone 上也不会同步到你的其他设备。'
			}
		]
	},
	model: {
		title: '坦白讲，什么在保护你',
		head: ['别人拿到了…', '还剩什么在保护你'],
		rows: [
			['只有你的那句话', '你的邮箱；App 从未公开时还有域常量'],
			['App 和你的邮箱', '那句话有多难猜：每猜一次都要 1 GiB × 128 遍'],
			['App、邮箱和那句话', '没有了，这三样加起来就是助记词']
		],
		points: [
			'Keyper 是一个算法，不是保险箱。安全靠的是你那句话，和每次猜测的代价。',
			'这句话只用于 Keyper，依赖它之前先做一次恢复演练。',
			'用来生成的手机要干净：手机上已有的恶意软件，Keyper 防不住。'
		]
	},
	platforms: {
		title: 'Android 与 iPhone，同一组助记词',
		lead: '两个原生 App 遵循同一份冻结的规范，用同一套测试向量验证：同样的邮箱和那句话，在哪台手机上都得到同样的词。',
		android: 'Android 8.1 及以上',
		ios: 'iOS 17 及以上',
		caption: '都需要 4 GB 以上内存。中英双语。'
	},
	open: {
		title: '公开、冻结，离开我们也能恢复',
		lead: '找回助记词，永远不应该依赖 Keyper 这家公司，甚至不应该依赖 Keyper 这个 App。',
		items: [
			{
				title: '协议已冻结',
				text: 'v1 协议精确成文，永远不会改。测试钉死了每一个常量，任何更新都不可能改变你已有的助记词。'
			},
			{
				title: '互相独立的实现',
				text: 'Android 上的 Kotlin、iPhone 上的 Swift 和一份独立的 Python 参考实现，都复现同一组测试向量，并对照标准库逐一核验。'
			},
			{
				title: '没有手机，用电脑也能找回',
				text: '手机丢了、App 没了也不怕：在任何一台电脑上运行开源的恢复脚本，输入同样的邮箱和那句话，半分钟左右就能算出同一组助记词，不需要 Keyper App。',
				link: { label: '怎样在电脑上恢复', path: 'README-zh.md#脱离-app-恢复' }
			},
			{
				title: '开源',
				text: '以 MIT 许可证发布。任何人都能阅读、构建、核验每一行代码，也可以在它的基础上继续开发。'
			}
		],
		spec: '阅读协议规范',
		security: '安全政策',
		source: '浏览源码'
	},
	pricing: {
		title: '一次买断，或者免费',
		lead: '两种方式得到的是同一个 App：功能一样，助记词也一样。商店版多的只是省事。',
		build: {
			name: '自己编译',
			price: '免费',
			per: '永久',
			points: [
				'完整源码，MIT 许可证',
				'与商店版完全相同的 App，同样的助记词',
				'需要 Android Studio 或 Xcode，以及一个下午'
			],
			action: '怎样编译',
			guide: 'README-zh.md#构建与维护'
		},
		store: {
			name: 'Google Play 与 App Store',
			price: site.price,
			per: '一次性',
			points: [
				'官方签名版本，只在这两家商店发布',
				'通过商店更新，离线手机上可以关掉自动更新',
				'不订阅、不内购、无广告、无需账户',
				'支持 Keyper 的持续开发'
			]
		},
		note: '全球统一定价，商店会按你所在地区的货币显示。Android 和 iPhone 需分别购买，这是两家商店的规定。'
	},
	faq: {
		title: '常见问题',
		items: [
			{
				q: '开源为什么还要付费？',
				a: '不付费也完全可以：任何人都能从源码免费编译 Keyper。在商店购买，得到的是官方签名版本和自动更新，不用自己搭编译环境，同时支持项目持续维护。'
			},
			{
				q: 'Keyper 是钱包吗？',
				a: '不是。Keyper 只负责生成助记词。把它导入任何支持标准 12 或 24 词 BIP39 助记词的钱包即可。Keyper 从不持有、也不转移资产。'
			},
			{
				q: '为什么要填邮箱？',
				a: '邮箱是盐，不是秘密：它让同一句话在不同人那里得到无关的助记词，攻击者只能一个人一个人地猜。大小写、点和空格都不影响，用手机号也可以。'
			},
			{
				q: '忘了那句话怎么办？',
				a: '那组助记词就再也找不回来了，没有人能帮你恢复，这正是设计初衷。选一句多年后还记得的话，拼写保持一致，并做一次恢复演练。'
			},
			{
				q: 'Keyper 不在了怎么办？',
				a: '协议是公开的，Python 参考实现在任何电脑上都能运行。留一份源码和你用过的 App：有它们，助记词随时能再算出来。'
			},
			{
				q: '能用中文吗？',
				a: '用拼音写，比如 “Wo de di yi zhi mao jiao MiMi!”。那句话由字母、数字和 18 个不易混淆的符号组成，多年后在任何手机或电脑上都能原样输入。'
			},
			{
				q: '怎么确认装的是正版？',
				a: '看来源：只从 Google Play 和 App Store 上的官方页面安装，或者自己从源码编译。屏幕底部的兼容码只能说明算出的助记词一致，篡改版也可以显示同样的码。这台手机从此保持断网，并关掉自动更新：断了网，即使是篡改版也发不出任何东西。'
			},
			{
				q: '为什么手机必须断网？',
				a: '这样那句话和助记词只会出现在一台什么都发不出去的手机上。Keyper 自己完全不联网；门禁是为了防止你在联网的手机上误用。'
			}
		]
	},
	cta: {
		title: '把助记词放在谁也找不到的地方。',
		text:
			'Keyper 的 Android 和 iPhone 首个版本正在收尾：商店版 ' +
			site.price +
			' 一次买断，自己编译免费。',
		soon: '即将推出'
	},
	footer: {
		license: '以 MIT 许可证开源。',
		security: '报告安全漏洞',
		check: '兼容码',
		checkHint:
			'官方 Keyper 屏幕最底部都显示这串码。码相同，算出的助记词就相同；但它证明不了 App 是正版。'
	}
};
