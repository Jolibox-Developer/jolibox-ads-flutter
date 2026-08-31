# Jolibox Ads Flutter

> 中文说明：[README_CN.md](README_CN.md)

Flutter bridge for the Jolibox Ad Mediation native SDK. It supports standard
AdMob Banner, Interstitial, and Rewarded ads on Android and iOS.

## Requirements

- Flutter `3.22.3`
- Android: `minSdk 23`, `compileSdk 35`, Java 17, Kotlin `2.0.21`,
  Android Gradle Plugin `8.6.1`, and Gradle `8.7`
- iOS `13.0` or later
- A released Jolibox Ad Mediation native SDK for each platform

The native host starts SDK initialization once during application startup.
Flutter must wait for the native initialization result before it renders a
banner or loads a fullscreen ad. The optional Flutter initialization API
delegates to that same native SDK; it never creates a second configuration or
ad state.

## Mixed-host example

[`example/`](example/) is a complete mixed Android/iOS host rather than a
Flutter-only snippet. Its Android `Application` and iOS `AppDelegate` each
initialize the native SDK, while its Flutter screen demonstrates the Banner
Widget and the Interstitial/Rewarded `load → show` lifecycles. It contains no
host credentials: configuration values remain placeholders and AdMob App IDs
are Google's official samples. Local configuration files are ignored by Git. See the
[example guide](example/README.md) before running it.

## Add the package

Use the tagged package source supplied with your release:

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: 0.6.4
```

Run `flutter pub get` after updating `pubspec.yaml`.

## Native setup

### Android

Add the matching binary Maven repository to the host application's Gradle
repositories. For a Flutter `3.22.3` project, put it in the existing
`allprojects.repositories` block in the host's `android/build.gradle`:

```gradle
allprojects {
  repositories {
    google()
    mavenCentral()
    maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ad-mediation-android-maven/0.6.2/") }
  }
}
```

If the host already centralizes repositories with
`dependencyResolutionManagement`, add the same three repository entries to the
existing `repositories` block in `android/settings.gradle` instead. Do not add
the repository in both places when the host enforces settings-level repositories.

```gradle
dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
    maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ad-mediation-android-maven/0.6.2/") }
  }
}
```

The Flutter bridge uses `com.jolibox.android:jolibox-ad-mediation:0.6.2`,
which transitively resolves Google Mobile Ads `24.0.0`. The Android NDK is not
required merely to consume the released AAR. The host adds only the Maven
repository: do **not** manually add another
`implementation("com.jolibox.android:jolibox-ad-mediation:...")` dependency,
and do not edit this Flutter plugin's own `android/build.gradle`.

Add the host's AdMob App ID inside the `<application>` element of
`android/app/src/main/AndroidManifest.xml`. This is an App ID containing `~`,
not an ad unit ID containing `/`.

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="YOUR_ANDROID_ADMOB_APP_ID" />
```

Initialize the native SDK once from the Android application startup path. The
exact configuration value is provided separately for your integration. When
using an `Application` subclass, declare it with `android:name` in the host
`AndroidManifest.xml`.

```kotlin
class HostApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        JoliboxAds.initialize(
            this,
            "YOUR_JOLI_SOURCE",
            MediationEnvironment.STAGING,
            object : InitializationCallback {
                override fun onInitialized() {}
                override fun onInitializationFailed(error: JoliboxAdError) {}
            },
        )
    }
}
```

### iOS

Flutter bridge `0.6.4` requires Flutter `3.22.3` and uses CocoaPods for iOS
delivery. It bundles native mediation `0.6.1` and resolves
Google Mobile Ads SDK `12.1.0`. Keep the Android Maven repository at `0.6.2`
unless a later native SDK release is supplied. The Flutter Swift Package Manager integration
documented for earlier releases is not supported by this release. An existing
iOS host must migrate to the CocoaPods steps below; if CocoaPods cannot be used,
it cannot integrate `0.6.4`.

The plugin links its bundled native XCFramework through CocoaPods. From the
Flutter application root, run:

```bash
flutter pub get
cd ios && pod install && cd ..
```

