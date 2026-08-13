# iOS Host Integration (Blocked)

> **Chinese documentation:** [iOS Host Integration (Chinese)](IOS-HOST-INTEGRATION.zh-CN.md)

## Status

**NOT ACCEPTED FOR DELIVERY.**

The repository contains the iOS bridge implementation, but the iOS SDK artifact repository and private CocoaPods Specs distribution are not ready. iOS QA has not been completed. This document describes the intended future integration shape only.

Do not start iOS Host integration, run `pod install` for this plugin, or use the iOS bridge in production until Jolibox explicitly confirms that iOS is unblocked.

## Future integration boundary

When iOS is unblocked, the native iOS Host will:

- own Jolibox SDK and ad-provider initialization once per App process;
- use the company-approved `JoliboxSDKAll` CocoaPods dependency;
- embed the Flutter module using the Host's existing Flutter Add-to-App architecture;
- register the plugin for every custom or cached `FlutterEngine`.

Flutter will call the bridge with a business `scene`. It will not initialize the SDK or access provider, channel, ad unit, or internal configuration values.

## Future Podfile shape

This is a reference shape, not an instruction to run today:

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

Only after iOS is unblocked may the Host configure the approved private Specs source, run `flutter pub get`, run `pod install`, and open the generated workspace.

## Future Flutter Engine registration

For a custom or cached engine, the Host must register generated Flutter plugins before presenting the Flutter page:

```swift
let engine = FlutterEngine(name: "your-flutter-engine")
engine.run()
GeneratedPluginRegistrant.register(with: engine)
openFlutterPage(engine: engine)
```

The exact initialization API and configuration values belong to the approved iOS SDK release instructions and must not be inferred from this public bridge repository.

## Single-copy rule

After iOS delivery is approved, the Host should use only the approved `JoliboxSDKAll` dependency. Do not mix it with an old SDK-All archive, standalone Google Mobile Ads or UMP dependencies, standalone `IGList*` XCFrameworks, or equivalent duplicate package dependencies.

## Unblocking criteria

All of the following are required:

- the iOS SDK artifact repository is available to the target build environment;
- the private CocoaPods Specs source resolves the approved `JoliboxSDKAll` version;
- the iOS Host installs dependencies and builds successfully;
- initialization, Banner, interstitial, rewarded, lifecycle, disposal, and callback QA pass;
- Jolibox explicitly marks iOS accepted for delivery.
