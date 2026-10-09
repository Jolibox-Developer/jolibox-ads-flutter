import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shared module resolves the base API without a native bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      expect(await JoliboxAdsFlutter.isAvailable(refresh: true), isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
