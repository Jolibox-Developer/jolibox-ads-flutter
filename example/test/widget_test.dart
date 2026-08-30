import 'package:flutter_test/flutter_test.dart';
import 'package:jolibox_ads_flutter_example/main.dart';

void main() {
  testWidgets('renders the Flutter QA controls', (tester) async {
    await tester.pumpWidget(const JoliboxAdsExampleApp());
    expect(find.text('Jolibox Ad Mediation QA'), findsOneWidget);
    expect(find.text('Initialize'), findsOneWidget);
    expect(find.text('Banner'), findsOneWidget);
    expect(find.text('Load Interstitial'), findsOneWidget);
    expect(find.text('Load Rewarded'), findsOneWidget);
  });
}
