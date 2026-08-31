import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('jolibox_ads_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
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

  test('fullscreen callback accepts optional handlers', () {
    const callbacks = JoliboxFullScreenContentCallback();
    expect(callbacks.onAdClicked, isNull);
    expect(callbacks.onAdDismissedFullScreenContent, isNull);
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
