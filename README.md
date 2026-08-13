# Jolibox Ads Flutter

`jolibox_ads_flutter` is the public Flutter bridge for scene-based Jolibox banner, interstitial, and rewarded ads.

`jolibox_ads_flutter` 是 Jolibox 面向 Flutter 宿主提供的公开广告桥接插件，支持通过业务场景值调用 Banner、插屏和激励广告。

The native Android or iOS Host owns SDK initialization. Flutter must not initialize Jolibox, AdMob, or any other ad provider.

Android 或 iOS 原生宿主负责 SDK 初始化。Flutter 不需要、也不应该初始化 Jolibox、AdMob 或其他广告渠道。

## Architecture / 接入边界

```text
Native Host initializes the Jolibox SDK once
原生宿主只初始化一次 Jolibox SDK
                ↓
Flutter calls the bridge with a business scene
Flutter 只通过业务 scene 调用桥接
                ↓
Jolibox SDK selects the provider and ad unit internally
Jolibox SDK 内部选择广告渠道和广告位
```

Flutter does not know the advertising provider, ad unit ID, or internal advertising configuration.

Flutter 不需要知道广告渠道、广告位 ID 或内部广告配置。

## Installation / 安装

Use a fixed release tag from the Jolibox GitHub repository.

请使用 Jolibox GitHub 仓库中的固定发布 Tag：

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: v0.1.0
```

Then run the following command:

然后执行：

```bash
flutter pub get
```

Commit `pubspec.lock` in host applications when the team needs reproducible dependency resolution.

如果宿主团队需要保证依赖解析一致，建议提交宿主项目中的 `pubspec.lock`。

## Native prerequisites / 原生前置条件

### Android

- Configure the matching Jolibox Android SDK-All dependency in the Android Host.
- The Android Host initializes Jolibox once and opens Flutter only after ad initialization succeeds.
- Configure the required AdMob Application ID in the Android Host Manifest.
- Do not manually add another Jolibox SDK or AdMob initialization beside the approved SDK-All dependency graph.

### Android 中文说明

- Android 宿主配置与 Flutter Plugin 兼容的 Jolibox Android SDK-All 依赖。
- Android 宿主只初始化一次 Jolibox，并在广告初始化成功后再打开 Flutter 页面。
- 在 Android 宿主 Manifest 中配置所需的 AdMob Application ID。
- 不要在 SDK-All 之外重复添加另一套 Jolibox SDK，也不要自行调用 AdMob 初始化。

### iOS

> **iOS delivery blocked / iOS 交付阻塞：** The iOS bridge code is present, but iOS is **not accepted for delivery yet**. The iOS SDK artifact repository and private CocoaPods Specs distribution are currently not ready. Do not start iOS Host integration, run `pod install` for this plugin, or treat the iOS bridge as production-ready until Jolibox confirms artifact availability and completes iOS QA.

> **iOS 当前尚未验收：**仓库中虽然已经包含 iOS 桥接代码，但 iOS **尚未验收，不属于当前可交付能力**。由于 iOS SDK 制品仓库和私有 CocoaPods Specs 分发仍存在问题，宿主暂时不要开始 iOS 接入，不要针对本插件执行 `pod install`，也不要将 iOS 桥接视为可用于生产的能力；必须等待 Jolibox 确认制品可用并完成 iOS QA 验收。

The following notes describe the intended future integration boundary only; they are not a current delivery instruction.

以下内容仅描述未来的接入边界，不代表当前可以执行 iOS 接入。

- The iOS Host will own Jolibox SDK initialization once.
- 未来由 iOS 宿主负责 Jolibox SDK 初始化，且每个 App 进程只初始化一次。
- The iOS Host will use the company-approved Jolibox iOS SDK-All CocoaPods dependency.
- 未来由 iOS 宿主使用公司批准的 Jolibox iOS SDK-All CocoaPods 依赖。
- Do not publish private SDK binaries, artifact credentials, or private repository details in this public repository.
- 不要在这个公开仓库中发布私有 SDK 二进制、制品凭证或私有仓库详情。

## Flutter usage / Flutter 调用

Flutter calls ads with a business `scene`. The `scene` is agreed between the host business and Jolibox. It is not an ad unit ID.

Flutter 通过业务 `scene` 调用广告。`scene` 由宿主业务与 Jolibox 共同约定，不是广告位 ID。

```dart
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

JoliboxBannerAd(
  scene: 'YOUR_BANNER_SCENE',
  onLoaded: () {},
  onFailedToLoad: (error) {},
  onImpression: () {},
  onClicked: () {},
  onOpened: () {},
  onClosed: () {},
)
```

For interstitial and rewarded ads, load first, show once, and dispose loaded ads that will no longer be shown.

插屏和激励广告必须先加载、再展示；一个已展示的广告对象不能重复使用，不再展示的已加载广告需要释放。

```dart
final ad = await JoliboxAdsFlutter.loadInterstitial(
  'YOUR_INTERSTITIAL_SCENE',
);

