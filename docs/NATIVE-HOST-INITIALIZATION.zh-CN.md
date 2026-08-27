# 原生宿主初始化

> **English documentation:** [Native Host Initialization](NATIVE-HOST-INITIALIZATION.md)

Flutter 桥接不会初始化 Jolibox 或广告渠道。Android 或 iOS 原生宿主必须在 Flutter 页面发起任何广告调用前，于每个 App 进程内仅完成一次以下初始化流程。

## 已批准的配置

请通过约定的交付渠道向 Jolibox 获取已批准的 `joliSource`、环境、scene 值和各平台宿主配置。不要硬编码、公开或提交这些值。本公开仓库不会包含配置接口、凭证或广告位 ID。

## Android 宿主

1. 按根目录 README 的 Android 前置条件接入已批准的 SDK-All 依赖和平台配置。
2. 原生 App 启动期间，仅调用一次 `Jolibox.init(applicationContext, suppliedJoliSource, hostProvider)`。其中 `hostProvider` 是宿主已批准的 `JoliboxSDKProvider` 实现。
3. 基础 SDK 配置完成后，仅调用一次 `JoliboxAds.initialize(context, callback)`。
4. 必须等待 `callback.onReady()` 后，才允许 Flutter 页面请求或展示广告；`onFailure(error)` 进入宿主正常的启动/错误处理流程。

不要在 Dart 中再次初始化 Jolibox、Google Mobile Ads 或其他广告渠道。若 App 使用缓存的 FlutterEngine，必须在展示可能请求广告的 Flutter 内容前完成上述原生初始化。

## iOS 宿主

1. 按 [iOS 宿主接入](IOS-HOST-INTEGRATION.zh-CN.md) 解析桥接及其传递依赖的 `JoliboxSDKAll` Swift Package，并配置 Jolibox 提供的 `GADApplicationIdentifier`。
2. 原生 App 启动期间，使用已批准的环境和 `joliSource` 配置 `JoliboxSDK.shared`，且仅配置一次。
3. 基础 SDK 配置完成后，仅 `await JoliboxAds.initialize()` 一次。
4. 仅在初始化成功后渲染 Flutter 广告页面或开放广告调用；初始化失败进入宿主正常的错误处理流程。

不要在 Dart 中初始化 Jolibox、Google Mobile Ads 或其他广告渠道。若使用自定义或缓存 FlutterEngine，请在展示 Flutter 页面前完成生成插件注册，具体见 iOS 宿主接入文档。

## Flutter 边界

Flutter 只向桥接传递业务 `scene` 并接收广告回调。渠道选择、广告位选择和配置均由原生 SDK 处理。重新进入 Flutter 页面不需要、也不得再次触发原生 SDK 初始化。
