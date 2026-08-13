# Changelog

## 0.1.0

- Adds a shared Flutter API for Banner, Interstitial, and Rewarded ads.
- 增加统一的 Banner、插屏和激励广告 Flutter API。
- Provides Android and iOS bridge code in the repository. Android is the currently validated delivery target; iOS bridge code is present but iOS artifact distribution and QA are not complete.
- 仓库中提供 Android 和 iOS 桥接代码。Android 是当前已验证的交付目标；iOS 虽然已有桥接代码，但 iOS 制品分发和 QA 尚未完成。
- **iOS is not accepted for delivery yet. Do not begin iOS Host integration or use iOS in production until the artifact repository and private CocoaPods Specs distribution are fixed and Jolibox confirms iOS QA acceptance.**
- **iOS 当前尚未验收，不属于可交付能力。iOS 制品仓库和私有 CocoaPods Specs 分发问题解决、并且 Jolibox 确认 iOS QA 通过前，不要开始 iOS 宿主接入，也不要在生产环境使用 iOS 能力。**
- Forwards supported ad lifecycle callbacks without exposing ad revenue events.
- 透传已支持的广告生命周期回调，但不向宿主暴露广告收入事件。
- Requires native-host initialization before Flutter ad calls.
- Flutter 调用广告前必须由原生宿主完成 SDK 初始化。
