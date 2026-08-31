import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jolibox_ads_flutter/jolibox_ads_flutter.dart';

import 'example_native_initialization.dart';

const _scene =
    String.fromEnvironment('JOLIBOX_SCENE', defaultValue: 'YOUR_SCENE');

void main() => runApp(const JoliboxAdsExampleApp());

class JoliboxAdsExampleApp extends StatelessWidget {
  const JoliboxAdsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const JoliboxAdsExamplePage(),
    );
  }
}

class JoliboxAdsExamplePage extends StatefulWidget {
  const JoliboxAdsExamplePage({super.key});

  @override
  State<JoliboxAdsExamplePage> createState() => _JoliboxAdsExamplePageState();
}

class _JoliboxAdsExamplePageState extends State<JoliboxAdsExamplePage> {
  JoliboxBannerSize _bannerSize = JoliboxBannerSize.banner;
  JoliboxInterstitialAd? _interstitialAd;
  JoliboxRewardedAd? _rewardedAd;
  bool _nativeInitialized = false;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;
  String _status = 'Waiting for native SDK initialization.';

  @override
  void initState() {
    super.initState();
    unawaited(_waitForNativeInitialization());
  }

  @override
  void dispose() {
    final interstitialAd = _interstitialAd;
    final rewardedAd = _rewardedAd;
    if (interstitialAd != null) unawaited(interstitialAd.dispose());
    if (rewardedAd != null) unawaited(rewardedAd.dispose());
    super.dispose();
  }

