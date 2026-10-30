# Keyper

**记在脑子里的助记词。** 在一台离线的 Android 手机或 iPhone 上，用**邮箱 + 一句只有你记得的话**生成标准 BIP39 助记词。
同样的输入总是得到同样的助记词，所以不用抄写；App 也不保存你输入的任何内容。

即将上架 Google Play 和 App Store，售价 29.99 美元，一次买断。用本仓库自己编译免费，得到的是同一个 App。

[getkeyper.app](https://getkeyper.app/zh) · [English](README.md) · 简体中文

<p align="center">
  <img src="docs/images/zh-input.png" width="260" alt="用 Keyper 自带键盘输入记忆文本">
  <img src="docs/images/zh-result.png" width="260" alt="12 个词的助记词">
  <img src="docs/images/zh-offline.png" width="260" alt="断网门禁">
</p>
<p align="center"><sub>以上为 Android 版；iPhone 版界面相同，同样的输入得到同样的助记词（截图见 <a href="README.md">English README</a>）。</sub></p>

- **标准输出**：12 或 24 个词的 BIP39 助记词，任何钱包都能用。
- **难以暴力破解**：每猜一次都要跑一遍 Argon2id（1 GiB 内存 × 128 遍），骁龙 870 上约 1 分钟。
  记忆文本的熵超过约 48.4 位，攻击者光电费就超过 1 亿美元。
- **自带专用键盘**：邮箱和记忆文本都只能用 Keyper 自己的键盘输入，系统输入法完全接触不到，无从学习、同步或上传。
- **断网门禁**：飞行模式打开、Wi-Fi 和蓝牙都关闭时才能输入和生成（iOS 只允许 App 检查网络，蓝牙只能提醒）；一旦联网，记忆文本和助记词立即清除。
- **零权限**：两个平台都不申请任何权限、不联网，除了系统自带的库（Android 上另有 Kotlin 标准库）不打包任何库；Android 版 APK 约 95 KB，iOS 版不到 1 MB。
- **恢复演练**：生成后凭记忆再输一遍，当场核对两次结果是否一致。
- **协议公开**：[SPEC.md](SPEC.md) 精确定义了算法（v1 已冻结），独立的 [Python 实现](reference/keyper.py)可以复现。

需要 Android 8.1（API 27）或 iOS 17 及以上，4 GB 以上内存。中英双语。

## 原理

```
邮箱 ──── 须是有效地址，A–Z 转小写 ─────────────────────────────┐ (盐)
记忆文本 ─ 合并多余空格 ─ HMAC-SHA256(域常量) ─ Argon2id(1 GiB × 128 遍) ─ K ─┬─ HMAC ─ 12 个词
                                                                              └─ HMAC ─ 24 个词
```

- **记忆文本只认 80 个字符**：26 个英文字母（大小写）、10 个数字、18 个符号 `! @ # $ % ^ & * ( ) . , ? - _ + = /`。
  **大小写、符号和词之间的空格都算数**，多打的空格（连续空格、首尾空格）不算。没有引号、`|`、`\`、`:`、`;` 这类容易看错的符号。
  中文用拼音写，比如 `Wo de di yi zhi mao jiao MiMi!`。
- **邮箱须是有效地址，除大小写外每个字符都算数**：`Alice@Example.com` 和 `alice@example.com` 是同一个，`a.b@gmail.com` 和 `ab@gmail.com` 不是。不接受手机号。完整规则见 [SPEC.md §2](SPEC.md#2-algorithm)。
- **12 词和 24 词互相独立**，知道一个推不出另一个。
- **域常量**：写在 [`Domain.kt`](app-android/app/src/main/kotlin/app/getkeyper/Domain.kt) 和 [`Domain.swift`](app-ios/Keyper/Domain.swift) 里的 32 字节随机数，
  让同一句话在不同部署里得到不同结果。它随 App 公开。

用邮箱作盐是这类工具的标准做法（WarpWallet 也这样做）：同一句话在不同人那里得到无关的助记词，攻击者只能一个人一个人地猜，
没法用一张预先算好的表对付所有人。同一个邮箱可以配多句不同的话，各得一组助记词。

### 自带键盘

```
字母层                          数字符号层
q w e r t y u i o p            1 2 3 4 5 6 7 8 9 0
 a s d f g h j k l             ! @ # $ % ^ & * ( )
⇧ z x c v b n m ⌫              . , ? - _ + = /  ⌫
123 [   空格   ] 完成           ABC [   空格   ] 完成
```

- 每台手机上一模一样：固定 QWERTY、固定尺寸（不随系统字体缩放）、等宽字体（`0`/`O`、`1`/`l`/`I` 一眼可辨）。
  输入邮箱时底行多出 `@` 和 `.`，“完成”变成“下一项”。
- 手感像 iPhone 键盘：键盘上每一点都归最近的键，点在缝隙里也不会落空；按下时手指上方弹出放大的字符，
  抬起才输入，按偏了可以滑到正确的键再松手；另一根手指按下时前一个键立即输入，双拇指快打不乱序。⇧、⌫ 和 123 按下即生效。
- ⇧ 点一次只管下一个字母，连点两次锁定大写；按住 ⌫ 连删；按返回键收起键盘；在键盘上从屏幕边缘滑动不会触发返回。
- 光标是系统原生的：点按定位，拖动光标（或手柄）移动，带放大镜。
- 两个输入框都不给系统输入法任何连接，粘贴、长按菜单、拖放、实体键盘和注入的按键都进不来。

## 安全模型

代码和域常量都是公开的，要当作每个攻击者都有。

| 别人拿到了… | 还剩什么在保护你 |
|---|---|
| 你的邮箱 | 记忆文本有多难猜：每猜一次都要 1 GiB × 128 遍 |
| 你的记忆文本 | 只剩邮箱，而邮箱通常不是秘密 |
| 邮箱和记忆文本 | 没有了，这两样加起来就是助记词 |

1. **难猜不等于字多。** 名句、歌词、俗语、“我的猫叫某某”这类模板，攻击者最先试，几块钱电费就能命中。
   要用只有你知道的具体细节：人名、年份、地点、数字，再加一两个符号。

   | 记忆文本的熵 | 一千张顶级显卡 | 光电费 |
   |---:|---:|---:|
   | 30 位 | 7.5 小时 | 300 美元 |
   | 40 位 | 320 天 | 30 万美元 |
   | 50 位 | 890 年 | 3.1 亿美元 |
   | 60 位 | 91 万年 | 3200 亿美元 |

   你输入时，App 会按这个模型估算（偏向攻击者，见 [SPEC.md §4](SPEC.md#4-security-model)），低于 1 亿美元会弹窗提醒，但认不出名句，所以别用名句。
2. **使用助记词之前，先做恢复演练。** 生成后点“首次使用？做一次恢复演练”，凭记忆再输一遍，一致才算数。
3. **域常量丢了或被改了，所有人的助记词都无法再生成。** 见[构建与维护](#构建与维护)。

App 内的其他保护：离开 App 立即清空记忆文本和助记词；不允许自动填充服务读取。导出助记词以二维码为主，每次启动后第一次复制前会提醒一次。

- **Android**：禁止截屏和录屏（二维码页面也是），最近任务里是空白；记忆文本、助记词区域和键盘对无障碍服务隐藏（Android 14+）；复制的助记词标记为敏感。
- **iOS**：系统没有 FLAG_SECURE，所以把整个界面画进安全输入框的容器层（没有公开 API），截屏、录屏和投屏都不会包含这一层；
  离开 App 时有遮罩，多任务界面里看不到内容；复制的助记词只留在本机（不进通用剪贴板），App 被关掉也会按时过期。

App 在前台时，**断网门禁**每 0.5 秒检查一次，不需要任何权限：

- **Android** 读取飞行模式、Wi-Fi 设置和蓝牙适配器的实时状态；未满足的每一项都能点，直接跳到对应的系统设置页。
  **小米 / 红米（HyperOS）**：控制中心的蓝牙按钮只断开新连接，蓝牙其实还开着，要在“设置 → 蓝牙”里关掉最上面的开关。
- **iOS** 不让 App 读取飞行模式和 Wi-Fi 开关：门禁要求没有任何网络接口拥有超出本地链路的地址（用 `getifaddrs` 读取），且蜂窝射频已关。
  它刻意不用 Network 框架：在国行 iPhone 上，那会让系统弹出“是否允许使用无线数据”，而用户点“不允许”又会被误判为已断网。
  它看不到“Wi-Fi 开着但没连任何网络”的情况；读取蓝牙需要申请权限，所以只提醒你关掉。iOS 不允许 App 打开这些设置页，所以各项是文字说明。

### 剪贴板

复制的助记词应在 60 秒后离开剪贴板。Keyper 只清除它自己复制的内容：之后从其他 App 复制的内容一定保留。

| | iPhone | Android 10+ |
|---|---|---|
| Keyper 在前台 | 60 秒时由 iOS 清除 | 60 秒时由 Keyper 清除 |
| Keyper 在后台 | 60 秒时由 iOS 清除 | 下次打开 Keyper 时清除 |
| Keyper 被关闭、杀掉或强行停止 | 60 秒时由 iOS 清除 | 下次打开 Keyper 时清除 |

iPhone 上，复制的内容带 60 秒有效期，由 iOS 强制执行，与 Keyper 是否在运行无关，也不会同步到你的其他设备。
Android 10 及以上，后台 App 看不到剪贴板，Keyper 分不清那是不是自己复制的，所以要等回到前台才处理；
如果一直不再打开 Keyper，Android 13+ 系统约 1 小时后会自己清空剪贴板。Android 8 和 9 仍允许这项检查，所以能按时清除。
测试：`app-android/backgroundtest` 和 `app-ios/KeyperTests/ClipboardTests.swift`。

### 内存清除

联网和离开 App 会结束一切由记忆文本推导出的状态，只保留邮箱；“全部清除”连邮箱一起清掉。落到内存上是这样：

| 内容 | 时机 | iPhone | Android |
|---|---|---|---|
| 密钥 K、演练指纹 | 联网、离开、全部清除、重新推导 | 用 `memset_s` 覆盖 | 经 `Wipe` 覆盖 |
| P = HMAC(域常量, 记忆文本)、助记词的熵、Argon2 的临时块 | 每次推导结束时，取消时也一样 | 用 `memset_s` 覆盖 | 经 `Wipe` 覆盖 |
| Argon2 的 1 GiB 计算内存 | 同上 | 用 `memset_s` 覆盖后解除映射 | 经 `Wipe` 覆盖后解除映射 |
| 文字形式的记忆文本和单词 | 联网、离开、全部清除 | 丢弃，无法覆盖 | 丢弃，无法覆盖 |

- **iPhone**：`memset_s` 由 C11（附录 K）规定，即使内存之后不再被读取，编译器也必须执行；CI 会检查优化后的 Release 二进制确实链接了它（`app-ios/scripts/check-release.sh`）。
  它只覆盖传给它的那块内存，所以每个敏感数组都保持唯一持有，不留写时复制的副本。
- **Android**：`Wipe` 写入零之后再把它们读进一个 volatile 字段，让这些写入可被观察到；但 JVM 和 ART 都不正式保证它们能挺过所有优化，
  ART 的移动式垃圾回收也可能早已把堆上的数组复制到代码够不着的地方。计算内存在堆外，回收器不会移动它，但仅凭这一点也不能保证一定擦除。Android 上的清零是尽力而为。
- **两个平台**：Kotlin 和 Swift 的字符串都无法原地覆盖，由系统稍后回收。

恢复演练不再保存记忆文本的快速哈希：指纹是以 K 为密钥的 HMAC-SHA256，内容是一个标签加上带长度前缀的规范化邮箱和记忆文本，没有 K 就毫无用处，并与 K 同生同灭。
测试：`Argon2idTest`/`Argon2idTests`（完成和取消后计算内存全为零），`KeyperTest`/`KeyperTests`（指纹的向量、密钥依赖和编码）。

冻结前对协议和 Android 版的安全审计，以及“什么情况下助记词会被算出来”，见 [docs/security-audit-zh.md](docs/security-audit-zh.md)；
报告安全漏洞见 [SECURITY.md](SECURITY.md)。

## 使用

1. 打开飞行模式，关闭 Wi-Fi 和蓝牙。
2. 用 Keyper 的键盘输入邮箱，按“下一项”，再输入记忆文本（点“显示”可核对）。
3. 选 12 或 24 个词，点“生成助记词”，等约一分钟。
4. 第一次用这句话时，做一次恢复演练。
5. 用**二维码**给钱包扫描，或**复制**到同一台手机的钱包 App（见[剪贴板](#剪贴板)）。
6. 页脚显示构建的域指纹（本仓库为 `A248-7EAB`）。指纹一样，助记词就一样；指纹变了就**不要用**，先弄清原因。
   指纹证明不了 App 是正版，篡改版也能显示同样的指纹。正版只能靠来源保证：只从官方商店页面安装，或者自己从源码编译；
   使用助记词之前，再用[恢复脚本](#脱离-app-恢复)核对一次。

## 构建与维护

### Android

需要 JDK 21 和 Android SDK（compileSdk 36）。

```sh
cd app-android
./gradlew :core:test :app:testDebugUnitTest :app:lintDebug :app:assembleRelease
# 输出 app/build/outputs/apk/release/app-release.apk
```

发布签名读取 `app-android/keystore.properties`（storeFile / storePassword / keyAlias / keyPassword，已被 git 忽略）；没有时 release 不签名。
`./gradlew :app:bundleRelease` 生成上传 Google Play 用的 AAB。

### iOS

需要 Mac 上的 Xcode 26。

```sh
cd app-ios/KeyperCore && swift test -c release   # 协议核心，含 SPEC 的 1 GiB 向量
cd app-ios && xcodebuild -scheme Keyper -destination 'platform=iOS Simulator,name=iPhone 17' test
```

在真机上运行请用 Xcode 打开 `app-ios/Keyper.xcodeproj`，签名换成你自己的团队，并把 scheme 的 Run 配置改成 Release：
Debug 构建接受下面的测试开关，也能被调试器附加。核心是只依赖系统 CryptoKit 的 Swift 包；
界面用 SwiftUI，键盘、输入框和防截屏层用 UIKit。工程使用同步文件夹，新增文件不用改工程文件。
Debug 构建另外接受 `-KeyperSimulateOffline`、`-KeyperAllowScreenshots`（UI 测试用）和 `-KeyperBench`（真机测速）；正式版里没有这些开关。

### 两个平台通用

核心测试会用完整的 1 GiB Argon2id 跑 SPEC 的测试向量，需要几分钟。

- **协议已冻结。** `KeyperTest.protocolV1IsFrozen`（以及它的 Swift 版本）钉死了所有协议常量，SPEC 的测试向量钉死了结果；
  任何改变 v1 结果的改动都会让测试失败。两个核心读取 [`test-vectors/`](test-vectors) 里同一套夹具。
- **域常量永远不能改**：[`Domain.kt`](app-android/app/src/main/kotlin/app/getkeyper/Domain.kt) 和
  [`Domain.swift`](app-ios/Keyper/Domain.swift) 里各有一份（指纹 `A248-7EAB`），测试钉死指纹并保证两份相同。
  源码仓库和发出去的每个 App 都要离线备份多份，它们都含有域常量。
- **自己部署一套？** 在任何人使用前用 `openssl rand -hex 32` 换掉两个文件里的域常量，并更新指纹测试。不同部署的助记词互不相干。
- 正式分发前用自己的密钥签名，并公布签名证书的 SHA-256。
- 用 SPEC 的测试域常量构建时，界面顶部显示红色“测试构建”警告。
- **上架应用市场**：更新会自动推送，新版本加权限也不会询问用户，所以开发者账号就是信任链的一环：务必开两步验证；
  离线手机上的 Keyper 建议关闭自动更新。
  Google Play 的加密货币政策只针对托管类服务，Keyper 不碰资产，但提交前在 Play Console 再确认。
  2023 年 11 月后注册的个人开发者账号，要先做至少 12 名测试者、连续 14 天的封闭测试。

### 脱离 App 恢复

需要一台装有 Python 3.9 及以上的电脑，和一份本仓库的副本：脚本从仓库里读取域常量，所以请离线保存一份。笔记本上约 25 秒。

```sh
python3 -m venv keyper-env
keyper-env/bin/pip install --require-hashes -r reference/requirements-recovery.txt
# 断开电脑的网络，然后：
keyper-env/bin/python reference/keyper.py --domain-file app-android/app/src/main/kotlin/app/getkeyper/Domain.kt --words 12
```

Windows 上把 `keyper-env/bin/` 换成 `keyper-env\Scripts\`。脚本在要求输入之前先显示 `domain id A248-7EAB (official Keyper)`，
显示的不是这个就停下。记忆文本要输两遍，屏幕上不显示。`--self-test` 用 SPEC 的测试向量核对脚本本身。

## 验证情况

| 项目 | 方法 | 结果 |
|---|---|---|
| Argon2id / BLAKE2b | RFC 9106、RFC 7693 向量；48 组随机参数对照 argon2-cffi（RFC 参考 C 实现） | 全部一致 |
| BIP39 | 词表 SHA-256；Trezor 官方 24 组向量 | 全部一致 |
| 二维码 | 对照 segno 逐模块比较 40 个版本 × 8 种掩码；zxing-cpp 解码 42 个真实助记词和 App 截图 | 全部一致 / 全部解出 |
| 协议 | Kotlin 与 Python 参考实现（argon2-cffi + Trezor mnemonic）对 SPEC 的 7 组向量；模拟器上的 App 与 Python 参考实现（真实域常量）对照 | 一致 |
| 邮箱规则 | 55 个边界用例（`test-vectors/email.tsv`），Kotlin、Swift 和 Python 参考实现 | 全部一致 |
| 冻结守卫 | 协议常量、域常量指纹各有测试钉死 | 通过 |
| 测试有效性 | 人为植入错误（Argon2、二维码掩码、中断时的线程等待） | 对应测试均失败 |
| 自带键盘 | 模拟器上用自带键盘输入各类字符；点在键缝和边缘；滑动纠正；用真实多点触控事件测双指交替 | 符合设计 |
| 切换语言 | 输入了邮箱、记忆文本并生成助记词后切换中英文 | 进程不重建，全部内容保留 |
| 输入隔离 | 输入框获得焦点时系统输入法状态；adb 注入文字和按键 | 系统输入法从不弹出；注入全部被拦下 |
| 恢复演练 | 先输错一个字，再输对 | 提示不一致；一致时重新显示助记词 |
| 大字体 | 系统字体 1.6 倍下显示 24 个词 | 每个词完整显示 |
| 取消与中止 | 计算中点“取消”、按 Home、打开 Wi-Fi | CPU 2 秒内从 300%+ 降到 0，无崩溃 |
| 断网门禁 | 模拟器（API 36、30）和 Redmi K40（HyperOS）上逐项切换 | 未断网时不能输入和生成；联网立即清除；蓝牙“半开”能正确识别 |
| 内存 | Java 堆上限 192 MB 的模拟器连续生成 8 次 | 每次都释放 |
| 截屏 / 权限 | 设备内 `screencap`；合并后的 manifest | 黑屏；0 个权限 |
| iOS 核心 | 同一套夹具和 SPEC 的 7 组向量（`swift test -c release`） | 全部一致 |
| iOS App | 模拟器上用自带键盘逐键输入、生成，与 Python 参考实现（真实域常量）逐词比对；二维码、恢复演练、切换语言、离开 App、弱口令和过短输入、断网门禁各有 UI 测试 | 一致；符合设计 |
| iOS 键盘 | 多指单元测试：双指交替、滑动纠正、键缝和边缘、按住删除时另一指打字 | 符合设计 |
| iOS 文案 | 紧凑数字对照 ICU 本身（test-vectors/compact.tsv）；强度文案对照 Android 版 | 一致 |
| iOS 真机 | iPhone 11（iOS 26.5）：用自带键盘输入、生成，与 Python 参考实现比对；运行中截图；开着防截屏切后台再回来三次；全新安装 | 一致；截图里只有背景色；无崩溃；不弹任何系统询问 |
| iOS 断网门禁 | iPhone 11 开飞行模式、Wi-Fi 连着，再关掉 Wi-Fi，全程 USB 连着 Mac | 先拦截（界面已核对），后放行；USB 链路和苹果的设备隧道不计入 |
| iOS 权限 | 编出的 Info.plist 和链接的库 | 没有权限说明、没有后台模式；只链接系统框架 |

Argon2id 耗时（1 GiB × 128 遍，4 路）：Redmi K40（骁龙 870）App 正式版 64.6 秒，满载一分钟未见降频；iPhone 11（A13）约 72 秒；
桌面 JVM（M2 Pro）约 22 秒；Swift（M2 Pro）约 25 秒；argon2-cffi（参考 C 实现，M2 Pro）约 25 秒。
复现：`./gradlew :core:test`、`./gradlew :core:bench`；手机上用 debug 包跑
`adb shell 'CLASSPATH=$(pm path app.getkeyper.private | cut -d: -f2) app_process / app.getkeyper.DeviceBenchKt'`。
测试夹具由 `reference/make_fixtures.py` 从上述独立实现生成。

## 已知限制

- 域常量能从 App 中提取，不是秘密。
- 强度估算是启发式的，认不出名句和公开的个人信息。
- 拼写要多年前后一致（大小写、符号、拼音的 `zh`/`z`、`ü` 写成 `v` 还是 `u`）。恢复演练能当场发现错误，几年后的记忆偏差只能靠用户自己。
- Android 上清除剪贴板只能尽力而为，见[剪贴板](#剪贴板)。输入法和厂商的剪贴板历史可能另存一份，任何 App 都清除不了：优先用二维码。
- 断网门禁防误操作，不是隔离保证。Android 上只看飞行模式、Wi-Fi、蓝牙，覆盖不到 USB 网络共享、有线网卡、NFC；
  iOS 上看网络接口和蜂窝射频，看不到“Wi-Fi 开着但没连网”，也看不到蓝牙。
- iOS 的防截屏依赖系统绘制安全输入框的方式，这不是公开 API；如果以后的 iOS 改了，App 照常可用，只是没有这层保护。
- 读屏类恶意软件的防护依赖 Android 14+ 的敏感数据标记；更老的系统上，离线手机本身要干净。
- Android 上的内存清零只能尽力而为，两个平台都无法覆盖字符串：见[内存清除](#内存清除)。威胁模型不包括内存取证。
- 需要 4 GB 以上内存；没在 32 位或真实低端机上实测，比 K40 慢的手机预计要几分钟。
- targetSdk 36；Android 17（API 37）的行为变化还没评估。

## 目录

```
SPEC.md                     协议规范（v1 已冻结）、设计理由、测试向量
SECURITY.md                 如何报告安全漏洞
docs/security-audit-zh.md   冻结前的安全审计、攻击场景、残余风险（英文版 security-audit.md）
reference/keyper.py         独立的 Python 参考实现（交叉验证、脱离 App 恢复）
reference/requirements-recovery.txt  恢复所需的依赖，带哈希锁定
reference/make_fixtures.py  从独立实现生成测试夹具
test-vectors/               两个核心共同使用的测试夹具
app-android/core/           纯 Kotlin/JVM：协议、Argon2id、BLAKE2b、BIP39、二维码、强度估算
app-android/app/            Android 界面：自带键盘、断网门禁、恢复演练（只用平台控件）
app-ios/KeyperCore/         Swift 包：同一套核心的 Swift 实现，基于系统 CryptoKit
app-ios/Keyper/             iOS 界面：SwiftUI，键盘、输入框和防截屏层用 UIKit
website/                    官网 getkeyper.app：SvelteKit 预渲染，部署在 Cloudflare
store/                      商店文案、审核说明、隐私问卷答案、商店图片
```

## 参与贡献

欢迎报告问题、改进翻译和界面。协议已冻结：任何改动都不能改变 v1 的结果。详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

Copyright © 2026 MONDAY LABS LTD。Keyper 以 [MIT 许可证](LICENSE) 开源。
