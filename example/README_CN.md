# Jolibox Ads Flutter 示例

这是可运行的 Android/iOS 混编宿主示例，不是只包含 Flutter 调用的代码片段。它覆盖
Banner、插屏和激励视频广告，不包含真实的 `joliSource`、场景值、广告位 ID 或其他环境凭据。

仓库中的 Android Manifest 与 iOS plist 使用 Google 官方示例 AdMob App ID，可安全用于
开发测试。生产宿主必须在 `android/app/src/main/AndroidManifest.xml` 和
`ios/Runner/Info.plist` 中替换为自己的 App ID。

## 示例内容

1. Android 在 `ExampleApplication.onCreate()` 中初始化 `JoliboxAds`。
2. iOS 在应用启动时由 `AppDelegate` 初始化 `JoliboxAds`。
3. Flutter 等待原生初始化完成后，以 Widget 形式展示 `JoliboxBannerAd`，并分别演示
   插屏和激励视频的 `load → show` 流程。
4. Flutter 刻意**不会**调用 `JoliboxAdsFlutter.initialize()`。

`jolibox_ads_flutter_example/initialization` MethodChannel 只用于原生初始化完成后
启用该示例的操作按钮，并非公开 SDK API。生产宿主可根据自身原生初始化完成回调决定何时
启用 Flutter 广告 UI，无需复制该 Channel。

## 运行方式

1. 先按上级[接入文档](../README_CN.md)完成 Android 或 iOS 原生配置。
2. 将 `qa.local.json.example` 复制为 `qa.local.json`，填写 `JOLIBOX_SCENE`。该本地
   文件已被 Git 忽略。
   仅配置当前准备运行的平台对应的原生参数即可。
3. 在已 Git 忽略的 `android/local.properties` 中追加原生配置：

   ```properties
   jolibox.joliSource=YOUR_JOLI_SOURCE
   jolibox.environment=staging
   ```

4. iOS 复制本地配置模板后，填写提供的参数：

   ```bash
   cp ios/Runner/Config/Jolibox.local.xcconfig.example \
     ios/Runner/Config/Jolibox.local.xcconfig
   ```

   ```xcconfig
   JOLIBOX_JOLI_SOURCE = YOUR_JOLI_SOURCE
   JOLIBOX_ENVIRONMENT = staging
   ```

5. 使用本地场景配置运行：

   ```bash
   flutter run --dart-define-from-file=qa.local.json
   ```

`ExampleApplication.kt` 会经由 `BuildConfig` 在 `FlutterActivity` 渲染前发起 Android
初始化，Flutter 控件会等待其结果；`AppDelegate.swift` 会在应用启动时发起 iOS 初始化，
Flutter 控件会在加载广告前等待结果。`android/local.properties` 与
`ios/Runner/Config/Jolibox.local.xcconfig` 均已被 Git 忽略。

原生初始化成功后，Banner Widget 会自动请求广告。插屏和激励视频使用独立的 Load、Show
控件，用于验证对象式生命周期。iOS 请先执行 `flutter pub get`，再执行
`cd ios && pod install && cd ..`，之后使用 Xcode 打开 `Runner.xcworkspace`。生产接入方式
和回调语义请参考上级文档。

For English, see [README.md](README.md).
