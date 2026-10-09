# Jolibox Ads Flutter

[English](README.md)

`jolibox_ads_flutter` 是两个原生构建共用的唯一 Dart API 包，不包含原生插件或广告 SDK 依赖。宿主在原生侧决定是否添加 Android library 或 iOS Pod `JoliboxFlutterAdsBridgeAdMob`；有广告构建由该桥接引入 Jolibox Ad Mediation 和 Google Mobile Ads。两种构建共用同一份 Flutter module、pubspec、lockfile 和 Dart API。

`0.8.0` 通过 Git tag 提供 Dart 包和 iOS Pod，通过同一 tag 下的 Maven 目录提供 Android 桥接制品，见 [GitHub Release](https://github.com/Jolibox-Developer/jolibox-ads-flutter/releases/tag/0.8.0)。iOS 使用明确的 Git Pod 依赖，不通过 CocoaPods trunk 分发。

## 环境基线

- Flutter 3.22.3 / Dart 3.4.4，支持 Android 与 iOS。
- Android：minSdk 23、Java 17、Kotlin 2.0.21；桥接依赖 mediation 0.6.2，后者传递引入 Google Mobile Ads 24.0.0。
- iOS：部署目标 13.0；桥接包含 Jolibox Ad Mediation 0.6.6 XCFramework，并依赖 `Google-Mobile-Ads-SDK` 12.1.0。
- 本地验证工具链为 Android Gradle Plugin 8.6.1 / Gradle 8.7、Xcode 26.4 / CocoaPods 1.17.0。其他宿主版本组合需自行构建验证。

## 统一 Flutter 依赖

Flutter module 只依赖基础 Dart 包。两个 native 构建必须消费同一份已解析的 module。正式接入固定发布 tag；[共享 module](examples/native_channels/flutter_module/pubspec.yaml)保留本地 path 以便开发。

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: 0.8.0
```

Flutter module 不再依赖旧 `jolibox_ads_flutter_admob` 插件。此前导出的 Flutter AAR/framework 如含旧插件，需要重新构建。

## Android 宿主接入

[双 flavor 原生宿主](examples/native_channels/android_host/README.md)给出本地源码接线：`base` 不加桥接，只有 `admob` 添加 `native/android` 和 Jolibox Maven 仓库。桥接的 `api` 依赖传递引入 mediation/AdMob，无需把 Google SDK 再塞进自己的 AAR。

```gradle
dependencies {
    admobImplementation project(":adBridge")
}
```

只有广告 flavor 编译桥接 import 和注册包装。对每个广告 Engine 注册一次 `JoliboxAdsFlutterPlugin()`，必须早于 Dart 首次调用 `isAvailable()`；宿主其他 Flutter 插件照常注册。AdMob App ID、SDK 初始化代码只放广告 flavor。基础 flavor 不能通过共享模块继承广告依赖或初始化配置。

使用正式制品时，在宿主 settings 的依赖仓库中添加下列仓库，并保留 `google()`、`mavenCentral()` 和已有 Flutter 仓库：

```gradle
maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ads-flutter/0.8.0/maven/") }
maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ad-mediation-android-maven/0.6.2/") }
```

将广告 flavor 的 project 依赖替换为：

```gradle
admobImplementation("com.jolibox.admediation:jolibox-ads-flutter-bridge-admob:0.8.0")
```

Maven 发布包含 AAR、POM 和 Gradle module 元数据，mediation/AdMob 自动传递引入，Flutter embedding 由宿主提供。源码接入则继续使用 `native/android` project 依赖。

## iOS 宿主接入

[双 target 原生宿主](examples/native_channels/ios_host/README.md)共用同一 Flutter module。只有 `HostAds` 加 native Pod 和注册代码：

```ruby
target 'HostAds' do
  install_all_flutter_pods(flutter_application_path)
  pod 'JoliboxFlutterAdsBridgeAdMob',
      :git => 'https://github.com/Jolibox-Developer/jolibox-ads-flutter.git',
      :tag => '0.8.0'
end
```

`HostBase` 安装同一 Flutter module，但不加广告 Pod。不要把广告 Pod 放在两个 target 的共同父 target 中；广告 target 也不要再用 SPM 或手工 framework 链接第二份 Google/Jolibox。桥接引用宿主已有 Flutter Engine，不自带另一份引擎。

本地开发可用 `:path => '/path/to/jolibox-ads-flutter'` 替代 `:git`/`:tag`。Podspec 位于仓库根目录；源码和内置 framework 仍位于 `native/ios`。

Flutter 3.22.3 的 iOS Engine 必须先调用 `engine.run()`，再注册 MethodChannel。之后注册原有插件，并对每个广告 Engine 调用一次 `JoliboxAdsFlutterPlugin.register(with: engine)`。Dart 首次探测能力前要等注册完成；[宿主示例](examples/native_channels/ios_host/HostAds/AppDelegate.swift)在两个 target 都实现 `waitForHostReady`，这个握手属于示例宿主，不是 SDK 公共 API。

广告 target 仍需配置自己的 `GADApplicationIdentifier`、隐私/同意策略，以及 Jolibox source/scene。示例 App ID 只能用于宿主配置检查，不能代替可用的 Jolibox 广告测试配置。

## Dart 行为

当前 Engine 没有桥接时，`JoliboxAdsFlutter.isAvailable()` 返回 `false`；注册兼容桥接后返回 `true`，但这不表示 SDK 已初始化或已有广告。基础构建中 `initialize()` 和插屏/激励 `load()` 的 Future 正常完成，不创建广告对象，也不触发任何广告回调；Banner 包括 `reserveSpace` 模式均零占位。不返回 `unavailable` 错误。

如果宿主业务只等广告回调来结束 loading，必须先检查能力：不可用时直接跳过等待。`load()` Future 完成并不表示广告加载成功。有广告构建保留真实的初始化、加载、展示、奖励及错误回调；SDK 或配置错误不会被转成静默行为。

```dart
final available = await JoliboxAdsFlutter.isAvailable();
if (available) {
  await JoliboxAdsFlutter.initialize(
    joliSource: suppliedSource,
    environment: JoliboxMediationEnvironment.staging,
  );
  // 初始化成功后再启用 Banner、插屏、激励流程。
}
```

如果宿主原生侧已负责 SDK 初始化，则不要在 Dart 重复初始化。现有 `JoliboxBannerAd`、`JoliboxInterstitialAd` 和 `JoliboxRewardedAd` API 保留。有广告构建的 `scene` 必须非空；基础构建在广告参数校验前返回，但 Dart 编译期的 `required` 参数仍需提供。

## 验证

[原生宿主示例](examples/native_channels/)使用同一 Flutter module 运行两种组合。基础 APK/target 不应包含广告桥接、mediation、AdMob 二进制或初始化元数据；广告 APK/target 应仅有一套依赖且能力探测为 `true`。真实广告、回调和奖励仍需授权的 Jolibox 测试 source/scene。旧 [example](example/) 保留其宿主改动，不作为此原生可选桥接的接入样板。
