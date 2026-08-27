# Jolibox Ads Flutter

`jolibox_ads_flutter` 是面向宿主的公开 Flutter 广告桥接插件，通过业务场景值调用 Jolibox 的 Banner、插屏和激励广告。

> **English documentation:** [README.md](README.md)

## 当前交付状态

- **Android：** 当前已验证的交付目标。
- **iOS：** 通过匹配的公开 iOS SDK Release 和 Swift Package Manager 交付。CocoaPods 不是受支持的 iOS 交付方式；生产接入前仍需完成宿主运行时验收。

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
      ref: v0.4.0
```

然后执行：

```bash
flutter pub get
```

如需保证依赖解析一致，宿主项目应提交 `pubspec.lock`。

## Android 前置条件

1. 在 Android 宿主根目录的 `build.gradle` 中，向已有的 `allprojects.repositories` 加入所需 Maven 仓库。Flutter Android 工具会为 engine 制品声明项目级仓库，只在 `settings.gradle` 中配置可能被忽略；保持 `public` 在 `android-internal` 之前：

```gradle
allprojects {
  repositories {
    // 保留宿主已有仓库。
    maven { url = uri('https://repo.jolibox.com/repository/public/') }
    maven { url = uri('https://repo.jolibox.com/repository/android-internal/') }
  }
}
```

如果使用 Kotlin DSL，请使用 `maven(url = "https://repo.jolibox.com/repository/public/")` 和对应的 `android-internal` URL。

如果宿主强制使用 `RepositoriesMode.FAIL_ON_PROJECT_REPOS`，不要原样增加上述项目级 repositories：Flutter 也会为 engine 制品声明项目级仓库，宿主构建负责人需要在既有的 settings 级仓库策略中加入两个 Jolibox 仓库，并保留 Flutter engine 所需仓库。最终必须通过 `assembleDebug` 验证该策略。

然后在 Android app 模块的 `build.gradle` 中加入批准且匹配的 SDK-All 依赖：

```gradle
dependencies {
  implementation 'com.jolibox.android:jolibox-platform-sdk-all:1.9.0-rc.23239'
}
```

如果宿主已在第一期完成原生 Android SDK 接入，只需保留同一套已批准的 SDK-All 版本和 Maven 配置；不要为了 Flutter 再增加第二套 Jolibox SDK 依赖图或不同版本的 SDK-All。

2. 在 Android 宿主 Manifest 中配置所需的 AdMob Application ID。
3. 打开 Flutter 页面前，由 Android 原生宿主完成一次 `Jolibox.init(...)` 和 `JoliboxAds.initialize(...)`。初始化的归属、顺序和配置边界见[原生宿主初始化](docs/NATIVE-HOST-INITIALIZATION.zh-CN.md)。
4. 不要在 SDK-All 之外添加第二套 Jolibox 依赖，也不要重复初始化 AdMob。

Flutter 页面可以嵌入已有 Android 应用；Flutter 只负责调用桥接，不负责原生初始化。

### 自定义或缓存 FlutterEngine

标准 `FlutterActivity` 流程不需要额外编写 Jolibox 插件注册代码。若宿主自行创建或缓存 `FlutterEngine`，请遵循 Flutter 官方混编生命周期：缓存前先执行 Dart entrypoint，再通过 `FlutterActivity.withCachedEngine(...)` 附着到页面。全屏广告需要前台 Activity，因此必须保留默认的 Activity attachment。

```kotlin
val flutterEngine = FlutterEngine(applicationContext)
flutterEngine.dartExecutor.executeDartEntrypoint(
  DartExecutor.DartEntrypoint.createDefault(),
)
FlutterEngineCache.getInstance().put("host_ads_engine", flutterEngine)

startActivity(
  FlutterActivity.withCachedEngine("host_ads_engine").build(this),
)
```

请使用宿主项目原有的 Flutter 自动生成插件注册方式；不要手动创建 `JoliboxAdsFlutterPlugin`，也不要在 Dart 中初始化 Jolibox 或 AdMob。

## Flutter 调用

业务 `scene` 由宿主业务与 Jolibox 约定，是路由键，不是广告位 ID。渠道、广告位和内部配置均由原生 SDK 处理。

### 0.4.0 源码兼容性

`JoliboxBannerSize` 已改为 class，以便自适应构造方法接收宽度和可选最大高度。常用固定尺寸调用保持不变：`JoliboxBannerSize.banner`、`JoliboxBannerSize.largeBanner`、`JoliboxBannerSize.mediumRectangle`。若旧代码依赖 Dart `enum` 成员（`values`、`index` 或穷尽 `switch` 语义），则必须迁移并使用 `0.4.0` 重新编译。

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

### 自适应 Banner

必须传入 Banner 父布局实际可用的宽度；插件不会推断屏幕宽度。推荐通过 `LayoutBuilder` 获取约束：

```dart
LayoutBuilder(
  builder: (context, constraints) => JoliboxBannerAd(
    scene: 'YOUR_BANNER_SCENE',
    size: JoliboxBannerSize.largeAnchoredAdaptive(
      width: constraints.maxWidth,
    ),
  ),
)
```

页面顶部或底部固定展示使用 `largeAnchoredAdaptive`；滚动内容内嵌使用 `inlineAdaptive`。`maxHeight` 可选，传入时至少为 `32` logical pixel：

```dart
JoliboxBannerAd(
  scene: 'YOUR_INLINE_BANNER_SCENE',
  size: JoliboxBannerSize.inlineAdaptive(width: bannerWidth, maxHeight: 100),
)
```

自适应 Banner 在广告加载前或加载失败后不预留最终 Banner 高度；内部会保留 1 logical pixel 的启动布局，以便原生 PlatformView 开始加载，成功后由桥接替换为 Google Mobile Ads 实际解析出的尺寸。修改 scene、尺寸模式、宽度或 `maxHeight` 会销毁旧原生 Banner 并重新请求。

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

iOS 桥接要求 Flutter `3.44` 或更高版本；该版本默认启用 Swift Package Manager。如果之前曾关闭 SwiftPM，请在解析 Flutter App 前执行：

```bash
flutter config --enable-swift-package-manager
```

iOS 宿主可无需 GitHub 仓库认证，直接解析公开的 `Jolibox-Developer/jolibox-ios-sdk` 仓库及其 Release asset。原生 iOS 宿主在展示 Flutter 页面前只初始化一次 Jolibox；Flutter 不得初始化 Jolibox 或 Google Mobile Ads。请勿使用 `pod install` 交付本桥接。

SPM 的解析与构建链路已经验证；生产接入前仍需完成宿主运行时验收。

## 支持与信息边界

接入前请与 Jolibox 确认批准的插件 Tag、Android SDK-All 版本、环境和 scene。不要在宿主文档或公开仓库中发布仓库凭证、内部配置接口或广告位 ID。

## 相关文档

- [iOS 宿主接入](docs/IOS-HOST-INTEGRATION.zh-CN.md)
- [原生宿主初始化](docs/NATIVE-HOST-INITIALIZATION.zh-CN.md)
- [更新日志](CHANGELOG.zh-CN.md)
