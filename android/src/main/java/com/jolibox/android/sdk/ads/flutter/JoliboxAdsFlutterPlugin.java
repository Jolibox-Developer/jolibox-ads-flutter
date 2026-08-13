package com.jolibox.android.sdk.ads.flutter;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;

import com.jolibox.android.sdk.ads.AdsError;
import com.jolibox.android.sdk.ads.JoliboxAdSize;
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
        JoliboxInterstitialAd interstitialAd = interstitialAds.remove(id);
        if (interstitialAd != null) { showInterstitial(id, interstitialAd, result); return; }
        JoliboxRewardedAd rewardedAd = rewardedAds.remove(id);
        if (rewardedAd != null) { showRewarded(id, rewardedAd, result); return; }
        result.error("ADS_AD_NOT_FOUND", "The loaded ad is missing, disposed, or already shown", null);
    }

    private void showInterstitial(@NonNull String id, @NonNull JoliboxInterstitialAd ad, @NonNull MethodChannel.Result result) {
        ad.setFullScreenContentCallback(new ResultCallback(id, result, false));
        ad.show(activity);
    }

    private void showRewarded(@NonNull String id, @NonNull JoliboxRewardedAd ad, @NonNull MethodChannel.Result result) {
        ResultCallback callback = new ResultCallback(id, result, true);
        ad.setFullScreenContentCallback(callback);
        ad.show(activity, callback::onRewarded);
    }

    private void disposeAd(@NonNull String id, @NonNull MethodChannel.Result result) {
        JoliboxInterstitialAd interstitialAd = interstitialAds.remove(id);
        if (interstitialAd != null) { interstitialAd.destroy(); result.success(null); return; }
        JoliboxRewardedAd rewardedAd = rewardedAds.remove(id);
        if (rewardedAd != null) { rewardedAd.destroy(); result.success(null); return; }
        result.error("ADS_AD_NOT_FOUND", "The loaded ad is missing, disposed, or already shown", null);
    }

    private static void fail(@NonNull MethodChannel.Result result, @NonNull AdsError error) { result.error(error.getCode(), error.getMessage(), null); }

    @Override public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) { disposeAll(); if (channel != null) channel.setMethodCallHandler(null); channel = null; applicationContext = null; }
    @Override public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) { activity = binding.getActivity(); }
    @Override public void onDetachedFromActivityForConfigChanges() { activity = null; }
    @Override public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) { activity = binding.getActivity(); }
    @Override public void onDetachedFromActivity() { activity = null; }

    private void disposeAll() { for (JoliboxInterstitialAd ad : interstitialAds.values()) ad.destroy(); for (JoliboxRewardedAd ad : rewardedAds.values()) ad.destroy(); interstitialAds.clear(); rewardedAds.clear(); }

    @NonNull static Map<String, Object> getArguments(Object arguments) { Map<String, Object> result = new HashMap<>(); if (!(arguments instanceof Map)) return result; for (Map.Entry<?, ?> entry : ((Map<?, ?>) arguments).entrySet()) if (entry.getKey() != null) result.put(String.valueOf(entry.getKey()), entry.getValue()); return result; }
    @NonNull static String getString(@NonNull Map<String, Object> arguments, @NonNull String key) { Object value = arguments.get(key); return value == null ? "" : String.valueOf(value); }
    @NonNull static JoliboxAdSize bannerSize(@NonNull Map<String, Object> arguments) { String size = getString(arguments, "size"); if ("largeBanner".equals(size)) return JoliboxAdSize.LARGE_BANNER; if ("mediumRectangle".equals(size)) return JoliboxAdSize.MEDIUM_RECTANGLE; return JoliboxAdSize.BANNER; }

    private final class ResultCallback extends JoliboxFullScreenContentCallback {
        @NonNull private final String adId; @NonNull private final MethodChannel.Result result; private final boolean rewardable; private boolean clicked; private boolean rewarded;
        ResultCallback(@NonNull String adId, @NonNull MethodChannel.Result result, boolean rewardable) { this.adId = adId; this.result = result; this.rewardable = rewardable; }
        private void emit(@NonNull String event) { if (channel != null) { Map<String, Object> value = new HashMap<>(); value.put("adId", adId); channel.invokeMethod(event, value); } }
        private void emitFailure(@NonNull AdsError error) { if (channel != null) { Map<String, Object> value = new HashMap<>(); value.put("adId", adId); value.put("code", error.getCode()); value.put("message", error.getMessage()); channel.invokeMethod("onAdFailedToShowFullScreenContent", value); } }
        void onRewarded() { rewarded = true; emit("onUserEarnedReward"); }
        @Override public void onAdShowedFullScreenContent() { emit("onAdShowedFullScreenContent"); }
        @Override public void onAdImpression() { emit("onAdImpression"); }
        @Override public void onAdClicked() { clicked = true; emit("onAdClicked"); }
        @Override public void onAdDismissedFullScreenContent() { emit("onAdDismissedFullScreenContent"); Map<String, Object> value = new HashMap<>(); value.put("clicked", clicked); value.put("rewarded", rewardable && rewarded); result.success(value); }
        @Override public void onAdFailedToShowFullScreenContent(@NonNull AdsError error) { emitFailure(error); fail(result, error); }
    }
}
