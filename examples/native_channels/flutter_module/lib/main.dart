import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

const _source = String.fromEnvironment('JOLIBOX_SOURCE');
const _scene = String.fromEnvironment('JOLIBOX_SCENE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const MethodChannel('jolibox_native_channels/host')
      .invokeMethod<void>('waitForHostReady');
  runApp(const MaterialApp(home: NativeChannelsPage()));
}

class NativeChannelsPage extends StatefulWidget {
  const NativeChannelsPage({super.key});

  @override
  State<NativeChannelsPage> createState() => _NativeChannelsPageState();
}

class _NativeChannelsPageState extends State<NativeChannelsPage> {
  bool? _available;
  bool _initialized = false;
  bool _busy = false;
  int _callbacks = 0;
  String _status = 'Checking native bridge';
  JoliboxInterstitialAd? _interstitial;
  JoliboxRewardedAd? _rewarded;

  bool get _configured => _source.isNotEmpty && _scene.isNotEmpty;
  bool get _ready => _available == true && _configured && _initialized;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  @override
  void dispose() {
    if (_interstitial != null) unawaited(_interstitial!.dispose());
    if (_rewarded != null) unawaited(_rewarded!.dispose());
    super.dispose();
  }

  void _report(String value) {
    if (mounted) setState(() => _status = value);
  }

  Future<void> _check() async {
    try {
      final available = await JoliboxAdsFlutter.isAvailable();
      if (!mounted) return;
      setState(() {
        _available = available;
        _status = available ? 'Bridge registered' : 'Bridge absent';
      });
    } catch (error) {
      _report('Capability error: $error');
    }
  }

  Future<void> _exerciseNoOp() async {
    setState(() {
      _busy = true;
      _callbacks = 0;
    });
    try {
      await JoliboxAdsFlutter.initialize(
        joliSource: '',
        environment: JoliboxMediationEnvironment.staging,
      );
      await JoliboxInterstitialAd.load(
        scene: '',
        adLoadCallback: JoliboxInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _recordCallback();
            unawaited(ad.dispose());
          },
          onAdFailedToLoad: (_) => _recordCallback(),
        ),
      );
      await JoliboxRewardedAd.load(
        scene: '',
        adLoadCallback: JoliboxRewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _recordCallback();
            unawaited(ad.dispose());
          },
          onAdFailedToLoad: (_) => _recordCallback(),
        ),
      );
      _report('No-op Futures completed; callbacks: $_callbacks');
    } catch (error) {
      _report('No-op error: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _recordCallback() {
    if (mounted) setState(() => _callbacks++);
  }

  Future<void> _initialize() async {
    try {
      await JoliboxAdsFlutter.initialize(
        joliSource: _source,
        environment: JoliboxMediationEnvironment.staging,
      );
      if (mounted) setState(() => _initialized = true);
      _report('SDK initialized');
    } catch (error) {
      _report('Initialization failed: $error');
    }
  }

  Future<void> _loadInterstitial() async {
    final previous = _interstitial;
    _interstitial = null;
    if (previous != null) await previous.dispose();
    _report('Loading interstitial');
    try {
      await JoliboxInterstitialAd.load(
        scene: _scene,
        adLoadCallback: JoliboxInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (!mounted) {
              unawaited(ad.dispose());
              return;
            }
            setState(() => _interstitial = ad);
            _report('Interstitial loaded');
          },
          onAdFailedToLoad: (error) => _report('Interstitial failed: $error'),
        ),
      );
    } catch (error) {
      _report('Interstitial error: $error');
    }
  }

  Future<void> _loadRewarded() async {
    final previous = _rewarded;
    _rewarded = null;
    if (previous != null) await previous.dispose();
    _report('Loading rewarded');
    try {
      await JoliboxRewardedAd.load(
        scene: _scene,
        adLoadCallback: JoliboxRewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (!mounted) {
              unawaited(ad.dispose());
              return;
            }
            setState(() => _rewarded = ad);
            _report('Rewarded loaded');
          },
          onAdFailedToLoad: (error) => _report('Rewarded failed: $error'),
        ),
      );
    } catch (error) {
      _report('Rewarded error: $error');
    }
  }

  Future<void> _showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return;
    ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
      onAdDismissedFullScreenContent: () {
        if (mounted) setState(() => _interstitial = null);
        _report('Interstitial dismissed');
      },
      onAdFailedToShowFullScreenContent: (error) =>
          _report('Interstitial show failed: $error'),
    );
    try {
      await ad.show();
    } catch (error) {
      _report('Interstitial show error: $error');
    }
  }

  Future<void> _showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return;
    ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
      onAdDismissedFullScreenContent: () {
        if (mounted) setState(() => _rewarded = null);
        _report('Rewarded dismissed');
      },
      onAdFailedToShowFullScreenContent: (error) =>
          _report('Rewarded show failed: $error'),
    );
    try {
      await ad.show(onUserEarnedReward: () => _report('Reward received'));
    } catch (error) {
      _report('Rewarded show error: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Jolibox native channels')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Bridge: ${_available ?? 'checking'}'),
            Text(_status),
            if (_available == false) ...[
              FilledButton(
                onPressed: _busy ? null : _exerciseNoOp,
                child: const Text('Check no-op calls'),
              ),
              JoliboxBannerAd(
                scene: '',
                layoutMode: JoliboxBannerLayoutMode.reserveSpace,
                onLoaded: _recordCallback,
                onFailedToLoad: (_) => _recordCallback(),
              ),
              Text('Callbacks: $_callbacks'),
            ],
            if (_available == true) ...[
              if (!_configured) const Text('Ad test configuration missing'),
              FilledButton(
                onPressed: _configured && !_initialized ? _initialize : null,
                child: const Text('Initialize SDK'),
              ),
              Wrap(spacing: 8, children: [
                OutlinedButton(
                  onPressed: _ready ? _loadInterstitial : null,
                  child: const Text('Load interstitial'),
                ),
                OutlinedButton(
                  onPressed: _ready && _interstitial != null
                      ? _showInterstitial
                      : null,
                  child: const Text('Show interstitial'),
                ),
                OutlinedButton(
                  onPressed: _ready ? _loadRewarded : null,
                  child: const Text('Load rewarded'),
                ),
                OutlinedButton(
                  onPressed: _ready && _rewarded != null ? _showRewarded : null,
                  child: const Text('Show rewarded'),
                ),
              ]),
              if (_ready)
                JoliboxBannerAd(
                  scene: _scene,
                  onLoaded: () => _report('Banner loaded'),
                  onFailedToLoad: (error) => _report('Banner failed: $error'),
                ),
            ],
          ],
        ),
      );
}
