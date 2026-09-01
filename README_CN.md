# Jolibox Ads Flutter

> English documentation: [README.md](README.md)

Jolibox Ad Mediation 原生 SDK 的 Flutter 桥接，支持 Android 与 iOS 的
标准 AdMob Banner、插屏和激励视频广告。

## 环境要求

- Flutter `3.22.3`
- Android：`minSdk 23`、Java 17、Kotlin `2.0.21`，且最终解析的 Google
  Mobile Ads 版本为 `24.0.0`
- iOS `13.0` 及以上，Google Mobile Ads SDK `12.1.0`
- 已提供对应平台的 Jolibox Ad Mediation 原生 SDK 制品

Android 已验收基线为 Android Gradle Plugin `8.6.1`、Gradle `8.7`、
`compileSdk 35` 和 `targetSdk 35`。这些是验收值，不要求所有宿主照搬；宿主可以使用其他
兼容的 AGP、Gradle、compile SDK 或 target SDK。本版本固定使用 Flutter `3.22.3` 与
Kotlin `2.0.21`。

iOS 已验收基线为 Xcode `26.4` 与 CocoaPods `1.17.0`。本版本不对其他 Xcode 或
CocoaPods 版本作已验收承诺。

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
      ref: 0.6.8
```

解析依赖前先执行 `flutter --version`，确认输出严格为 `3.22.3`，再执行
`flutter pub get`。

## 原生配置

### Android

将宿主已有的 Kotlin 版本声明精确设置为 `2.0.21`。使用 plugins DSL 的 Flutter 项目
通常在 `android/settings.gradle` 中声明：

```gradle
plugins {
  id "org.jetbrains.kotlin.android" version "2.0.21" apply false
}
```

旧工程也可能在 `android/build.gradle` 中使用
`ext.kotlin_version = "2.0.21"`。只更新宿主已有声明，不要重复添加第二份 Kotlin
插件声明。

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
`android/settings.gradle` 已有的 `repositories` 中配置以下四个仓库，不要同时在两个
位置重复配置 Jolibox 仓库。Flutter `3.22.3` 的 settings 级仓库管理必须使用
`PREFER_SETTINGS`：

```gradle
dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
  repositories {
    google()
    mavenCentral()
    maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ad-mediation-android-maven/0.6.2/") }
  }
}
```

Flutter `3.22.3` 自带的 Gradle 插件，以及使用时的 `integration_test` 插件，都会声明
项目级仓库。因此固定 Flutter `3.22.3` 的宿主无论使用哪个 Jolibox 插件版本，都**不得**
使用 `RepositoriesMode.FAIL_ON_PROJECT_REPOS`。使用 `PREFER_SETTINGS` 时，Gradle 可能
提示 Flutter 自有项目级仓库已被忽略，这是预期警告；上面的 settings 列表必须同时保留
Flutter Engine 与 Jolibox Maven 仓库。

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

原生/Flutter 混编宿主应在 Android 应用启动阶段完成一次原生初始化；若使用
`Application` 子类，需在宿主 `AndroidManifest.xml` 的 `android:name` 中声明该类。
纯 Flutter 宿主应跳过这段原生初始化，改用下文 Dart 初始化模式。

```kotlin
import android.app.Application
import com.jolibox.admediation.JoliboxAds
import com.jolibox.admediation.api.InitializationCallback
import com.jolibox.admediation.api.JoliboxAdError
import com.jolibox.admediation.api.MediationEnvironment

class HostApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        JoliboxAds.initialize(
            this,
            "YOUR_JOLI_SOURCE",
            MediationEnvironment.STAGING,
            object : InitializationCallback {
                override fun onInitialized() {
                    // 通过宿主状态或宿主自有 MethodChannel 通知 Flutter 已就绪。
                }

                override fun onInitializationFailed(error: JoliboxAdError) {
                    // 通知失败，并保持 Flutter 广告 UI 禁用。
                }
            },
        )
    }
}
```

同时在宿主 Manifest 的 application 元素声明该类：

```xml
<application
    android:name=".HostApplication"
    ...>
