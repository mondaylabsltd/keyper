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
	intro: 'Keyper is made by MONDAY LABS LTD (“we”).',
	updatedLabel: 'Last updated',
	updated: '27 October 2026',
	privacy: {
		title: 'Privacy Policy',
		description:
			'What Keyper and getkeyper.app collect: the app collects nothing; the website counts visits.',
		sections: [
			{
				heading: 'The app',
				paragraphs: [
					'Keyper collects no personal data. It has no account, asks for no permission, contains no analytics, advertising or crash-reporting code, and never connects to the network.',
					'Your email, your sentence and the phrase exist only in the app’s memory while you use it. They are never written to storage, and they are wiped when you leave the app or the phone goes online.',
					'The only thing kept between sessions is your choice of language, which the phone’s own per-app language setting remembers.'
				]
			},
			{
				heading: 'Buying from Google Play or the App Store',
				paragraphs: [
					'Google and Apple handle the purchase under their own privacy policies. They send us sales reports, which may include your country or region and the order details, but never anything you type in Keyper.',
					'If you let your phone share diagnostics with app developers, Google or Apple may send us crash reports. These contain technical details such as the device model, the system version and where the app crashed, not what you typed.'
				]
			},
			{
				heading: 'This website',
				paragraphs: [
					'getkeyper.app is a set of static pages hosted by Cloudflare. To deliver them and protect them from abuse, Cloudflare processes your IP address and the details of each request.',
					'We count visits with Rybbit, an open-source analytics tool, hosted at tj.appsdata.org. It records the pages you view, the page that linked you here, your browser, language, screen size and approximate location (from your IP address), and keeps a random visitor ID in your browser’s local storage. It sets no cookies.'
				]
			},
			{
				heading: 'Email',
				paragraphs: [
					'If you write to us, we use your address and your message only to reply, and keep them only as long as the conversation needs.'
				]
			},
			{
				heading: 'Changes',
				paragraphs: [
					'If this policy changes, the new version will be posted here with a new date.'
				]
			}
		],
		contact: 'Questions about this policy:'
	},
	terms: {
		title: 'Terms of Service',
		description:
			'The terms for using Keyper and for buying it from Google Play or the App Store.',
		sections: [
			{
				heading: 'What Keyper is',
				paragraphs: [
					'Keyper turns your email and a sentence you remember into a standard BIP39 recovery phrase. It is not a wallet: it never holds, sends or receives funds, and we never see your inputs or your phrase.'
				]
			},
			{
				heading: 'What depends on you',
				paragraphs: [
					'The phrase can be generated again only from the same email and the same sentence, typed exactly as before. Nobody, including us, can recover them for you. Do the recovery drill before you use the phrase.',
					'If others can guess your sentence, they can generate your phrase. Use a clean, offline phone, and install Keyper only from its official store listings or build it from the source.'
				]
			},
			{
				heading: 'Licence and purchase',
				paragraphs: [
					'The source code is open under the MIT License. The store version is built from the same code. Buying it is a one-time purchase handled by Google Play or the App Store under their terms, including their refund policies. On the App Store, Apple’s standard Licensed Application End User License Agreement applies.'
				]
			},
			{
				heading: 'No warranty',
				paragraphs: [
					'Keyper is provided “as is”, without warranty of any kind. To the extent the law allows, we are not liable for any loss, including lost funds, that results from using Keyper, from forgetting or mistyping your inputs, or from a compromised phone.',
					'Nothing in these terms limits rights that the law gives you and that cannot be waived.'
				]
			},
			{
				heading: 'If the app goes away',
				paragraphs: [
					'Protocol v1 is frozen, so every version of Keyper gives the same phrases. If the app ever leaves the stores, the open-source recovery script described in the README still derives them on a computer.'
				]
			},
			{
				heading: 'Changes',
				paragraphs: [
					'If these terms change, the new version will be posted here with a new date.'
				]
			}
		],
		contact: 'Questions about these terms:'
	}
};

