package com.jolibox.android.sdk.ads.flutter;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;

import com.jolibox.android.sdk.ads.AdsError;
import com.jolibox.android.sdk.ads.JoliboxAdSize;
import com.jolibox.android.sdk.ads.JoliboxBannerSize;
import com.jolibox.android.sdk.ads.JoliboxFullScreenContentCallback;
import com.jolibox.android.sdk.ads.JoliboxInterstitialAd;
import com.jolibox.android.sdk.ads.JoliboxRewardedAd;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformViewFactory;

public final class JoliboxAdsFlutterPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    static final String CHANNEL_NAME = "jolibox_ads_flutter";
    static final String BANNER_VIEW_TYPE = "jolibox_ads_flutter/banner";

    private final Map<String, JoliboxInterstitialAd> interstitialAds = new HashMap<>();
    private final Map<String, JoliboxRewardedAd> rewardedAds = new HashMap<>();
    private final Map<String, ShowingAd> showingAds = new HashMap<>();
    private Context applicationContext;
    private Activity activity;
    private MethodChannel channel;

    @Override public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
        binding.getPlatformViewRegistry().registerViewFactory(BANNER_VIEW_TYPE, new PlatformViewFactory(StandardMessageCodec.INSTANCE) {
            @Override public JoliboxAdsBannerPlatformView create(Context context, int viewId, Object arguments) {
                return new JoliboxAdsBannerPlatformView(context, binding.getBinaryMessenger(), viewId, getArguments(arguments));
            }
        });
    }

    @Override public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        Map<String, Object> arguments = getArguments(call.arguments);
        switch (call.method) {
            case "loadInterstitial": loadInterstitial(arguments, result); return;
            case "loadRewarded": loadRewarded(arguments, result); return;
            case "show": show(getString(arguments, "adId"), result); return;
            case "disposeAd": disposeAd(getString(arguments, "adId"), result); return;
            default: result.notImplemented();
        }
    }

    private void loadInterstitial(@NonNull Map<String, Object> arguments, @NonNull MethodChannel.Result result) {
        JoliboxInterstitialAd.load(applicationContext, getString(arguments, "scene"), new com.jolibox.android.sdk.ads.JoliboxAdRequest.Builder().build(), new JoliboxInterstitialAd.LoadCallback() {
            @Override public void onAdLoaded(@NonNull JoliboxInterstitialAd ad) { String id = UUID.randomUUID().toString(); interstitialAds.put(id, ad); result.success(id); }
            @Override public void onAdFailedToLoad(@NonNull AdsError error) { fail(result, error); }
        });
    }

    private void loadRewarded(@NonNull Map<String, Object> arguments, @NonNull MethodChannel.Result result) {
        JoliboxRewardedAd.load(applicationContext, getString(arguments, "scene"), new com.jolibox.android.sdk.ads.JoliboxAdRequest.Builder().build(), new JoliboxRewardedAd.LoadCallback() {
            @Override public void onAdLoaded(@NonNull JoliboxRewardedAd ad) { String id = UUID.randomUUID().toString(); rewardedAds.put(id, ad); result.success(id); }
            @Override public void onAdFailedToLoad(@NonNull AdsError error) { fail(result, error); }
        });
    }

    private void show(@NonNull String id, @NonNull MethodChannel.Result result) {
        if (activity == null) { result.error("ADS_ACTIVITY_REQUIRED", "A Flutter Activity is required to show an ad", null); return; }
        if (!showingAds.isEmpty()) { result.error("ADS_SHOW_IN_PROGRESS", "A fullscreen ad is already presenting", null); return; }
        JoliboxInterstitialAd interstitialAd = interstitialAds.remove(id);
        if (interstitialAd != null) {
            ShowingAd showingAd = ShowingAd.interstitial(id, interstitialAd, result);
            showingAds.put(id, showingAd);
            showInterstitial(showingAd);
            return;
        }
        JoliboxRewardedAd rewardedAd = rewardedAds.remove(id);
        if (rewardedAd != null) {
            ShowingAd showingAd = ShowingAd.rewarded(id, rewardedAd, result);
            showingAds.put(id, showingAd);
            showRewarded(showingAd);
            return;
        }
        result.error("ADS_AD_NOT_FOUND", "The loaded ad is missing, disposed, or already shown", null);
    }

    private void showInterstitial(@NonNull ShowingAd showingAd) {
        JoliboxInterstitialAd ad = showingAd.interstitialAd;
        if (ad == null) return;
        ad.setFullScreenContentCallback(new ResultCallback(showingAd, false));
        try {
            ad.show(activity);
        } catch (RuntimeException error) {
            failShowing(showingAd, showException(error));
        }
    }

    private void showRewarded(@NonNull ShowingAd showingAd) {
        JoliboxRewardedAd ad = showingAd.rewardedAd;
        if (ad == null) return;
        ResultCallback callback = new ResultCallback(showingAd, true);
        ad.setFullScreenContentCallback(callback);
        try {
            ad.show(activity, callback::onRewarded);
        } catch (RuntimeException error) {
            failShowing(showingAd, showException(error));
        }
    }

    @NonNull private static AdsError showException(@NonNull RuntimeException error) {
        String message = error.getMessage();
        return new AdsError("ADS_SHOW_EXCEPTION", message == null ? error.getClass().getSimpleName() : message);
    }

    private void failShowing(@NonNull ShowingAd showingAd, @NonNull AdsError error) {
        if (showingAd.terminal) return;
        showingAd.terminal = true;
        showingAds.remove(showingAd.adId);
        showingAd.destroy();
        if (channel != null) {
            Map<String, Object> value = new HashMap<>();
            value.put("adId", showingAd.adId);
            value.put("code", error.getCode());
            value.put("message", error.getMessage());
            channel.invokeMethod("onAdFailedToShowFullScreenContent", value);
        }
        if (!showingAd.resultCompleted) {
            showingAd.resultCompleted = true;
            fail(showingAd.result, error);
        }
    }

    private void disposeAd(@NonNull String id, @NonNull MethodChannel.Result result) {
        JoliboxInterstitialAd interstitialAd = interstitialAds.remove(id);
        if (interstitialAd != null) { interstitialAd.destroy(); result.success(null); return; }
        JoliboxRewardedAd rewardedAd = rewardedAds.remove(id);
        if (rewardedAd != null) { rewardedAd.destroy(); result.success(null); return; }
        ShowingAd showingAd = showingAds.get(id);
        if (showingAd != null) {
            result.success(null);
            return;
        }
        result.error("ADS_AD_NOT_FOUND", "The loaded ad is missing, disposed, or already shown", null);
    }

    private static void fail(@NonNull MethodChannel.Result result, @NonNull AdsError error) { result.error(error.getCode(), error.getMessage(), null); }

    @Override public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) { disposeAll(); if (channel != null) channel.setMethodCallHandler(null); channel = null; applicationContext = null; }
    @Override public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) { activity = binding.getActivity(); }
    @Override public void onDetachedFromActivityForConfigChanges() { activity = null; }
    @Override public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) { activity = binding.getActivity(); }
    @Override public void onDetachedFromActivity() { activity = null; }

    private void disposeAll() {
        for (JoliboxInterstitialAd ad : interstitialAds.values()) ad.destroy();
        for (JoliboxRewardedAd ad : rewardedAds.values()) ad.destroy();
        AdsError error = new AdsError("ADS_ENGINE_DETACHED", "The Flutter engine was detached while an ad was showing");
        for (ShowingAd showingAd : new HashMap<>(showingAds).values()) failShowing(showingAd, error);
        interstitialAds.clear();
        rewardedAds.clear();
        showingAds.clear();
    }

    @NonNull static Map<String, Object> getArguments(Object arguments) { Map<String, Object> result = new HashMap<>(); if (!(arguments instanceof Map)) return result; for (Map.Entry<?, ?> entry : ((Map<?, ?>) arguments).entrySet()) if (entry.getKey() != null) result.put(String.valueOf(entry.getKey()), entry.getValue()); return result; }
    @NonNull static String getString(@NonNull Map<String, Object> arguments, @NonNull String key) { Object value = arguments.get(key); return value == null ? "" : String.valueOf(value); }
    @NonNull static JoliboxAdSize fixedBannerSize(@NonNull String size) { if ("largeBanner".equals(size)) return JoliboxAdSize.LARGE_BANNER; if ("mediumRectangle".equals(size)) return JoliboxAdSize.MEDIUM_RECTANGLE; return JoliboxAdSize.BANNER; }

    @NonNull static JoliboxBannerSize adaptiveBannerSize(@NonNull String size, double width, Double maxHeight) {
        if (!Double.isFinite(width) || width <= 0) throw new IllegalArgumentException("Banner width must be finite and greater than zero");
        int widthDp = (int) Math.round(width);
        if ("largeAnchoredAdaptive".equals(size)) return JoliboxBannerSize.largeAnchoredAdaptive(widthDp);
        if ("inlineAdaptive".equals(size)) {
            if (maxHeight == null) return JoliboxBannerSize.inlineAdaptive(widthDp);
            if (!Double.isFinite(maxHeight) || maxHeight < 32) throw new IllegalArgumentException("Inline adaptive Banner maxHeight must be finite and at least 32dp");
            return JoliboxBannerSize.inlineAdaptive(widthDp, (int) Math.round(maxHeight));
        }
        throw new IllegalArgumentException("Unsupported adaptive Banner size: " + size);
    }

    private final class ResultCallback extends JoliboxFullScreenContentCallback {
        @NonNull private final ShowingAd showingAd; private final boolean rewardable; private boolean clicked; private boolean rewarded;
        ResultCallback(@NonNull ShowingAd showingAd, boolean rewardable) { this.showingAd = showingAd; this.rewardable = rewardable; }
        private void emit(@NonNull String event) { if (channel != null) { Map<String, Object> value = new HashMap<>(); value.put("adId", adId()); channel.invokeMethod(event, value); } }
        private void emitFailure(@NonNull AdsError error) { if (channel != null) { Map<String, Object> value = new HashMap<>(); value.put("adId", adId()); value.put("code", error.getCode()); value.put("message", error.getMessage()); channel.invokeMethod("onAdFailedToShowFullScreenContent", value); } }
        @NonNull private String adId() { return showingAd.adId; }
        private boolean finishTerminal() {
            if (showingAd.terminal) return false;
            showingAd.terminal = true;
            showingAds.remove(showingAd.adId);
            showingAd.destroy();
            return true;
        }
        void onRewarded() { if (showingAd.terminal || rewarded) return; rewarded = true; emit("onUserEarnedReward"); }
        @Override public void onAdShowedFullScreenContent() { if (!showingAd.terminal) emit("onAdShowedFullScreenContent"); }
        @Override public void onAdImpression() { if (!showingAd.terminal) emit("onAdImpression"); }
        @Override public void onAdClicked() { if (!showingAd.terminal) { clicked = true; emit("onAdClicked"); } }
        @Override public void onAdDismissedFullScreenContent() {
            if (!finishTerminal()) return;
            emit("onAdDismissedFullScreenContent");
            Map<String, Object> value = new HashMap<>();
            value.put("clicked", clicked);
            value.put("rewarded", rewardable && rewarded);
            if (!showingAd.resultCompleted) { showingAd.resultCompleted = true; showingAd.result.success(value); }
        }
        @Override public void onAdFailedToShowFullScreenContent(@NonNull AdsError error) {
            if (!finishTerminal()) return;
            emitFailure(error);
            if (!showingAd.resultCompleted) { showingAd.resultCompleted = true; fail(showingAd.result, error); }
        }
    }

    private static final class ShowingAd {
        @NonNull final String adId;
        @NonNull final MethodChannel.Result result;
        JoliboxInterstitialAd interstitialAd;
        JoliboxRewardedAd rewardedAd;
        boolean terminal;
        boolean resultCompleted;

        private ShowingAd(@NonNull String adId, @NonNull MethodChannel.Result result) { this.adId = adId; this.result = result; }
        @NonNull static ShowingAd interstitial(@NonNull String id, @NonNull JoliboxInterstitialAd ad, @NonNull MethodChannel.Result result) { ShowingAd value = new ShowingAd(id, result); value.interstitialAd = ad; return value; }
        @NonNull static ShowingAd rewarded(@NonNull String id, @NonNull JoliboxRewardedAd ad, @NonNull MethodChannel.Result result) { ShowingAd value = new ShowingAd(id, result); value.rewardedAd = ad; return value; }
        void releaseNativeReference() { interstitialAd = null; rewardedAd = null; }
        void destroy() { if (interstitialAd != null) interstitialAd.destroy(); if (rewardedAd != null) rewardedAd.destroy(); releaseNativeReference(); }
    }
}
