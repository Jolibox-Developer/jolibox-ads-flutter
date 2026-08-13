# 更新日志

> **English documentation:** [CHANGELOG.md](CHANGELOG.md)

## 0.1.0

- 增加统一的 Banner、插屏和激励广告 Flutter API。
- 仓库提供 Android 和 iOS 桥接代码；Android 是当前已验证的交付目标。
- Flutter 调用广告前必须由原生宿主初始化；Flutter 不初始化 Jolibox 或广告渠道。
- 透传已支持的广告生命周期回调，但不向宿主暴露 `onPaidEvent` 等收入事件。
- SDK-All 升级后，需要回归原生 Android Game 和 Drama 广告流程。
- **iOS 当前尚未验收。** iOS 制品仓库和私有 CocoaPods Specs 分发尚未就绪，iOS QA 也未完成。Jolibox 明确确认 iOS 验收前，不要开始 iOS 宿主接入、执行 `pod install` 或在生产环境使用 iOS 桥接。
