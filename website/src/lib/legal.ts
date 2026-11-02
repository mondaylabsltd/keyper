/** The privacy policy and the terms of service, in English and Chinese. */

export type LegalRoute = '/privacy' | '/terms' | '/zh/privacy' | '/zh/terms';
export type LegalKind = 'privacy' | 'terms';

export interface LegalDoc {
	title: string;
	description: string;
	sections: { heading: string; paragraphs: string[] }[];
	contact: string;
}

export interface Legal {
	lang: 'en' | 'zh';
	home: '/' | '/zh';
	paths: Record<LegalKind, LegalRoute>;
	other: { label: string; hreflang: string; paths: Record<LegalKind, LegalRoute> };
	intro: string;
	updatedLabel: string;
	updated: string;
	privacy: LegalDoc;
	terms: LegalDoc;
}

const enPaths = { privacy: '/privacy', terms: '/terms' } as const;
const zhPaths = { privacy: '/zh/privacy', terms: '/zh/terms' } as const;

export const legalEn: Legal = {
	lang: 'en',
	home: '/',
	paths: enPaths,
	other: { label: '中文', hreflang: 'zh-Hans', paths: zhPaths },
	intro: 'Keyper is developed by MONDAY LABS LTD, registered in England and Wales, company number 16988118. Registered office: 61 Bridge Street, Kington, HR5 3DJ, United Kingdom.',
	updatedLabel: 'Last updated',
	updated: '2 November 2026',
	privacy: {
		title: 'Privacy Policy',
		description:
			'What the offline app does with your secrets, and what this website, app stores, and email services process.',
		sections: [
			{
				heading: 'Your secrets stay in the offline app',
				paragraphs: [
					'Keyper does not connect to the internet. It has no accounts, ads, analytics, or built-in crash reporting. We do not receive your email address, secret sentence, or recovery phrase.',
					'These are used in local memory, not saved to permanent storage. Leaving the app or failing an offline check clears the secret sentence and recovery result. The email may stay in memory until cleared or the app process ends. Clearing the app does not guarantee erasing every system memory copy. Your language setting is kept by your phone.'
				]
			},
			{
				heading: 'Copies you make',
				paragraphs: [
					'If you copy a recovery phrase or give it to a wallet, your operating system or another app handles that copy. Clipboard history may keep it. Keyper cannot control or erase those copies.'
				]
			},
			{
				heading: 'The website and app stores are separate',
				paragraphs: [
					'Cloudflare hosts this website and processes IP addresses and request details. Rybbit at tj.appsdata.org counts visits. It records pages and URL parameters, referring pages, external links, browser and device details, language, screen size, and an approximate location based on the IP address. It stores a random visitor ID in browser local storage, not a cookie. Any consent required by law must be obtained separately; reading this policy is not consent.',
					'Google or Apple handles purchases under its own privacy policy. We may receive order reports and, if you enable system diagnostics sharing, technical crash reports. This does not give us the secrets entered in the app.'
				]
			},
			{
				heading: 'How other personal data is used and kept',
				paragraphs: [
					'Website data is used to run and protect the site and understand visits. Email is used to answer your requests. Do not send wallet secrets. Where EU or UK law applies, the legal basis is our legitimate interests, steps needed for a contract, a legal duty, or consent where required, depending on the purpose.',
					'Hosting, analytics, store, and email providers process this data. Retention depends on the service settings, the request, and legal record-keeping duties. Providers may process data outside your country; any transfer covered by EU or UK law needs a valid transfer basis and safeguards where required. Contact us for the recipients, retention details, and transfer safeguards that apply to your data.'
				]
			},
			{
				heading: 'Privacy questions',
				paragraphs: [
					'Where the law applies, you may request access, correction, deletion, a copy of your data, or limits on its use. You may object to processing based on legitimate interests or withdraw consent. Contact us below. You may also complain to the UK Information Commissioner’s Office or your local data protection authority. We cannot retrieve secrets from the offline app because we never receive them.',
					'Changes to this policy will be posted here with a new date. We will give any extra notice or ask for consent where the law requires it.'
				]
			}
		],
		contact: 'Privacy contact:'
	},
	terms: {
		title: 'Terms of Service',
		description:
			'Keyper is an open-source offline tool, provided as is. Understand the risks, check recovery, and protect your secrets before use.',
		sections: [
			{
				heading: 'What Keyper provides',
				paragraphs: [
					'Keyper is an open-source offline tool that creates BIP39 recovery phrases. The source code uses the MIT License. Keyper is not a wallet: it does not hold or transfer funds, and provides no investment advice, custody, or insurance.'
				]
			},
			{
				heading: 'Your responsibility before use',
				paragraphs: [
					'Do your own research (DYOR). Understand the method and risks, check the software source and device, and test recovery with a separate program before adding funds. You are responsible for choosing, remembering, and protecting your email, secret sentence, and recovery phrase, and keeping the correct recovery tools offline. We cannot recover forgotten secrets or undo their exposure.'
				]
			},
			{
				heading: 'As-is software and limits on responsibility',
				paragraphs: [
					'Keyper is an open-source offline tool provided “as is”. We do not guarantee that it is free of errors or vulnerabilities, or that today’s cryptographic methods will remain secure as technology advances, including quantum computing. Strength scores and attack costs are estimates, not guarantees.',
					'To the extent the law allows, we are not responsible for financial or other losses caused by your input, exposed secrets, third-party devices or software, or vulnerabilities, attacks, and changes in technology that we could not reasonably prevent or control.',
					'These terms do not exclude or limit any responsibility that applicable law expressly prohibits us from excluding or limiting.'
				]
			},
			{
				heading: 'Purchases',
				paragraphs: [
					'The store version is a one-time purchase. Android and iPhone versions are bought separately. Google Play or the App Store handles payments and refunds under its terms and applicable law. Apple’s standard Licensed Application End User License Agreement applies where relevant. These terms do not themselves waive any statutory cancellation right.'
				]
			},
			{
				heading: 'Applicable law and changes',
				paragraphs: [
					'The laws of England and Wales apply, subject to mandatory protections under applicable law, including those of your country of residence. We will post changes here and update the date. Changes do not retroactively remove rights from an earlier purchase.'
				]
			}
		],
		contact: 'Support and legal contact:'
	}
};

