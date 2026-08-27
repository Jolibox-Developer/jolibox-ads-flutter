# 更新日志

> **English documentation:** [CHANGELOG.md](CHANGELOG.md)

## 0.4.0

- 在现有 `JoliboxBannerAd` Widget 中增加固定、Large Anchored Adaptive 和 Inline Adaptive Banner 尺寸能力。
- 自适应请求必须由宿主传入 Banner 容器的实际宽度；原生广告加载成功前 Widget 不预留最终 Banner 高度。
- Android 桥接升级为依赖 SDK-All `1.9.0-rc.23239`，iOS 桥接使用匹配的 iOS SDK `0.4.0` Release。
- `JoliboxBannerSize` 从 Dart `enum` 调整为 class；常用固定尺寸常量保持兼容，但依赖 `values`、`index` 或穷尽 `switch` 的 enum 用法需要迁移。

## 0.3.0

- 通过 Flutter Swift Package Manager 和公开的 `JoliboxSDKAll` `0.3.0` Package 交付 iOS 桥接。
- 要求 iOS 15 及以上；不支持的 CocoaPods 接入会给出明确配置错误。
- Flutter Android API 和原生 Android 桥接保持不变。

## 0.2.0

- 对应 Android SDK-All `1.9.0-rc.22399`。
- 增加与 AdMob 调用形态一致的插屏、激励广告对象 API，以及 Banner、全屏广告回调实体。
- 保留原有静态全屏广告 API，确保源码兼容。
- 强化 Android 全屏广告终态和释放事件处理。

## 0.1.0

- 增加统一的 Banner、插屏和激励广告 Flutter API。
- 仓库提供 Android 和 iOS 桥接代码；Android 是当前已验证的交付目标。
- Flutter 调用广告前必须由原生宿主初始化；Flutter 不初始化 Jolibox 或广告渠道。
- 透传已支持的广告生命周期回调，但不向宿主暴露 `onPaidEvent` 等收入事件。
