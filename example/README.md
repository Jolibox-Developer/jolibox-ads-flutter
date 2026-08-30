# Jolibox Ads Flutter example

This is a runnable mixed Android/iOS host example, not a Flutter-only snippet.
It covers Banner, Interstitial, and Rewarded ads. It does not contain a real
`joliSource`, scene, ad unit ID, or other environment credential.

## What it demonstrates

1. Android initializes `JoliboxAds` from `ExampleApplication.onCreate()`.
2. iOS initializes `JoliboxAds` from `AppDelegate` during application startup.
3. Flutter waits for native initialization, renders `JoliboxBannerAd` as a
   Widget, and separately loads then shows Interstitial and Rewarded ads.
4. Flutter deliberately does **not** call `JoliboxAdsFlutter.initialize()`.

The `jolibox_ads_flutter_example/initialization` method channel exists only to
enable this example's controls after native initialization. It is not a public
SDK API. A production host can enable its Flutter ad UI from its own native
initialization completion instead.

## Run

1. Follow the native Android or iOS setup in the parent
   [integration guide](../README.md).
2. Copy `qa.local.json.example` to `qa.local.json` and set `JOLIBOX_SCENE`.
   The local file is ignored by Git.
   Configure only the native platform that you are about to run.
3. Append the following native configuration to the ignored
   `android/local.properties` file:

   ```properties
   jolibox.joliSource=YOUR_JOLI_SOURCE
   jolibox.environment=staging
   ```

4. For iOS, copy the ignored local configuration template and set the same
   supplied value:

   ```bash
   cp ios/Runner/Config/Jolibox.local.xcconfig.example \
     ios/Runner/Config/Jolibox.local.xcconfig
   ```

   ```xcconfig
   JOLIBOX_JOLI_SOURCE = YOUR_JOLI_SOURCE
   JOLIBOX_ENVIRONMENT = staging
   ```

5. Run the example with the local scene configuration:

   ```bash
   flutter run --dart-define-from-file=qa.local.json
   ```

`ExampleApplication.kt` starts Android initialization through `BuildConfig`
before `FlutterActivity` renders; the Flutter controls wait for its result.
`AppDelegate.swift` starts iOS initialization from application startup, and the
Flutter controls wait before loading ads. Both `android/local.properties` and
`ios/Runner/Config/Jolibox.local.xcconfig` are ignored by Git.

After native initialization succeeds, the Banner Widget requests its ad
automatically. Use the separate Load and Show controls to verify the
Interstitial and Rewarded object lifecycles. On iOS, run `flutter pub get`,
then `cd ios && pod install && cd ..` before opening `Runner.xcworkspace`.
See the parent guide for production integration and callback semantics.

For Chinese, see [README_CN.md](README_CN.md).
