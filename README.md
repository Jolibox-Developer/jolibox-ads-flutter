# Jolibox Ads Flutter

`jolibox_ads_flutter` is the public Flutter bridge for scene-based Jolibox banner, interstitial, and rewarded ads.

> **Chinese documentation:** [README.zh-CN.md](README.zh-CN.md)

## Delivery status

- **Android:** current validated delivery target.
- **iOS:** bridge code exists, but iOS is not accepted for delivery yet. The iOS SDK artifact repository and private CocoaPods Specs distribution are not ready. Do not start iOS Host integration, run `pod install` for this plugin, or use the iOS bridge in production until Jolibox confirms artifact availability and iOS QA acceptance.

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
      ref: v0.2.0
```

Then run:

```bash
flutter pub get
```

Host applications should commit `pubspec.lock` when reproducible dependency resolution is required.

## Android prerequisites

1. In the Android Host's `settings.gradle`, add the required Maven repositories to the existing `dependencyResolutionManagement.repositories` block. Keep `public` before `android-internal`, and do not create a second repositories block:

```gradle
dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
    maven { url = uri('https://repo.jolibox.com/repository/public/') }
    maven { url = uri('https://repo.jolibox.com/repository/android-internal/') }
  }
}
```

Then add the approved matching SDK-All dependency in the Android app module's `build.gradle`:

```gradle
dependencies {
  implementation 'com.jolibox.android:jolibox-platform-sdk-all:1.9.0-rc.22399'
}
```

If the Host already completed the native Android SDK integration in an earlier phase, keep that same approved SDK-All version and Maven configuration. Do not add a second Jolibox SDK graph or a different SDK-All version for Flutter.

2. Configure the required AdMob Application ID in the Android Host manifest.
3. Complete the one-time `Jolibox.init(...)` and `JoliboxAds.initialize(...)` flow in the native Android Host, using the separately supplied Android SDK-All integration guide, before opening the Flutter page.
4. Do not add a second Jolibox SDK graph or manually initialize AdMob beside SDK-All.

The Flutter page may be embedded in an existing Android application. Flutter only calls the bridge; it does not own native initialization.

## Flutter API

The business `scene` is agreed between the Host business and Jolibox. It is a routing key, not an ad unit ID. Provider, channel, and ad unit selection remain internal to the native SDK.

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

The repository contains iOS bridge code for future integration, but it is not a current delivery target. Do not add the plugin to an iOS Host, configure private Specs, or run `pod install` until the iOS artifact repository is available and Jolibox confirms iOS QA acceptance.

See [iOS Host Integration](docs/IOS-HOST-INTEGRATION.md) for the blocked future integration shape.

## Support

Before integrating, confirm the approved plugin tag, Android SDK-All version, environment, and scene values with Jolibox. Do not publish repository credentials, internal configuration endpoints, or ad unit IDs in the Host application documentation.

## Related documentation

- [Release Guide](docs/RELEASE.md)
- [iOS Host Integration](docs/IOS-HOST-INTEGRATION.md) (blocked until iOS acceptance)
- [Changelog](CHANGELOG.md)
