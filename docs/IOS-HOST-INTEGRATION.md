# iOS Host Integration (Blocked) / iOS 宿主接入（当前阻塞）

> **Status / 状态: NOT ACCEPTED FOR DELIVERY / 尚未验收，不可交付**
>
> The iOS bridge code is present in this repository, but the iOS SDK artifact repository and private CocoaPods Specs distribution are currently not ready. iOS Host integration, `pod install`, runtime verification, and production use are blocked until Jolibox confirms that the artifacts are available and the iOS Host passes QA.
>
> 本仓库虽然已经包含 iOS 桥接代码，但 iOS SDK 制品仓库和私有 CocoaPods Specs 分发目前仍未就绪。iOS 宿主接入、`pod install`、运行验证和生产使用均已阻塞，必须等待 Jolibox 确认制品可用并完成 iOS 宿主 QA 验收。

This document describes the intended future integration shape only. It is not a current iOS delivery instruction.

本文仅描述未来的接入结构，不是当前可执行的 iOS 交付接入说明。

The `JoliboxSDKAll` version declared by the plugin Podspec is a future compatibility contract only. It does not confirm that the artifact repository can currently resolve that version.

插件 Podspec 中声明的 `JoliboxSDKAll` 版本目前仅代表未来的兼容性契约，不代表制品仓库当前已经可以解析该版本。

## Future prerequisites / 未来前置条件

When iOS delivery is unblocked, the iOS Host is expected to:

待 iOS 交付解阻后，iOS 宿主预计需要：

- Integrate the company-approved `JoliboxSDKAll` CocoaPods dependency.
- 接入公司批准的 `JoliboxSDKAll` CocoaPods 依赖。
- Initialize the Jolibox SDK and ads exactly once per App process before opening Flutter.
- 在打开 Flutter 前，按 App 进程只初始化一次 Jolibox SDK 和广告能力。
- Use Flutter Add-to-App CocoaPods integration and register plugins for any custom or cached `FlutterEngine`.
- 使用 Flutter Add-to-App CocoaPods 接入；如果使用自定义或缓存 `FlutterEngine`，需要完成插件注册。

Do not execute the following steps until Jolibox confirms the iOS artifact repository and Specs distribution are ready.

在 Jolibox 确认 iOS 制品仓库和 Specs 分发就绪前，不要执行下面的步骤。

## Future Host Podfile shape / 未来宿主 Podfile 结构

The following is a future reference example only:

以下仅作为未来参考示例：

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

Only after the release is unblocked should the Host run `flutter pub get`, configure the approved private Specs source, run `pod install`, and open the generated `.xcworkspace`.

只有在 iOS 版本解阻后，宿主才能执行 `flutter pub get`、配置批准的私有 Specs 源、执行 `pod install` 并打开生成的 `.xcworkspace`。

## Future Host lifecycle / 未来宿主生命周期

```swift
try await JoliboxAds.initialize()

let engine = FlutterEngine(name: "your-flutter-engine")
engine.run()
GeneratedPluginRegistrant.register(with: engine)
openFlutterPage(engine: engine)
```

The exact SDK configuration values belong to the native Host integration. Flutter must not initialize the SDK or access advertising configuration.

具体 SDK 配置值属于原生宿主接入内容。Flutter 不得初始化 SDK，也不得访问广告配置。

## Future single-copy rule / 未来单一依赖规则

When iOS delivery is approved, `JoliboxSDKAll` should be the only approved iOS SDK dependency visible to the Host. Do not mix it with:

当 iOS 交付获批准后，宿主应只使用批准的 `JoliboxSDKAll` iOS SDK 依赖，不要与以下依赖混用：

- an old SDK-All ZIP linked manually in Xcode / 手动链接到 Xcode 的旧 SDK-All ZIP；
- `Google-Mobile-Ads-SDK` or `GoogleUserMessagingPlatform` / `Google-Mobile-Ads-SDK` 或 `GoogleUserMessagingPlatform`；
- standalone GMA, UMP, or `IGList*` XCFrameworks / 独立的 GMA、UMP 或 `IGList*` XCFramework；
- equivalent Swift Package Manager dependencies / 等价的 Swift Package Manager 依赖。

## Unblocking criteria / 解阻条件

iOS can be reconsidered only after all of the following are true:

只有满足以下全部条件后，才能重新评估 iOS 接入：

- The iOS SDK artifact repository is available to the intended Host build environment.
- iOS SDK 制品仓库已对目标宿主构建环境可用。
- The private CocoaPods Specs source resolves the approved `JoliboxSDKAll` version.
- 私有 CocoaPods Specs 源可以解析批准版本的 `JoliboxSDKAll`。
- The iOS Host completes dependency installation and build verification.
- iOS 宿主完成依赖安装和构建验证。
- Banner, interstitial, rewarded, initialization, lifecycle, and callback QA pass.
- Banner、插屏、激励、初始化、生命周期和回调 QA 全部通过。
- Jolibox explicitly confirms that iOS is accepted for delivery.
- Jolibox 明确确认 iOS 已通过验收并可交付。