export const legalZh: Legal = {
	lang: 'zh',
	home: '/zh',
	paths: zhPaths,
	other: { label: 'English', hreflang: 'en', paths: enPaths },
	intro: 'Keyper 由 MONDAY LABS LTD 开发。公司注册于英格兰及威尔士，注册号 16988118。注册地址：61 Bridge Street, Kington, HR5 3DJ, United Kingdom。',
	updatedLabel: '最后更新',
	updated: '2026 年 11 月 2 日',
	privacy: {
		title: '隐私政策',
		description: '离线 App 如何处理秘密，以及官网、应用商店和邮件服务处理哪些数据。',
		sections: [
			{
				heading: '秘密只在离线 App 中处理',
				paragraphs: [
					'Keyper 不联网，没有账户、广告、统计或内置崩溃上报。我们不会收到你的邮箱、记忆文本或助记词。',
					'这些内容只在本机内存中使用，不写入持久存储。离开 App 或离线检查不通过时，记忆文本和结果会被清除；邮箱可能保留到主动清除或进程结束。清除不保证擦除所有系统内存副本。语言设置由手机保存。'
				]
			},
			{
				heading: '你复制或交给其他应用的内容',
				paragraphs: [
					'复制助记词或交给钱包后，操作系统和接收应用会处理这份副本，剪贴板历史也可能保留它。Keyper 无法控制或删除这些副本。'
				]
			},
			{
				heading: '官网和应用商店另行处理数据',
				paragraphs: [
					'官网由 Cloudflare 托管，会处理 IP 和请求信息。tj.appsdata.org 上的 Rybbit 用于访问统计，记录页面及网址参数、来源、外部链接、浏览器及设备、语言、屏幕尺寸和 IP 推断的大致地区，并在浏览器本地存储中保存随机访客 ID，不设置 Cookie。法律要求的同意需另行取得，阅读本政策不等于同意。',
					'Google 或 Apple 按各自隐私政策处理购买。我们可能收到订单报告，以及你允许系统共享的技术崩溃报告。这不会让我们获得 App 中的秘密。'
				]
			},
			{
				heading: '其他个人数据的用途和保存',
				paragraphs: [
					'官网数据用于提供和保护网站、了解访问情况；邮件用于处理你的请求，请勿发送钱包秘密。适用欧盟或英国法律时，根据具体目的，以合法利益、合同需要、法定义务或法律要求的同意作为处理依据。',
					'托管、统计、商店和邮件服务商会处理相关数据。保存期限取决于服务设置、请求需要及法定记录义务。服务商可能在其他国家处理数据；受欧盟或英国法律约束的传输须有有效依据，并在法律要求时提供保障措施。可联系我们了解适用的接收方、保存期限及跨境保障。'
				]
			},
			{
				heading: '隐私问题',
				paragraphs: [
					'在法律适用时，你可请求访问、更正、删除或取得数据副本，限制使用，反对基于合法利益的处理，或撤回同意。请通过下方邮箱联系；也可向英国 ICO 或当地数据保护机构投诉。App 的秘密从未发送给我们，因此我们无法找回。',
					'政策变更会发布在这里并更新日期；法律要求时另行通知或征求同意。'
				]
			}
		],
		contact: '隐私联系邮箱：'
	},
	terms: {
		title: '服务条款',
		description:
			'Keyper 是按原样提供的开源离线工具。使用前请自行研究风险、验证恢复并保管秘密。',
		sections: [
			{
				heading: '我们提供什么',
				paragraphs: [
					'Keyper 是开源的离线 BIP39 助记词生成工具，源码采用 MIT 许可证。它不是钱包，不持有或转移资产，也不提供投资建议、资产托管或保险。'
				]
			},
			{
				heading: '使用前你需要负责的事',
				paragraphs: [
					'请自行研究（DYOR）原理和风险，核查软件来源及设备，并在转入资产前用独立程序验证恢复。你负责选择、记住和保管邮箱、记忆文本及助记词，并离线保存正确的恢复工具。我们无法找回遗忘的秘密，也无法撤销秘密泄露。'
				]
			},
			{
				heading: '按原样提供与责任限制',
				paragraphs: [
					'Keyper 是按“原样”提供的开源离线工具。我们不保证它没有错误或漏洞，也不保证现有密码学方法能始终抵御未来技术，包括量子计算。强度评分和攻击成本均为估算，不是保证。',
					'在法律允许的范围内，对于因用户输入、秘密泄露、第三方设备或软件，以及我们无法合理预防或控制的漏洞、攻击或技术变化造成的资金或其他损失，我们不承担赔偿责任。',
					'本条款不排除或限制适用法律明确禁止排除或限制的责任。'
				]
			},
			{
				heading: '购买',
				paragraphs: [
					'商店版一次买断，Android 与 iPhone 分别购买。付款及退款由 Google Play 或 App Store 按其条款和适用法律处理；适用时采用 Apple 标准的许可应用最终用户许可协议。本条款本身不构成对法定撤回权的放弃。'
				]
			},
			{
				heading: '适用法律与变更',
				paragraphs: [
					'本条款适用英格兰及威尔士法律，并受适用的强制性法律保护约束，包括你居住国依法适用的保护。变更会发布在这里并更新日期，不追溯剥夺此前购买产生的权利。'
				]
			}
		],
		contact: '支持与法律联系邮箱：'
	}
};
