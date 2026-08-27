# iOS 宿主接入

> **English documentation:** [iOS Host Integration](IOS-HOST-INTEGRATION.md)

## 状态

iOS 桥接通过 Flutter Swift Package Manager 交付，需要使用匹配发布的 `JoliboxSDKAll` `0.4.0`。

生产上线前仍需完成宿主初始化和真实广告展示的运行时验收。本桥接不支持 CocoaPods。

## 前置条件

- iOS 15 及以上。
- Flutter 3.44 或更高版本；默认已启用 Swift Package Manager。若之前关闭过 SwiftPM，请在解析 Flutter App 前执行：

```bash
flutter config --enable-swift-package-manager
```

- 在 iOS app target 的 `Info.plist` 中增加 Jolibox 提供的 Google Mobile Ads 应用 ID：

```xml
<key>GADApplicationIdentifier</key>
<string>由 Jolibox 提供的值</string>
```

- 使用批准的 Flutter 桥接 Tag：

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: v0.4.0
```

- 桥接会传递解析公开的 `JoliboxSDKAll` `0.4.0` Swift Package。Flutter App 不要额外添加 Jolibox SDK、Google Mobile Ads、UMP 或 `IGList*` 依赖。

## 原生宿主边界

原生 iOS 宿主在 App 进程内负责一次 Jolibox SDK 和广告渠道初始化。应用启动时初始化基础 SDK；基础 SDK 就绪后、展示 Flutter 内容前初始化广告。初始化顺序与配置边界见[原生宿主初始化](NATIVE-HOST-INITIALIZATION.zh-CN.md)。

Flutter 仅通过业务 `scene` 调用桥接，不初始化 Jolibox、Google Mobile Ads、广告渠道或内部配置。

## Flutter Engine 注册

自定义或缓存 engine 必须在展示 Flutter 页面前注册生成的插件：

```swift
let engine = FlutterEngine(name: "your-flutter-engine")
engine.run()
GeneratedPluginRegistrant.register(with: engine)
openFlutterPage(engine: engine)
```

## 依赖规则

- 只使用桥接通过 Swift Package Manager 解析出的依赖图。
- 不要通过 `pod install` 交付本桥接；旧 CocoaPods 接入会明确报出配置错误。
- 不要嵌入旧 SDK archive，也不要重复添加 Google Mobile Ads、UMP 或 `IGList*` framework。
- 初始化始终由原生宿主负责，不要在 Flutter 侧增加初始化。

## 生产验收

生产上线前，需要在目标 iOS 环境验收宿主的一次初始化，以及 Banner、插屏、激励、生命周期、销毁和已支持回调的真实流程。
