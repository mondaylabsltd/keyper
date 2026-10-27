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
	cost: {
		title: string;
		lead: string;
		head: [string, string, string];
		rows: [string, string, string][];
		note: string;
		warning: string;
	};
	features: { title: string; items: { title: string; text: string }[] };
	model: {
		title: string;
		lead: string;
		head: [string, string];
		rows: [string, string][];
		points: string[];
	};
	platforms: { title: string; lead: string; android: string; ios: string; caption: string };
	open: {
		title: string;
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
			'On an offline phone, Keyper turns your email and a sentence only you know into a standard BIP39 recovery phrase. The same inputs always give the same phrase. Open source, no permissions, Android and iPhone.'
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
		lead: 'On an offline phone, Keyper turns your email and a sentence only you know into a standard BIP39 recovery phrase. The same inputs always give the same phrase, so you do not need to write it down, and the app never saves what you type.',
		primary: 'Get Keyper',
		secondary: 'See how it works',
		note: `${site.price}, paid once. Or build it yourself for free.`
	},
	shots: [
		{ src: '/screens/en-input.png', alt: 'Typing the sentence on Keyper’s own keyboard' },
		{ src: '/screens/en-result.png', alt: 'A 12-word recovery phrase' }
	],
	facts: [
		'No permissions',
		'Saves nothing you type',
		'Works only offline',
		'Same phrases in every version',
		'MIT License'
	],
	how: {
		title: 'How it works',
		steps: [
			{
				title: 'Go offline',
				text: 'Turn on airplane mode and switch off Wi-Fi and Bluetooth. Keyper lets you type only while the phone has no network connection.'
			},
			{
				title: 'Type two things',
				text: 'Your email, then a sentence only you know, both on Keyper’s own keyboard. The email ignores capitals and punctuation; the sentence does not: every capital, symbol and space between words counts.'
			},
			{
				title: 'Wait a minute',
				text: 'Keyper runs Argon2id over 1 GiB of memory, 128 passes. About a minute on a phone: deliberately slow, so that guessing is slow too.'
			},
			{
				title: 'Use the phrase',
				text: '12 or 24 standard BIP39 words. Copy them into a wallet on the same phone or show them as a QR code.'
			}
		],
		flow: {
			email: 'Your email',
			sentence: 'Your sentence',
			slow: 'Argon2id · 1 GiB × 128',
			words: '12 or 24 BIP39 words'
		}
	},
	cost: {
		title: 'What guessing costs',
		lead: 'Every guess repeats the minute of work your phone does; a top GPU manages about 20 a second. With assumptions that favour the attacker:',
		head: ['How unguessable the sentence is', '1000 top GPUs', 'Electricity alone'],
		rows: [
			['30 bits', '7.5 hours', 'US$300'],
			['40 bits', '320 days', 'US$305,000'],
			['50 bits', '890 years', 'US$313 million'],
			['60 bits', '910,000 years', 'US$320 billion']
		],
		note: 'Each extra bit doubles the number of guesses. Above about 48.4 bits, the electricity alone passes US$100 million. Keyper estimates these figures while you type.',
		warning:
			'Length alone does not make a sentence hard to guess. Famous lines, lyrics, proverbs and “my cat is called…” are an attacker’s first tries and fall for a few dollars. Use details only you know: names, years, places, numbers, a symbol or two.'
	},
	features: {
		title: 'Protections',
		items: [
			{
				title: 'Its own keyboard',
				text: 'A fixed keyboard with exactly the characters a sentence may use. The system keyboard never connects, so nothing learns, syncs or uploads what you type. Paste and injected keys are blocked.'
			},
			{
				title: 'An offline gate',
				text: 'You can only type and generate while the phone has no network connection. When a connection comes back, the sentence and the phrase are wiped at once.'
			},
			{
				title: 'Nothing you type is saved',
				text: 'No account, no files, no backups. When you leave the app, the sentence and the phrase are gone.'
			},
			{
				title: 'No screenshots',
				text: 'Screenshots and screen recordings see nothing, and the app switcher shows a blank page.'
			},
			{
				title: 'A recovery drill',
				text: 'Before you use the phrase, type both inputs again from memory. Keyper tells you at once whether they match.'
			},
			{
				title: 'Clipboard cleared automatically',
				text: 'A copied phrase is cleared from the clipboard after 60 seconds, or at once if the phone goes online. To keep it off the clipboard entirely, use the QR code.'
			}
		]
	},
	model: {
		title: 'Security model',
		lead: 'Everything in Keyper’s code is public, including the constants built into the app: assume every attacker has it.',
		head: ['If someone has…', 'What still protects the phrase'],
		rows: [
			[
				'your email',
				'how hard your sentence is to guess: every guess costs 1 GiB × 128 passes'
			],
			['your sentence', 'only your email, which is usually not a secret'],
			['your email and your sentence', 'nothing: together they are the phrase']
		],
		points: [
			'Use the sentence for Keyper only.',
			'The phone you use should be clean: Keyper cannot protect you from malware already on it.'
		]
	},
	platforms: {
		title: 'Android and iPhone, the same phrase',
		lead: 'The same email and sentence give the same words on either phone.',
		android: 'Android 8.1 or later',
		ios: 'iOS 17 or later',
		caption: 'Both need 4 GB of RAM or more. English and Chinese.'
	},
	open: {
		title: 'A frozen protocol, and recovery without the app',
		items: [
			{
				title: 'A frozen protocol',
				text: 'Protocol v1 is written down exactly and will never change. Tests pin every constant, so an update that changed a phrase would fail them.'
			},
			{
				title: 'Three implementations',
				text: 'Kotlin on Android, Swift on iPhone and a Python reference all reproduce the same test vectors, which are checked against standard libraries.'
			},
			{
				title: 'No phone? Use a computer',
				text: 'If the phone is lost or the app is no longer available, the open-source recovery script gives the same phrase on a computer in about half a minute. Install it and the two libraries it needs, disconnect the computer from the network, then type the same email and sentence.',
				link: {
					label: 'How to recover on a computer',
					path: 'README.md#recovering-without-the-app'
				}
			}
		],
		spec: 'Read the protocol',
		security: 'Security policy',
		source: 'Browse the source'
	},
	pricing: {
		title: 'Pricing',
		lead: 'The store version and a build from source are the same app and give the same phrases. Buying it saves you the build and pays for Keyper’s upkeep.',
		build: {
			name: 'Build it yourself',
			price: 'Free',
			per: 'forever',
			points: [
				'Needs Android Studio, or Xcode on a Mac',
				'On iPhone, a build signed with a free Apple account must be reinstalled every 7 days'
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
		note: 'One price worldwide; each store shows it in your currency. Android and iPhone are separate purchases.'
	},
	faq: {
		title: 'Questions',
		items: [
			{
				q: 'Is Keyper a wallet?',
				a: 'No. Keyper only produces the recovery phrase. Put it into any wallet that accepts a standard 12- or 24-word BIP39 phrase. Keyper never holds or moves funds.'
			},
			{
				q: 'Why does it need my email?',
				a: 'So that the same sentence gives different phrases for different people, and an attacker has to guess one person at a time. The email does not need to be secret. Keyper uses only its letters and digits and ignores case, so Alice@Example.com, alice@example.com and alice.@example.com give the same phrase. A phone number works too. Your sentence is the opposite: one different capital, symbol or space between words gives a different phrase.'
			},
			{
				q: 'What if I forget the sentence?',
				a: 'Then the phrase is gone; nobody can recover it. Choose a sentence you will remember for years, keep its spelling consistent, and do the recovery drill.'
			},
			{
				q: 'How do I know my copy is genuine?',
				a: 'Install Keyper only from its Google Play or App Store listing, or build it from the source, and turn off automatic updates for it. A tampered copy would not need the network to hurt you: it could show a phrase its maker already knows. To rule that out, check your phrase once with the open-source recovery script on an offline computer before you use it.'
			},
			{
				q: 'Why must the phone be offline?',
				a: 'So that your sentence and phrase only ever exist on a phone that cannot send them anywhere. Keyper itself never connects to the network; the gate keeps you from using it on a connected phone by mistake.'
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
			'在一台离线手机上，Keyper 用你的邮箱和一句只有你知道的话，生成标准 BIP39 助记词。同样的输入总是得到同样的助记词。开源、零权限，支持 Android 和 iPhone。'
	},
	nav: { how: '原理', security: '安全', pricing: '定价', faq: '常见问题', source: '源码' },
	hero: {
		eyebrow: 'Android 与 iPhone',
		title: '记在脑子里的助记词。',
		lead: '在一台离线手机上，Keyper 用你的邮箱和一句只有你知道的话，生成标准 BIP39 助记词。同样的输入总是得到同样的助记词，所以不用抄写，App 也从不保存你输入的内容。',
		primary: '获取 Keyper',
		secondary: '看看原理',
		note: `${site.price}，一次买断。也可以自己免费编译。`
	},
	shots: [
		{ src: '/screens/zh-input.png', alt: '用 Keyper 自带键盘输入那句话' },
		{ src: '/screens/zh-result.png', alt: '12 个词的助记词' }
	],
	facts: ['零权限', '不保存你的输入', '只在离线时工作', '每个版本算出的都一样', 'MIT 许可证'],
	how: {
		title: '原理',
		steps: [
			{
				title: '先断网',
				text: '打开飞行模式，关闭 Wi-Fi 和蓝牙。手机还有网络连接时，Keyper 不让你输入。'
			},
			{
				title: '输入两样东西',
				text: '先输入邮箱，再输入只有你知道的一句话，都用 Keyper 自带的键盘。邮箱不分大小写、忽略标点；那句话不一样，大小写、符号和词之间的空格都算数。'
			},
			{
				title: '等一分钟',
				text: 'Keyper 用 1 GiB 内存跑 128 遍 Argon2id，手机上约一分钟。故意算得慢，别人猜起来也就慢。'
			},
			{
				title: '使用助记词',
				text: '12 或 24 个标准 BIP39 词。复制到同一台手机的钱包，或用二维码给另一台设备扫描。'
			}
		],
		flow: {
			email: '你的邮箱',
			sentence: '你的那句话',
			slow: 'Argon2id · 1 GiB × 128',
			words: '12 或 24 个 BIP39 词'
		}
	},
	cost: {
		title: '猜一次要花多少',
		lead: '你手机上那一分钟的计算，攻击者每猜一次都得重做一遍，顶级显卡每秒也只能做约 20 次。按偏向攻击者的假设：',
		head: ['那句话有多难猜', '一千张顶级显卡', '光电费'],
		rows: [
			['30 位', '7.5 小时', '300 美元'],
			['40 位', '320 天', '30 万美元'],
			['50 位', '890 年', '3.1 亿美元'],
			['60 位', '91 万年', '3200 亿美元']
		],
		note: '每多 1 位，要猜的次数就翻一倍。超过约 48.4 位，光电费就超过 1 亿美元。你输入时，Keyper 会估算这几个数。',
		warning:
			'字多不等于难猜。名句、歌词、俗语、“我的猫叫某某”这类模板，攻击者最先试，几块钱电费就能命中。要用只有你知道的细节：人名、年份、地点、数字，再加一两个符号。'
	},
	features: {
		title: '保护措施',
		items: [
			{
				title: '自带键盘',
				text: '固定布局，只提供那句话允许的字符。系统输入法从不连接，也就没法学习、同步或上传你输入的内容；粘贴和注入的按键都会被拦截。'
			},
			{
				title: '断网门禁',
				text: '只有手机没有网络连接时才能输入和生成。一旦恢复连接，那句话和助记词立即清除。'
			},
			{
				title: '不保存你的输入',
				text: '没有账户、没有文件、没有备份。离开 App，那句话和助记词就没了。'
			},
			{
				title: '防截屏',
				text: '截屏和录屏都看不到内容，多任务界面里也是空白。'
			},
			{
				title: '恢复演练',
				text: '使用助记词之前，凭记忆把两样输入再打一遍，Keyper 当场告诉你是否一致。'
			},
			{
				title: '剪贴板自动清除',
				text: '复制的助记词 60 秒后从剪贴板清除，手机一联网则立即清除。想让它完全不经过剪贴板，就用二维码。'
			}
		]
	},
	model: {
		title: '安全模型',
		lead: 'Keyper 的代码完全公开，包括 App 里内置的常量，要当作每个攻击者都有。',
		head: ['别人拿到了…', '还剩什么在保护你'],
		rows: [
			['你的邮箱', '那句话有多难猜：每猜一次都要 1 GiB × 128 遍'],
			['你的那句话', '只剩邮箱，而邮箱通常不是秘密'],
			['邮箱和那句话', '没有了，这两样加起来就是助记词']
		],
		points: [
			'那句话只用在 Keyper 上，别在别处用。',
			'用来生成的手机要干净：手机上已有的恶意软件，Keyper 防不住。'
		]
	},
	platforms: {
		title: 'Android 与 iPhone，同一组助记词',
		lead: '同样的邮箱和那句话，在哪台手机上都得到同样的词。',
		android: 'Android 8.1 及以上',
		ios: 'iOS 17 及以上',
		caption: '都需要 4 GB 以上内存。中英双语。'
	},
	open: {
		title: '冻结的协议，以及不靠 App 恢复',
		items: [
			{
				title: '协议已冻结',
				text: 'v1 协议精确成文，永远不会改。测试钉死了每一个常量，任何会改变助记词的更新都通不过测试。'
			},
			{
				title: '三套实现',
				text: 'Android 上的 Kotlin、iPhone 上的 Swift 和一份 Python 参考实现，都复现同一组测试向量，这些向量都对照标准库核验过。'
			},
			{
				title: '没有手机，用电脑也能找回',
				text: '手机丢了或者 App 下架了，开源的恢复脚本能在电脑上半分钟左右算出同一组助记词。先装好脚本和它需要的两个库，断开电脑的网络，再输入同样的邮箱和那句话。',
				link: { label: '怎样在电脑上恢复', path: 'README-zh.md#脱离-app-恢复' }
			}
		],
		spec: '阅读协议规范',
		security: '安全政策',
		source: '浏览源码'
	},
	pricing: {
		title: '定价',
		lead: '商店版和自己编译的是同一个 App，算出的助记词也相同。买商店版省去自己编译，也支持 Keyper 的持续维护。',
		build: {
			name: '自己编译',
			price: '免费',
			per: '永久',
			points: [
				'需要 Android Studio，或者 Mac 上的 Xcode',
				'iPhone 上用免费 Apple 账户签名的版本，每 7 天要重新安装一次'
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
		note: '全球统一定价，商店会按你所在地区的货币显示。Android 和 iPhone 需要分别购买。'
	},
	faq: {
		title: '常见问题',
		items: [
			{
				q: 'Keyper 是钱包吗？',
				a: '不是。Keyper 只负责生成助记词。把它导入任何支持标准 12 或 24 词 BIP39 助记词的钱包即可。Keyper 从不持有、也不转移资产。'
			},
			{
				q: '为什么要填邮箱？',
				a: '为了让同一句话在不同人那里得到不同的助记词，攻击者只能一个人一个人地猜。邮箱不需要保密。Keyper 只取邮箱里的英文字母和数字，不分大小写，所以 Alice@Example.com、alice@example.com 和 alice.@example.com 算出的是同一组助记词。也可以用手机号代替邮箱。那句话正好相反：大小写、符号、词之间的空格，错一处，助记词就完全不同。'
			},
			{
				q: '忘了那句话怎么办？',
				a: '那组助记词就找不回来了，没有人能帮你恢复。选一句多年后还记得的话，拼写保持一致，并做一次恢复演练。'
			},
			{
				q: '怎么确认装的是正版？',
				a: '只从 Google Play 或 App Store 上的官方页面安装，或者自己从源码编译，并关掉它的自动更新。篡改版不联网也能害你：它可以显示一组作者早就知道的助记词。要排除这种情况，在使用助记词之前，用开源恢复脚本在一台断网的电脑上核对一次。'
			},
			{
				q: '为什么手机必须断网？',
				a: '这样那句话和助记词只会出现在一台什么都发不出去的手机上。Keyper 自己完全不联网；门禁是为了防止你在联网的手机上误用。'
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
