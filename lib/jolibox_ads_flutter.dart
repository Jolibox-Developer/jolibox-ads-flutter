import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class JoliboxAdsFlutter {
  JoliboxAdsFlutter._();
  static const MethodChannel _channel = MethodChannel('jolibox_ads_flutter');
  static final Map<String, JoliboxFullscreenAdCallbacks?> _fullscreenCallbacks =
      {};
  static bool _fullscreenEventHandlerInitialized = false;
  static Future<JoliboxFullscreenAd> loadInterstitial(String scene) =>
      _load('loadInterstitial', scene, JoliboxAdFormat.interstitial);
  static Future<JoliboxFullscreenAd> loadRewarded(String scene) =>
      _load('loadRewarded', scene, JoliboxAdFormat.rewarded);
  static Future<JoliboxFullscreenAd> _load(
    String method,
    String scene,
    JoliboxAdFormat format,
  ) async {
    _ensureSupportedPlatform();
    final id = await _channel.invokeMethod<String>(method, {'scene': scene});
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
    _fullscreenCallbacks[ad.id] = callbacks;
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('show', {
        'adId': ad.id,
      });
      return JoliboxAdsShowResult(
        clicked: result?['clicked'] as bool? ?? false,
        rewarded: result?['rewarded'] as bool? ?? false,
      );
    } finally {
      _fullscreenCallbacks.remove(ad.id);
    }
  }

  static void _ensureFullscreenEventHandler() {
    if (_fullscreenEventHandlerInitialized) return;
    _fullscreenEventHandlerInitialized = true;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments as Map<Object?, Object?>?;
      final adId = arguments?['adId'] as String?;
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
    await _channel.invokeMethod<void>('disposeAd', {'adId': ad.id});
  }

  static void _ensureSupportedPlatform() {
    if (!Platform.isAndroid && !Platform.isIOS)
      throw UnsupportedError(
        'Jolibox Ads Flutter supports Android and iOS only.',
      );
  }
}

enum JoliboxAdFormat { interstitial, rewarded }

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

class JoliboxBannerAd extends StatefulWidget {
  const JoliboxBannerAd({
    super.key,
    required this.scene,
    this.size = JoliboxBannerSize.banner,
    this.onLoaded,
    this.onFailedToLoad,
    this.onImpression,
    this.onClicked,
    this.onOpened,
    this.onClosed,
  });
  final String scene;
  final JoliboxBannerSize size;
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

  @override
  void didUpdateWidget(covariant JoliboxBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene || oldWidget.size != widget.size) {
      _eventChannel?.setMethodCallHandler(null);
      _eventChannel = null;
    }
  }

  @override
  void dispose() {
    _eventChannel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    JoliboxAdsFlutter._ensureSupportedPlatform();
    final creationParams = {'scene': widget.scene, 'size': widget.size.name};
    final viewType = 'jolibox_ads_flutter/banner';
    return SizedBox(
      height: widget.size.height,
      width: double.infinity,
      child: Platform.isAndroid
          ? AndroidView(
              key: ValueKey('${widget.scene}:${widget.size.name}'),
              viewType: viewType,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onPlatformViewCreated,
            )
          : UiKitView(
              key: ValueKey('${widget.scene}:${widget.size.name}'),
              viewType: viewType,
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _onPlatformViewCreated,
            ),
    );
  }

  Future<void> _onPlatformViewCreated(int id) async {
    final channel = MethodChannel('jolibox_ads_flutter/banner/$id');
    _eventChannel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onLoaded') widget.onLoaded?.call();
      if (call.method == 'onImpression') widget.onImpression?.call();
      if (call.method == 'onClicked') widget.onClicked?.call();
      if (call.method == 'onOpened') widget.onOpened?.call();
      if (call.method == 'onClosed') widget.onClosed?.call();
      if (call.method == 'onFailedToLoad') {
        final arguments = call.arguments as Map<Object?, Object?>?;
        widget.onFailedToLoad?.call(
          PlatformException(
            code: arguments?['code'] as String? ?? 'ADS_LOAD_FAILED',
            message: arguments?['message'] as String?,
          ),
        );
      }
    });
    if (!mounted || _eventChannel != channel) return;
    try {
      await channel.invokeMethod<void>('loadBanner');
    } on PlatformException catch (error) {
      if (mounted && _eventChannel == channel) {
        widget.onFailedToLoad?.call(error);
      }
    }
  }
}

enum JoliboxBannerSize {
  banner(50),
  largeBanner(100),
  mediumRectangle(250);

  const JoliboxBannerSize(this.height);
  final double height;
}
