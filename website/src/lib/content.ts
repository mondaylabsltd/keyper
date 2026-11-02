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
	nav: { how: string; security: string; pricing: string; source: string };
	hero: {
		title: string;
		lead: string;
		primary: string;
		secondary: string;
	};
	shots: { src: string; alt: string }[];
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
		/** One per icon in Landing.svelte, in order. */
		items: { title: string; text: string }[];
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
		title: 'Keyper · Recovery doesn’t have to depend on paper.',
		description:
			'Generate BIP39 recovery words from your email and a secret sentence on an offline phone. Same inputs, same words. See how Keyper changes backup and recovery, and the responsibility that comes with remembering. Open source, for Android and iPhone.'
	},
	nav: {
		how: 'How to use',
		security: 'Security & risks',
		pricing: 'Get Keyper',
		source: 'View source ↗'
	},
	hero: {
		title: 'Recovery doesn’t have to depend on paper.',
		lead: 'Generate recovery words from your email and a sentence you remember on an offline device. Enter the same inputs later to get the same words again.',
		primary: 'Get Keyper',
		secondary: 'See how recovery works'
	},
	shots: [
		{
			src: '/screens/en-input.png',
			alt: 'Keyper email and sentence fields with public demo data; strength and cost are model estimates'
		},
		{
			src: '/screens/en-result.png',
			alt: 'Public example recovery words in Keyper; never use them to hold assets'
		}
	],
	how: {
		title: 'Recover without finding that piece of paper.',
		steps: [
			{
				title: 'Prepare a trusted offline device',
				text: 'Enable airplane mode and disable Wi-Fi and Bluetooth in Settings. Another Android phone or iPhone can generate the words again.'
			},
			{
				title: 'Enter your original email and sentence',
				text: 'Use the app’s own keyboard. Keep the email, capitalization, and punctuation exact.'
			},
			{
				title: 'Check first, then import',
				text: 'Get 12 or 24 BIP39 words. Rehearse recovery on first use, then scan the QR code with a compatible wallet.'
			}
		],
		flow: {
			email: 'Your email (example)',
			sentence: 'Your sentence (example)',
			slow: 'Regenerate offline',
			words: '12 or 24 BIP39 words'
		}
	},
	security: {
		title: 'How much difference can a harder-to-guess sentence make?',
		lead: 'Every guess requires a full Argon2id run. This model assumes 1,000 data-centre GPUs, each making 20 guesses per second at 40 joules per guess, with electricity at US$0.05 per kWh. On average, half the search space is tried:',
		head: ['Entropy', 'Time', 'Electricity'],
		rows: [
			['30 bits', '7.5 hours', 'US$300'],
			['40 bits', '320 days', 'US$305,000'],
			['50 bits', '890 years', 'US$313 million'],
			['60 bits', '910,000 years', 'US$320 billion']
		],
		note: 'Entropy values here are assumptions, not measurements of your sentence. Hardware costs are excluded; actual attack costs may differ. The app’s score cannot tell you which row your inputs belong in.',
		model: { label: 'See the assumptions and calculation', path: 'SPEC.md#4-security-model' },
		items: [
			{
				title: 'Forget the inputs, and no one can help',
				text: 'Keyper does not store your email or sentence and offers no recovery service. Even one missing punctuation mark can generate a different recovery phrase.'
			},
			{
				title: 'Guessable sentences are still dangerous',
				text: 'Quotations, lyrics, and public personal information are not reliable secrets. Argon2id makes each guess more expensive, but cannot turn a weak sentence into a strong secret.'
			},
			{
				title: 'Offline does not mean a completely safe device',
				text: 'Disconnecting reduces the risk of information being sent out, but cannot stop malware already on the device. Use a device you trust.'
			},
			{
				title: 'Keyper is not insurance for your assets',
				text: 'It only generates recovery words. It does not hold assets or revoke an exposed phrase. Independently verify recovery before transferring assets.'
			}
		]
	},
	pricing: {
		title: 'Skip the build. Pay once.',
		lead: 'The store version saves you build and installation setup and supports maintenance. Source is free; build it yourself for the same features.',
		build: {
			name: 'Build from source',
			price: 'Free',
			per: 'All features',
			points: [
				'Android needs a build environment; iPhone needs a Mac, Xcode, and signing setup.'
			],
			action: 'Read the build instructions',
			guide: 'README.md#building-and-maintaining'
		},
		store: {
			name: 'Google Play & App Store',
			price: site.price,
			per: 'One purchase',
			status: 'Coming soon',
			googlePlay: 'Google Play',
			appStore: 'App Store'
		},
		note: 'No subscription. Android and iPhone are separate purchases; final local pricing will appear in the stores.'
	},
	faq: {
		title: 'A few more questions worth asking.',
		items: [
			{
				q: 'Isn’t this a brainwallet?',
				a: 'Yes. Keyper uses your email as salt and memory-intensive Argon2id to raise guessing costs, addressing some weaknesses of traditional brainwallets. It cannot guarantee that a sentence is unguessable, and strength estimates have limitations.'
			},
			{
				q: 'Can Keyper hold or transfer assets directly?',
				a: 'No. Keyper only generates standard BIP39 recovery words. It is not a wallet. You need compatible wallet software to manage assets.'
			},
			{
				q: 'What if the app is gone years from now?',
				a: 'The protocol is public, with a separate Python recovery implementation. Before relying on it, personally verify the recovery process on an offline computer and preserve a reliable way to recover.'
			},
			{
				q: 'Why is an email address needed?',
				a: 'It distinguishes different users’ derivation inputs. It is not an account and requires no login. The address must be entered accurately: differences such as dots in some addresses change the result.'
			}
		]
	},
	footer: {
		license: 'Open source under the MIT License.',
		security: 'Report a security issue',
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
		title: 'Keyper · 助记词，不必只靠一张纸',
		description:
			'用邮箱和记忆文本，在离线手机上生成 BIP39 助记词。输入相同，结果相同。了解 Keyper 怎样改变备份与恢复流程，以及需要承担的记忆责任。Android 与 iPhone，开源。'
	},
	nav: {
		how: '怎么使用',
		security: '安全与风险',
		pricing: '获取',
		source: '查看源码 ↗'
	},
	hero: {
		title: '助记词，不必只靠一张纸。',
		lead: '用邮箱和一句你记得的话，在离线设备上生成助记词。以后输入相同，就能重新得到它们。',
		primary: '获取 Keyper',
		secondary: '看看恢复过程'
	},
	shots: [
		{
			src: '/screens/zh-input.png',
			alt: 'Keyper 的邮箱和记忆文本输入界面，使用公开演示数据，评分与成本仅为模型估算'
		},
		{ src: '/screens/zh-result.png', alt: 'Keyper 生成的公开示例助记词，请勿用于存放资产' }
	],
	how: {
		title: '恢复时，不必翻找那张纸。',
		steps: [
			{
				title: '准备可信的离线设备',
				text: '打开飞行模式，在设置中关闭 Wi-Fi 和蓝牙。换一台 Android 手机或 iPhone，也可以重新生成。'
			},
			{
				title: '输入原来的邮箱和文本',
				text: '用 App 自带键盘输入。邮箱、文本的大小写和符号要记准。'
			},
			{
				title: '先核对，再导入钱包',
				text: '得到 12 或 24 个 BIP39 词。首次使用先做恢复演练，再通过二维码交给兼容的钱包。'
			}
		],
		flow: {
			email: '你的邮箱（示例）',
			sentence: '你的记忆文本（示例）',
			slow: '离线重新生成',
			words: '12 或 24 个 BIP39 词'
		}
	},
	security: {
		title: '一句话有多难猜，差别能有多大？',
		lead: '每猜一次都要完整跑一遍 Argon2id。下面是模型计算：假设攻击者有 1000 张数据中心级显卡，每张每秒猜 20 次、每次耗电 40 焦耳，电价每度 0.05 美元。平均搜索一半空间：',
		head: ['熵', '时间', '电费'],
		rows: [
			['30 位', '7.5 小时', '300 美元'],
			['40 位', '320 天', '30 万美元'],
			['50 位', '890 年', '3.1 亿美元'],
			['60 位', '91 万年', '3200 亿美元']
		],
		note: '表中的熵是假设值，不是对你那句话的测量。不含硬件成本，实际攻击成本可能不同；App 评分也不能告诉你，自己的输入属于哪一行。',
		model: { label: '查看假设与计算方法', path: 'SPEC.md#4-security-model' },
		items: [
			{
				title: '忘记输入，谁都帮不了你',
				text: 'Keyper 不存储邮箱和句子，也不提供找回服务。少一个标点，都可能生成另一组助记词。'
			},
			{
				title: '容易猜的句子，依然危险',
				text: '名言、歌词、个人公开信息都不是可靠的秘密。Argon2id 让每次猜测更昂贵，却不能把弱句子变成强秘密。'
			},
			{
				title: '离线不等于设备绝对安全',
				text: '断网降低信息传出的风险，但挡不住设备上已经存在的恶意软件。务必使用可信设备。'
			},
			{
				title: 'Keyper 不是资产保险',
				text: '它只负责生成助记词，不持有资产，也不能撤销泄露的助记词。转入资产前，应做独立恢复验证。'
			}
		]
	},
	pricing: {
		title: '省去编译，一次买断。',
		lead: '商店版省去构建和安装的准备，也支持项目维护。源码免费，自行编译的版本功能相同。',
		build: {
			name: '自行编译',
			price: '免费',
			per: '完整功能',
			points: ['Android 需要构建环境；iPhone 需要 Mac、Xcode 和签名配置。'],
			action: '查看编译说明',
			guide: 'README-zh.md#构建与维护'
		},
		store: {
			name: 'Google Play 与 App Store',
			price: site.price,
			per: '一次买断',
			status: '即将上架',
			googlePlay: 'Google Play',
			appStore: 'App Store'
		},
		note: '无需订阅。Android 与 iPhone 分别购买，实际价格以上架后的商店页面为准。'
	},
	faq: {
		title: '还有几个问题值得问。',
		items: [
			{
				q: '这不就是脑钱包吗？',
				a: '是。Keyper 使用邮箱作为盐，并通过高内存成本的 Argon2id 增加猜测代价，针对传统脑钱包的一些弱点做了改进。但它不能保证一句话不可猜测；强度评估也有局限。'
			},
			{
				q: 'Keyper 能直接保存或转移资产吗？',
				a: '不能。Keyper 只生成标准 BIP39 助记词，不是钱包。你需要使用兼容的钱包软件管理资产。'
			},
			{
				q: '多年后 App 不见了怎么办？',
				a: '协议公开，并提供独立 Python 恢复实现。你应当在真正依赖它之前，在离线电脑上亲自验证恢复流程，并妥善留存可靠的恢复方法。'
			},
			{
				q: '为什么需要邮箱？',
				a: '邮箱用于区分不同用户的推导输入，不是账户，也不需要登录。但邮箱文本必须准确，某些地址的点号等字符差异会改变结果。'
			}
		]
	},
	footer: {
		license: '以 MIT 许可证开源。',
		security: '报告安全问题',
		privacy: '隐私政策',
		terms: '服务条款'
	}
};
