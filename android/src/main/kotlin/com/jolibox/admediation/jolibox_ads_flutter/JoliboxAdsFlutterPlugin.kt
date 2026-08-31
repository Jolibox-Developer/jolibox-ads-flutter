package com.jolibox.admediation.jolibox_ads_flutter

import android.app.Activity
import android.content.Context
import com.jolibox.admediation.JoliboxAds
import com.jolibox.admediation.api.FullScreenAdLoadCallback
import com.jolibox.admediation.api.FullScreenContentCallback
import com.jolibox.admediation.api.InitializationCallback
import com.jolibox.admediation.api.JoliboxAdError
import com.jolibox.admediation.api.JoliboxInterstitialAd
import com.jolibox.admediation.api.JoliboxRewardedAd
import com.jolibox.admediation.api.MediationEnvironment
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.UUID

class JoliboxAdsFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    companion object {
        const val CHANNEL_NAME = "jolibox_ads_flutter"
        const val BANNER_VIEW_TYPE = "jolibox_ads_flutter/banner"
    }

    private sealed interface FullscreenAd {
        fun show(activity: Activity, reward: (() -> Unit)? = null)
        fun setCallback(callback: FullScreenContentCallback?)
        fun dispose()
        val rewarded: Boolean
    }

    private class Interstitial(private val ad: JoliboxInterstitialAd) : FullscreenAd {
        override fun show(activity: Activity, reward: (() -> Unit)?) = ad.show(activity)
        override fun setCallback(callback: FullScreenContentCallback?) = ad.setFullScreenContentCallback(callback)
        override fun dispose() = ad.dispose()
        override val rewarded = false
    }

    private class Rewarded(private val ad: JoliboxRewardedAd) : FullscreenAd {
        override fun show(activity: Activity, reward: (() -> Unit)?) {
            ad.show(activity) { reward?.invoke() }
        }

        override fun setCallback(callback: FullScreenContentCallback?) = ad.setFullScreenContentCallback(callback)
        override fun dispose() = ad.dispose()
        override val rewarded = true
    }

    private data class ShowingAd(
        val id: String,
        val ad: FullscreenAd,
        val result: MethodChannel.Result,
        var terminal: Boolean = false,
    )

    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private val loadedAds = mutableMapOf<String, FullscreenAd>()
    private var showing: ShowingAd? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also { it.setMethodCallHandler(this) }
        binding.platformViewRegistry.registerViewFactory(
            BANNER_VIEW_TYPE,
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, arguments: Any?): JoliboxBannerPlatformView {
                    return JoliboxBannerPlatformView(
                        context = context,
                        messenger = binding.binaryMessenger,
                        viewId = viewId,
                        arguments = arguments.asStringMap(),
                    )
                }
            },
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call.arguments.asStringMap(), result)
            "loadInterstitial" -> loadInterstitial(call.arguments.asStringMap(), result)
            "loadRewarded" -> loadRewarded(call.arguments.asStringMap(), result)
            "show" -> show(call.arguments.asStringMap().string("adId"), result)
            "disposeAd" -> dispose(call.arguments.asStringMap().string("adId"), result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val environment = mediationEnvironment(arguments.string("environment"))
        if (environment == null) {
            result.error("INVALID_ARGUMENT", "environment must be staging or production.", null)
            return
        }
        val context = applicationContext
        if (context == null) {
            result.error("ENGINE_DETACHED", "The Flutter engine is detached.", null)
            return
        }
        JoliboxAds.initialize(context, arguments.string("joliSource"), environment, object : InitializationCallback {
            override fun onInitialized() = result.success(null)
            override fun onInitializationFailed(error: JoliboxAdError) = result.fail(error)
        })
    }

    private fun loadInterstitial(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val scene = arguments.string("scene")
        if (scene.isBlank()) {
            result.error("INVALID_ARGUMENT", "scene is required.", null)
            return
        }
        JoliboxInterstitialAd.load(scene, object : FullScreenAdLoadCallback<JoliboxInterstitialAd> {
            override fun onAdLoaded(ad: JoliboxInterstitialAd) {
                result.success(store(Interstitial(ad)))
            }

            override fun onAdFailedToLoad(error: JoliboxAdError) = result.fail(error)
        })
    }

    private fun loadRewarded(arguments: Map<String, Any?>, result: MethodChannel.Result) {
        val scene = arguments.string("scene")
        if (scene.isBlank()) {
            result.error("INVALID_ARGUMENT", "scene is required.", null)
            return
        }
        JoliboxRewardedAd.load(scene, object : FullScreenAdLoadCallback<JoliboxRewardedAd> {
            override fun onAdLoaded(ad: JoliboxRewardedAd) {
                result.success(store(Rewarded(ad)))
            }

            override fun onAdFailedToLoad(error: JoliboxAdError) = result.fail(error)
        })
    }

    private fun store(ad: FullscreenAd): String {
        val id = UUID.randomUUID().toString()
        loadedAds[id] = ad
        return id
    }

    private fun show(id: String, result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("ACTIVITY_REQUIRED", "A Flutter Activity is required to show an ad.", null)
            return
        }
        if (showing != null) {
            result.error("SHOW_IN_PROGRESS", "A fullscreen ad is already presenting.", null)
            return
        }
        val ad = loadedAds.remove(id)
        if (ad == null) {
            result.error("AD_NOT_FOUND", "The loaded ad is missing, disposed, or already shown.", null)
            return
        }
        val state = ShowingAd(id, ad, result)
        showing = state
        val callback = object : FullScreenContentCallback() {
            override fun onAdShowedFullScreenContent() = emit(state, "onAdShowedFullScreenContent")
            override fun onAdImpression() = emit(state, "onAdImpression")
            override fun onAdClicked() = emit(state, "onAdClicked")
            override fun onAdDismissedFullScreenContent() {
                emit(state, "onAdDismissedFullScreenContent")
                finish(state, null)
            }

            override fun onAdFailedToShowFullScreenContent(error: JoliboxAdError) {
                emit(state, "onAdFailedToShowFullScreenContent", error)
                finish(state, error)
            }
        }
        ad.setCallback(callback)
        try {
            ad.show(currentActivity) {
                if (ad.rewarded && !state.terminal) {
                    emit(state, "onUserEarnedReward")
                }
            }
        } catch (error: RuntimeException) {
            finish(state, JoliboxAdError(com.jolibox.admediation.api.JoliboxAdErrorCode.AD_SHOW_FAILED, error.message ?: "Ad show failed."))
        }
    }

    private fun dispose(id: String, result: MethodChannel.Result) {
        val ad = loadedAds.remove(id)
        if (ad != null) {
            ad.dispose()
            result.success(null)
            return
        }
        if (showing?.id == id) {
            result.success(null)
            return
        }
        result.error("AD_NOT_FOUND", "The loaded ad is missing, disposed, or already shown.", null)
    }

    private fun emit(state: ShowingAd, method: String, error: JoliboxAdError? = null) {
        if (state.terminal || showing?.id != state.id) return
        val values = mutableMapOf<String, Any>("adId" to state.id)
        if (error != null) {
            values["code"] = error.code.name
            values["message"] = error.message.orEmpty()
        }
        channel?.invokeMethod(method, values)
    }

    private fun finish(state: ShowingAd, error: JoliboxAdError?) {
        if (state.terminal || showing?.id != state.id) return
        state.terminal = true
        showing = null
        state.ad.dispose()
        if (error == null) state.result.success(null) else state.result.fail(error)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        loadedAds.values.forEach { it.dispose() }
        loadedAds.clear()
        showing?.let {
            it.ad.dispose()
            it.result.error("ENGINE_DETACHED", "The Flutter engine detached while an ad was showing.", null)
        }
        showing = null
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}

internal fun Any?.asStringMap(): Map<String, Any?> =
    (this as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value }.orEmpty()

internal fun Map<String, Any?>.string(key: String): String =
    (this[key] as? String).orEmpty().trim()

internal fun mediationEnvironment(value: String): MediationEnvironment? = when (value.trim()) {
    "staging" -> MediationEnvironment.STAGING
    "production" -> MediationEnvironment.PRODUCTION
    else -> null
}

internal fun MethodChannel.Result.fail(error: JoliboxAdError) {
    this.error(error.code.name, error.message, null)
}
