package com.jolibox.android.sdk.ads.flutter;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.google.android.gms.ads.AdSize;
import com.google.android.gms.ads.AdView;
import com.jolibox.android.sdk.ads.AdsError;
import com.jolibox.android.sdk.ads.JoliboxAdRequest;
import com.jolibox.android.sdk.ads.JoliboxAdSize;
import com.jolibox.android.sdk.ads.JoliboxBannerAd;
import com.jolibox.android.sdk.ads.JoliboxBannerSize;
import java.util.HashMap;
import java.util.Map;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

final class JoliboxAdsBannerPlatformView implements PlatformView {
  @NonNull private final FrameLayout container;
  @NonNull private final MethodChannel events;
  @NonNull private final JoliboxBannerAd bannerAd;
  @NonNull private final String scene;
  @NonNull private final String sizeName;
  @Nullable private final JoliboxAdSize fixedSize;
  @Nullable private final JoliboxBannerSize adaptiveSize;
  @Nullable private final AdsError sizeError;
  private boolean loadStarted;
  private boolean disposed;

  JoliboxAdsBannerPlatformView(@NonNull Context context, @NonNull BinaryMessenger messenger, int viewId, @NonNull Map<String, Object> arguments) {
    container = new FrameLayout(context);
    events = new MethodChannel(messenger, JoliboxAdsFlutterPlugin.BANNER_VIEW_TYPE + "/" + viewId);
    scene = JoliboxAdsFlutterPlugin.getString(arguments, "scene");
    sizeName = JoliboxAdsFlutterPlugin.getString(arguments, "size");
    JoliboxAdSize parsedFixedSize = null;
    JoliboxBannerSize parsedAdaptiveSize = null;
    AdsError parsedSizeError = null;
    try {
      if ("largeAnchoredAdaptive".equals(sizeName) || "inlineAdaptive".equals(sizeName)) {
        Object maxHeight = arguments.get("maxHeight");
        parsedAdaptiveSize = JoliboxAdsFlutterPlugin.adaptiveBannerSize(
                sizeName,
                number(arguments.get("width")),
                maxHeight instanceof Number ? ((Number) maxHeight).doubleValue() : null
        );
      } else {
        parsedFixedSize = JoliboxAdsFlutterPlugin.fixedBannerSize(sizeName);
      }
    } catch (IllegalArgumentException error) {
      parsedSizeError = new AdsError("ADS_INVALID_AD_SIZE", error.getMessage() == null ? "Invalid Banner size" : error.getMessage());
    }
    fixedSize = parsedFixedSize;
    adaptiveSize = parsedAdaptiveSize;
    sizeError = parsedSizeError;
    bannerAd = new JoliboxBannerAd(context);
    bannerAd.setAdListener(new JoliboxBannerAd.Listener() {
      @Override public void onAdLoaded(@NonNull View view) { dispatch(() -> { if (view.getParent() instanceof ViewGroup) ((ViewGroup) view.getParent()).removeView(view); container.removeAllViews(); container.addView(view); events.invokeMethod("onLoaded", dimensions(view)); }); }
      @Override public void onAdFailedToLoad(@NonNull AdsError error) { dispatch(() -> notifyFailure(events, error)); }
      @Override public void onAdImpression() { dispatch(() -> events.invokeMethod("onImpression", null)); }
      @Override public void onAdClicked() { dispatch(() -> events.invokeMethod("onClicked", null)); }
      @Override public void onAdOpened() { dispatch(() -> events.invokeMethod("onOpened", null)); }
      @Override public void onAdClosed() { dispatch(() -> events.invokeMethod("onClosed", null)); }
    });
    events.setMethodCallHandler((call, result) -> {
      if (!"loadBanner".equals(call.method)) { result.notImplemented(); return; }
      if (disposed) { result.error("ADS_VIEW_DISPOSED", "Banner view has already been disposed", null); return; }
      loadBanner();
      result.success(null);
    });
  }

  private void loadBanner() {
    if (disposed || loadStarted) return;
    loadStarted = true;
    if (sizeError != null) {
      notifyFailure(events, sizeError);
      return;
    }
    if (adaptiveSize != null) bannerAd.loadAd(scene, adaptiveSize, new JoliboxAdRequest.Builder().build());
    else if (fixedSize != null) bannerAd.loadAd(scene, fixedSize, new JoliboxAdRequest.Builder().build());
    else notifyFailure(events, new AdsError("ADS_INVALID_AD_SIZE", "Unable to resolve Banner size"));
  }

  private void dispatch(@NonNull Runnable action) {
    container.post(() -> {
      if (!disposed) action.run();
    });
  }

  @NonNull @Override public View getView(){return container;}
  @Override public void dispose(){disposed=true;events.setMethodCallHandler(null);bannerAd.destroy();container.removeAllViews();}
  private static void notifyFailure(@NonNull MethodChannel channel,@NonNull AdsError error){Map<String,Object> args=new HashMap<>();args.put("code",error.getCode());args.put("message",error.getMessage());channel.invokeMethod("onFailedToLoad",args);}
  private static double number(Object value) { return value instanceof Number ? ((Number) value).doubleValue() : Double.NaN; }
  @NonNull private static Map<String, Object> dimensions(@NonNull View view) { AdSize size = view instanceof AdView ? ((AdView) view).getAdSize() : null; Map<String, Object> values = new HashMap<>(); values.put("width", size == null ? 0 : size.getWidth()); values.put("height", size == null ? 0 : size.getHeight()); return values; }
}
