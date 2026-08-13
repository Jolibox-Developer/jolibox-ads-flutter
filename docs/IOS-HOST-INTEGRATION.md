# iOS Host Integration

## Prerequisites

- The iOS Host integrates the company private `JoliboxSDKAll` CocoaPods dependency.
- The Host initializes Jolibox SDK and ads exactly once before it opens Flutter.
- The Host uses Flutter Add-to-App CocoaPods integration and calls `GeneratedPluginRegistrant.register(with:)` after `FlutterEngine.run()`.

The Flutter Plugin declares an exact `JoliboxSDKAll` dependency. Configure the company private Specs source in the Host Podfile; do not add a second Joli SDK, GMA, UMP, or IGList source manually.

## Host Podfile Shape

```ruby
platform :ios, '15.0'

flutter_application_path = File.expand_path('../flutter_ads_module', __dir__)
podhelper = File.join(flutter_application_path, '.ios', 'Flutter', 'podhelper.rb')
require podhelper

target 'YourHost' do
  use_frameworks!
  install_all_flutter_pods(flutter_application_path)
end

post_install do |installer|
  flutter_post_install(installer)
end
```

Run `flutter pub get`, then `pod install`, and open the generated `.xcworkspace`.

## Required Host Lifecycle

```swift
try await JoliboxAds.initialize()

let engine = FlutterEngine(name: "your-flutter-engine")
engine.run()
GeneratedPluginRegistrant.register(with: engine)
openFlutterPage(engine: engine)
```

The exact SDK configuration values belong to the native Host integration. Flutter must not initialize the SDK or access advertising configuration.

## Single-Copy Rule

`JoliboxSDKAll` is the only iOS SDK dependency visible to the Host. Do not mix it with:

- an old SDK-All ZIP linked manually in Xcode;
- `Google-Mobile-Ads-SDK` or `GoogleUserMessagingPlatform`;
- standalone GMA, UMP, or `IGList*` XCFrameworks;
- equivalent Swift Package Manager dependencies.
