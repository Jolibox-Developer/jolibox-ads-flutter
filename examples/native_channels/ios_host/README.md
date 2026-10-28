# Native iOS target isolation

Both `HostBase` and `HostAds` embed `../flutter_module`, with the same Flutter
`pubspec.lock` and the same generated module code. Run `flutter pub get` in the
module, then use CocoaPods' bundled Ruby to run `ruby generate_project.rb` in
this directory and `pod install`. Open `NativeChannelsHost.xcworkspace`.

`HostBase` has no ad Pod, imports or registration. `HostAds` alone depends on
`JoliboxFlutterAdsBridgeAdMob` and registers it on its own `FlutterEngine`.
Flutter iOS does not permit setting method handlers until `engine.run()`, so
both hosts run the engine, finish registrar setup, and then acknowledge the
shared module's `jolibox_native_channels/host.waitForHostReady` handshake. Dart
must await that acknowledgement before its first ad capability probe. This is
a local demonstration. The example uses the repository root as a development
Pod path; production hosts can install the same Pod from Git tag `0.8.1`, as
shown in the root integration guide.
The test AdMob App ID only satisfies SDK host configuration; real Jolibox ad
loads require authorized `joliSource` and `scene` values. The native host must
also implement its production consent/privacy policy.

`HostAdsTests` checks per-engine registration, duplicate registration and
post-detach call rejection on an iOS simulator; real delayed SDK load callbacks
still need controlled native test configuration.

Run the lifecycle tests with `xcodebuild -workspace NativeChannelsHost.xcworkspace
-scheme HostAds -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4'
-parallel-testing-enabled NO test`. Choose an installed simulator when needed.
The test action starts without LLDB; normal app debugging remains enabled.
