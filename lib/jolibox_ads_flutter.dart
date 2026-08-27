import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class JoliboxAdsFlutter {
  JoliboxAdsFlutter._();
  static const MethodChannel _channel = MethodChannel('jolibox_ads_flutter');
  static final Map<String, JoliboxFullscreenAdCallbacks?> _fullscreenCallbacks =
      {};
  static final Map<String, _JoliboxObjectAd> _fullscreenObjects = {};
  static bool _fullscreenEventHandlerInitialized = false;
  static String? _showingFullscreenAdId;
  static Future<JoliboxFullscreenAd> loadInterstitial(String scene) =>
      _load('loadInterstitial', scene, JoliboxAdFormat.interstitial);
  static Future<JoliboxFullscreenAd> loadRewarded(String scene) =>
      _load('loadRewarded', scene, JoliboxAdFormat.rewarded);

  static Future<String> _loadObject(String method, String scene) async {
    _ensureSupportedPlatform();
    _ensureFullscreenEventHandler();
    final id = await _channel.invokeMethod<String>(method, {
      'scene': _requireScene(scene),
    });
    if (id == null || id.isEmpty) {
      throw StateError('Jolibox Ads did not return a loaded ad.');
    }
    return id;
  }

  static Future<void> _showObject(_JoliboxObjectAd ad) async {
    _ensureSupportedPlatform();
    _beginFullscreenShow(ad.id);
    try {
      await _channel.invokeMethod<Object?>('show', {'adId': ad.id});
    } finally {
      _endFullscreenShow(ad.id);
    }
  }

  static Future<void> _disposeObject(_JoliboxObjectAd ad) async {
    _ensureSupportedPlatform();
    try {
      await _channel.invokeMethod<void>('disposeAd', {'adId': ad.id});
    } on PlatformException catch (error) {
      if (error.code != 'ADS_AD_NOT_FOUND') rethrow;
    } finally {
      _fullscreenObjects.remove(ad.id);
    }
  }

  static Future<void> _loadInterstitialObject(
    String scene,
    JoliboxInterstitialAdLoadCallback callback,
  ) async {
    late JoliboxInterstitialAd ad;
    try {
      final id = await _loadObject('loadInterstitial', scene);
      ad = JoliboxInterstitialAd._(id);
      _fullscreenObjects[id] = ad;
    } on PlatformException catch (error) {
      callback.onAdFailedToLoad(error);
      return;
    } catch (error) {
      callback.onAdFailedToLoad(
        PlatformException(code: 'ADS_LOAD_FAILED', message: '$error'),
      );
      return;
    }
    callback.onAdLoaded(ad);
  }

  static Future<void> _loadRewardedObject(
    String scene,
    JoliboxRewardedAdLoadCallback callback,
  ) async {
    late JoliboxRewardedAd ad;
    try {
      final id = await _loadObject('loadRewarded', scene);
      ad = JoliboxRewardedAd._(id);
      _fullscreenObjects[id] = ad;
    } on PlatformException catch (error) {
      callback.onAdFailedToLoad(error);
      return;
    } catch (error) {
      callback.onAdFailedToLoad(
        PlatformException(code: 'ADS_LOAD_FAILED', message: '$error'),
      );
      return;
    }
    callback.onAdLoaded(ad);
  }

  static Future<JoliboxFullscreenAd> _load(
    String method,
    String scene,
    JoliboxAdFormat format,
  ) async {
    _ensureSupportedPlatform();
    final id = await _channel.invokeMethod<String>(method, {
      'scene': _requireScene(scene),
    });
    if (id == null || id.isEmpty)
      throw StateError('Jolibox Ads did not return a loaded ad.');
    return JoliboxFullscreenAd._(id, format);
  }

  static Future<JoliboxAdsShowResult> show(
    JoliboxFullscreenAd ad, {
    JoliboxFullscreenAdCallbacks? callbacks,
  }) async {
    _ensureSupportedPlatform();
    _ensureFullscreenEventHandler();
    _beginFullscreenShow(ad.id);
    _fullscreenCallbacks[ad.id] = callbacks;
    var shouldRelease = false;
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('show', {
        'adId': ad.id,
      });
      shouldRelease = true;
      return JoliboxAdsShowResult(
        clicked: result?['clicked'] as bool? ?? false,
        rewarded: result?['rewarded'] as bool? ?? false,
      );
    } on PlatformException catch (error) {
      shouldRelease = error.code != 'ADS_ACTIVITY_REQUIRED';
      rethrow;
    } finally {
      _fullscreenCallbacks.remove(ad.id);
      if (shouldRelease) {
        await _disposeIdSilently(ad.id);
      }
      _endFullscreenShow(ad.id);
    }
  }

  static void _ensureFullscreenEventHandler() {
    if (_fullscreenEventHandlerInitialized) return;
    _fullscreenEventHandlerInitialized = true;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      final adId = arguments?['adId'] as String?;
      final objectAd = adId == null ? null : _fullscreenObjects[adId];
      if (objectAd != null) {
        objectAd._handleEvent(call, arguments);
        return;
      }
      final callbacks = adId == null ? null : _fullscreenCallbacks[adId];
      switch (call.method) {
        case 'onAdShowedFullScreenContent':
          callbacks?.onAdShowedFullScreenContent?.call();
          break;
        case 'onAdImpression':
          callbacks?.onAdImpression?.call();
          break;
        case 'onAdClicked':
          callbacks?.onAdClicked?.call();
          break;
        case 'onUserEarnedReward':
          callbacks?.onUserEarnedReward?.call();
          break;
        case 'onAdDismissedFullScreenContent':
          callbacks?.onAdDismissedFullScreenContent?.call();
          break;
        case 'onAdFailedToShowFullScreenContent':
          callbacks?.onAdFailedToShowFullScreenContent?.call(
            PlatformException(
              code: arguments?['code'] as String? ?? 'ADS_SHOW_FAILED',
              message: arguments?['message'] as String?,
            ),
          );
          break;
      }
    });
  }

  static Future<void> disposeAd(JoliboxFullscreenAd ad) async {
    _ensureSupportedPlatform();
    await _disposeIdSilently(ad.id);
  }

  static Future<void> _disposeIdSilently(String id) async {
    try {
      await _channel.invokeMethod<void>('disposeAd', {'adId': id});
    } on PlatformException catch (error) {
      if (error.code != 'ADS_AD_NOT_FOUND') rethrow;
    }
  }

  static String _requireScene(String scene) {
    final value = scene.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(scene, 'scene', 'scene must not be blank.');
    }
    return value;
  }

  static void _beginFullscreenShow(String adId) {
    final showingAdId = _showingFullscreenAdId;
    if (showingAdId != null) {
      throw StateError(
        'A fullscreen ad is already showing. Wait for it to finish first.',
      );
    }
    _showingFullscreenAdId = adId;
  }

  static void _endFullscreenShow(String adId) {
    if (_showingFullscreenAdId == adId) {
      _showingFullscreenAdId = null;
    }
  }

  static void _ensureSupportedPlatform() {
    if (!Platform.isAndroid && !Platform.isIOS)
      throw UnsupportedError(
        'Jolibox Ads Flutter supports Android and iOS only.',
      );
  }
}

