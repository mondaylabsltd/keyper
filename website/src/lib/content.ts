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
	origin: {
		title: string;
		reasons: { title: string; text: string; link?: { label: string; url: string } }[];
		tension: {
			title: string;
			text: string;
			history: string;
			link: { label: string; url: string };
		};
		fit: { title: string; text: string };
	};
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
			'Create a BIP39 recovery phrase from your email address and a secret sentence, on an offline phone. The same email and sentence give you the same phrase. Open source, for Android and iPhone.'
	},
	nav: {
		how: 'How to use it',
		security: 'Security & risks',
		pricing: 'Get Keyper',
		source: 'View source ↗'
	},
	hero: {
		title: 'Recovery doesn’t have to depend on paper.',
		lead: 'Create a wallet recovery phrase from your email address and a secret sentence, on an offline phone. Use the same email and sentence later to get the same phrase again.',
		primary: 'Get Keyper',
		secondary: 'See how recovery works'
	},
	shots: [
		{
			src: '/screens/en-input.png',
			alt: 'Keyper email and secret sentence fields. Public example; strength and cost numbers are estimates.'
		},
		{
			src: '/screens/en-result.png',
			alt: 'A public example of a 12-word recovery phrase in Keyper. Do not use these words for funds.'
		}
	],
	origin: {
		title: 'Why build Keyper?',
		reasons: [
			{
				title: 'You still need to keep your backup safe.',
				text: 'A paper or steel backup can be lost or stolen. You may not know if someone has copied it, even if you still have the original.'
			},
			{
				title: 'Random number generation can go wrong.',
				text: 'A software bug caused Coldcard to create recovery phrases that were easier to guess. Keyper uses your email and secret sentence instead of new random numbers for each wallet. Another program can check that it gives you the same phrase. That does not prove your sentence is hard to guess.',
				link: {
					label: 'Read Coldcard’s official security notice',
					url: 'https://blog.coinkite.com/coldcard-mk3-seed-generation-warning/'
				}
			}
		],
		tension: {
			title: 'Someone may still guess the sentence you choose.',
			text: 'Keyper is still a brainwallet: it creates a recovery phrase from a secret you remember. Your email helps separate your result from other people’s. Argon2id makes each guess more costly to run. A long sentence or a high app score does not prove that your sentence is hard to guess.',
			history:
				'In one study, researchers found 884 brainwallets. Of these, 863 were emptied, some within minutes of receiving funds. This study does not show how often theft would happen with Keyper.',
			link: {
				label: 'Read the original study',
				url: 'https://discovery.ucl.ac.uk/id/eprint/10154816/'
			}
		},
		fit: {
			title: 'Is Keyper right for you?',
			text: 'You need a secret created using a reliable random process. You also need to remember it exactly for years. If you cannot do both, use a trusted wallet that creates a random recovery phrase, and keep a safe backup.'
		}
	},
	how: {
		title: 'Recover without finding that piece of paper.',
		steps: [
			{
				title: 'Take a trusted phone offline',
				text: 'Turn on airplane mode. Turn off Wi-Fi and Bluetooth in Settings. You can use another Android phone or iPhone to create the same recovery phrase.'
			},
			{
				title: 'Enter the same email and secret sentence',
				text: 'Use Keyper’s own keyboard. Type the email and sentence exactly as before, including capital letters and symbols.'
			},
			{
				title: 'Check recovery before using the phrase',
				text: 'Create a 12- or 24-word BIP39 recovery phrase. On first use, enter your email and secret sentence again from memory to check that you get the same phrase. Then scan its QR code with a wallet that supports BIP39.'
			}
		],
		flow: {
			email: 'Your email (example)',
			sentence: 'Your secret sentence (example)',
			slow: 'Create again offline',
			words: '12- or 24-word BIP39 recovery phrase'
		}
	},
	security: {
		title: 'How much does a harder-to-guess sentence change the cost?',
		lead: 'Each guess must run Argon2id. This example uses 1,000 data-center graphics cards. Each card tries 20 guesses per second and uses 40 joules per guess. Electricity costs US$0.05 per kWh. We assume the attacker tries half of all possible choices, on average:',
		head: ['Entropy (bits)', 'Time', 'Electricity cost'],
		rows: [
			['30 bits', '7.5 hours', 'US$300'],
			['40 bits', '320 days', 'US$305,000'],
			['50 bits', '890 years', 'US$313 million'],
			['60 bits', '910,000 years', 'US$320 billion']
		],
		note: 'Entropy is a measure of randomness. The values here are assumptions, not measurements of your sentence. Hardware costs are not included, and real attack costs may differ. The app’s score cannot tell you which row applies to your sentence.',
		model: { label: 'See how the numbers are calculated', path: 'SPEC.md#4-security-model' },
		items: [
			{
				title: 'We cannot recover a secret you forget',
				text: 'Keyper does not save your email or secret sentence, and we cannot recover them for you. Missing a punctuation mark may produce a different recovery phrase.'
			},
			{
				title: 'A sentence may be easy to guess',
				text: 'Quotes, song lyrics, and public facts about you are not reliable secrets. Argon2id makes each guess more costly. It does not make an easy-to-guess sentence safe.'
			},
			{
				title: 'An offline phone can still have malware',
				text: 'Going offline lowers the risk of sending your secret out. It does not stop malware already on the phone. Use a phone you trust.'
			},
			{
				title: 'Keyper only creates the recovery phrase',
				text: 'Keyper does not hold your funds or undo a leak. Before adding funds, use another recovery program to check that you get the same phrase.'
			}
		]
	},
	pricing: {
		title: 'Pay once to skip building it yourself.',
		lead: 'The store version saves you the work of building and installing the app. Your purchase also supports its maintenance. The source code is free. Build it yourself for the same features.',
		build: {
			name: 'Build from source',
			price: 'Free',
			per: 'All features',
			points: [
				'Android needs the tools to build the app. For iPhone, you need a Mac, Xcode, and a way to sign the app.'
			],
			action: 'Read the build instructions',
			guide: 'README.md#building-and-maintaining'
		},
		store: {
			name: 'Google Play & App Store',
			price: site.price,
			per: 'Pay once',
			status: 'Coming soon',
			googlePlay: 'Google Play',
			appStore: 'App Store'
		},
		note: 'No subscription. Buy Android and iPhone versions separately. Each store will show the price in your region.'
	},
	faq: {
		title: 'A few more questions worth asking.',
		items: [
			{
				q: 'Isn’t this a brainwallet?',
				a: 'Yes. Keyper uses your email as a salt, so the same sentence can give different people different recovery phrases. Argon2id uses a lot of memory to make each guess more costly. These steps address some problems with older brainwallets. They do not guarantee that your sentence is hard to guess. The strength score can also be wrong.'
			},
			{
				q: 'Can Keyper hold or send funds?',
				a: 'No. Keyper only creates a standard BIP39 recovery phrase. It is not a wallet. Use a wallet that supports the phrase to manage your funds.'
			},
			{
				q: 'What if the app is gone years from now?',
				a: 'The rules for creating the phrase are public. A separate Python program can recreate it on an offline computer. Try that process yourself before relying on Keyper, and keep a copy of the recovery tools and instructions.'
			},
			{
				q: 'Why do I need an email address?',
				a: 'It helps give different people different results. You do not create an account or log in. Use the same email address each time. Small differences, such as a dot in the address, can change the recovery phrase.'
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
	origin: {
		title: '为什么做 Keyper？',
		reasons: [
			{
				title: '备份助记词，还得考虑怎么保存。',
				text: '纸条和钢板都有丢失、被盗的可能。即使原件还在，也不容易确认是否被人复制过。'
			},
			{
				title: '设备的随机数生成也可能出错。',
				text: 'Coldcard 曾因固件缺陷生成强度不足的种子。Keyper 根据用户输入推导助记词，不依赖设备为每个钱包生成新的随机数。你可以用独立实现核对结果，但这不能证明输入足够难猜。',
				link: {
					label: 'Coldcard 官方事故公告',
					url: 'https://blog.coinkite.com/coldcard-mk3-seed-generation-warning/'
				}
			}
		],
		tension: {
			title: '自选句子仍有被猜中的风险。',
			text: 'Keyper 仍属于脑钱包。邮箱盐和 Argon2id 增加了猜测成本，但自选句子的实际强度无法靠长度或评分确定。',
			history:
				'研究人员曾识别出 884 个脑钱包，其中 863 个被清空，有些在入金后几分钟就被转走。这些历史样本不能用来估计 Keyper 的被盗率。',
			link: {
				label: '阅读原始研究',
				url: 'https://discovery.ucl.ac.uk/id/eprint/10154816/'
			}
		},
		fit: {
			title: '为什么不适合你？',
			text: '如果你无法生成足够随机的输入，或无法长期准确地记住它，Keyper 就不适合你。建议使用传统钱包，由可靠随机源生成助记词，并妥善保管备份。'
		}
	},
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
