# Native Host Initialization

> **Chinese documentation:** [Native Host Initialization (Chinese)](NATIVE-HOST-INITIALIZATION.zh-CN.md)

The Flutter bridge does not initialize Jolibox or an ad provider. The native Android or iOS Host must complete the following sequence once for each App process before a Flutter page makes an ad call.

## Approved configuration

Obtain the approved `joliSource`, environment, scene values, and platform-specific Host configuration from Jolibox through the agreed delivery channel. Do not hard-code, publish, or commit those values. This public repository intentionally does not contain configuration endpoints, credentials, or ad unit IDs.

## Android Host

1. Add the approved SDK-All dependency and platform configuration described in the Android prerequisites in the root README.
2. During native App startup, call `Jolibox.init(applicationContext, suppliedJoliSource, hostProvider)` exactly once. `hostProvider` is the Host's approved `JoliboxSDKProvider` implementation.
3. After the base SDK is configured, call `JoliboxAds.initialize(context, callback)` exactly once.
4. Wait for `callback.onReady()` before allowing the Flutter page to request or show ads. Handle `onFailure(error)` in the Host's normal startup/error flow.

Do not initialize Jolibox, Google Mobile Ads, or another provider again from Dart. If the App uses a cached FlutterEngine, finish this native initialization before presenting Flutter content that can request ads.

## iOS Host

1. Resolve the bridge and its transitive `JoliboxSDKAll` Swift Package dependency and add the supplied `GADApplicationIdentifier` as described in [iOS Host Integration](IOS-HOST-INTEGRATION.md).
2. During native App startup, configure `JoliboxSDK.shared` exactly once using the approved environment and supplied `joliSource`.
3. After the base SDK is configured, await `JoliboxAds.initialize()` exactly once.
4. Only render or enable Flutter ad calls after initialization succeeds. Route an initialization failure through the Host's normal error flow.

Do not initialize Jolibox, Google Mobile Ads, or another provider from Dart. For a custom or cached FlutterEngine, register generated plugins before presenting the Flutter page, as described in the iOS Host Integration guide.

## Flutter boundary

Flutter only passes a business `scene` to the bridge and receives ad callbacks. Provider selection, ad-unit selection, and configuration remain in the native SDK. Re-entering a Flutter page does not require, and must not trigger, another native SDK initialization.