enum JoliboxAdFormat { interstitial, rewarded }

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

enum _JoliboxObjectAdState { loaded, showing, terminal, disposed }

abstract class _JoliboxObjectAd {
  _JoliboxObjectAd(this.id);

  final String id;
  _JoliboxObjectAdState _state = _JoliboxObjectAdState.loaded;
  JoliboxFullScreenContentCallback? _fullScreenContentCallback;
  VoidCallback? _onUserEarnedReward;

  set fullScreenContentCallback(JoliboxFullScreenContentCallback? value) {
    assert(
      _state == _JoliboxObjectAdState.loaded,
      'fullScreenContentCallback must be set before show().',
    );
    if (_state == _JoliboxObjectAdState.loaded) {
      _fullScreenContentCallback = value;
    }
  }

  Future<void> dispose() async {
    if (_state == _JoliboxObjectAdState.disposed) return;
    if (_state == _JoliboxObjectAdState.showing) {
      return;
    }
    _state = _JoliboxObjectAdState.disposed;
    await JoliboxAdsFlutter._disposeObject(this);
  }

  Future<void> _show({VoidCallback? onUserEarnedReward}) async {
    if (_state != _JoliboxObjectAdState.loaded) {
      throw StateError('This ad can only be shown once after loading.');
    }
    if (JoliboxAdsFlutter._showingFullscreenAdId != null) {
      throw StateError(
        'A fullscreen ad is already showing. Wait for it to finish first.',
      );
    }
    _onUserEarnedReward = onUserEarnedReward;
    _state = _JoliboxObjectAdState.showing;
    try {
      await JoliboxAdsFlutter._showObject(this);
    } on PlatformException catch (error) {
      if (error.code == 'ADS_ACTIVITY_REQUIRED' ||
          error.code == 'ADS_SHOW_IN_PROGRESS') {
        _state = _JoliboxObjectAdState.loaded;
        _onUserEarnedReward = null;
      } else {
        _state = _JoliboxObjectAdState.terminal;
      }
      rethrow;
    } catch (error) {
      _state = _JoliboxObjectAdState.terminal;
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
        _state = _JoliboxObjectAdState.terminal;
        _fullScreenContentCallback?.onAdDismissedFullScreenContent?.call();
        unawaited(_releaseAfterTerminal());
        break;
      case 'onAdFailedToShowFullScreenContent':
        _state = _JoliboxObjectAdState.terminal;
        final error = PlatformException(
          code: arguments?['code'] as String? ?? 'ADS_SHOW_FAILED',
          message: arguments?['message'] as String?,
        );
        _fullScreenContentCallback?.onAdFailedToShowFullScreenContent?.call(
          error,
        );
        unawaited(_releaseAfterTerminal());
        break;
    }
  }

