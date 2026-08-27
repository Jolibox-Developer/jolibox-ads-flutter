# iOS Host Integration

> **Chinese documentation:** [iOS Host Integration (Chinese)](IOS-HOST-INTEGRATION.zh-CN.md)

## Status

The iOS bridge is delivered through Flutter Swift Package Manager support. It requires the matching published `JoliboxSDKAll` `0.4.0` release.

Complete Host runtime acceptance for initialization and ad display before a production rollout. CocoaPods is not supported for this bridge.

## Prerequisites

- iOS 15 or later.
- Flutter 3.44 or later. Swift Package Manager support is enabled by default. If it was previously disabled, enable it before resolving the Flutter App:

```bash
flutter config --enable-swift-package-manager
```

- Add the Google Mobile Ads application identifier supplied by Jolibox to the iOS app target's `Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>value supplied by Jolibox</string>
```

- Add the Flutter bridge at the approved tag:

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: v0.4.0
```

- The public `JoliboxSDKAll` `0.4.0` Swift package is resolved transitively by the bridge. Do not add an additional Jolibox SDK, Google Mobile Ads, UMP, or `IGList*` package directly to the Flutter App.

## Native Host Boundary

The native iOS Host owns Jolibox SDK and ad-provider initialization once per App process. Initialize the base SDK during App startup, then initialize ads after the base SDK is ready and before showing Flutter content. Follow [Native Host Initialization](NATIVE-HOST-INITIALIZATION.md) for the required order and configuration boundary.

Flutter calls the bridge with a business `scene`. It does not initialize Jolibox, Google Mobile Ads, an ad channel, or internal configuration.

## Flutter Engine Registration

For a custom or cached engine, register generated plugins before presenting the Flutter page:

```swift
let engine = FlutterEngine(name: "your-flutter-engine")
engine.run()
GeneratedPluginRegistrant.register(with: engine)
openFlutterPage(engine: engine)
```

## Dependency Rules

- Use only the Swift Package Manager dependency graph resolved by the bridge.
- Do not run `pod install` to deliver this bridge. Legacy CocoaPods integration stops with a setup error.
- Do not embed old SDK archives or duplicate Google Mobile Ads, UMP, or `IGList*` frameworks.
- Keep native initialization in the Host; do not add Flutter-side initialization.

## Production Acceptance

Before production rollout, verify the Host's one-time initialization and real Banner, interstitial, rewarded, lifecycle, disposal, and supported callback flows on the target iOS environment.
