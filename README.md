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
      ref: v0.1.0
```

Then run:

```bash
flutter pub get
```

Host applications should commit `pubspec.lock` when reproducible dependency resolution is required.

## Android prerequisites

1. Add the approved, matching Jolibox Android SDK-All dependency to the Android Host.
2. Configure the required AdMob Application ID in the Android Host manifest.
3. Initialize Jolibox once in the native Android Host before opening the Flutter page.
4. Do not add a second Jolibox SDK graph or manually initialize AdMob beside SDK-All.

The Flutter page may be embedded in an existing Android application. Flutter only calls the bridge; it does not own native initialization.

## Flutter API

The business `scene` is agreed between the Host business and Jolibox. It is a routing key, not an ad unit ID. Provider, channel, and ad unit selection remain internal to the native SDK.

### Banner

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

Dispose the banner widget/controller according to the Flutter page lifecycle. Do not keep a disposed banner mounted or reuse a disposed native view.

### Interstitial and rewarded

Load first, show after a successful load, and dispose an ad that will no longer be shown. A displayed ad object must not be reused. The current API exposes `show` and `disposeAd` as static methods on `JoliboxAdsFlutter`.

```dart
final interstitial = await JoliboxAdsFlutter.loadInterstitial(
  'YOUR_INTERSTITIAL_SCENE',
);
try {
  await JoliboxAdsFlutter.show(interstitial);
} finally {
  await JoliboxAdsFlutter.disposeAd(interstitial);
}

final rewarded = await JoliboxAdsFlutter.loadRewarded(
  'YOUR_REWARDED_SCENE',
);
try {
  await JoliboxAdsFlutter.show(
    rewarded,
    callbacks: JoliboxFullscreenAdCallbacks(
      onUserEarnedReward: () {},
    ),
  );
} finally {
  await JoliboxAdsFlutter.disposeAd(rewarded);
}
```

Use the callback API exposed by the plugin for lifecycle and result handling. Revenue events such as `onPaidEvent` are intentionally not exposed to the Host API.

## Compatibility and verification

- Existing Android Game and Drama ad flows must be regression-tested in the native Android Demo after upgrading SDK-All.
- Flutter bridge verification covers the Android mixed-host scenario: native Android initializes the SDK, then a Flutter page displays ads through scene calls.
- Staging/test configurations may use test ad units. Production must use the approved production configuration and must never use test ad units.
- Pin the Flutter plugin to an approved release tag and use a matching SDK-All version.

## iOS integration status

The repository contains iOS bridge code for future integration, but it is not a current delivery target. Do not add the plugin to an iOS Host, configure private Specs, or run `pod install` until the iOS artifact repository is available and Jolibox confirms iOS QA acceptance.

See [iOS Host Integration](docs/IOS-HOST-INTEGRATION.md) for the blocked future integration shape.

## Support

Before integrating, confirm the approved plugin tag, Android SDK-All version, environment, and scene values with Jolibox. Do not publish private artifact URLs, credentials, internal configuration endpoints, or ad unit IDs in the Host application documentation.

## Related documentation

- [Release Guide](docs/RELEASE.md)
- [iOS Host Integration](docs/IOS-HOST-INTEGRATION.md) (blocked until iOS acceptance)
- [Changelog](CHANGELOG.md)