  Future<void> _releaseAfterTerminal() async {
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
  }) => JoliboxAdsFlutter._loadInterstitialObject(scene, adLoadCallback);

  Future<void> show() => _show();
}

class JoliboxRewardedAd extends _JoliboxObjectAd {
  JoliboxRewardedAd._(super.id);

  static Future<void> load({
    required String scene,
    required JoliboxRewardedAdLoadCallback adLoadCallback,
  }) => JoliboxAdsFlutter._loadRewardedObject(scene, adLoadCallback);

  Future<void> show({VoidCallback? onUserEarnedReward}) =>
      _show(onUserEarnedReward: onUserEarnedReward);
}

@immutable
class JoliboxFullscreenAd {
  const JoliboxFullscreenAd._(this.id, this.format);
  final String id;
  final JoliboxAdFormat format;
}

@immutable
class JoliboxAdsShowResult {
  const JoliboxAdsShowResult({required this.clicked, required this.rewarded});
  final bool clicked;
  final bool rewarded;
}

class JoliboxFullscreenAdCallbacks {
  const JoliboxFullscreenAdCallbacks({
    this.onAdShowedFullScreenContent,
    this.onAdImpression,
    this.onAdClicked,
    this.onUserEarnedReward,
    this.onAdDismissedFullScreenContent,
    this.onAdFailedToShowFullScreenContent,
  });
  final VoidCallback? onAdShowedFullScreenContent;
  final VoidCallback? onAdImpression;
  final VoidCallback? onAdClicked;
  final VoidCallback? onUserEarnedReward;
  final VoidCallback? onAdDismissedFullScreenContent;
  final ValueChanged<PlatformException>? onAdFailedToShowFullScreenContent;
}

class JoliboxBannerAdCallbacks {
  const JoliboxBannerAdCallbacks({
    this.onLoaded,
    this.onFailedToLoad,
    this.onImpression,
    this.onClicked,
    this.onOpened,
    this.onClosed,
  });

  final VoidCallback? onLoaded;
  final ValueChanged<PlatformException>? onFailedToLoad;
  final VoidCallback? onImpression;
  final VoidCallback? onClicked;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;
}

class JoliboxBannerAd extends StatefulWidget {
  const JoliboxBannerAd({
    super.key,
    required this.scene,
    this.size = JoliboxBannerSize.banner,
    this.callbacks,
    this.onLoaded,
    this.onFailedToLoad,
    this.onImpression,
    this.onClicked,
    this.onOpened,
    this.onClosed,
  }) : assert(
         callbacks == null ||
             (onLoaded == null &&
                 onFailedToLoad == null &&
                 onImpression == null &&
                 onClicked == null &&
                 onOpened == null &&
                 onClosed == null),
         'Use either callbacks or the legacy Banner callbacks, not both.',
       );
  final String scene;
  final JoliboxBannerSize size;
  final JoliboxBannerAdCallbacks? callbacks;
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
  double? _resolvedAdaptiveHeight;

  @override
  void didUpdateWidget(covariant JoliboxBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene || oldWidget.size != widget.size) {
      _viewGeneration++;
      _eventChannel?.setMethodCallHandler(null);
      _eventChannel = null;
      _resolvedAdaptiveHeight = null;
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
    final creationParams = {
      'scene': JoliboxAdsFlutter._requireScene(widget.scene),
      ...widget.size.creationParams,
    };
    final viewType = 'jolibox_ads_flutter/banner';
    final viewGeneration = _viewGeneration;
    return SizedBox(
      height: widget.size.fixedHeight ?? _resolvedAdaptiveHeight ?? 1,
      width: widget.size.width ?? double.infinity,
      child: Platform.isAndroid
          ? AndroidView(
              key: ValueKey('${widget.scene}:${widget.size.identity}'),
              viewType: viewType,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: (id) =>
                  _onPlatformViewCreated(id, viewGeneration),
            )
          : UiKitView(
              key: ValueKey('${widget.scene}:${widget.size.identity}'),
              viewType: viewType,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: (id) =>
                  _onPlatformViewCreated(id, viewGeneration),
            ),
    );
  }

