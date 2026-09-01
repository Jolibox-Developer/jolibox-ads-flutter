import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Flutter bridge for the Jolibox native ad mediation SDK.
///
/// Initialize exactly once: either initialize from the native host and gate
/// Flutter ad UI on that result, or call [initialize] from Dart before creating
/// ad widgets or loading fullscreen ads. Do not combine both modes.
class JoliboxAdsFlutter {
  JoliboxAdsFlutter._();

  static const MethodChannel _channel = MethodChannel('jolibox_ads_flutter');
  static final Map<String, _JoliboxObjectAd> _fullscreenAds = {};
  static bool _eventsRegistered = false;
  static String? _showingAdId;

  static Future<void> initialize({
    required String joliSource,
    required JoliboxMediationEnvironment environment,
  }) async {
    _ensureSupportedPlatform();
    try {
      await _channel.invokeMethod<void>('initialize', {
        'joliSource': joliSource,
        'environment': environment.name,
      });
    } on PlatformException catch (error) {
      throw _publicError(error);
    }
  }

  static Future<void> _loadObject(
    String method,
    String scene,
    ValueChanged<String> onLoaded,
    ValueChanged<PlatformException> onFailedToLoad,
  ) async {
    _ensureSupportedPlatform();
    _ensureEventHandler();
    final normalizedScene = _requireScene(scene);
    late final String id;
    try {
      final loadedId = await _channel.invokeMethod<String>(method, {
        'scene': normalizedScene,
      });
      if (loadedId == null || loadedId.isEmpty) {
        throw PlatformException(
          code: 'ADS_LOAD_FAILED',
          message: 'The native SDK did not return a loaded ad.',
        );
      }
      id = loadedId;
    } on PlatformException catch (error) {
      onFailedToLoad(_publicError(error));
      return;
    } catch (error) {
      onFailedToLoad(
        PlatformException(code: 'ADS_LOAD_FAILED', message: '$error'),
      );
      return;
    }
    onLoaded(id);
  }

  static Future<void> _showObject(_JoliboxObjectAd ad) async {
    _ensureSupportedPlatform();
    if (_showingAdId != null) {
      throw PlatformException(
        code: 'ADS_SHOW_IN_PROGRESS',
        message:
            'A fullscreen ad is already showing. Wait for it to finish first.',
      );
    }
    _showingAdId = ad.id;
    try {
      await _channel.invokeMethod<void>('show', {'adId': ad.id});
    } on PlatformException catch (error) {
      throw _publicError(error);
    } finally {
      if (_showingAdId == ad.id) {
        _showingAdId = null;
      }
    }
  }

  static Future<void> _disposeObject(_JoliboxObjectAd ad) async {
    try {
      await _channel.invokeMethod<void>('disposeAd', {'adId': ad.id});
    } on PlatformException catch (error) {
      final publicError = _publicError(error);
      if (publicError.code != 'ADS_AD_NOT_FOUND') throw publicError;
    } finally {
      _fullscreenAds.remove(ad.id);
    }
  }

  static void _ensureEventHandler() {
    if (_eventsRegistered) return;
    _eventsRegistered = true;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      final adId = arguments?['adId'] as String?;
      if (adId == null) return;
      final ad = _fullscreenAds[adId];
      ad?._handleEvent(call, arguments);
    });
  }

  static String _requireScene(String scene) {
    final value = scene.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(scene, 'scene', 'scene must not be blank.');
    }
    return value;
  }

  static PlatformException _publicError(PlatformException error) {
    final code = switch (error.code) {
      'AD_LOAD_FAILED' => 'ADS_LOAD_FAILED',
      'AD_SHOW_FAILED' => 'ADS_SHOW_FAILED',
      'AD_NOT_FOUND' => 'ADS_AD_NOT_FOUND',
      'ACTIVITY_REQUIRED' => 'ADS_ACTIVITY_REQUIRED',
      'SHOW_IN_PROGRESS' => 'ADS_SHOW_IN_PROGRESS',
      final code when code.startsWith('ADS_') => code,
      final code => 'ADS_$code',
    };
    return PlatformException(
      code: code,
      message: error.message,
      details: error.details,
      stacktrace: error.stacktrace,
    );
  }

  static void _ensureSupportedPlatform() {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError(
        'Jolibox Ads Flutter supports Android and iOS only.',
      );
    }
  }
}

enum JoliboxMediationEnvironment { staging, production }

enum JoliboxBannerSize { banner, largeBanner, mediumRectangle }

/// Controls whether a banner reserves its layout space before it is ready.
enum JoliboxBannerLayoutMode {
  /// Does not reserve space until the native banner has loaded and laid out.
  collapseUntilLoaded,

  /// Reserves the requested banner height while the banner is loading.
  reserveSpace,
}

class JoliboxFullScreenContentCallback {
  const JoliboxFullScreenContentCallback({
    this.onAdShowedFullScreenContent,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdDismissedFullScreenContent,
    this.onAdFailedToShowFullScreenContent,
  });

