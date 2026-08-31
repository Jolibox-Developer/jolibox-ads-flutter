# Jolibox Ads Flutter

> English documentation: [README.md](README.md)

Jolibox Ad Mediation 原生 SDK 的 Flutter 桥接，支持 Android 与 iOS 的
标准 AdMob Banner、插屏和激励视频广告。

## 环境要求

- Flutter `3.22.3`
- Android：`minSdk 23`、`compileSdk 35`、Java 17、Kotlin `2.0.21`、
  Android Gradle Plugin `8.6.1`、Gradle `8.7`
- iOS `13.0` 及以上
- 已提供对应平台的 Jolibox Ad Mediation 原生 SDK 制品

宿主应在应用启动阶段发起一次原生 SDK 初始化。Flutter 必须等待原生初始化结果后，
再渲染 Banner 或加载全屏广告。Flutter 的可选初始化接口只会委托给同一份原生 SDK
状态，不会创建第二份配置或广告状态。

## 混编示例

[`example/`](example/) 是完整的 Android/iOS 混编宿主示例，不是只包含 Flutter
调用的代码片段。Android 的 `Application` 和 iOS 的 `AppDelegate` 分别负责原生
SDK 初始化；Flutter 页面演示 Banner Widget，以及插屏/激励视频的 `load → show`
生命周期。仓库不包含宿主凭据：配置值均为占位符，AdMob App ID 使用 Google 官方
示例值；本地配置文件均已 Git 忽略。运行前请先阅读
[示例说明](example/README_CN.md)。

## 添加依赖

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: 0.6.4
```

更新 `pubspec.yaml` 后执行 `flutter pub get`。

## 原生配置

### Android

在宿主应用的 Gradle 仓库中加入匹配的二进制 Maven 仓库。Flutter `3.22.3` 项目应将
仓库配置放到宿主 `android/build.gradle` 已有的 `allprojects.repositories` 中：

```gradle
allprojects {
  repositories {
    google()
    mavenCentral()
    maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ad-mediation-android-maven/0.6.2/") }
  }
}
```

若宿主已经通过 `dependencyResolutionManagement` 集中管理仓库，则改为在
`android/settings.gradle` 已有的 `repositories` 中加入相同的三个仓库。宿主若强制
使用 settings 级仓库，不要在两个位置重复配置。

```gradle
dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
    maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ad-mediation-android-maven/0.6.2/") }
  }
}
```

Flutter 桥接依赖 `com.jolibox.android:jolibox-ad-mediation:0.6.2`，并会传递
解析 Google Mobile Ads `24.0.0`。仅消费发布的 AAR 不需要安装 Android NDK。
宿主只需要添加 Maven 仓库：**不要**再手动添加
`implementation("com.jolibox.android:jolibox-ad-mediation:...")`，也不要修改 Flutter
插件自身的 `android/build.gradle`。

在 `android/app/src/main/AndroidManifest.xml` 的 `<application>` 内配置宿主自己的
AdMob App ID。App ID 包含 `~`，不要误填包含 `/` 的广告位 ID。

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="YOUR_ANDROID_ADMOB_APP_ID" />
```

请在 Android 应用启动阶段完成一次原生初始化；若使用 `Application` 子类，需在宿主
`AndroidManifest.xml` 的 `android:name` 中声明该类。

```kotlin
class HostApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        JoliboxAds.initialize(
            this,
            "YOUR_JOLI_SOURCE",
            MediationEnvironment.STAGING,
            object : InitializationCallback {
                override fun onInitialized() {}
                override fun onInitializationFailed(error: JoliboxAdError) {}
            },
        )
    }
}
```

### iOS

Flutter 桥接 `0.6.4` 固定要求 Flutter `3.22.3`，iOS 制品仅通过 CocoaPods 交付，
内置原生聚合 SDK `0.6.1`，并解析 Google Mobile Ads SDK `12.1.0`；除非后续提供新的
原生 SDK，否则 Android Maven 仓库仍使用 `0.6.2`。旧版本文档中基于 Flutter Swift Package Manager 的接入方式
不支持用于本版本。已有 iOS 宿主必须迁移到下方的 CocoaPods 步骤；若无法使用
CocoaPods，则无法接入 `0.6.4`。

插件通过 CocoaPods 链接随包提供的原生 XCFramework。在 Flutter 应用根目录执行：

```bash
flutter pub get
cd ios && pod install && cd ..
```

同一个 iOS application target 不应再通过 Swift Package Manager 引入
`JoliboxAdMediation`；Flutter 插件已经内置匹配的 framework。在
`ios/Runner/Info.plist` 中配置宿主自己的 AdMob App ID：

```xml
<key>GADApplicationIdentifier</key>
<string>YOUR_IOS_ADMOB_APP_ID</string>
```

请在 iOS 应用启动阶段发起一次原生初始化；初始化调用应放在
`AppDelegate.application(_:didFinishLaunchingWithOptions:)` 中，且在
Flutter 加载任何广告前执行。

```swift
import JoliboxAdMediation

JoliboxAds.initialize(
  joliSource: "YOUR_JOLI_SOURCE",
  environment: .staging
) { result in
  // 在 Flutter 加载广告前处理初始化成功或失败。
}
```

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

## 从 0.4.x 迁移

`0.6.4` 不再提供旧版静态全屏广告 API。请将
`JoliboxAdsFlutter.loadInterstitial(...)`、
`JoliboxAdsFlutter.loadRewarded(...)`、`JoliboxAdsFlutter.show(...)`、
`JoliboxAdsFlutter.disposeAd(...)` 和 `JoliboxFullscreenAd` 替换为上文所示的
`JoliboxInterstitialAd`、`JoliboxRewardedAd` 对象式 API。加载成功后在广告对象上设置
`fullScreenContentCallback`，每个对象只调用一次 `show()`；仅当已加载广告不再展示时
调用其 `dispose()`。

iOS 宿主若曾使用旧版 Flutter Swift Package Manager 接入，需要从 application target
删除该依赖，并按 iOS 配置章节改用 CocoaPods。

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
空字符串或仅包含空白字符的 `scene` 属于调用参数错误；Dart 会在发起任何原生请求前，
让加载 Future 以 `ArgumentError` 结束。
`ADS_ACTIVITY_REQUIRED` 与 `ADS_SHOW_IN_PROGRESS` 可重试：等待有效展示页面就绪或当前
全屏广告结束后，可对同一个已加载对象再次调用 `show()`。其他展示失败属于终态，重试前
需要重新加载新的广告对象。
