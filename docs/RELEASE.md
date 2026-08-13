# Jolibox Flutter Plugin Release Guide / Jolibox Flutter 插件发布指南

## Purpose / 目的

`jolibox_ads_flutter` is a public GitHub Flutter bridge. It provides the Dart API, Android bridge, and iOS bridge. It does not include native SDK binaries, advertising configuration, credentials, or internal service implementations.

`jolibox_ads_flutter` 是公开发布在 GitHub 的 Flutter 广告桥接插件，提供 Dart API、Android 桥接和 iOS 桥接。不包含原生 SDK 二进制、广告配置、凭证或内部服务实现。

Hosts reference a fixed Git tag:

宿主必须引用固定 Git Tag：

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: v0.1.0
```

## Integration boundary / 接入边界

| Platform / 平台 | Flutter bridge / Flutter 桥接 | Native SDK distribution / 原生 SDK 分发 | Initialization owner / 初始化方 |
|---|---|---|---|
| Android | Android implementation in this repository / 本仓库 Android 实现 | Jolibox-approved Android SDK-All / Jolibox 批准的 Android SDK-All | Android Host, once / Android 宿主，只初始化一次 |
| iOS | `ios/Classes` in this repository / 本仓库 `ios/Classes` | Jolibox-approved iOS SDK-All CocoaPods / Jolibox 批准的 iOS SDK-All CocoaPods | iOS Host, once / iOS 宿主，只初始化一次 |

> **iOS delivery status / iOS 交付状态:** The iOS bridge code is present, but iOS is **not accepted for delivery yet**. The iOS SDK artifact repository and private CocoaPods Specs distribution are currently not ready. Hosts must not begin iOS integration or treat the iOS bridge as production-ready until Jolibox confirms artifact availability and completes iOS QA.
>
> **iOS 当前状态：**仓库中虽然已经包含 iOS 桥接代码，但 iOS **尚未验收，不属于当前可交付能力**。由于 iOS SDK 制品仓库和私有 CocoaPods Specs 分发仍未准备好，宿主暂时不要开始 iOS 接入，也不要将 iOS 桥接视为可用于生产的能力；必须等待 Jolibox 确认制品可用并完成 iOS QA 验收。

Flutter does not initialize the SDK and does not process advertising-provider selection, ad unit IDs, or advertising configuration. Flutter passes only a business `scene`.

Flutter 不初始化 SDK，也不处理广告渠道选择、广告位 ID 或广告配置。Flutter 只传递业务 `scene`。

## Release checklist / 发布检查清单

1. Use a semantic Flutter Plugin version and a Git tag such as `v0.1.0`.
2. 使用语义化 Flutter Plugin 版本，并创建类似 `v0.1.0` 的 Git Tag。
3. Confirm the Android Host resolves the compatible approved Android SDK version. The iOS check is blocked until the iOS artifacts and private Specs distribution are ready.
4. 确认 Android 宿主解析到兼容且已批准的 Android SDK 版本。iOS 检查项当前阻塞，必须等待 iOS 制品和私有 Specs 分发就绪后再执行。
5. Run `flutter analyze` and `flutter test`.
6. 执行 `flutter analyze` 和 `flutter test`。
7. Build and verify the Android Host.
8. 构建并验证 Android 宿主。
9. **Blocked / 当前阻塞:** Verify the iOS Host through its approved CocoaPods integration and build pipeline only after Jolibox unblocks iOS delivery.
10. **当前阻塞：**只有 Jolibox 解阻 iOS 交付后，才能通过批准的 CocoaPods 接入和构建流程验证 iOS 宿主。
11. Ensure the repository contains no SDK binaries, private artifact locations, credentials, test configuration, advertising configuration, or internal routing code.
12. 确保仓库不包含 SDK 二进制、私有制品地址、凭证、测试配置、广告配置或内部路由代码。
13. Ensure [`LICENSE`](../LICENSE) and public contact information are present before publishing or tagging.
14. 发布或打 Tag 前，确认 [`LICENSE`](../LICENSE) 和公开联系信息已存在。

## iOS release model / iOS 发布模型

The iOS SDK-All dependency is distributed through Jolibox's private CocoaPods Specs and artifact infrastructure. The public Flutter bridge declares the compatible SDK version, while its binary artifacts and distribution details remain private.

iOS SDK-All 通过 Jolibox 私有 CocoaPods Specs 和制品基础设施分发。公开 Flutter 桥接只声明兼容的 SDK 版本，二进制制品和分发细节保持私有。

The exact `JoliboxSDKAll` version declared by the public Flutter Plugin Podspec is a future compatibility contract only. It does not mean that the iOS artifact is currently available, resolvable, or accepted for delivery.

公开 Flutter Plugin Podspec 中声明的 `JoliboxSDKAll` 版本目前仅代表未来的兼容性契约，不代表对应 iOS 制品当前已经可用、可解析或通过交付验收。

Hosts must follow the company-provided iOS integration instructions. Do not manually add duplicate Jolibox SDK or ad-provider dependencies alongside the approved SDK-All integration.

宿主必须遵循公司提供的 iOS 接入说明。不要在批准的 SDK-All 接入之外手动添加重复的 Jolibox SDK 或广告渠道依赖。

The iOS release model remains blocked until the artifact repository and Specs distribution are fixed and the iOS Host integration passes QA.

在制品仓库和 Specs 分发问题解决、且 iOS 宿主接入通过 QA 之前，iOS 发布流程保持阻塞状态。

## Support / 支持

For licensing, integration, or support inquiries, contact [contact@jolibox.com](mailto:contact@jolibox.com).

如有授权、接入或技术支持问题，请联系 [contact@jolibox.com](mailto:contact@jolibox.com)。