  final VoidCallback? onAdShowedFullScreenContent;
  final VoidCallback? onAdImpression;
  final VoidCallback? onAdClicked;
  final VoidCallback? onAdDismissedFullScreenContent;
  final ValueChanged<PlatformException>? onAdFailedToShowFullScreenContent;
}

class JoliboxInterstitialAdLoadCallback {
  const JoliboxInterstitialAdLoadCallback({
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

  final ValueChanged<JoliboxInterstitialAd> onAdLoaded;
  final ValueChanged<PlatformException> onAdFailedToLoad;
}

class JoliboxRewardedAdLoadCallback {
  const JoliboxRewardedAdLoadCallback({
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
  });

  final ValueChanged<JoliboxRewardedAd> onAdLoaded;
  final ValueChanged<PlatformException> onAdFailedToLoad;
}

enum _AdState { loaded, showing, terminal, disposed }

abstract class _JoliboxObjectAd {
  _JoliboxObjectAd(this.id);

  final String id;
  _AdState _state = _AdState.loaded;
  JoliboxFullScreenContentCallback? _fullScreenContentCallback;
  VoidCallback? _onUserEarnedReward;

  set fullScreenContentCallback(JoliboxFullScreenContentCallback? value) {
    assert(_state == _AdState.loaded, 'Set callbacks before showing the ad.');
    if (_state == _AdState.loaded) {
      _fullScreenContentCallback = value;
    }
  }

  Future<void> dispose() async {
    if (_state == _AdState.disposed || _state == _AdState.showing) return;
    _state = _AdState.disposed;
    await JoliboxAdsFlutter._disposeObject(this);
  }

  Future<void> showInternal({VoidCallback? onUserEarnedReward}) async {
    if (_state != _AdState.loaded) {
      throw StateError('This ad can only be shown once after loading.');
    }
    _state = _AdState.showing;
    _onUserEarnedReward = onUserEarnedReward;
    try {
      await JoliboxAdsFlutter._showObject(this);
    } on PlatformException catch (error) {
      if (error.code == 'ADS_ACTIVITY_REQUIRED' ||
          error.code == 'ADS_SHOW_IN_PROGRESS') {
        _state = _AdState.loaded;
        _onUserEarnedReward = null;
      } else {
        _state = _AdState.terminal;
      }
      rethrow;
    } catch (_) {
      _state = _AdState.terminal;
      rethrow;
    }
  }

  void _handleEvent(MethodCall call, Map<Object?, Object?>? arguments) {
    switch (call.method) {
      case 'onAdShowedFullScreenContent':
        _fullScreenContentCallback?.onAdShowedFullScreenContent?.call();
        break;
      case 'onAdImpression':
        _fullScreenContentCallback?.onAdImpression?.call();
        break;
      case 'onAdClicked':
        _fullScreenContentCallback?.onAdClicked?.call();
        break;
      case 'onUserEarnedReward':
        _onUserEarnedReward?.call();
        break;
      case 'onAdDismissedFullScreenContent':
        _state = _AdState.terminal;
        try {
          _fullScreenContentCallback?.onAdDismissedFullScreenContent?.call();
        } finally {
          unawaited(_releaseTerminal());
        }
        break;
      case 'onAdFailedToShowFullScreenContent':
        _state = _AdState.terminal;
        final error = PlatformException(
          code: arguments?['code'] as String? ?? 'ADS_SHOW_FAILED',
          message: arguments?['message'] as String?,
        );
        try {
          _fullScreenContentCallback?.onAdFailedToShowFullScreenContent?.call(
            JoliboxAdsFlutter._publicError(error),
          );
        } finally {
          unawaited(_releaseTerminal());
        }
        break;
    }
  }

  Future<void> _releaseTerminal() async {
    try {
      await JoliboxAdsFlutter._disposeObject(this);
    } catch (_) {}
  }
}

class JoliboxInterstitialAd extends _JoliboxObjectAd {
  JoliboxInterstitialAd._(super.id);

  static Future<void> load({
    required String scene,
    required JoliboxInterstitialAdLoadCallback adLoadCallback,
  }) {
    return JoliboxAdsFlutter._loadObject('loadInterstitial', scene, (id) {
      final ad = JoliboxInterstitialAd._(id);
      JoliboxAdsFlutter._fullscreenAds[id] = ad;
      try {
        adLoadCallback.onAdLoaded(ad);
      } catch (_) {
        unawaited(ad.dispose());
        rethrow;
      }
    }, adLoadCallback.onAdFailedToLoad);
  }

  Future<void> show() => showInternal();
}

class JoliboxRewardedAd extends _JoliboxObjectAd {
  JoliboxRewardedAd._(super.id);

  static Future<void> load({
    required String scene,
    required JoliboxRewardedAdLoadCallback adLoadCallback,
  }) {
    return JoliboxAdsFlutter._loadObject('loadRewarded', scene, (id) {
      final ad = JoliboxRewardedAd._(id);
      JoliboxAdsFlutter._fullscreenAds[id] = ad;
      try {
        adLoadCallback.onAdLoaded(ad);
      } catch (_) {
        unawaited(ad.dispose());
        rethrow;
      }
    }, adLoadCallback.onAdFailedToLoad);
  }

  Future<void> show({VoidCallback? onUserEarnedReward}) {
    return showInternal(onUserEarnedReward: onUserEarnedReward);
  }
}

class JoliboxBannerAd extends StatefulWidget {
  const JoliboxBannerAd({
    super.key,
    required this.scene,
    this.size = JoliboxBannerSize.banner,
    this.layoutMode = JoliboxBannerLayoutMode.collapseUntilLoaded,
    this.onLoaded,
    this.onFailedToLoad,
    this.onImpression,
    this.onClicked,
    this.onOpened,
    this.onClosed,
  });

  final String scene;
  final JoliboxBannerSize size;
  final JoliboxBannerLayoutMode layoutMode;

  /// Called after the native banner is ready to be displayed.
  final VoidCallback? onLoaded;
  final ValueChanged<PlatformException>? onFailedToLoad;
  final VoidCallback? onImpression;
  final VoidCallback? onClicked;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;

  @override
  State<JoliboxBannerAd> createState() => _JoliboxBannerAdState();
}

class _JoliboxBannerAdState extends State<JoliboxBannerAd> {
  MethodChannel? _eventChannel;
  int _viewGeneration = 0;
  _BannerLoadState _loadState = _BannerLoadState.idle;

  @override
  void didUpdateWidget(covariant JoliboxBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene || oldWidget.size != widget.size) {
      _viewGeneration++;
      _eventChannel?.setMethodCallHandler(null);
      _eventChannel = null;
      _loadState = _BannerLoadState.idle;
    }
  }

  @override
  void dispose() {
    _viewGeneration++;
    _eventChannel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    JoliboxAdsFlutter._ensureSupportedPlatform();
    final height = switch (widget.size) {
      JoliboxBannerSize.banner => 50.0,
      JoliboxBannerSize.largeBanner => 100.0,
      JoliboxBannerSize.mediumRectangle => 250.0,
    };
    final shouldReserveSpace =
        widget.layoutMode == JoliboxBannerLayoutMode.reserveSpace ||
            _loadState == _BannerLoadState.loaded;
    final generation = _viewGeneration;
    final params = {
      'scene': JoliboxAdsFlutter._requireScene(widget.scene),
      'size': widget.size.name,
    };
    // Keep the platform view mounted so native loading can start, while only
    // reserving layout space after the banner has loaded successfully.
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: shouldReserveSpace ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          height: height,
          child: defaultTargetPlatform == TargetPlatform.android
              ? AndroidView(
                  key: ValueKey('${widget.scene}:${widget.size.name}'),
                  viewType: 'jolibox_ads_flutter/banner',
                  creationParams: params,
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: (id) =>
                      _onPlatformViewCreated(id, generation),
                )
              : UiKitView(
                  key: ValueKey('${widget.scene}:${widget.size.name}'),
                  viewType: 'jolibox_ads_flutter/banner',
                  creationParams: params,
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: (id) =>
                      _onPlatformViewCreated(id, generation),
                ),
        ),
      ),
    );
  }

  Future<void> _onPlatformViewCreated(int id, int generation) async {
    if (!mounted || generation != _viewGeneration) {
      return;
    }
    final channel = MethodChannel('jolibox_ads_flutter/banner/$id');
    _eventChannel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted ||
          generation != _viewGeneration ||
          _eventChannel != channel) {
        return;
      }
      final arguments = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'onLoaded':
          setState(() => _loadState = _BannerLoadState.loaded);
          widget.onLoaded?.call();
          break;
        case 'onImpression':
          widget.onImpression?.call();
          break;
        case 'onClicked':
          widget.onClicked?.call();
          break;
        case 'onOpened':
          widget.onOpened?.call();
          break;
        case 'onClosed':
          widget.onClosed?.call();
          break;
        case 'onFailedToLoad':
          final error = PlatformException(
            code: arguments?['code'] as String? ?? 'ADS_LOAD_FAILED',
            message: arguments?['message'] as String?,
          );
          setState(() => _loadState = _BannerLoadState.failed);
          widget.onFailedToLoad?.call(JoliboxAdsFlutter._publicError(error));
          break;
      }
    });
    if (!mounted || _eventChannel != channel) return;
    _loadState = _BannerLoadState.loading;
    try {
      await channel.invokeMethod<void>('loadBanner');
    } on PlatformException catch (error) {
      if (mounted && _eventChannel == channel) {
        setState(() => _loadState = _BannerLoadState.failed);
        widget.onFailedToLoad?.call(JoliboxAdsFlutter._publicError(error));
      }
    }
  }
}

enum _BannerLoadState { idle, loading, loaded, failed }
