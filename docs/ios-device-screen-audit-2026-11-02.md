# iOS 屏幕保护真机验证（2026-11-02）

## 结果

**在 iPhone 15 Pro、iOS 26.5.2（23F84）上，本次验证通过。**

系统截图中的 9 个敏感场景均未出现页面内容；Release 构建的独立系统截图验证也通过。通过 USB 接入的独立 AVFoundation 视频捕获链路采样 120 帧，其中 114 帧来自受保护页面，页面区域全部为单色背景；6 帧关闭保护的对照能正常看到界面。

测试结束后，已将手机上的 Keyper 恢复为本次签名的 Release 构建并正常启动，没有带入测试启动参数。显示构建为 `29010f476401-dirty`。本次未修改派生协议或屏幕保护的生产实现。

本结论针对这一台设备和这一系统版本。没有验证所有 iPhone/iOS 组合，也没有读取控制中心原生录屏生成的相册视频或测试 AirPlay 接收端。不能把本次通过扩大为这些路径均已验证。

## 环境与保护状态

- 真实硬件：iPhone 15 Pro；有线连接，开发者模式已启用。
- 系统：iOS 26.5.2，构建 23F84；工具：Xcode 26.3。
- Debug 场景测试使用公开邮箱和公开测试口令，以及瞬时派生替身，避免浪费计算时间或使用真实钱包数据。
- 受保护场景的 App 启动参数中**没有** `-KeyperAllowScreenshots`。模拟离线和替身仅提供测试状态，不替代屏幕保护。
- Release 使用新建的 `KeyperReleaseScreenProtection` scheme 和专用 test plan，避免把只能在 Debug 编译的单测工具带入 Release。
- Release 二进制确认链接 `memset_s`，未命中既有检查列出的截图放行、模拟离线、假派生、剪贴板缩时、基准等 Debug 开关。
- USB 捕获只接入指定手机的屏幕视频源，不接入摄像头视频或音频输出。只保存被测试标记覆盖的页面区域，排除状态栏和底部指示条。

## 系统截图

用 `XCUIScreen.main.screenshot()` 调用真实手机的系统截图服务，不使用模拟器截图代替。每个场景先通过可访问性状态确认相应界面存在，再取图。

| 场景 | 系统截图中的页面区域 |
|---|---|
| 主页面 | 单色背景 |
| 明文口令与自带键盘 | 单色背景 |
| 弱口令提示 | 单色背景 |
| 12 词助记词 | 单色背景 |
| 24 词助记词 | 单色背景 |
| 二维码 | 单色背景 |
| 复制警告 | 单色背景 |
| 恢复演练的明文输入与键盘 | 单色背景 |
| 恢复演练通过页 | 单色背景 |

同一手机上先用 Debug 专用开关关闭屏幕保护，得到正常可见的对照。独立像素分析中，对照页面约 **42.27%** 的像素与背景存在明显差异；9 张受保护截图均为 **0%**。判断阈值是 RGB 三通道差值之和大于 24，不包括系统状态栏和底部指示条。这是图像检测结果，不是对秘密熵的估算。

[关闭保护的对照截图](../app-ios/build/device-sensitive-screens-attachments/control-unshielded.png) · [受保护的二维码截图](../app-ios/build/device-sensitive-screens-attachments/protected-qr.png)

## 独立 USB 视频捕获

使用 Apple 的 CoreMediaIO 屏幕设备发现和 AVFoundation `.muxed` 屏幕输入，以视频输出的帧验证，未调用 App 内部的 `drawHierarchy` 生成这些图像。每 0.5 秒采样一次，在测试标记进入相应场景后保存页面帧。

| 阶段 | 采样帧数 | 页面差异像素比例最大值 |
|---|---:|---:|
| 关闭保护的对照 | 6 | 41.94% |
| 主页面 | 23 | 0% |
| 明文口令与键盘 | 9 | 0% |
| 弱口令提示 | 11 | 0% |
| 12 词结果 | 6 | 0% |
| 24 词结果 | 8 | 0% |
| 二维码 | 10 | 0% |
| 复制警告及其后的受保护转换 | 33 | 0% |
| 恢复演练明文输入与键盘 | 9 | 0% |
| 恢复演练通过 | 5 | 0% |

标记之间的帧计入上一个阶段，所以上表不是每个静态页面精确停留时长。所有受保护阶段的样本均为单色，说明在此 USB 捕获会话中，没有观察到转换过程暴露页面。采样并非逐帧穷尽，不能据此证明所有瞬间或所有录屏 API。

第一次 USB 捕获与 XCTest 同时建立连接时，Xcode 暂时找不到设备，未实际执行测试、未保存样本；等待设备发现稳定后重跑通过。此失败属于测试连接问题，没有当作屏幕保护失败或通过的依据。

## 其他真机验证

- `ScreenShieldTests` 的 7 个测试方法通过，包括内部容器、保护缺失时拒绝显示、真实设备渲染截图、6 类覆盖界面、前后台状态遮罩及敏感状态清理；参数化方法有多个运行用例。
- `testScreenShieldHidesTheScreen` 通过。
- `testShieldedScreenSurvivesBackground` 通过：连续 3 次 Home/返回后界面正常，保护仍可工作，键盘触摸正常。
- 新增 `testSensitiveScreensStayOutOfSystemScreenshots` 通过，并在 USB 捕获期间再次通过。
- Release test plan 实际执行 1 项系统截图测试，通过；独立像素分析的页面差异为 0%。

前后台测试包括在真机上验证页面状态遮罩以及实际 Home/返回；没有对 SpringBoard 中的真实多任务卡片另外做像素比对。后续支持更多系统时应重复此检查，并补测控制中心原生录屏及 AirPlay。

## 复测与证据

新增的 UI 测试和 Release test plan 已放在源码中。以下命令从 `app-ios` 执行，将 `<UDID>` 替换为可用真机 ID：

```sh
xcodebuild -project Keyper.xcodeproj -scheme Keyper \
  -destination 'platform=iOS,id=<UDID>' \
  -only-testing:KeyperTests/KeyperClaims/ScreenShieldTests \
  -only-testing:KeyperUITests/KeyperUITests/testScreenShieldHidesTheScreen \
  -only-testing:KeyperUITests/KeyperUITests/testShieldedScreenSurvivesBackground \
  -only-testing:KeyperUITests/KeyperUITests/testSensitiveScreensStayOutOfSystemScreenshots test

xcodebuild -project Keyper.xcodeproj -scheme KeyperReleaseScreenProtection \
  -destination 'platform=iOS,id=<UDID>' test
```

本地证据在 Git 忽略的 build 目录，随当前工作区提供，不会随 Git 提交自动上传：

- `app-ios/build/device-screen-audit-baseline.xcresult`：初始真机屏幕保护与前后台测试。
- `app-ios/build/device-sensitive-screens.xcresult`：9 个敏感场景和对照截图。
- `app-ios/build/device-release-screen-audit.xcresult`：Release 真机系统截图验证。
- `app-ios/build/device-usb-screen-audit-2.xcresult`：USB 捕获期间的系统截图测试。
- `app-ios/build/device-sensitive-screens-attachments/pixel-analysis.json`：系统截图像素分析。
- `app-ios/build/device-usb-screen-frames/analysis.json`：120 帧 USB 捕获统计及各场景 PNG。
- `app-ios/build/capture-iphone-screen.swift`、`run-usb-screen-audit.py`：本次独立捕获辅助程序，未编入 App。
