package com.jolibox.android.sdk.ads.flutter;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import androidx.annotation.NonNull;
import com.jolibox.android.sdk.ads.AdsError;
import com.jolibox.android.sdk.ads.JoliboxAdRequest;
import com.jolibox.android.sdk.ads.JoliboxAdSize;
import com.jolibox.android.sdk.ads.JoliboxBannerAd;
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
  @NonNull private final JoliboxAdSize size;
  private boolean loadStarted;
  private boolean disposed;

  JoliboxAdsBannerPlatformView(@NonNull Context context, @NonNull BinaryMessenger messenger, int viewId, @NonNull Map<String, Object> arguments) {
    container = new FrameLayout(context);
    events = new MethodChannel(messenger, JoliboxAdsFlutterPlugin.BANNER_VIEW_TYPE + "/" + viewId);
    scene = JoliboxAdsFlutterPlugin.getString(arguments, "scene");
    size = JoliboxAdsFlutterPlugin.bannerSize(arguments);
    bannerAd = new JoliboxBannerAd(context);
    bannerAd.setAdListener(new JoliboxBannerAd.Listener() {
      @Override public void onAdLoaded(@NonNull View view) { dispatch(() -> { if (view.getParent() instanceof ViewGroup) ((ViewGroup) view.getParent()).removeView(view); container.removeAllViews(); container.addView(view); events.invokeMethod("onLoaded", null); }); }
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
    bannerAd.loadAd(scene, size, new JoliboxAdRequest.Builder().build());
  }

  private void dispatch(@NonNull Runnable action) {
    container.post(() -> {
      if (!disposed) action.run();
    });
  }

  @NonNull @Override public View getView(){return container;}
  @Override public void dispose(){disposed=true;events.setMethodCallHandler(null);bannerAd.destroy();container.removeAllViews();}
  private static void notifyFailure(@NonNull MethodChannel channel,@NonNull AdsError error){Map<String,Object> args=new HashMap<>();args.put("code",error.getCode());args.put("message",error.getMessage());channel.invokeMethod("onFailedToLoad",args);}
}
