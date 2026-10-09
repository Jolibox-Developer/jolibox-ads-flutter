# Jolibox Ads Flutter

[中文文档](README_CN.md)

`jolibox_ads_flutter` is one Dart API package for both native host configurations. It has no native plugin or advertising SDK dependency. The native host chooses whether to link the Android library or iOS Pod `JoliboxFlutterAdsBridgeAdMob`. That adapter brings Jolibox Ad Mediation and Google Mobile Ads into the ads-enabled native build. Both configurations use the same Flutter module, pubspec, lockfile, and Dart API.

The native adapters are source deliverables in this repository. There is no published `0.8.0` Git tag, Maven coordinate, or Pod release yet. Do not put an unresolvable release version into a consuming host.

## Supported baseline

- Flutter 3.22.3 / Dart 3.4.4, Android and iOS.
- Android: minSdk 23, Java 17, Kotlin 2.0.21. The adapter declares `com.jolibox.android:jolibox-ad-mediation:0.6.2`, which brings Google Mobile Ads 24.0.0.
- iOS: deployment target 13.0. The adapter includes Jolibox Ad Mediation 0.6.6 XCFramework and depends on `Google-Mobile-Ads-SDK` 12.1.0.
- Local validation used Android Gradle Plugin 8.6.1 / Gradle 8.7 and Xcode 26.4 / CocoaPods 1.17.0. Other host toolchain combinations need their own build verification.

## Shared Flutter dependency

The host's Flutter module declares only the base Dart package. Both native configurations consume that same resolved module. For local development, see [the shared module](examples/native_channels/flutter_module/pubspec.yaml); it uses a relative path to this checkout. A published Git dependency can be substituted after an approved ref actually exists.

```yaml
dependencies:
  jolibox_ads_flutter:
    path: /path/to/jolibox-ads-flutter
```

The Flutter module must not depend on the old `jolibox_ads_flutter_admob` plugin. Rebuild any previously exported Flutter AAR/framework that still contains it.

## Android native host

The [Android two-flavor host](examples/native_channels/android_host/README.md) contains the tested local source wiring. `base` excludes the adapter; `admob` alone adds `native/android` and the Jolibox Maven repository. The adapter's `api` dependency supplies mediation and AdMob transitively; do not embed another copy of the Google SDK in the AAR.

```gradle
dependencies {
    admobImplementation project(":adBridge")
}
```

Only the ads flavor compiles its adapter import and registration wrapper. Register `JoliboxAdsFlutterPlugin()` on each ads-enabled `FlutterEngine` before Dart first calls `isAvailable()`. Preserve other plugins' normal registration. Add the host's AdMob App ID to the ads flavor manifest and initialize Jolibox Ads once, either from native code or via Dart. The base flavor must not inherit the App ID, SDK dependency, or initialization code through a shared module.

For source integration, include `native/android` as an Android library. Its Gradle configuration also defines a local-only Maven publication; remote coordinates and artifacts are not published. A lone AAR does not convey the adapter's mediation dependency; a Maven consumer needs its POM.

## iOS native host

The [iOS two-target host](examples/native_channels/ios_host/README.md) demonstrates a shared Flutter module with `HostBase` and `HostAds`. Only `HostAds` includes the native Pod and registration code:

```ruby
target 'HostAds' do
  install_all_flutter_pods(flutter_application_path)
  pod 'JoliboxFlutterAdsBridgeAdMob', :path => '/path/to/jolibox-ads-flutter/native/ios'
end
```

`HostBase` installs the same Flutter module without the ad Pod. Keep the Pod out of any common parent target. Do not also link Google Mobile Ads or Jolibox through SPM or a manually embedded framework in the ads target. The native adapter uses the host's Flutter engine; it does not bundle another Flutter engine.

On Flutter 3.22.3 iOS, call `engine.run()` before registering method handlers. Then register other plugins and call `JoliboxAdsFlutterPlugin.register(with: engine)` once per ads-enabled engine. Dart must wait until registration completes before probing capabilities. The [host example](examples/native_channels/ios_host/HostAds/AppDelegate.swift) uses a small `waitForHostReady` channel in both targets. This is an example host protocol, not part of the SDK API.

Configure the ads target's `GADApplicationIdentifier`, consent/privacy policy, and Jolibox source and scene. The included sample App ID allows host configuration checks but does not provide an authorized Jolibox ad source.

## Dart behavior

`JoliboxAdsFlutter.isAvailable()` is `false` without a native adapter and `true` after a compatible adapter is registered on the current engine. It does not indicate SDK initialization or ad availability. In the base native build, `initialize()` and full-screen `load()` Futures complete normally without advertising callbacks or ad objects. Banner, including `reserveSpace`, occupies zero space. The base path does not emit an `unavailable` error.

A caller that advances only on an ad callback must check capability and skip that wait when it is `false`. Completion of a `load()` Future does not mean an ad loaded. In the ads build, genuine initialization, loading, presentation, reward, and error callbacks remain active; configuration and SDK failures are not silently converted into base behavior.

```dart
final available = await JoliboxAdsFlutter.isAvailable();
if (available) {
  await JoliboxAdsFlutter.initialize(
    joliSource: suppliedSource,
    environment: JoliboxMediationEnvironment.staging,
  );
  // Enable Banner, interstitial, and rewarded workflows after initialization.
}
```

Use native initialization instead if the host already owns SDK setup; do not initialize twice. Retain the existing `JoliboxBannerAd`, `JoliboxInterstitialAd`, and `JoliboxRewardedAd` APIs. `scene` is required and nonblank in an ads-enabled build. A base build returns before ad parameter validation, though Dart `required` arguments must still be supplied.

## Verification

The [native host examples](examples/native_channels/) exercise both configurations against one shared Flutter module. The base APK/target must have no adapter, mediation, AdMob binary, or ad initialization metadata; the ads APK/target must contain one provider and report capability `true`. Native callbacks and rewards require an authorized Jolibox test source and scene. The older [example](example/) retains its own host changes and is not the reference for this native optional bridge.
