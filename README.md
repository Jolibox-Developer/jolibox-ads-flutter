# Jolibox Ads Flutter

> 中文说明：[README_CN.md](README_CN.md)

Flutter bridge for the Jolibox Ad Mediation native SDK. It supports standard
AdMob Banner, Interstitial, and Rewarded ads on Android and iOS.

## Requirements

- Flutter `3.22.3`
- Android: `minSdk 23`, Java 17, Kotlin `2.0.21`, and a final resolved Google
  Mobile Ads version of `24.0.0`
- iOS `13.0` or later with Google Mobile Ads SDK `12.14.0`, added to the Runner target through Xcode SPM
- A released Jolibox Ad Mediation native SDK for each platform

The verified Android baseline uses Android Gradle Plugin `8.6.1`, Gradle `8.7`,
`compileSdk 35`, and `targetSdk 35`. These are verification values rather than
requirements that every host must copy: the host may use another compatible
AGP, Gradle, compile SDK, or target SDK. Flutter `3.22.3` and Kotlin `2.0.21`
are fixed for this release.

The verified iOS baseline uses Xcode `26.4` and CocoaPods `1.17.0`. Other Xcode
or CocoaPods versions are not claimed as verified by this release.

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
      ref: 0.7.2
```

Before resolving dependencies, run `flutter --version` and confirm that it
reports exactly `3.22.3`. Then run `flutter pub get`.

## Native setup

### Android

Set Kotlin to exactly `2.0.21` in the host's existing version declaration. A
Flutter project using the plugins DSL normally declares it in
`android/settings.gradle`:

```gradle
plugins {
  id "org.jetbrains.kotlin.android" version "2.0.21" apply false
}
```

A legacy project may instead have
`ext.kotlin_version = "2.0.21"` in `android/build.gradle`. Update the existing
declaration; do not add a second Kotlin plugin declaration.

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
`dependencyResolutionManagement`, use the following four repositories in the
existing `repositories` block in `android/settings.gradle` instead. Do not add
the Jolibox repository in both places. With Flutter `3.22.3`, settings-level
repository management must use `PREFER_SETTINGS`:

```gradle
dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
  repositories {
    google()
    mavenCentral()
    maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    maven { url = uri("https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ad-mediation-android-maven/0.6.2/") }
  }
}
```

Flutter `3.22.3`'s own Gradle plugin, and its `integration_test` plugin when
used, declare project-level repositories. A host fixed to Flutter `3.22.3`
therefore **must not** use `RepositoriesMode.FAIL_ON_PROJECT_REPOS`, regardless
of the Jolibox plugin version. With `PREFER_SETTINGS`, Gradle may warn that
those Flutter-owned project repositories were ignored; this is expected. The
settings list above must retain both the Flutter Engine and Jolibox Maven
repositories.

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

For mixed native/Flutter hosts, initialize the native SDK once from the Android
application startup path. The exact configuration value is provided separately
for your integration. When using an `Application` subclass, declare it with
`android:name` in the host `AndroidManifest.xml`. Pure Flutter hosts should skip
this native initialization block and use the Dart mode below.

```kotlin
import android.app.Application
import com.jolibox.admediation.JoliboxAds
import com.jolibox.admediation.api.InitializationCallback
import com.jolibox.admediation.api.JoliboxAdError
import com.jolibox.admediation.api.MediationEnvironment

class HostApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        JoliboxAds.initialize(
            this,
            "YOUR_JOLI_SOURCE",
            MediationEnvironment.STAGING,
            object : InitializationCallback {
                override fun onInitialized() {
                    // Publish a ready state to Flutter through host-owned state
                    // or a host-owned MethodChannel.
                }

                override fun onInitializationFailed(error: JoliboxAdError) {
                    // Publish the failure; do not let Flutter load ads.
                }
            },
        )
    }
}
```

Declare that class on the host application element:

```xml
<application
    android:name=".HostApplication"
    ...>
```

### iOS

Flutter bridge `0.7.2` requires Flutter `3.22.3` and uses CocoaPods only to
deliver the plugin and bundled native mediation `0.6.5`. Google Mobile Ads is
not a CocoaPods dependency of this plugin: add Google Mobile Ads `12.14.0` to
the Runner application target through Xcode SPM, so the application links the
only copy. Keep the Android Maven repository at `0.6.2` unless a later native
SDK release is supplied. Flutter `3.22.3` does not automatically manage Swift
packages for plugins; this is a normal Xcode Runner-target package dependency.

The plugin links its bundled native XCFramework through CocoaPods. From the
Flutter application root, run:

```bash
flutter pub get
cd ios && pod install && cd ..
```

After `pod install`, inspect `ios/Podfile.lock`. It must resolve
`jolibox_ads_flutter (0.7.2)` and must not contain `Google-Mobile-Ads-SDK`.
Do not delete an existing lockfile merely to change versions. Then open
`ios/Runner.xcworkspace` in Xcode, add
`https://github.com/googleads/swift-package-manager-google-mobile-ads.git` with
exact version `12.14.0`, and link the `GoogleMobileAds` product to the Runner
application target.