  Future<void> _waitForNativeInitialization() async {
    while (mounted) {
      final snapshot = await ExampleNativeInitialization.fetch();
      if (!mounted) return;
      setState(() {
        _nativeInitialized = snapshot.isReady;
        _status = snapshot.message;
      });
      if (snapshot.isTerminal) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _loadInterstitial() async {
    setState(() => _loadingInterstitial = true);
    _setStatus('Loading interstitial...');
    final oldAd = _interstitialAd;
    _interstitialAd = null;
    if (oldAd != null) unawaited(oldAd.dispose());

    await JoliboxInterstitialAd.load(
      scene: _scene,
      adLoadCallback: JoliboxInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            unawaited(ad.dispose());
            return;
          }
          setState(() {
            _interstitialAd = ad;
            _loadingInterstitial = false;
          });
          _setStatus('Interstitial loaded. Tap Show Interstitial.');
        },
        onAdFailedToLoad: (error) {
          if (mounted) setState(() => _loadingInterstitial = false);
          _setStatus('Interstitial load failed: ${_formatError(error)}');
        },
      ),
    );
  }

  Future<void> _showInterstitial() async {
    final ad = _interstitialAd;
    if (ad == null) return;
    ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
      onAdShowedFullScreenContent: () => _setStatus('Interstitial showed.'),
      onAdImpression: () => _setStatus('Interstitial impression.'),
      onAdClicked: () => _setStatus('Interstitial clicked.'),
      onAdDismissedFullScreenContent: () {
        if (mounted) setState(() => _interstitialAd = null);
        _setStatus('Interstitial dismissed. Load a new ad to show again.');
      },
      onAdFailedToShowFullScreenContent: (error) {
        if (mounted) setState(() => _interstitialAd = null);
        _setStatus('Interstitial show failed: ${_formatError(error)}');
      },
    );
    try {
      await ad.show();
    } catch (error) {
      _setStatus('Interstitial show failed: $error');
    }
  }

  Future<void> _loadRewarded() async {
    setState(() => _loadingRewarded = true);
    _setStatus('Loading rewarded ad...');
    final oldAd = _rewardedAd;
    _rewardedAd = null;
    if (oldAd != null) unawaited(oldAd.dispose());

    await JoliboxRewardedAd.load(
      scene: _scene,
      adLoadCallback: JoliboxRewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            unawaited(ad.dispose());
            return;
          }
          setState(() {
            _rewardedAd = ad;
            _loadingRewarded = false;
          });
          _setStatus('Rewarded ad loaded. Tap Show Rewarded Ad.');
        },
        onAdFailedToLoad: (error) {
          if (mounted) setState(() => _loadingRewarded = false);
          _setStatus('Rewarded load failed: ${_formatError(error)}');
        },
      ),
    );
  }

  Future<void> _showRewarded() async {
    final ad = _rewardedAd;
    if (ad == null) return;
    ad.fullScreenContentCallback = JoliboxFullScreenContentCallback(
      onAdShowedFullScreenContent: () => _setStatus('Rewarded ad showed.'),
      onAdImpression: () => _setStatus('Rewarded ad impression.'),
      onAdClicked: () => _setStatus('Rewarded ad clicked.'),
      onAdDismissedFullScreenContent: () {
        if (mounted) setState(() => _rewardedAd = null);
        _setStatus('Rewarded ad dismissed. Load a new ad to show again.');
      },
      onAdFailedToShowFullScreenContent: (error) {
        if (mounted) setState(() => _rewardedAd = null);
        _setStatus('Rewarded show failed: ${_formatError(error)}');
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: () => _setStatus('Rewarded ad reward callback.'),
      );
    } catch (error) {
      _setStatus('Rewarded show failed: $error');
    }
  }

  void _setStatus(String value) {
    debugPrint('[Jolibox Ads QA] $value');
    if (mounted) setState(() => _status = value);
  }

  String _formatError(PlatformException error) =>
      error.message == null ? error.code : '${error.code}: ${error.message}';

  @override
  Widget build(BuildContext context) {
    final controlsEnabled = _nativeInitialized;
    return Scaffold(
      appBar: AppBar(title: const Text('Jolibox Ad Mediation QA')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Scene: $_scene'),
            const SizedBox(height: 12),
            const Text(
              'This mixed-host example initializes the SDK natively. '
              'Flutter does not call JoliboxAdsFlutter.initialize().',
            ),
            const SizedBox(height: 12),
            _StatusCard(status: _status),
            const SizedBox(height: 24),
            Text('Banner', style: Theme.of(context).textTheme.titleLarge),
            DropdownButtonFormField<JoliboxBannerSize>(
              value: _bannerSize,
              decoration: const InputDecoration(labelText: 'Banner size'),
              items: JoliboxBannerSize.values
                  .map(
                    (size) => DropdownMenuItem(
                      value: size,
                      child: Text(_bannerSizeLabel(size)),
                    ),
                  )
                  .toList(),
              onChanged: controlsEnabled
                  ? (size) {
                      if (size != null) setState(() => _bannerSize = size);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            if (controlsEnabled)
              _BannerPreview(
                scene: _scene,
                size: _bannerSize,
                onStatus: _setStatus,
              )
            else
              const Text(
                'Wait for native initialization before rendering the banner.',
              ),
            const SizedBox(height: 24),
            Text('Interstitial', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controlsEnabled && !_loadingInterstitial
                        ? _loadInterstitial
                        : null,
                    child: Text(
                      _loadingInterstitial ? 'Loading...' : 'Load Interstitial',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _interstitialAd == null ? null : _showInterstitial,
                    child: const Text('Show Interstitial'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Rewarded', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controlsEnabled && !_loadingRewarded
                        ? _loadRewarded
                        : null,
                    child:
                        Text(_loadingRewarded ? 'Loading...' : 'Load Rewarded'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _rewardedAd == null ? null : _showRewarded,
                    child: const Text('Show Rewarded'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _bannerSizeLabel(JoliboxBannerSize size) => switch (size) {
      JoliboxBannerSize.banner => 'Banner (320 x 50)',
      JoliboxBannerSize.largeBanner => 'Large Banner (320 x 100)',
      JoliboxBannerSize.mediumRectangle => 'Medium Rectangle (300 x 250)',
    };

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(status),
      ),
    );
  }
}

class _BannerPreview extends StatelessWidget {
  const _BannerPreview({
    required this.scene,
    required this.size,
    required this.onStatus,
  });

  final String scene;
  final JoliboxBannerSize size;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: JoliboxBannerAd(
        scene: scene,
        size: size,
        onLoaded: () => onStatus('Banner loaded.'),
        onFailedToLoad: (error) => onStatus(
          'Banner load failed: ${error.code}${error.message == null ? '' : ': ${error.message}'}',
        ),
        onImpression: () => onStatus('Banner impression.'),
        onClicked: () => onStatus('Banner clicked.'),
        onOpened: () => onStatus('Banner opened.'),
        onClosed: () => onStatus('Banner closed.'),
      ),
    );
  }
}
