# Jolibox Ads Flutter

[中文文档](README_CN.md)

`jolibox_ads_flutter` is one Dart API package for both native host configurations. It has no native plugin or advertising SDK dependency. The native host chooses whether to link the Android library or iOS Pod `JoliboxFlutterAdsBridgeAdMob`. That adapter brings Jolibox Ad Mediation and Google Mobile Ads into the ads-enabled native build. Both configurations use the same Flutter module, pubspec, lockfile, and Dart API.

Release `0.8.1` provides the Dart package and iOS Pod through the Git tag, and the Android adapter through the Maven directory in that same tag. See the [GitHub release](https://github.com/Jolibox-Developer/jolibox-ads-flutter/releases/tag/0.8.1). The iOS Pod uses an explicit Git dependency; it is not distributed through CocoaPods trunk.

## Supported baseline

- Flutter 3.22.3 / Dart 3.4.4, Android and iOS.
- Android: minSdk 23, Java 17, Kotlin 2.0.21. The adapter declares `com.jolibox.android:jolibox-ad-mediation:0.8.1`, which brings Google Mobile Ads 24.0.0.
- iOS: deployment target 13.0. The adapter includes Jolibox Ad Mediation 0.6.6 XCFramework and depends on `Google-Mobile-Ads-SDK` 12.1.0.
- Local validation used Android Gradle Plugin 8.6.1 / Gradle 8.7 and Xcode 26.4 / CocoaPods 1.17.0. Other host toolchain combinations need their own build verification.

## Shared Flutter dependency

The host's Flutter module declares only the base Dart package. Both native configurations consume that same resolved module. Pin the release tag in production; [the shared module](examples/native_channels/flutter_module/pubspec.yaml) uses a relative path for local development.

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: 0.8.1
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

For a released binary, add these repositories to the host's settings-level dependency repositories, alongside `google()`, `mavenCentral()` and the existing Flutter repositories:

```gradle
maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ads-flutter/0.8.1/maven/") }
maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ad-mediation-android-maven/0.8.1/") }
```

Replace the ads flavor's project dependency with:

```gradle
admobImplementation("com.jolibox.admediation:jolibox-ads-flutter-bridge-admob:0.8.1")
```

The Maven publication includes the AAR, POM and Gradle module metadata, so mediation and AdMob resolve transitively. Flutter embedding is supplied by the host. For source integration, keep the `native/android` project dependency instead.

When upgrading to `0.8.1`, update both Maven repository URLs and the bridge coordinate above, as well as the Dart Git ref. Updating only the Dart dependency does not update the native host's Gradle dependencies. Native mediation `0.8.1` moves the Google Mobile Ads initialization entry point to a worker and adds timing/thread diagnostics; initialization completion and ad callbacks retain main-thread dispatch. Wait for initialization to complete before loading ads.

## iOS native host

The [iOS two-target host](examples/native_channels/ios_host/README.md) demonstrates a shared Flutter module with `HostBase` and `HostAds`. Only `HostAds` includes the native Pod and registration code:

```ruby
target 'HostAds' do
  install_all_flutter_pods(flutter_application_path)
  pod 'JoliboxFlutterAdsBridgeAdMob',
      :git => 'https://github.com/Jolibox-Developer/jolibox-ads-flutter.git',
      :tag => '0.8.1'
end
```

Existing iOS hosts may keep Pod tag `0.8.0` for this Android fix. Adopting Pod tag `0.8.1` aligns release metadata while retaining the same iOS native `0.6.6` binary and Google Mobile Ads `12.1.0`.

`HostBase` installs the same Flutter module without the ad Pod. Keep the Pod out of any common parent target. Do not also link Google Mobile Ads or Jolibox through SPM or a manually embedded framework in the ads target. The native adapter uses the host's Flutter engine; it does not bundle another Flutter engine.

For local development, use `:path => '/path/to/jolibox-ads-flutter'` instead of `:git`/`:tag`. The Podspec is at the repository root; its sources and vendored framework remain in `native/ios`.

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
