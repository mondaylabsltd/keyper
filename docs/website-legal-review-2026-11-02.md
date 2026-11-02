# 官网英文与法律页面检查（2026-11-02）

## 本次范围与结论

- 落地页英文改用常见动词、短句，统一 `secret sentence`（用户输入）与 `recovery phrase`（生成的助记词）。不改中文落地页、布局或算法。
- 隐私政策和服务条款同步更新中英文，加入用户确认的公司名称、注册号、注册地、注册地址及联系邮箱。
- App 是离线单机工具；官网、应用商店和客服邮件另有数据处理，不能混为一谈。
- 条款明确无托管、无找回、无保险，以及输入、备份、设备和验证的用户责任；保留依法不能排除的责任，避免笼统的“任何损失均不负责”。
- **本次是源码事实检查与法律文案草案，不是英、美、德或其他法域的全面合规认证。官网统计仍有下列待处理事项，不能仅靠修改政策认定已合规。未部署页面。**

## 确认的事实

公司信息由用户提供：MONDAY LABS LTD，注册于英格兰及威尔士，注册号 16988118，注册地址 61 Bridge Street, Kington, HR5 3DJ, United Kingdom；联系邮箱 hello@mondaylabs.ltd。

App 不上传用户输入。代码显示，离开 App 或离线检查不通过时清除记忆文本和结果，但邮箱可继续保留在进程内存中。原政策“离开时也擦除邮箱”的说法不准确；字符串副本完全擦除也没有平台保证，已修正。

官网 `src/app.html` 当前直接加载 `https://tj.appsdata.org/api/script.js`。本次只下载和阅读脚本，没有执行其中代码，也没有向统计服务发送测试访问事件。

本次读取的公开跟踪配置 `/api/site/tracking-config/c503a6f27899`：

- 页面访问、网址查询参数、外部链接统计开启。
- 会话录制、表单交互、复制跟踪、按钮跟踪、错误跟踪、性能统计和功能标志关闭。
- 脚本会读写浏览器 localStorage 中的访客 ID。没有 Cookie 不等于没有设备存储，也不代表当然免于同意要求。
- 这些是读取时的配置；远端脚本和配置可变，不能当作永久保证。

## 仍需处理的官网统计事项

1. **同意或适用豁免。** 当前统计脚本直接加载，没有先行选择界面。德国对非必要设备存储/访问的要求，以及英国统计用途例外的具体条件，需要分别落实。英国例外也有告知和免费便捷反对机制等要求，不能直接等同于“无需任何控制”。政策说明不替代实际控制。本次保留统计配置，不擅自停用服务或宣称已有同意。
2. **接收方与保留期限。** 用户未确认 tj.appsdata.org 的运营主体、处理国家和实际保留期限。没有编造这些信息；目前政策只说明已知服务和用途，并提供联系渠道。应补充实际接收方、期限或足够明确的确定标准。
3. **跨境传输与处理协议。** 按实际服务商、所在地、处理角色核对 DPA、充分性决定、SCC 或 UK 适用保障措施。没有确认任何协议已经签署，也未宣称数据仅保存在英国或 EEA。
4. **权利请求操作。** 落实网站、订单和邮件数据的查询、删除、反对和投诉处理。离线 App 的秘密不在公司手中，不能提供云端找回或删除。
5. **其他适用事项。** 是否需要 EEA 代表、德国额外服务商信息、特定美国州隐私披露，以及商店购买流程的撤回权确认，需结合实际投放、数据规模和供应链判断。

以上不改变 App 本身不联网、不收集输入的事实。

## 责任限制的处理

- 不把用户遗忘、弱输入或第三方设备风险自动等同于开发者赔偿义务；也不以这些风险免除开发者自身依法应承担的责任。
- 公共条款将不可排除责任浓缩为一句法定保留，不逐项列举；这并不意味着欺诈、故意、重大过失、过失造成的人身伤害、法定产品责任或强制消费者权利因此可以排除。
- 明确不保证没有漏洞或永久抗破解，列明未来计算技术（包括量子计算）的风险；没有把所有漏洞或攻击直接认定为“不可抗力”。只有合理无法预防或控制的事件才落入对应描述，实际免责仍取决于适用法律。
- 根据用户要求压缩为按原因划分的责任说明，不另设德国普通过失责任上限；保留自身违反义务时依法应承担的责任，避免用简单的“原样提供”覆盖强制法律要求。具体效果仍需德国法律专业审核。
- 保留英国数字内容质量、描述、救济等不可排除权利，以及其他地区的强制权利。
- 没有设置一律以购买价为上限的赔偿限制、强制仲裁、放弃集体诉讼或仅限英国法院等条款。
- 英格兰及威尔士法律选择保留消费者通常居住地的强制保护及依法可使用的法院。
- 退款按商店规则及适用法律处理；条款本身不视为放弃撤回权。即时数字下载的同意及知悉确认仍需在真实商店流程中核对，不在公开条款中逐项列举维权路径。

## 官方依据

- [英国 Consumer Rights Act 2015，第 47 条：数字内容不可排除的责任](https://www.legislation.gov.uk/ukpga/2015/15/part/1/chapter/3/crossheading/can-a-trader-contract-out-of-statutory-rights-and-remedies-under-a-digital-content-contract)
- [英国 Consumer Rights Act 2015，第 65 条：过失导致死亡或人身伤害](https://www.legislation.gov.uk/ukpga/2015/15/section/65)
- [德国 BGB § 307：格式条款公平性与透明度](https://www.gesetze-im-internet.de/bgb/__307.html)
- [德国 BGB § 309，特别是第 7 项：重大过失、人身伤害等责任](https://www.gesetze-im-internet.de/bgb/__309.html)
- [德国 BGB § 327s：数字产品消费者协议限制](https://www.gesetze-im-internet.de/bgb/__327s.html)
- [英国公司网站披露规定，2015 Regulations，第 25 条](https://www.legislation.gov.uk/uksi/2015/17/regulation/25/made)
- [英国数字内容撤回权，Consumer Contracts Regulations 2013，第 37 条](https://www.legislation.gov.uk/uksi/2013/3134/regulation/37?timeline=false)
- [欧盟数字内容指令 2019/770](https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX%3A32019L0770)
- [爱尔兰 DPC：GDPR 第 13、14 条的身份、保留期限和跨境告知](https://www.dataprotection.ie/en/individuals/know-your-rights/right-be-informed-transparency-article-13-14-gdpr)
- [ICO 2026 指引：统计用途例外及反对机制](https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guidance-on-the-use-of-storage-and-access-technologies/what-are-the-exceptions/)
- [德国监管机构关于 TDDDG 与设备存储/访问的说明](https://www.lfd.niedersachsen.de/startseite/infothek/faqs_zur_ds_gvo/faq-telekommunikation-digitale-dienste-datenschutzgesetz-tdddg-206449.html)
- [FTC：免责声明与州法差异；“as is”不是一切责任的免除](https://www.ftc.gov/business-guidance/resources/businesspersons-guide-federal-warranty-law)

## 对 Safe / Bybit 类比的核对

[Safe 当前条款](https://safe.global/terms)第 18 节也区分免费/付费服务，保留故意、重大过失、欺诈隐瞒及强制责任等例外，第 19–20 节另行说明漏洞与外部事件。该页面标示 2025 年 10 月生效，晚于 Bybit 事件；不能把当前条款当作事故发生时的合同，也不能据事故报道推定 Safe 已获法院认定完全免责。本次没有查得足以作出该法律结论的判决依据。
