# Jolibox Flutter Plugin Release Guide

## Purpose

`jolibox_ads_flutter` is a public GitHub Flutter bridge. It provides the Dart API, Android bridge, and iOS bridge. It does not include native SDK binaries, advertising configuration, credentials, or internal service implementations.

Hosts reference a fixed Git tag:

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: v0.1.0
```

## Integration boundary

| Platform | Flutter bridge | Native SDK distribution | Initialization owner |
|---|---|---|---|
| Android | Android implementation in this repository | Jolibox-approved Android SDK-All dependency | Android Host, once |
| iOS | `ios/Classes` in this repository | Jolibox-approved iOS SDK-All CocoaPods dependency | iOS Host, once |

Flutter does not initialize the SDK and does not process advertising-provider selection, ad unit IDs, or advertising configuration. Flutter passes only a business `scene`.

## iOS release model

The iOS SDK-All dependency is distributed through Jolibox's private CocoaPods Specs and artifact infrastructure. The public Flutter bridge declares the compatible SDK version, while its binary artifacts and distribution details remain private.

Hosts must follow the company-provided iOS integration instructions. Do not manually add duplicate Jolibox SDK or ad-provider dependencies alongside the approved SDK-All integration.

## Release checklist

1. Use a semantic Flutter Plugin version and a Git tag such as `v0.1.0`.
2. Confirm the Android and iOS Host integrations resolve compatible approved SDK-All versions.
3. Run `flutter analyze` and `flutter test`.
4. Build and verify the Android Host.
5. Verify the iOS Host through its approved CocoaPods integration and build pipeline.
6. Ensure the repository contains no SDK binaries, private artifact locations, credentials, test configuration, advertising configuration, or internal routing code.
7. Ensure [`LICENSE`](../LICENSE) and public contact information are present before publishing or tagging.

## Support

For licensing, integration, or support inquiries, contact [contact@jolibox.com](mailto:contact@jolibox.com).
