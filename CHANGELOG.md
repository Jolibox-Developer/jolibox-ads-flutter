# Changelog

> 中文说明：[CHANGELOG_CN.md](CHANGELOG_CN.md)

## 0.6.4

- Uses Kotlin `2.0.21`, Android Gradle Plugin `8.6.1`, and Gradle `8.7` while retaining `compileSdk 35` and Java 17.
- Updates the Android native mediation dependency to Kotlin `2.0.21` compatible release `0.6.2`.
- Documents host Maven placement, required AdMob App IDs, iOS Google Mobile Ads `12.1.0`, and the `0.4.x` API migration.
- Prevents host `onAdLoaded` exceptions from being reported as native ad load failures.
- Treats terminal fullscreen show failures consistently and does not recache consumed iOS ads.
- Keeps an ad retryable when another fullscreen ad is already showing.
- Replaces the generated Android plugin test with bridge behavior tests and expands Dart lifecycle coverage.

## 0.6.3

- Aligns Flutter package, Android Gradle plugin, and CocoaPods metadata at `0.6.3`.
- Updates the Android native mediation dependency to `0.6.1`.
- Removes embedded Swift ABI metadata that exposed local build paths.
- Makes invalid example environment values fail explicitly instead of falling back to staging.

## 0.6.2

- Aligns public Git dependency references to the `0.6.2` Flutter bridge release.

## 0.6.1

- Adds the runnable mixed Android/iOS host example and bilingual integration guidance.

## 0.6.0

- Normalizes all public Flutter ad errors to the `ADS_` prefix.
- Clarifies that iOS `0.6.0` delivery uses CocoaPods and requires Flutter `3.22.3`.
- Uses matching Android Maven and bundled iOS native SDK artifacts at `0.6.0`.

## 0.5.0

- First public release of the Jolibox Ad Mediation Flutter bridge.
- Supports fixed-size Banner Widgets, Interstitial, and Rewarded ads on Android and iOS.
- Android resolves `jolibox-ad-mediation:0.5.0` from the matching public GitHub Maven repository.
- iOS bundles the matching `JoliboxAdMediation` XCFramework through CocoaPods.
