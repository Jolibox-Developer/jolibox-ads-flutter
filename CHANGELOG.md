# Changelog

> **Chinese documentation:** [CHANGELOG.zh-CN.md](CHANGELOG.zh-CN.md)

## 0.4.0

- Adds fixed, Large Anchored Adaptive, and Inline Adaptive Banner sizing through the existing `JoliboxBannerAd` Widget.
- Requires the Host to provide the actual Banner-container width for adaptive requests; the Widget reserves no final Banner height until the native ad loads.
- Updates the Android bridge to use SDK-All `1.9.0-rc.23239` and the iOS bridge to use the matching iOS SDK `0.4.0` release.
- Changes `JoliboxBannerSize` from a Dart `enum` to a class; common fixed-size constants remain compatible, while enum-only usage (`values`, `index`, exhaustive `switch`) requires migration.

## 0.3.0

- Delivers the iOS bridge through Flutter Swift Package Manager support and the public `JoliboxSDKAll` `0.3.0` package.
- Requires iOS 15 or later and rejects unsupported CocoaPods integration with a clear setup error.
- Keeps the Android Flutter API and native Android bridge unchanged.

## 0.2.0

- Requires Android SDK-All `1.9.0-rc.22399`.
- Adds AdMob-shaped object APIs for interstitial and rewarded ads, plus callback entities for Banner and full-screen ads.
- Keeps the previous static full-screen API for source compatibility.
- Strengthens Android full-screen lifecycle handling for terminal and disposal events.

## 0.1.0

- Adds a shared Flutter API for Banner, interstitial, and rewarded ads.
- Provides Android and iOS bridge code in the repository. Android is the currently validated delivery target.
- Requires native-Host initialization before Flutter ad calls; Flutter does not initialize Jolibox or an ad provider.
- Forwards supported ad lifecycle callbacks without exposing revenue events such as `onPaidEvent`.
