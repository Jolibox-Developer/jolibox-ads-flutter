# 更新日志

> **English documentation:** [CHANGELOG.md](CHANGELOG.md)

## 0.2.0

- 对应 Android SDK-All `1.9.0-rc.22399`。
- 增加与 AdMob 调用形态一致的插屏、激励广告对象 API，以及 Banner、全屏广告回调实体。
- 保留原有静态全屏广告 API，确保源码兼容。
- 强化 Android 全屏广告终态和释放事件处理。
- Android 混编 QA 已验证原生初始化，以及 Banner、插屏、激励测试广告真实展示。
- **iOS 仍未验收，不可交付。**

## 0.1.0

- 增加统一的 Banner、插屏和激励广告 Flutter API。
- 仓库提供 Android 和 iOS 桥接代码；Android 是当前已验证的交付目标。
- Flutter 调用广告前必须由原生宿主初始化；Flutter 不初始化 Jolibox 或广告渠道。
- 透传已支持的广告生命周期回调，但不向宿主暴露 `onPaidEvent` 等收入事件。
- SDK-All 升级后，需要回归原生 Android Game 和 Drama 广告流程。
- **iOS 当前尚未验收。** iOS 制品仓库和私有 CocoaPods Specs 分发尚未就绪，iOS QA 也未完成。Jolibox 明确确认 iOS 验收前，不要开始 iOS 宿主接入、执行 `pod install` 或在生产环境使用 iOS 桥接。
