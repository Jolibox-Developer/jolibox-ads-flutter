# Jolibox Ads Flutter

`jolibox_ads_flutter` is the public Flutter bridge for scene-based Jolibox banner, interstitial, and rewarded ads.

> **Chinese documentation:** [README.zh-CN.md](README.zh-CN.md)

## Delivery status

- **Android:** current validated delivery target.
- **iOS:** delivered through Swift Package Manager using the matching public iOS SDK release. CocoaPods is not a supported iOS delivery path. Complete Host runtime acceptance before production rollout.

## Architecture

```text
Native Host initializes the Jolibox SDK once
                ↓
Flutter calls the bridge with a business scene
                ↓
Jolibox SDK selects the provider and ad unit internally
```

The native Host owns Jolibox SDK and ad-provider initialization. Flutter must not initialize Jolibox, AdMob, or another ad provider. Flutter does not need to know the provider, ad unit ID, or internal configuration.

## Installation

Use a fixed release tag from the public GitHub repository:

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: v0.4.0
```

Then run:

```bash
flutter pub get
```

Host applications should commit `pubspec.lock` when reproducible dependency resolution is required.

## Android prerequisites

1. In the Android Host root `build.gradle`, add the required Maven repositories to the existing `allprojects.repositories` block. Flutter's Android tooling declares project-level repositories for engine artifacts, so placing these repositories only in `settings.gradle` can be ignored. Keep `public` before `android-internal`:

```gradle
allprojects {
  repositories {
    // Keep the Host's existing repositories.
    maven { url = uri('https://repo.jolibox.com/repository/public/') }
    maven { url = uri('https://repo.jolibox.com/repository/android-internal/') }
  }
}
```

For Kotlin DSL, use `maven(url = "https://repo.jolibox.com/repository/public/")` and the equivalent `android-internal` URL.

If the Host enforces `RepositoriesMode.FAIL_ON_PROJECT_REPOS`, do not add this project-level block unchanged: Flutter also declares project repositories for its engine artifacts, so the Host build owner must add both Jolibox repositories and retain the required Flutter engine repository in the existing settings-level repository policy. Validate the final policy with `assembleDebug`.

Then add the approved matching SDK-All dependency in the Android app module's `build.gradle`:

```gradle
dependencies {
  implementation 'com.jolibox.android:jolibox-platform-sdk-all:1.9.0-rc.23239'
}
```

If the Host already completed the native Android SDK integration in an earlier phase, keep that same approved SDK-All version and Maven configuration. Do not add a second Jolibox SDK graph or a different SDK-All version for Flutter.

2. Configure the required AdMob Application ID in the Android Host manifest.
3. Complete the one-time `Jolibox.init(...)` and `JoliboxAds.initialize(...)` flow in the native Android Host before opening the Flutter page. See [Native Host Initialization](docs/NATIVE-HOST-INITIALIZATION.md) for the required ownership, order, and configuration boundary.
4. Do not add a second Jolibox SDK graph or manually initialize AdMob beside SDK-All.

The Flutter page may be embedded in an existing Android application. Flutter only calls the bridge; it does not own native initialization.

### Custom or cached FlutterEngine

The standard `FlutterActivity` flow needs no extra Jolibox plugin-registration code. If the Host creates or caches its own `FlutterEngine`, follow Flutter's normal add-to-app lifecycle: execute the Dart entrypoint before caching the engine, then attach it with `FlutterActivity.withCachedEngine(...)`. Keep the default Activity attachment enabled because fullscreen ads require the foreground Activity.

```kotlin
val flutterEngine = FlutterEngine(applicationContext)
flutterEngine.dartExecutor.executeDartEntrypoint(
  DartExecutor.DartEntrypoint.createDefault(),
)
FlutterEngineCache.getInstance().put("host_ads_engine", flutterEngine)

startActivity(
  FlutterActivity.withCachedEngine("host_ads_engine").build(this),
)
```

Use the Host project's normal generated Flutter plugin-registration setup. Do not manually construct `JoliboxAdsFlutterPlugin`, and do not initialize Jolibox or AdMob from Dart.

## Flutter API

The business `scene` is agreed between the Host business and Jolibox. It is a routing key, not an ad unit ID. Provider, channel, and ad unit selection remain internal to the native SDK.

### 0.4.0 source compatibility

`JoliboxBannerSize` is now a class so adaptive constructors can accept width and optional maximum height. The common fixed-size calls remain unchanged: `JoliboxBannerSize.banner`, `JoliboxBannerSize.largeBanner`, and `JoliboxBannerSize.mediumRectangle`. Code that relied on the old Dart `enum` members (`values`, `index`, or exhaustive `switch` behavior) must be migrated and recompiled for `0.4.0`.

### Banner

```dart
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