final result = await JoliboxAdsFlutter.show(
  ad,
  callbacks: JoliboxFullscreenAdCallbacks(
    onAdShowedFullScreenContent: () {},
    onAdImpression: () {},
    onAdClicked: () {},
    onAdDismissedFullScreenContent: () {},
    onAdFailedToShowFullScreenContent: (error) {},
  ),
);

// result.clicked indicates whether the ad was clicked.
// result.clicked 表示本次展示是否发生点击。
```

Use `loadRewarded` and `onUserEarnedReward` for rewarded ads. Only grant business rewards after `onUserEarnedReward` is received.

激励广告使用 `loadRewarded` 和 `onUserEarnedReward`。只有收到 `onUserEarnedReward` 后，宿主才能发放业务奖励。

## Callbacks / 回调

The bridge exposes the following callbacks to Flutter hosts.

插件向 Flutter 宿主提供以下回调：

### Banner

- `onLoaded` — Banner load succeeded / Banner 加载成功
- `onFailedToLoad` — Banner load failed / Banner 加载失败
- `onImpression` — Banner impression / Banner 曝光
- `onClicked` — Banner clicked / Banner 点击
- `onOpened` — Ad overlay opened / 广告覆盖层打开
- `onClosed` — Ad overlay closed / 广告覆盖层关闭

### Interstitial and rewarded / 插屏和激励

- `onAdShowedFullScreenContent` — full-screen content shown / 全屏广告展示
- `onAdImpression` — impression / 曝光
- `onAdClicked` — clicked / 点击
- `onAdDismissedFullScreenContent` — dismissed / 关闭
- `onAdFailedToShowFullScreenContent` — show failed / 展示失败
- `onUserEarnedReward` — rewarded user callback / 用户获得激励，仅激励广告提供

`onPaidEvent` is not exposed to Flutter hosts.

`onPaidEvent` 不对 Flutter 宿主开放，宿主不需要实现收入事件处理。

## Lifecycle / 生命周期

- Keep Jolibox SDK initialization process-scoped and execute it once per app process.
- Open Flutter pages only after native ad initialization succeeds.
- Remove `JoliboxBannerAd` from the Widget tree when the page no longer needs it.
- Dispose loaded interstitial or rewarded ads that will not be shown.
- Do not reuse a full-screen ad object after it has been shown.
- If using a cached or custom `FlutterEngine`, ensure this plugin is registered with that Engine.

- Jolibox SDK 初始化按 App 进程管理，每个进程只执行一次。
- 只有原生广告初始化成功后，才能打开包含广告调用的 Flutter 页面。
- 页面不再需要 Banner 时，将 `JoliboxBannerAd` 从 Widget 树中移除。
- 不再展示的已加载插屏或激励广告需要调用 `disposeAd` 释放。
- 全屏广告对象展示后不能再次复用。
- 如果宿主使用缓存或自定义 `FlutterEngine`，必须确认插件已注册到该 Engine。

## Game / Drama compatibility / Game 与 Drama 兼容性

The Flutter bridge does not change the existing Android Game or Drama APIs. However, Flutter Banner/interstitial/rewarded verification does not replace the host's real Game/Drama regression.

Flutter 桥接不会修改 Android 现有 Game 或 Drama API。但是，Flutter Banner、插屏、激励的验证不能替代宿主真实 Game/Drama 页面回归。

Before release, hosts must verify their real Game and Drama pages, including ad loading, playback, return navigation, app restart, and re-entry after visiting Flutter pages.

正式发布前，宿主必须使用真实 Game 和 Drama 页面验证广告加载、播放、返回导航、App 重启，以及从 Flutter 页面返回后再次进入的行为。

## Version and release requirements / 版本与发布要求

- Keep the Flutter Git tag and native Android/iOS SDK versions compatible.
- Use staging sources and test IDs only in staging/test builds.
- Production builds must not contain staging test IDs or hard-coded test ad unit IDs.
- Do not publish SDK binaries, credentials, private artifact locations, advertising configuration, or internal routing code here.

- Flutter Git Tag 与 Android/iOS 原生 SDK 版本必须兼容。
- staging/测试包只能使用 staging 配置和测试 ID。
- 正式包不得包含 staging 测试 ID，也不得写死测试广告位 ID。
- 不要在本公开仓库中发布 SDK 二进制、凭证、私有制品地址、广告配置或内部路由代码。

## Support / 支持

For licensing, integration, or support inquiries, contact [contact@jolibox.com](mailto:contact@jolibox.com).

如有授权、接入或技术支持问题，请联系 [contact@jolibox.com](mailto:contact@jolibox.com)。

See [`docs/RELEASE.md`](docs/RELEASE.md) for the release model.

发布流程请参阅 [`docs/RELEASE.md`](docs/RELEASE.md)。
