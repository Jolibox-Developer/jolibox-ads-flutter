# Jolibox Ads Flutter

> English documentation: [README.md](README.md)

Jolibox Ad Mediation 原生 SDK 的 Flutter 桥接，支持 Android 与 iOS 的
标准 AdMob Banner、插屏和激励视频广告。

## 环境要求

- Flutter `3.22.3`
- Android：`minSdk 23`、`compileSdk 35`、Java 17
- iOS `13.0` 及以上
- 已提供对应平台的 Jolibox Ad Mediation 原生 SDK 制品

宿主应在 Flutter 页面渲染或加载广告前完成原生 SDK 初始化。Flutter 的可选
初始化接口只会委托给同一份原生 SDK 状态，不会创建第二份配置或广告状态。

## 添加依赖

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: 0.6.0
```

更新 `pubspec.yaml` 后执行 `flutter pub get`。

## 原生配置

### Android

在宿主应用的 Gradle 仓库中加入匹配的二进制 Maven 仓库。Flutter 插件会传递解析
原生聚合库；同一个 application target 不应再额外引入第二份原生 SDK。

```gradle
repositories {
  google()
  mavenCentral()
  maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ad-mediation-android-maven/0.5.0/") }
}
```

Flutter 桥接依赖 `com.jolibox.android:jolibox-ad-mediation:0.5.0`，并会传递
解析 Google Mobile Ads `24.0.0`。仅消费发布的 AAR 不需要安装 Android NDK。
请在 Android 应用启动阶段完成一次原生初始化。

### iOS

`0.6.0` 固定要求 Flutter `3.22.3`，iOS 制品仅通过 CocoaPods 交付。旧版本文档中
基于 Flutter Swift Package Manager 的接入方式不支持用于本版本。已有 iOS 宿主必须
迁移到下方的 CocoaPods 步骤；若无法使用 CocoaPods，则无法接入 `0.6.0`。

插件通过 CocoaPods 链接随包提供的原生 XCFramework。在 Flutter 应用根目录执行：

```bash
flutter pub get
cd ios && pod install && cd ..
```

同一个 iOS application target 不应再通过 Swift Package Manager 引入
`JoliboxAdMediation`；Flutter 插件已经内置匹配的 framework。请在 iOS 应用
启动阶段完成一次原生初始化。

## Banner Widget

`JoliboxBannerAd` 自身管理原生 PlatformView。将它放到需要展示广告的 Widget
树中；移除该 Widget 时会自动销毁原生 Banner。

```dart
JoliboxBannerAd(
  scene: 'YOUR_SCENE',
  size: JoliboxBannerSize.banner,
  onLoaded: () {},
  onFailedToLoad: (error) {},
  onImpression: () {},
  onClicked: () {},
)
```

目前支持固定尺寸：`banner`、`largeBanner`、`mediumRectangle`。

## 插屏与激励视频

全屏广告遵循原生 AdMob 的对象生命周期：先加载对象、设置回调、仅展示一次；
展示关闭或终态展示失败后，桥接会自动释放对象。仅当已加载广告不再展示时调用
`dispose()`。

```dart
JoliboxInterstitialAd.load(
  scene: 'YOUR_SCENE',
  adLoadCallback: JoliboxInterstitialAdLoadCallback(
    onAdLoaded: (ad) async {
      ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
        onAdImpression: () {},
        onAdClicked: () {},
        onAdDismissedFullScreenContent: () {},
        onAdFailedToShowFullScreenContent: (error) {},
      );
      await ad.show();
    },
    onAdFailedToLoad: (error) {},
  ),
);
```

激励视频使用 `JoliboxRewardedAd.load`，并在 `show` 中传入
`onUserEarnedReward`。奖励回调不包含金额或类型。

## 可选的 Flutter 初始化

仅当宿主明确让 Flutter 负责第一次原生初始化时调用。若混编宿主已经在原生层
初始化，不应再次调用。

```dart
await JoliboxAdsFlutter.initialize(
  joliSource: suppliedConfiguration,
  environment: JoliboxMediationEnvironment.staging,
);
```

## 错误与回调

加载或展示失败以 `PlatformException` 返回。全屏回调为
`onAdShowedFullScreenContent`、`onAdImpression`、`onAdClicked`、
`onAdDismissedFullScreenContent`、`onAdFailedToShowFullScreenContent`。
Banner 支持加载成功、加载失败、曝光、点击、打开和关闭回调。

所有公开 `PlatformException.code` 均使用 `ADS_` 前缀。既有广告错误包括
`ADS_LOAD_FAILED`、`ADS_SHOW_FAILED`、`ADS_AD_NOT_FOUND`、
`ADS_ACTIVITY_REQUIRED` 和 `ADS_SHOW_IN_PROGRESS`。初始化和配置类错误同样使用
`ADS_` 前缀。