JoliboxBannerAd(
  scene: 'YOUR_BANNER_SCENE',
  callbacks: JoliboxBannerAdCallbacks(
    onLoaded: () {},
    onFailedToLoad: (error) {},
    onImpression: () {},
    onClicked: () {},
    onOpened: () {},
    onClosed: () {},
  ),
)
```

Dispose the banner widget according to the Flutter page lifecycle. Do not keep a disposed banner mounted or reuse a disposed native view.

### Adaptive Banner

Use the actual width available to the Banner's parent layout. The plugin does not infer screen width. `LayoutBuilder` is the recommended Flutter pattern:

```dart
LayoutBuilder(
  builder: (context, constraints) => JoliboxBannerAd(
    scene: 'YOUR_BANNER_SCENE',
    size: JoliboxBannerSize.largeAnchoredAdaptive(
      width: constraints.maxWidth,
    ),
  ),
)
```

Use `largeAnchoredAdaptive` for a Banner anchored at the top or bottom of a page. Use `inlineAdaptive` for a Banner inserted in scrolling content; `maxHeight` is optional and, when supplied, must be at least `32` logical pixels:

```dart
JoliboxBannerAd(
  scene: 'YOUR_INLINE_BANNER_SCENE',
  size: JoliboxBannerSize.inlineAdaptive(width: bannerWidth, maxHeight: 100),
)
```

Adaptive Banner widgets do not reserve their final Banner height before an ad loads or after a load failure. A one-logical-pixel internal bootstrap layout allows the native PlatformView to start loading; it is replaced with the actual size resolved by Google Mobile Ads on success. Changing the scene, size mode, width, or `maxHeight` disposes the old native Banner and requests a new one.

### Interstitial and rewarded

Load first and show after a successful load. Dispose an ad that will no longer be shown. A displayed ad object must not be reused; the bridge automatically releases its native reference after dismissal or a show failure. Await every `show` call: a second fullscreen ad is rejected until the current one finishes.

```dart
JoliboxInterstitialAd? interstitialAd;

Future<void> loadInterstitial() => JoliboxInterstitialAd.load(
  scene: 'YOUR_INTERSTITIAL_SCENE',
  adLoadCallback: JoliboxInterstitialAdLoadCallback(
    onAdLoaded: (ad) => interstitialAd = ad,
    onAdFailedToLoad: (error) {},
  ),
);

Future<void> showInterstitial() async {
  final ad = interstitialAd;
  if (ad == null) return;
  interstitialAd = null;
  ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
    onAdImpression: () {},
    onAdClicked: () {},
    onAdDismissedFullScreenContent: () {},
    onAdFailedToShowFullScreenContent: (error) {},
  );
  try {
    await ad.show();
  } finally {
    await ad.dispose();
  }
}

JoliboxRewardedAd? rewardedAd;

Future<void> loadRewarded() => JoliboxRewardedAd.load(
  scene: 'YOUR_REWARDED_SCENE',
  adLoadCallback: JoliboxRewardedAdLoadCallback(
    onAdLoaded: (ad) => rewardedAd = ad,
    onAdFailedToLoad: (error) {},
  ),
);

Future<void> showRewarded() async {
  final ad = rewardedAd;
  if (ad == null) return;
  rewardedAd = null;
  ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
    onAdDismissedFullScreenContent: () {},
    onAdFailedToShowFullScreenContent: (error) {},
  );
  try {
    await ad.show(onUserEarnedReward: () {});
  } finally {
    await ad.dispose();
  }
}
```

Call `showInterstitial()` or `showRewarded()` from an awaited Host business event, such as a button handler. Use the callback API exposed by the plugin for lifecycle and result handling. Revenue events such as `onPaidEvent` are intentionally not exposed to the Host API.

The previous `JoliboxAdsFlutter.load...`, `show`, and `disposeAd` static APIs remain available for source compatibility. New integrations should use the object APIs above.

## Compatibility and verification

- Existing Android Game and Drama ad flows must be regression-tested in the native Android Demo after upgrading SDK-All.
- Flutter bridge verification covers the Android mixed-host scenario: native Android initializes the SDK, then a Flutter page displays ads through scene calls.
- Staging/test configurations may use test ad units. Production must use the approved production configuration and must never use test ad units.
- Pin the Flutter plugin to an approved release tag and use a matching SDK-All version.

## iOS integration status

The iOS bridge requires Flutter `3.44` or later. Swift Package Manager support is enabled by default in that release. If it was previously disabled, enable it before resolving the Flutter app:

```bash
flutter config --enable-swift-package-manager
```

The iOS Host resolves the public `Jolibox-Developer/jolibox-ios-sdk` repository and its release assets without GitHub repository credentials. The native iOS Host initializes Jolibox once before rendering Flutter; Flutter must not initialize Jolibox or Google Mobile Ads. Do not use `pod install` to deliver this bridge.

The SPM package-resolution and build path has been validated. Complete Host runtime acceptance before production rollout.

## Support

Before integrating, confirm the approved plugin tag, Android SDK-All version, environment, and scene values with Jolibox. Do not publish repository credentials, internal configuration endpoints, or ad unit IDs in the Host application documentation.

## Related documentation

- [iOS Host Integration](docs/IOS-HOST-INTEGRATION.md)
- [Native Host Initialization](docs/NATIVE-HOST-INITIALIZATION.md)
- [Changelog](CHANGELOG.md)
