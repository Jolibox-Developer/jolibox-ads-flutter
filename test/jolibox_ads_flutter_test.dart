import 'package:flutter_test/flutter_test.dart';
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

void main() {
  test('fixed banner sizes remain available', () {
    expect(JoliboxBannerSize.values, hasLength(3));
    expect(JoliboxBannerSize.banner.name, 'banner');
    expect(JoliboxBannerSize.largeBanner.name, 'largeBanner');
    expect(JoliboxBannerSize.mediumRectangle.name, 'mediumRectangle');
  });

  test('fullscreen callback accepts optional handlers', () {
    const callbacks = JoliboxFullScreenContentCallback();
    expect(callbacks.onAdClicked, isNull);
    expect(callbacks.onAdDismissedFullScreenContent, isNull);
  });
}
