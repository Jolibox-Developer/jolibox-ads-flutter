package com.jolibox.admediation.jolibox_ads_flutter

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.jolibox.admediation.api.BannerSize
import com.jolibox.admediation.api.JoliboxAdError
import com.jolibox.admediation.api.JoliboxBannerAd
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

internal class JoliboxBannerPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    arguments: Map<String, Any?>,
) : PlatformView {
    private val container = FrameLayout(context)
    private val scene = arguments.string("scene")
    private val size = size(arguments.string("size"))
    private val channel = MethodChannel(messenger, "jolibox_ads_flutter/banner/$viewId")
    private var banner: JoliboxBannerAd? = null

    init {
        channel.setMethodCallHandler(::handle)
    }

    override fun getView(): View = container

    override fun dispose() {
        banner?.destroy()
        banner = null
        channel.setMethodCallHandler(null)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "loadBanner") {
            result.notImplemented()
            return
        }
        if (scene.isBlank() || size == null) {
            result.error("INVALID_ARGUMENT", "A valid scene and banner size are required.", null)
            return
        }
        banner?.destroy()
        container.removeAllViews()
        val nextBanner = JoliboxBannerAd(container.context)
        nextBanner.setAdListener(object : JoliboxBannerAd.Listener {
            override fun onAdLoaded(view: View) {
                if (banner !== nextBanner) {
                    nextBanner.destroy()
                    return
                }
                container.addView(view, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ))
                channel.invokeMethod("onLoaded", emptyMap<String, Any>())
                result.success(null)
            }

            override fun onAdFailedToLoad(error: JoliboxAdError) {
                if (banner !== nextBanner) return
                result.fail(error)
            }

            override fun onAdImpression() = emit("onImpression")
            override fun onAdClicked() = emit("onClicked")
            override fun onAdOpened() = emit("onOpened")
            override fun onAdClosed() = emit("onClosed")

            private fun emit(method: String) {
                if (banner === nextBanner) {
                    channel.invokeMethod(method, emptyMap<String, Any>())
                }
            }
        })
        banner = nextBanner
        nextBanner.loadAd(scene, size)
    }

    private fun size(value: String): BannerSize? = when (value) {
        "banner" -> BannerSize.BANNER
        "largeBanner" -> BannerSize.LARGE_BANNER
        "mediumRectangle" -> BannerSize.MEDIUM_RECTANGLE
        else -> null
    }
}
