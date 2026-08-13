# Changelog

> **Chinese documentation:** [CHANGELOG.zh-CN.md](CHANGELOG.zh-CN.md)

## 0.1.0

- Adds a shared Flutter API for Banner, interstitial, and rewarded ads.
- Provides Android and iOS bridge code in the repository. Android is the currently validated delivery target.
- Requires native-Host initialization before Flutter ad calls; Flutter does not initialize Jolibox or an ad provider.
- Forwards supported ad lifecycle callbacks without exposing revenue events such as `onPaidEvent`.
- Existing native Android Game and Drama flows require regression verification after SDK-All upgrades.
- **iOS is not accepted for delivery yet.** The iOS artifact repository and private CocoaPods Specs distribution are not ready, and iOS QA is incomplete. Do not start iOS Host integration, run `pod install`, or use the iOS bridge in production until Jolibox explicitly confirms iOS acceptance.