```

### iOS

Flutter 桥接 `0.6.8` 固定要求 Flutter `3.22.3`，iOS 制品仅通过 CocoaPods 交付，
内置原生聚合 SDK `0.6.4`，并解析 Google Mobile Ads SDK `12.1.0`；除非后续提供新的
原生 SDK，否则 Android Maven 仓库仍使用 `0.6.2`。旧版本文档中基于 Flutter Swift Package Manager 的接入方式
不支持用于本版本。已有 iOS 宿主必须迁移到下方的 CocoaPods 步骤；若无法使用
CocoaPods，则无法接入 `0.6.8`。

插件通过 CocoaPods 链接随包提供的原生 XCFramework。在 Flutter 应用根目录执行：

```bash
flutter pub get
cd ios && pod install && cd ..
```

`pod install` 完成后检查 `ios/Podfile.lock`，其中必须解析为
`jolibox_ads_flutter (0.6.8)` 与 `Google-Mobile-Ads-SDK (12.1.0)`。不要仅为改变版本而
删除现有 lockfile；若任一版本不符，应先检查 Flutter 依赖选择的 Tag 和宿主 Pod
版本约束。

同一个 iOS application target 不应再通过 Swift Package Manager 引入
`JoliboxAdMediation`；Flutter 插件已经内置匹配的 framework。在
`ios/Runner/Info.plist` 中配置宿主自己的 AdMob App ID：

```xml
<key>GADApplicationIdentifier</key>
<string>YOUR_IOS_ADMOB_APP_ID</string>
```

混编宿主应在 `AppDelegate.application(_:didFinishLaunchingWithOptions:)` 中完成一次
原生初始化，将结果保存在宿主状态中，并在启用 Flutter 广告 UI 前把状态通知给 Flutter。

```swift
import Flutter
import JoliboxAdMediation
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private(set) var adsReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    JoliboxAds.initialize(
      joliSource: "YOUR_JOLI_SOURCE",
      environment: .staging
    ) { [weak self] result in
      switch result {
      case .success:
        self?.adsReady = true
        // 通知宿主的 Flutter 状态：广告 SDK 已就绪。
      case .failure(let error):
        self?.adsReady = false
        // 上报 error.code，并保持 Flutter 广告 UI 禁用。
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Example 中的初始化 Channel 是这个就绪门禁的参考实现；它的 Channel 名属于示例宿主，
不是 SDK 公共 API。

## 选择一种初始化模式

全程只初始化一次，不要同时使用下面两种模式。

### 纯 Flutter 宿主

完成上文 Maven/CocoaPods 与 AdMob App ID 配置后，在渲染任何广告 UI 前从 Dart 初始化：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initializationError;
  try {
    await JoliboxAdsFlutter.initialize(
      // 从宿主批准的配置渠道获取该值，不要提交到仓库。
      joliSource: suppliedConfiguration,
      environment: JoliboxMediationEnvironment.staging,
    );
  } catch (error) {
    initializationError = error;
  }
  runApp(HostApp(
    adsEnabled: initializationError == null,
    initializationError: initializationError,
  ));
}
```

上面的 `HostApp` 代表宿主自有 UI：`initializationError` 非空时，必须禁用所有广告
Widget 与加载操作，也可以提供明确的重试入口。使用这种模式时，不要再在 Android
`Application` 或 iOS `AppDelegate` 中重复初始化。

### 原生/Flutter 混编宿主

使用上文 Android/iOS 原生初始化方式。Flutter 必须消费宿主提供的 ready/failed 状态；
在状态为 ready 前，不得创建 `JoliboxBannerAd`，也不得调用全屏广告 `load`。完整参考实现
见 Example 的
[Android Application](example/android/app/src/main/kotlin/com/jolibox/admediation/jolibox_ads_flutter_example/ExampleApplication.kt)、
[iOS AppDelegate](example/ios/Runner/AppDelegate.swift) 与
[Flutter 就绪门禁](example/lib/main.dart)。

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
      try {
        await ad.show();
      } on PlatformException catch (error) {
        if (error.code == 'ADS_ACTIVITY_REQUIRED' ||
            error.code == 'ADS_SHOW_IN_PROGRESS') {
          // 保留这个已加载对象，稍后重试 show()。
          return;
        }
        // 该对象已进入终态；移除引用并重新加载新广告。
      }
    },
    onAdFailedToLoad: (error) {},
  ),
);
```

以上代码需要从 `package:flutter/services.dart` 导入 `PlatformException`。

激励视频使用 `JoliboxRewardedAd.load`，并在 `show` 中传入
`onUserEarnedReward`。奖励回调不包含金额或类型。

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
