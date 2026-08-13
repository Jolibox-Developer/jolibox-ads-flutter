# 发布指南

> **English documentation:** [Release Guide](RELEASE.md)

## 范围

本仓库发布公开 Flutter 桥接插件。Android 宿主提供批准的 Jolibox SDK-All 依赖并负责原生初始化。Flutter 插件不会打包或初始化 Jolibox、AdMob 或其他广告渠道。

## 发布检查清单

### Android

- 使用批准的 Android SDK-All 版本验证插件 API。
- 验证 Android 混编流程：原生初始化、打开 Flutter 页面，以及通过 scene 调用 Banner、插屏和激励广告。
- 回归原生 Android Demo 中已有的 Game 和 Drama 广告流程。
- 确认 staging/test 配置只使用测试广告位。
- 确认生产配置只使用批准的生产广告位。
- 验证所有广告类型的生命周期和销毁行为。
- 确认已支持的回调可以透传，且 `onPaidEvent` 不暴露给宿主 API。

### iOS——阻塞

iOS 桥接代码存在，但 iOS **尚未验收，不可交付**。iOS SDK 制品仓库和私有 CocoaPods Specs 分发尚未就绪，iOS QA 也未完成。

在解阻前不要：

- 开始 iOS 宿主接入；
- 为本版本配置私有 Specs；
- 针对本插件执行 `pod install`；
- 在生产环境使用 iOS 桥接；
- 将 iOS 描述为已支持的交付目标。

只有 Jolibox 确认制品可用、依赖可解析、宿主构建成功并完成 iOS QA 后，才能进入 iOS 发布验证。

## 版本管理

- 从批准的 Git Tag 发布 Flutter 插件。
- 明确记录 Flutter 插件 Tag 与 Android SDK-All 版本的匹配关系。
- 不要发布私有仓库地址、凭证、内部配置接口或广告位 ID。
- 每次公开发布都更新 `CHANGELOG.md` 和 `CHANGELOG.zh-CN.md`。

## 宿主依赖规则

宿主应使用一套批准的 SDK-All 依赖图。不要添加并行 Jolibox SDK 依赖，也不要在 SDK-All 旁边手动初始化 AdMob。Flutter 只提供 UI/API 桥接，不负责原生 SDK 初始化。

## 发布验收

Android 混编验证和原生 Game/Drama 回归全部通过后，Android 才可以发布。iOS 必须等到制品和 QA 明确验收后才能解阻。
