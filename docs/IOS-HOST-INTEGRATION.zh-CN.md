# iOS 宿主接入（当前阻塞）

> **English documentation:** [iOS Host Integration (Blocked)](IOS-HOST-INTEGRATION.md)

## 状态

**尚未验收，不可交付。**

仓库中包含 iOS 桥接实现，但 iOS SDK 制品仓库和私有 CocoaPods Specs 分发尚未就绪，iOS QA 也尚未完成。本文档只描述未来接入结构。

在 Jolibox 明确确认 iOS 解阻前，不要开始 iOS 宿主接入、针对本插件执行 `pod install`，也不要在生产环境使用 iOS 桥接。

## 未来接入边界

iOS 解阻后，原生 iOS 宿主将：

- 在 App 进程内负责一次 Jolibox SDK 和广告渠道初始化；
- 使用公司批准的 `JoliboxSDKAll` CocoaPods 依赖；
- 使用宿主现有的 Flutter Add-to-App 架构嵌入 Flutter 模块；
- 为每个自定义或缓存的 `FlutterEngine` 注册插件。

Flutter 通过业务 `scene` 调用桥接，不初始化 SDK，也不访问渠道、广告位或内部配置。

## 未来 Podfile 结构

以下只是未来参考结构，当前不要执行：

```ruby
platform :ios, '15.0'

flutter_application_path = File.expand_path('../flutter_ads_module', __dir__)
podhelper = File.join(flutter_application_path, '.ios', 'Flutter', 'podhelper.rb')
require podhelper

target 'YourHost' do
  use_frameworks!
  install_all_flutter_pods(flutter_application_path)
end

post_install do |installer|
  flutter_post_install(installer)
end
```

只有 iOS 解阻后，宿主才能配置批准的私有 Specs 源、执行 `flutter pub get`、执行 `pod install` 并打开生成的 workspace。

## 未来 Flutter Engine 注册

如果使用自定义或缓存的 engine，宿主在展示 Flutter 页面前必须注册生成的 Flutter 插件：

```swift
let engine = FlutterEngine(name: "your-flutter-engine")
engine.run()
GeneratedPluginRegistrant.register(with: engine)
openFlutterPage(engine: engine)
```

具体 SDK 初始化 API 和配置值以批准的 iOS SDK 发布说明为准，不要从这个公开桥接仓库推断。

## 单一依赖规则

iOS 交付批准后，宿主只能使用批准的 `JoliboxSDKAll` 依赖。不要与旧 SDK-All 压缩包、独立 Google Mobile Ads 或 UMP 依赖、独立 `IGList*` XCFramework，或其他重复依赖混用。

## 解阻条件

必须同时满足：

- iOS SDK 制品仓库对目标构建环境可用；
- 私有 CocoaPods Specs 源可以解析批准版本的 `JoliboxSDKAll`；
- iOS 宿主完成依赖安装并成功构建；
- 初始化、Banner、插屏、激励、生命周期、销毁和回调 QA 全部通过；
- Jolibox 明确标记 iOS 已验收并可交付。