Do not also add `JoliboxAdMediation` through Swift Package Manager to the same
iOS application target; the Flutter plugin already bundles the matching
framework. Add the host's AdMob App ID to `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>YOUR_IOS_ADMOB_APP_ID</string>
```

Initialize the native SDK once from the iOS application startup
path, in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, before
Flutter loads any ads.

```swift
import JoliboxAdMediation

JoliboxAds.initialize(
  joliSource: "YOUR_JOLI_SOURCE",
  environment: .staging
) { result in
  // Handle success or failure before Flutter loads ads.
}
```

## Banner Widget

`JoliboxBannerAd` owns its native platform view. Add it to the widget tree where
the banner should appear; removing the widget disposes the native banner.

```dart
JoliboxBannerAd(
  scene: 'YOUR_SCENE',
  size: JoliboxBannerSize.banner,
  onLoaded: () {},
  onFailedToLoad: (error) {},
  onImpression: () {},
  onClicked: () {},
)
```

Supported fixed sizes are `banner`, `largeBanner`, and `mediumRectangle`.

## Interstitial and Rewarded ads

Fullscreen ads follow the native AdMob object lifecycle: load an object, set
callbacks, show it once, then let the bridge release it after dismissal or a
terminal show failure. Call `dispose()` only when a loaded ad will not be shown.

```dart
JoliboxInterstitialAd.load(
  scene: 'YOUR_SCENE',
  adLoadCallback: JoliboxInterstitialAdLoadCallback(
    onAdLoaded: (ad) async {
      ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
        onAdImpression: () {},
        onAdClicked: () {},
        onAdDismissedFullScreenContent: () {},
        onAdFailedToShowFullScreenContent: (error) {},
      );
      await ad.show();
    },
    onAdFailedToLoad: (error) {},
  ),
);
```

For a rewarded ad, use `JoliboxRewardedAd.load` and pass
`onUserEarnedReward` to `show`. The reward callback has no amount or type
payload.

## Migrating from 0.4.x

The legacy static fullscreen API is not available in `0.6.4`. Replace
`JoliboxAdsFlutter.loadInterstitial(...)`,
`JoliboxAdsFlutter.loadRewarded(...)`, `JoliboxAdsFlutter.show(...)`,
`JoliboxAdsFlutter.disposeAd(...)`, and `JoliboxFullscreenAd` with the
object-style `JoliboxInterstitialAd` and `JoliboxRewardedAd` APIs shown above.
Set `fullScreenContentCallback` on the loaded object, call its `show()` once,
and call its `dispose()` only when a loaded ad will not be shown.

iOS hosts migrating from the old Flutter Swift Package Manager instructions
must remove that package from the application target and run CocoaPods as
described in the iOS setup section.

## Optional Flutter initialization

Use this only when the host deliberately delegates its first native
initialization to Flutter. For a mixed native/Flutter application that already
initializes natively, do not call it again.

```dart
await JoliboxAdsFlutter.initialize(
  joliSource: suppliedConfiguration,
  environment: JoliboxMediationEnvironment.staging,
);
```

## Errors and callbacks

Load and show failures arrive as `PlatformException`. Fullscreen callbacks map
to `onAdShowedFullScreenContent`, `onAdImpression`, `onAdClicked`,
`onAdDismissedFullScreenContent`, and `onAdFailedToShowFullScreenContent`.
Banner callbacks map to loaded, load failed, impression, click, opened, and
closed events.

All public `PlatformException.code` values use the `ADS_` prefix. Established
ad errors include `ADS_LOAD_FAILED`, `ADS_SHOW_FAILED`,
`ADS_AD_NOT_FOUND`, `ADS_ACTIVITY_REQUIRED`, and `ADS_SHOW_IN_PROGRESS`.
Initialization and configuration errors use the same `ADS_` prefix.
An empty or whitespace-only `scene` is a caller error and completes the Dart
load future with `ArgumentError` before any native request is made.
`ADS_ACTIVITY_REQUIRED` and `ADS_SHOW_IN_PROGRESS` are retryable: wait until an
active presenter is available or the current fullscreen ad finishes, then call
`show()` again on the same loaded object. Other show failures are terminal; load
a new ad object before retrying.

For a Chinese version, see [README_CN.md](README_CN.md).
