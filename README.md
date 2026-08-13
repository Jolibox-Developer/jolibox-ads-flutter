# Jolibox Ads Flutter

`jolibox_ads_flutter` is the Flutter bridge for scene-based Jolibox banner, interstitial, and rewarded ads.

The native Android or iOS Host owns SDK initialization. Flutter must not initialize Jolibox, AdMob, or any other ad provider.

## Installation

Use a fixed release tag from the Jolibox GitHub repository:

```yaml
dependencies:
  jolibox_ads_flutter:
    git:
      url: https://github.com/Jolibox-Developer/jolibox-ads-flutter.git
      ref: v0.1.0
```

Then run:

```bash
flutter pub get
```

## Native prerequisites

- Android Hosts configure the matching Jolibox Android SDK-All dependency.
- iOS Hosts configure the matching Jolibox iOS SDK-All CocoaPods dependency through the company-provided integration instructions.
- The native Host initializes the SDK once and opens Flutter only after ad initialization succeeds.

Do not manually add a second Jolibox SDK or an ad-provider SDK beside the approved SDK-All dependency graph.

## Flutter usage

Flutter calls ads with a business `scene`. It does not know the provider or ad unit ID.

```dart
JoliboxBannerAd(
  scene: 'YOUR_BANNER_SCENE',
  onLoaded: () {},
  onFailedToLoad: (error) {},
  onImpression: () {},
  onClicked: () {},
  onOpened: () {},
  onClosed: () {},
)
```

For interstitial and rewarded ads, load first, show once, and dispose loaded ads that will no longer be shown:

```dart
final ad = await JoliboxAdsFlutter.loadInterstitial('YOUR_INTERSTITIAL_SCENE');
await JoliboxAdsFlutter.show(
  ad,
  callbacks: JoliboxFullscreenAdCallbacks(
    onAdShowedFullScreenContent: () {},
    onAdImpression: () {},
    onAdClicked: () {},
    onAdDismissedFullScreenContent: () {},
    onAdFailedToShowFullScreenContent: (error) {},
  ),
);
```

Use `loadRewarded` and `onUserEarnedReward` for rewarded ads.

## Support and release requirements

- Keep the Flutter Git tag and Android/iOS SDK dependency versions compatible.
- Never publish SDK binaries, artifact credentials, advertising configuration, or internal implementation details in this repository.
- Read [`LICENSE`](LICENSE) before using this Software.
- See [`docs/RELEASE.md`](docs/RELEASE.md) for the release model.
- Contact [contact@jolibox.com](mailto:contact@jolibox.com) for licensing or support.