  Future<void> _onPlatformViewCreated(int id, int viewGeneration) async {
    if (!mounted || viewGeneration != _viewGeneration) return;
    final channel = MethodChannel('jolibox_ads_flutter/banner/$id');
    _eventChannel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted ||
          viewGeneration != _viewGeneration ||
          _eventChannel != channel) {
        return;
      }
      if (call.method == 'onLoaded') {
        final arguments = call.arguments as Map<Object?, Object?>?;
        if (widget.size.isAdaptive) {
          final height = (arguments?['height'] as num?)?.toDouble();
          if (height == null || !height.isFinite || height <= 0) {
            (widget.callbacks?.onFailedToLoad ?? widget.onFailedToLoad)?.call(
              PlatformException(
                code: 'ADS_INVALID_AD_SIZE',
                message:
                    'The loaded adaptive Banner did not provide a valid height.',
              ),
            );
            return;
          }
          setState(() => _resolvedAdaptiveHeight = height);
        }
        (widget.callbacks?.onLoaded ?? widget.onLoaded)?.call();
      }
      if (call.method == 'onImpression') {
        (widget.callbacks?.onImpression ?? widget.onImpression)?.call();
      }
      if (call.method == 'onClicked') {
        (widget.callbacks?.onClicked ?? widget.onClicked)?.call();
      }
      if (call.method == 'onOpened') {
        (widget.callbacks?.onOpened ?? widget.onOpened)?.call();
      }
      if (call.method == 'onClosed') {
        (widget.callbacks?.onClosed ?? widget.onClosed)?.call();
      }
      if (call.method == 'onFailedToLoad') {
        final arguments = call.arguments as Map<Object?, Object?>?;
        (widget.callbacks?.onFailedToLoad ?? widget.onFailedToLoad)?.call(
          PlatformException(
            code: arguments?['code'] as String? ?? 'ADS_LOAD_FAILED',
            message: arguments?['message'] as String?,
          ),
        );
        if (widget.size.isAdaptive && mounted) {
          setState(() => _resolvedAdaptiveHeight = null);
        }
      }
    });
    if (!mounted || _eventChannel != channel) return;
    try {
      await channel.invokeMethod<void>('loadBanner');
    } on PlatformException catch (error) {
      if (mounted && _eventChannel == channel) {
        (widget.callbacks?.onFailedToLoad ?? widget.onFailedToLoad)?.call(
          error,
        );
      }
    }
  }
}

class JoliboxBannerSize {
  const JoliboxBannerSize._fixed(this.name, this.fixedHeight)
    : width = null,
      maxHeight = null;

  JoliboxBannerSize.largeAnchoredAdaptive({required double width})
    : this._adaptive('largeAnchoredAdaptive', width, null);

  JoliboxBannerSize.inlineAdaptive({required double width, double? maxHeight})
    : this._adaptive('inlineAdaptive', width, maxHeight);

  JoliboxBannerSize._adaptive(this.name, double width, this.maxHeight)
    : fixedHeight = null,
      width = width {
    if (!width.isFinite || width <= 0) {
      throw ArgumentError.value(
        width,
        'width',
        'Adaptive Banner width must be finite and greater than zero.',
      );
    }
    if (maxHeight != null && (!maxHeight!.isFinite || maxHeight! < 32)) {
      throw ArgumentError.value(
        maxHeight,
        'maxHeight',
        'Inline adaptive Banner maxHeight must be finite and at least 32.',
      );
    }
  }

  static const banner = JoliboxBannerSize._fixed('banner', 50);
  static const largeBanner = JoliboxBannerSize._fixed('largeBanner', 100);
  static const mediumRectangle = JoliboxBannerSize._fixed(
    'mediumRectangle',
    250,
  );

  final String name;
  final double? fixedHeight;
  final double? width;
  final double? maxHeight;

  bool get isAdaptive => width != null;

  String get identity => '$name:$width:$maxHeight';

  Map<String, Object> get creationParams => {
    'size': name,
    if (width != null) 'width': width!,
    if (maxHeight != null) 'maxHeight': maxHeight!,
  };

  @override
  bool operator ==(Object other) =>
      other is JoliboxBannerSize &&
      name == other.name &&
      fixedHeight == other.fixedHeight &&
      width == other.width &&
      maxHeight == other.maxHeight;

  @override
  int get hashCode => Object.hash(name, fixedHeight, width, maxHeight);
}