Do not also add `JoliboxAdMediation` through Swift Package Manager to the same
iOS application target; the Flutter plugin already bundles the matching
framework. The Runner target must own the single `GoogleMobileAds` SPM product;
do not embed Google Mobile Ads in another binary framework. Add the host's
AdMob App ID to `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>YOUR_IOS_ADMOB_APP_ID</string>
```

For mixed native/Flutter hosts, initialize the native SDK once from
`AppDelegate.application(_:didFinishLaunchingWithOptions:)`. Keep the result in
host-owned state and expose that state to Flutter before enabling any ad UI.

```swift
import Flutter
import JoliboxAdMediation
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private(set) var adsReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    JoliboxAds.initialize(
      joliSource: "YOUR_JOLI_SOURCE",
      environment: .staging
    ) { [weak self] result in
      switch result {
      case .success:
        self?.adsReady = true
        // Notify the host's Flutter state that ads are ready.
      case .failure(let error):
        self?.adsReady = false
        // Report error.code and keep Flutter ad UI disabled.
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

The example's initialization channel is a reference implementation of this
readiness gate; its channel name is application-owned and is not SDK API.

## Choose one initialization mode

Initialize exactly once. Do not combine the two modes below.

### Pure Flutter host

After the native Maven/CocoaPods and AdMob App ID setup above, initialize from
Dart before rendering any ad UI:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initializationError;
  try {
    await JoliboxAdsFlutter.initialize(
      // Obtain this value from host-approved configuration; do not commit it.
      joliSource: suppliedConfiguration,
      environment: JoliboxMediationEnvironment.staging,
    );
  } catch (error) {
    initializationError = error;
  }
  runApp(HostApp(
    adsEnabled: initializationError == null,
    initializationError: initializationError,
  ));
}
```

`HostApp` above represents host-owned UI: it must keep all ad widgets and load
actions disabled when `initializationError` is non-null and may offer an
explicit retry path. Do not also initialize in Android `Application` or iOS
`AppDelegate`.

### Mixed native/Flutter host

Use the Android/iOS initialization shown above. Flutter must consume a
host-owned ready/failed state and must not create `JoliboxBannerAd` or call a
fullscreen `load` method until the state is ready. See the example's
[Android application](example/android/app/src/main/kotlin/com/jolibox/admediation/jolibox_ads_flutter_example/ExampleApplication.kt),
[iOS AppDelegate](example/ios/Runner/AppDelegate.swift), and
[Flutter readiness gate](example/lib/main.dart).

## Banner Widget

`JoliboxBannerAd` owns its native platform view. Add it to the widget tree where
the banner should appear; removing the widget disposes the native banner.

By default, a Banner reserves no layout space until its native view is loaded,
attached, and has a non-zero layout size. A failed load therefore leaves no
empty Banner slot. Once loaded, it reveals its full height immediately; no
reveal animation is applied unless the host explicitly requests one. This is
the recommended mode for new hosts.

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

`revealDuration` is optional and defaults to `Duration.zero`. It only affects
`collapseUntilLoaded`: zero reveals the Banner height immediately, while any
positive Dart `Duration` animates the height change. For example:

```dart
JoliboxBannerAd(
  scene: 'YOUR_SCENE',
  revealDuration: const Duration(milliseconds: 100),
)
```

`onLoaded` is called after the native Banner view is attached with a non-zero
layout size and before any optional reveal animation completes. It does not
guarantee that the first native pixel has already been drawn. The reveal
animation never delays `onLoaded`.

To reserve the requested Banner height while it is loading or after a load
failure, opt in explicitly:

```dart
JoliboxBannerAd(
  scene: 'YOUR_SCENE',
  size: JoliboxBannerSize.banner,
  layoutMode: JoliboxBannerLayoutMode.reserveSpace,
)
```

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
      try {
        await ad.show();
      } on PlatformException catch (error) {
        if (error.code == 'ADS_ACTIVITY_REQUIRED' ||
            error.code == 'ADS_SHOW_IN_PROGRESS') {
          // Keep this loaded object and retry show() later.
          return;
        }
        // This object is terminal. Drop the reference and load a new ad.
      }
    },
    onAdFailedToLoad: (error) {},
  ),
);
```

The snippet requires `package:flutter/services.dart` for `PlatformException`.

For a rewarded ad, use `JoliboxRewardedAd.load` and pass
`onUserEarnedReward` to `show`. The reward callback has no amount or type
payload.

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