export const legalZh: Legal = {
	lang: 'zh',
	home: '/zh',
	paths: zhPaths,
	other: { label: 'English', hreflang: 'en', paths: enPaths },
	intro: 'Keyper 由 MONDAY LABS LTD（下称“我们”）开发。',
	updatedLabel: '最后更新',
	updated: '2026 年 10 月 27 日',
	privacy: {
		title: '隐私政策',
		description: 'Keyper 和 getkeyper.app 收集什么：App 什么都不收集，网站统计访问量。',
		sections: [
			{
				heading: 'App',
				paragraphs: [
					'Keyper 不收集任何个人数据。它没有账户，不申请任何权限，不含统计、广告或崩溃上报代码，也从不联网。',
					'你的邮箱、那句话和助记词只在你使用时存在于 App 的内存里，从不写入存储；离开 App 或手机联网时立即清除。',
					'两次使用之间唯一保留的是你选的语言，由手机系统的“应用语言”设置记住。'
				]
			},
			{
				heading: '从 Google Play 或 App Store 购买',
				paragraphs: [
					'购买由 Google 和 Apple 按各自的隐私政策处理。它们会给我们销售报告，其中可能有你所在的国家或地区和订单信息，但绝不会有你在 Keyper 里输入的内容。',
					'如果你允许手机与应用开发者共享诊断信息，Google 或 Apple 可能把崩溃报告发给我们。报告里是设备型号、系统版本、崩溃位置这类技术信息，没有你输入的内容。'
				]
			},
			{
				heading: '本网站',
				paragraphs: [
					'getkeyper.app 是托管在 Cloudflare 上的静态网页。为了传送网页、防范滥用，Cloudflare 会处理你的 IP 地址和每次请求的信息。',
					'我们用开源统计工具 Rybbit 统计访问量，服务托管在 tj.appsdata.org。它记录你浏览的页面、从哪个页面来、浏览器、语言、屏幕尺寸和大致位置（根据 IP 地址推断），并在浏览器的本地存储里保存一个随机的访客 ID。它不使用 Cookie。'
				]
			},
			{
				heading: '邮件',
				paragraphs: [
					'你给我们发邮件时，我们只用你的地址和邮件内容来回复，只保留到沟通结束所需为止。'
				]
			},
			{
				heading: '变更',
				paragraphs: ['本政策如有变更，新版本会发布在这里，并更新日期。']
			}
		],
		contact: '对本政策有疑问：'
	},
	terms: {
		title: '服务条款',
		description: '使用 Keyper、以及从 Google Play 或 App Store 购买 Keyper 的条款。',
		sections: [
			{
				heading: 'Keyper 是什么',
				paragraphs: [
					'Keyper 用你的邮箱和一句你记得的话，生成标准 BIP39 助记词。它不是钱包：从不持有、发送或接收资产，我们也看不到你的输入和助记词。'
				]
			},
			{
				heading: '取决于你的部分',
				paragraphs: [
					'只有输入同样的邮箱和同样的那句话，一字不差，才能再次生成助记词。任何人，包括我们，都没法替你找回。使用助记词之前，先做恢复演练。',
					'别人猜得到你的那句话，就能算出你的助记词。请在干净的离线手机上使用，并且只从官方商店页面安装 Keyper，或者自己从源码编译。'
				]
			},
			{
				heading: '许可与购买',
				paragraphs: [
					'源代码以 MIT 许可证开源。商店版由同一份代码构建。购买是一次性的，由 Google Play 或 App Store 按其条款处理，退款也按它们的政策办理。在 App Store 上，适用 Apple 标准的“许可应用最终用户许可协议”。'
				]
			},
			{
				heading: '免责声明',
				paragraphs: [
					'Keyper 按“原样”提供，不附带任何形式的担保。在法律允许的范围内，因使用 Keyper、忘记或输错输入内容、或手机被入侵造成的任何损失（包括资产损失），我们不承担责任。',
					'本条款不影响法律赋予你、且不能被排除的权利。'
				]
			},
			{
				heading: '如果 App 下架',
				paragraphs: [
					'v1 协议已冻结，Keyper 的每个版本都生成同样的助记词。即使 App 将来从商店下架，README 里介绍的开源恢复脚本仍能在电脑上算出它们。'
				]
			},
			{
				heading: '变更',
				paragraphs: ['本条款如有变更，新版本会发布在这里，并更新日期。']
			}
		],
		contact: '对本条款有疑问：'
	}
};
