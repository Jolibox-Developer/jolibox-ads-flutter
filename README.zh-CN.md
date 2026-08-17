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
      ref: v0.2.0
```

然后执行：

```bash
flutter pub get
```

如需保证依赖解析一致，宿主项目应提交 `pubspec.lock`。

## Android 前置条件

1. 在 Android 宿主的 `settings.gradle` 中，向已有的 `dependencyResolutionManagement.repositories` 加入所需 Maven 仓库；保持 `public` 在 `android-internal` 之前，不要新增第二个 repositories 块：

```gradle
dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
    maven { url = uri('https://repo.jolibox.com/repository/public/') }
    maven { url = uri('https://repo.jolibox.com/repository/android-internal/') }
  }
}
```

然后在 Android app 模块的 `build.gradle` 中加入批准且匹配的 SDK-All 依赖：

```gradle
dependencies {
  implementation 'com.jolibox.android:jolibox-platform-sdk-all:1.9.0-rc.22399'
}
```

如果宿主已在第一期完成原生 Android SDK 接入，只需保留同一套已批准的 SDK-All 版本和 Maven 配置；不要为了 Flutter 再增加第二套 Jolibox SDK 依赖图或不同版本的 SDK-All。

2. 在 Android 宿主 Manifest 中配置所需的 AdMob Application ID。
3. 打开 Flutter 页面前，由 Android 原生宿主按单独提供的 Android SDK-All 接入文档完成一次 `Jolibox.init(...)` 和 `JoliboxAds.initialize(...)`。
4. 不要在 SDK-All 之外添加第二套 Jolibox 依赖，也不要重复初始化 AdMob。

Flutter 页面可以嵌入已有 Android 应用；Flutter 只负责调用桥接，不负责原生初始化。

## Flutter 调用

业务 `scene` 由宿主业务与 Jolibox 约定，是路由键，不是广告位 ID。渠道、广告位和内部配置均由原生 SDK 处理。

### Banner

```dart
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

JoliboxBannerAd(
  scene: 'YOUR_BANNER_SCENE',
  callbacks: JoliboxBannerAdCallbacks(
    onLoaded: () {},
    onFailedToLoad: (error) {},
    onImpression: () {},
    onClicked: () {},
    onOpened: () {},
    onClosed: () {},
  ),
)
```

按照 Flutter 页面生命周期销毁 Banner widget，不要继续挂载已销毁的 Banner，也不要复用已销毁的原生 View。

### 插屏和激励

必须先加载，加载成功后展示；不再展示的广告需要释放。已经展示过的广告对象不能重复使用；展示关闭或展示失败后，桥接会自动释放原生引用。每次 `show` 都必须 `await`；当前全屏广告结束前，第二次全屏展示会被拒绝。

```dart
JoliboxInterstitialAd? interstitialAd;

Future<void> loadInterstitial() => JoliboxInterstitialAd.load(
  scene: 'YOUR_INTERSTITIAL_SCENE',
  adLoadCallback: JoliboxInterstitialAdLoadCallback(
    onAdLoaded: (ad) => interstitialAd = ad,
    onAdFailedToLoad: (error) {},
  ),
);

Future<void> showInterstitial() async {
  final ad = interstitialAd;
  if (ad == null) return;
  interstitialAd = null;
  ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
    onAdImpression: () {},
    onAdClicked: () {},
    onAdDismissedFullScreenContent: () {},
    onAdFailedToShowFullScreenContent: (error) {},
  );
  try {
    await ad.show();
  } finally {
    await ad.dispose();
  }
}

JoliboxRewardedAd? rewardedAd;

Future<void> loadRewarded() => JoliboxRewardedAd.load(
  scene: 'YOUR_REWARDED_SCENE',
  adLoadCallback: JoliboxRewardedAdLoadCallback(
    onAdLoaded: (ad) => rewardedAd = ad,
    onAdFailedToLoad: (error) {},
  ),
);

Future<void> showRewarded() async {
  final ad = rewardedAd;
  if (ad == null) return;
  rewardedAd = null;
  ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
    onAdDismissedFullScreenContent: () {},
    onAdFailedToShowFullScreenContent: (error) {},
  );
  try {
    await ad.show(onUserEarnedReward: () {});
  } finally {
    await ad.dispose();
  }
}
```

从宿主已 `await` 的业务事件（例如按钮点击）中调用 `showInterstitial()` 或 `showRewarded()`。使用插件公开的生命周期和结果回调。`onPaidEvent` 等收入事件不会暴露给宿主 API。

为确保源码兼容，原有 `JoliboxAdsFlutter.load...`、`show`、`disposeAd` 静态 API 仍然可用；新接入请使用上方对象 API。

## 兼容性与验收

- 升级 SDK-All 后，必须在原生 Android Demo 回归已有 Game 和 Drama 广告流程。
- Flutter 桥接验收覆盖 Android 混编场景：Android 原生初始化 SDK，随后 Flutter 页面通过 scene 调用广告。
- staging/test 配置只能使用测试广告位；生产环境必须使用批准的生产配置，绝不能使用测试广告位。
- Flutter 插件 Tag 与 SDK-All 版本必须使用批准的匹配组合。

## iOS 接入状态

仓库包含未来使用的 iOS 桥接代码，但 iOS 当前不是交付目标。在 iOS 制品仓库可用且 Jolibox 确认 iOS QA 通过前，不要将插件接入 iOS 宿主、配置私有 Specs 或执行 `pod install`。

详见[iOS 宿主接入（当前阻塞）](docs/IOS-HOST-INTEGRATION.zh-CN.md)。

## 支持与信息边界

接入前请与 Jolibox 确认批准的插件 Tag、Android SDK-All 版本、环境和 scene。不要在宿主文档或公开仓库中发布仓库凭证、内部配置接口或广告位 ID。

## 相关文档

- [发布指南](docs/RELEASE.zh-CN.md)
- [iOS 宿主接入（当前阻塞）](docs/IOS-HOST-INTEGRATION.zh-CN.md)
- [更新日志](CHANGELOG.zh-CN.md)
