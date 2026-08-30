import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('exposes fixed Banner sizes', (tester) async {
    expect(JoliboxBannerSize.values, hasLength(3));
  });
}
