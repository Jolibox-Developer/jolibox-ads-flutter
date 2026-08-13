# Jolibox Ads Flutter

`jolibox_ads_flutter` 是面向宿主的公开 Flutter 广告桥接插件，通过业务场景值调用 Jolibox 的 Banner、插屏和激励广告。

> **English documentation:** [README.md](README.md)

## 当前交付状态

- **Android：** 当前已验证的交付目标。
- **iOS：** 仓库中包含桥接代码，但尚未验收，不属于当前可交付能力。iOS SDK 制品仓库和私有 CocoaPods Specs 分发尚未就绪。Jolibox 确认制品可用并完成 iOS QA 前，宿主不要开始 iOS 接入、不要针对本插件执行 `pod install`，也不要在生产环境使用 iOS 桥接。

## 架构边界

```text
原生宿主初始化 Jolibox SDK 一次
                ↓
Flutter 通过业务 scene 调用桥接
                ↓
Jolibox SDK 内部选择渠道和广告位
```

原生宿主负责 Jolibox SDK 和广告渠道初始化。Flutter 不需要、也不应该初始化 Jolibox、AdMob 或其他广告渠道，也不需要知道渠道、广告位 ID 或内部配置。

## 安装

使用公开 GitHub 仓库中的固定发布 Tag：

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: v0.1.0
```

然后执行：

```bash
flutter pub get
```

如需保证依赖解析一致，宿主项目应提交 `pubspec.lock`。

## Android 前置条件

1. 在 Android 宿主中加入批准且匹配的 Jolibox Android SDK-All 依赖。
2. 在 Android 宿主 Manifest 中配置所需的 AdMob Application ID。
3. 打开 Flutter 页面前，由 Android 原生宿主完成一次 Jolibox 初始化。
4. 不要在 SDK-All 之外添加第二套 Jolibox 依赖，也不要重复初始化 AdMob。

Flutter 页面可以嵌入已有 Android 应用；Flutter 只负责调用桥接，不负责原生初始化。

## Flutter 调用

业务 `scene` 由宿主业务与 Jolibox 约定，是路由键，不是广告位 ID。渠道、广告位和内部配置均由原生 SDK 处理。

### Banner

```dart
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

JoliboxBannerAd(
  scene: 'YOUR_BANNER_SCENE',
  onLoaded: () {},
  onFailedToLoad: (error) {},
  onImpression: () {},
  onClicked: () {},
  onOpened: () {},
  onClosed: () {},
)
```

按照 Flutter 页面生命周期销毁 Banner widget/controller，不要继续挂载已销毁的 Banner，也不要复用已销毁的原生 View。

### 插屏和激励

必须先加载，加载成功后展示；不再展示的广告需要释放。一个已经展示过的广告对象不能重复使用。当前 API 通过 `JoliboxAdsFlutter` 的静态方法调用 `show` 和 `disposeAd`。

```dart
final interstitial = await JoliboxAdsFlutter.loadInterstitial(
  'YOUR_INTERSTITIAL_SCENE',
);
try {
  await JoliboxAdsFlutter.show(interstitial);
} finally {
  await JoliboxAdsFlutter.disposeAd(interstitial);
}

final rewarded = await JoliboxAdsFlutter.loadRewarded(
  'YOUR_REWARDED_SCENE',
);
try {
  await JoliboxAdsFlutter.show(
    rewarded,
    callbacks: JoliboxFullscreenAdCallbacks(
      onUserEarnedReward: () {},
    ),
  );
} finally {
  await JoliboxAdsFlutter.disposeAd(rewarded);
}
```

使用插件公开的生命周期和结果回调。`onPaidEvent` 等收入事件不会暴露给宿主 API。

## 兼容性与验收

- 升级 SDK-All 后，必须在原生 Android Demo 回归已有 Game 和 Drama 广告流程。
- Flutter 桥接验收覆盖 Android 混编场景：Android 原生初始化 SDK，随后 Flutter 页面通过 scene 调用广告。
- staging/test 配置只能使用测试广告位；生产环境必须使用批准的生产配置，绝不能使用测试广告位。
- Flutter 插件 Tag 与 SDK-All 版本必须使用批准的匹配组合。

## iOS 接入状态

仓库包含未来使用的 iOS 桥接代码，但 iOS 当前不是交付目标。在 iOS 制品仓库可用且 Jolibox 确认 iOS QA 通过前，不要将插件接入 iOS 宿主、配置私有 Specs 或执行 `pod install`。

详见[iOS 宿主接入（当前阻塞）](docs/IOS-HOST-INTEGRATION.zh-CN.md)。

## 支持与信息边界

接入前请与 Jolibox 确认批准的插件 Tag、Android SDK-All 版本、环境和 scene。不要在宿主文档或公开仓库中发布私有制品地址、凭证、内部配置接口或广告位 ID。

## 相关文档

- [发布指南](docs/RELEASE.zh-CN.md)
- [iOS 宿主接入（当前阻塞）](docs/IOS-HOST-INTEGRATION.zh-CN.md)
- [更新日志](CHANGELOG.zh-CN.md)
