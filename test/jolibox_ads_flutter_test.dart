import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('jolibox_ads_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCapabilities') {
        return <String, Object>{
          'protocolVersion': 1,
          'provider': 'admob',
          'banner': true,
          'interstitial': true,
          'rewarded': true,
        };
      }
      return null;
    });
    await JoliboxAdsFlutter.isAvailable(refresh: true);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('fixed banner sizes remain available', () {
    expect(JoliboxBannerSize.values, hasLength(3));
    expect(JoliboxBannerSize.banner.name, 'banner');
    expect(JoliboxBannerSize.largeBanner.name, 'largeBanner');
    expect(JoliboxBannerSize.mediumRectangle.name, 'mediumRectangle');
  });

  test('banner reveal duration defaults to immediate', () {
    const banner = JoliboxBannerAd(scene: 'checkout');

    expect(banner.layoutMode, JoliboxBannerLayoutMode.collapseUntilLoaded);
    expect(banner.revealDuration, Duration.zero);
  });

  test('banner accepts a custom reveal duration', () {
    const banner = JoliboxBannerAd(
      scene: 'checkout',
      revealDuration: Duration(milliseconds: 100),
    );

    expect(banner.revealDuration, const Duration(milliseconds: 100));
  });

  test('fullscreen callback accepts optional handlers', () {
    const callbacks = JoliboxFullScreenContentCallback();
    expect(callbacks.onAdClicked, isNull);
    expect(callbacks.onAdDismissedFullScreenContent, isNull);
  });

  test('base-only calls complete without creating ads or firing callbacks',
      () async {
    var loadCallbacks = 0;
    messenger.setMockMethodCallHandler(channel, null);

    expect(await JoliboxAdsFlutter.isAvailable(refresh: true), isFalse);
    await JoliboxAdsFlutter.initialize(
      joliSource: 'source',
      environment: JoliboxMediationEnvironment.staging,
    );
    await JoliboxInterstitialAd.load(
      scene: ' ',
      adLoadCallback: JoliboxInterstitialAdLoadCallback(
        onAdLoaded: (_) => loadCallbacks++,
        onAdFailedToLoad: (_) => loadCallbacks++,
      ),
    );
    await JoliboxRewardedAd.load(
      scene: 'checkout',
      adLoadCallback: JoliboxRewardedAdLoadCallback(
        onAdLoaded: (_) => loadCallbacks++,
        onAdFailedToLoad: (_) => loadCallbacks++,
      ),
    );

    expect(loadCallbacks, 0);
  });

  test('old native bridge is reported as incompatible, not disabled', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCapabilities') throw MissingPluginException();
      if (call.method == 'loadInterstitial') {
        expect(call.arguments['scene'], isEmpty);
        throw PlatformException(code: 'INVALID_ARGUMENT');
      }
      fail('Unexpected native call: ${call.method}');
    });

    await expectLater(
      JoliboxAdsFlutter.isAvailable(refresh: true),
      throwsA(isA<StateError>()),
    );
  });

  test('malformed capabilities are not silently treated as disabled', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object>{'protocolVersion': 999};
    });

    await expectLater(
      JoliboxAdsFlutter.isAvailable(refresh: true),
      throwsA(isA<StateError>()),
    );
  });

  test('concurrent API calls share one capability probe', () async {
    final pendingCapabilities = Completer<Object?>();
    var probes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getCapabilities') {
        probes++;
        return pendingCapabilities.future;
      }
      if (call.method == 'loadInterstitial' &&
          call.arguments['scene'] == '') {
        throw MissingPluginException();
      }
      fail('No advertising call is expected without an implementation.');
    });
    final availability = JoliboxAdsFlutter.isAvailable(refresh: true);

    final initialization = JoliboxAdsFlutter.initialize(
      joliSource: 'source',
      environment: JoliboxMediationEnvironment.staging,
    );
    final interstitial = JoliboxInterstitialAd.load(
      scene: 'checkout',
      adLoadCallback: JoliboxInterstitialAdLoadCallback(
        onAdLoaded: (_) => fail('Unexpected ad.'),
        onAdFailedToLoad: (_) => fail('Unexpected failure callback.'),
      ),
    );
    final rewarded = JoliboxRewardedAd.load(
      scene: 'checkout',
      adLoadCallback: JoliboxRewardedAdLoadCallback(
        onAdLoaded: (_) => fail('Unexpected ad.'),
        onAdFailedToLoad: (_) => fail('Unexpected failure callback.'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(probes, 1);
    pendingCapabilities.completeError(MissingPluginException());
    expect(await availability, isFalse);
    await Future.wait([initialization, interstitial, rewarded]);
    expect(probes, 1);
  });

  testWidgets('base-only banner never creates a native view', (tester) async {
    try {
      messenger.setMockMethodCallHandler(channel, null);
      expect(
        await tester.runAsync(
          () => JoliboxAdsFlutter.isAvailable(refresh: true),
        ),
        isFalse,
      );

      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: JoliboxBannerAd(
          scene: 'checkout',
          layoutMode: JoliboxBannerLayoutMode.reserveSpace,
        ),
      ));
      await tester.pump();

      expect(find.byType(AndroidView), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('native initialization errors use the public ADS prefix', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'INVALID_ARGUMENT', message: 'invalid');
    });

    await expectLater(
      JoliboxAdsFlutter.initialize(
        joliSource: 'source',
        environment: JoliboxMediationEnvironment.staging,
      ),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'ADS_INVALID_ARGUMENT')
            .having((error) => error.message, 'message', 'invalid'),
      ),
    );
  });

  test('blank scenes fail before invoking the native loader', () async {
    var nativeCalls = 0;
    var failedCallbacks = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeCalls++;
      return 'unused';
    });

    await expectLater(
      JoliboxInterstitialAd.load(
        scene: '  ',
        adLoadCallback: JoliboxInterstitialAdLoadCallback(
          onAdLoaded: (_) {},
          onAdFailedToLoad: (_) => failedCallbacks++,
        ),
      ),
      throwsArgumentError,
    );

    expect(nativeCalls, 0);
    expect(failedCallbacks, 0);
  });

  test('native load failures are mapped once', () async {
    PlatformException? failure;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'AD_LOAD_FAILED', message: 'no fill');
    });

    await JoliboxRewardedAd.load(
      scene: 'checkout',
      adLoadCallback: JoliboxRewardedAdLoadCallback(
        onAdLoaded: (_) => fail('The ad must not load.'),
        onAdFailedToLoad: (error) => failure = error,
      ),
    );

    expect(failure?.code, 'ADS_LOAD_FAILED');
    expect(failure?.message, 'no fill');
  });

  test('host onAdLoaded exceptions are not reported as load failures',
      () async {
    var failedCallbacks = 0;
    final nativeMethods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      nativeMethods.add(call.method);
      if (call.method == 'loadInterstitial') return 'loaded-id';
      return null;
    });

    await expectLater(
      JoliboxInterstitialAd.load(
        scene: 'checkout',
        adLoadCallback: JoliboxInterstitialAdLoadCallback(
          onAdLoaded: (_) => throw StateError('host callback failed'),
          onAdFailedToLoad: (_) => failedCallbacks++,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'host callback failed',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(failedCallbacks, 0);
    expect(
        nativeMethods, containsAllInOrder(['loadInterstitial', 'disposeAd']));
  });

  test('activity errors keep an ad retryable', () async {
    late JoliboxInterstitialAd ad;
    var showAttempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'loadInterstitial') return 'retry-id';
      if (call.method == 'show') {
        showAttempts++;
        throw PlatformException(
          code: showAttempts == 1 ? 'ACTIVITY_REQUIRED' : 'AD_SHOW_FAILED',
        );
      }
      return null;
    });
    await JoliboxInterstitialAd.load(
      scene: 'checkout',
      adLoadCallback: JoliboxInterstitialAdLoadCallback(
        onAdLoaded: (value) => ad = value,
        onAdFailedToLoad: (error) => fail('$error'),
      ),
    );

    await expectLater(
      ad.show(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'ADS_ACTIVITY_REQUIRED',
        ),
      ),
    );
    await expectLater(
      ad.show(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'ADS_SHOW_FAILED',
        ),
      ),
    );
    await ad.dispose();

    expect(showAttempts, 2);
  });

  test('terminal show failures make an ad one-shot', () async {
    late JoliboxRewardedAd ad;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'loadRewarded') return 'terminal-id';
      if (call.method == 'show') {
        throw PlatformException(code: 'AD_SHOW_FAILED');
      }
      return null;
    });
    await JoliboxRewardedAd.load(
      scene: 'checkout',
      adLoadCallback: JoliboxRewardedAdLoadCallback(
        onAdLoaded: (value) => ad = value,
        onAdFailedToLoad: (error) => fail('$error'),
      ),
    );

    await expectLater(ad.show(), throwsA(isA<PlatformException>()));
    await expectLater(ad.show(), throwsStateError);
    await ad.dispose();
  });

  test('a concurrent show attempt remains retryable', () async {
    late JoliboxInterstitialAd firstAd;
    late JoliboxRewardedAd secondAd;
    final firstShow = Completer<Object?>();
    var loadCount = 0;
    var secondShowAttempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) {
      if (call.method == 'loadInterstitial' || call.method == 'loadRewarded') {
        loadCount++;
        return Future<Object?>.value('loaded-$loadCount');
      }
      if (call.method == 'show' && call.arguments['adId'] == 'loaded-1') {
        return firstShow.future;
      }
      if (call.method == 'show' && call.arguments['adId'] == 'loaded-2') {
        secondShowAttempts++;
        return Future<Object?>.error(
          PlatformException(code: 'AD_SHOW_FAILED'),
        );
      }
      return Future<Object?>.value();
    });
    await JoliboxInterstitialAd.load(
      scene: 'checkout',
      adLoadCallback: JoliboxInterstitialAdLoadCallback(
        onAdLoaded: (value) => firstAd = value,
        onAdFailedToLoad: (error) => fail('$error'),
      ),
    );
    await JoliboxRewardedAd.load(
      scene: 'checkout',
      adLoadCallback: JoliboxRewardedAdLoadCallback(
        onAdLoaded: (value) => secondAd = value,
        onAdFailedToLoad: (error) => fail('$error'),
      ),
    );

    final pendingFirstShow = firstAd.show();
    await expectLater(
      secondAd.show(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'ADS_SHOW_IN_PROGRESS',
        ),
      ),
    );

    final firstFailure = expectLater(
      pendingFirstShow,
      throwsA(isA<PlatformException>()),
    );
    firstShow.completeError(PlatformException(code: 'AD_SHOW_FAILED'));
    await firstFailure;
    await expectLater(secondAd.show(), throwsA(isA<PlatformException>()));
    await firstAd.dispose();
    await secondAd.dispose();

    expect(secondShowAttempts, 1);
  });
}
