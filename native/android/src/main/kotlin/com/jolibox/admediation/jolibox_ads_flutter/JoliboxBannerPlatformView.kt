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
    private val onDisposed: (JoliboxBannerPlatformView) -> Unit = {},
) : PlatformView {
    private val container = FrameLayout(context)
    private val scene = arguments.string("scene")
    private val size = size(arguments.string("size"))
    private val channel = MethodChannel(messenger, "jolibox_ads_flutter/banner/$viewId")
    private var banner: JoliboxBannerAd? = null
    private var pendingLayoutView: View? = null
    private var pendingLayoutListener: View.OnLayoutChangeListener? = null
    private var pendingResult: MethodChannel.Result? = null
    private var disposed = false

    init {
        channel.setMethodCallHandler(::handle)
    }

    override fun getView(): View = container

    // Implement Flutter's optional PlatformView callbacks in this class. Android hosts may
    // desugar the embedding's Java interface defaults independently of this published AAR.
    override fun onFlutterViewAttached(flutterView: View) = Unit

    override fun onFlutterViewDetached() = Unit

    override fun onInputConnectionLocked() = Unit

    override fun onInputConnectionUnlocked() = Unit

    override fun dispose() {
        if (disposed) return
        disposed = true
        completeError("VIEW_DISPOSED", "The banner view was disposed.")
        clearPendingLayoutListener()
        banner?.destroy()
        banner = null
        channel.setMethodCallHandler(null)
        onDisposed(this)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "loadBanner") {
            result.notImplemented()
            return
        }
        if (disposed) {
            result.error("VIEW_DISPOSED", "The banner view was disposed.", null)
            return
        }
        if (scene.isBlank() || size == null) {
            result.error("INVALID_ARGUMENT", "A valid scene and banner size are required.", null)
            return
        }
        completeError("REQUEST_SUPERSEDED", "A newer banner load replaced this request.")
        pendingResult = result
        clearPendingLayoutListener()
        banner?.destroy()
        container.removeAllViews()
        val nextBanner = JoliboxBannerAd(container.context)
        nextBanner.setAdListener(object : JoliboxBannerAd.Listener {
            override fun onAdLoaded(view: View) {
                if (banner !== nextBanner) {
                    nextBanner.destroy()
                    return
                }
                if (pendingResult == null) return
                container.addView(view, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ))
                completeSuccess()
                if (banner === nextBanner) emitLoadedWhenLaidOut(nextBanner, view)
            }

            override fun onAdFailedToLoad(error: JoliboxAdError) {
                if (banner !== nextBanner) return
                clearPendingLayoutListener()
                completeFailure(error)
                nextBanner.destroy()
                banner = null
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

    private fun completeSuccess() {
        pendingResult?.success(null)
        pendingResult = null
    }

    private fun completeFailure(error: JoliboxAdError) {
        pendingResult?.fail(error)
        pendingResult = null
    }

    private fun completeError(code: String, message: String) {
        pendingResult?.error(code, message, null)
        pendingResult = null
    }

    private fun emitLoadedWhenLaidOut(owner: JoliboxBannerAd, view: View) {
        clearPendingLayoutListener()
        var emitted = false
        val listener = object : View.OnLayoutChangeListener {
            override fun onLayoutChange(
                changedView: View,
                left: Int,
                top: Int,
                right: Int,
                bottom: Int,
                oldLeft: Int,
                oldTop: Int,
                oldRight: Int,
                oldBottom: Int,
            ) {
                if (emitted || banner !== owner || changedView.width <= 0 || changedView.height <= 0) {
                    return
                }
                emitted = true
                clearPendingLayoutListener()
                channel.invokeMethod("onLoaded", emptyMap<String, Any>())
            }
        }
        pendingLayoutView = view
        pendingLayoutListener = listener
        view.addOnLayoutChangeListener(listener)
        if (view.width > 0 && view.height > 0) {
            listener.onLayoutChange(view, 0, 0, view.width, view.height, 0, 0, 0, 0)
        }
    }

    private fun clearPendingLayoutListener() {
        pendingLayoutView?.let { view ->
            pendingLayoutListener?.let(view::removeOnLayoutChangeListener)
        }
        pendingLayoutView = null
        pendingLayoutListener = null
    }
}
