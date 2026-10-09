package com.jolibox.admediation.jolibox_ads_flutter

import android.content.Context
import com.jolibox.admediation.api.JoliboxInterstitialAd
import com.jolibox.admediation.api.JoliboxAdError
import com.jolibox.admediation.api.JoliboxAdErrorCode
import com.jolibox.admediation.api.MediationEnvironment
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewRegistry
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.mockito.Mockito

internal class JoliboxAdsFlutterPluginTest {
    @Test
    fun unknownMethodReturnsNotImplemented() {
        val result = mockResult()

        JoliboxAdsFlutterPlugin().onMethodCall(MethodCall("unknown", null), result)

        Mockito.verify(result).notImplemented()
    }

    @Test
    fun invalidEnvironmentReturnsArgumentErrorBeforeEngineAccess() {
        val result = mockResult()

        JoliboxAdsFlutterPlugin().onMethodCall(
            MethodCall("initialize", mapOf("environment" to "invalid")),
            result,
        )

        Mockito.verify(result).error(
            "INVALID_ARGUMENT",
            "environment must be staging or production.",
            null,
        )
    }

    @Test
    fun blankSceneReturnsArgumentErrorWithoutLoadingAnAd() {
        val result = mockResult()

        JoliboxAdsFlutterPlugin().onMethodCall(
            MethodCall("loadInterstitial", mapOf("scene" to "  ")),
            result,
        )

        Mockito.verify(result).error("INVALID_ARGUMENT", "scene is required.", null)
    }

    @Test
    fun argumentConversionTrimsStringsAndIgnoresNonStringValues() {
        val values = mapOf<String, Any?>("scene" to " demo ", "count" to 1)

        assertEquals("demo", values.string("scene"))
        assertEquals("", values.string("count"))
        assertEquals("", values.string("missing"))
        assertEquals(mapOf("scene" to "demo"), mapOf("scene" to "demo").asStringMap())
        assertEquals(emptyMap(), "invalid".asStringMap())
    }

    @Test
    fun environmentConversionAcceptsOnlyPublishedValues() {
        assertEquals(MediationEnvironment.STAGING, mediationEnvironment(" staging "))
        assertEquals(MediationEnvironment.PRODUCTION, mediationEnvironment("production"))
        assertNull(mediationEnvironment("debug"))
    }

    @Test
    fun nativeErrorsPreserveTheirCodeAndMessage() {
        val result = mockResult()
        val error = JoliboxAdError(JoliboxAdErrorCode.AD_LOAD_FAILED, "load failed")

        result.fail(error)

        Mockito.verify(result).error("AD_LOAD_FAILED", "load failed", null)
    }

    @Test
    fun detachedEngineCompletesPendingRequestOnceAndDisposesLateAd() {
        val plugin = JoliboxAdsFlutterPlugin()
        val binding = mockBinding()
        plugin.onAttachedToEngine(binding)
        val result = mockResult()

        // Exercise the same pending-load path used by both fullscreen SDK callbacks.
        val begin = plugin.javaClass.getDeclaredMethod("begin", MethodChannel.Result::class.java)
        begin.isAccessible = true
        val pending = begin.invoke(plugin, result)
        val sdkAd = Mockito.mock(JoliboxInterstitialAd::class.java)
        val wrapperClass = Class.forName("${plugin.javaClass.name}\$Interstitial")
        val wrapperConstructor = wrapperClass.getDeclaredConstructor(JoliboxInterstitialAd::class.java)
        wrapperConstructor.isAccessible = true
        val wrappedAd = wrapperConstructor.newInstance(sdkAd)
        val store = plugin.javaClass.declaredMethods.single { it.name == "store" }
        store.isAccessible = true

        plugin.onDetachedFromEngine(binding)
        store.invoke(plugin, wrappedAd, pending)
        store.invoke(plugin, wrappedAd, pending) // Even an erroneous duplicate callback is harmless.

        Mockito.verify(result, Mockito.times(1)).error(
            "ENGINE_DETACHED", "The Flutter engine detached during an ad request.", null,
        )
        Mockito.verify(result, Mockito.never()).success(Mockito.any())
        Mockito.verify(sdkAd, Mockito.times(2)).dispose()
    }

    @Test
    fun capabilitiesArePerAttachedEngineAndHaveNoSdkInitializationSideEffect() {
        val plugin = JoliboxAdsFlutterPlugin()
        val binding = mockBinding()
        plugin.onAttachedToEngine(binding)
        val result = mockResult()

        plugin.onMethodCall(MethodCall("getCapabilities", null), result)

        Mockito.verify(result).success(
            mapOf(
                "protocolVersion" to 1,
                "provider" to "admob",
                "banner" to true,
                "interstitial" to true,
                "rewarded" to true,
            ),
        )
        plugin.onDetachedFromEngine(binding)
        val afterDetach = mockResult()
        plugin.onMethodCall(MethodCall("getCapabilities", null), afterDetach)
        Mockito.verify(afterDetach).error("ENGINE_DETACHED", "The Flutter engine is detached.", null)
    }

    @Test
    fun duplicateLoadCompletionNeverCompletesFlutterResultTwice() {
        val plugin = JoliboxAdsFlutterPlugin()
        val binding = mockBinding()
        plugin.onAttachedToEngine(binding)
        val result = mockResult()
        val begin = plugin.javaClass.getDeclaredMethod("begin", MethodChannel.Result::class.java)
        begin.isAccessible = true
        val pending = begin.invoke(plugin, result)
        val success = pending.javaClass.getDeclaredMethod("success", Any::class.java)
        success.isAccessible = true

        success.invoke(pending, "first")
        success.invoke(pending, "second")
        plugin.onDetachedFromEngine(binding)

        Mockito.verify(result, Mockito.times(1)).success("first")
        Mockito.verify(result, Mockito.never()).success("second")
        Mockito.verify(result, Mockito.never()).error(Mockito.anyString(), Mockito.anyString(), Mockito.any())
    }

    private fun mockBinding(): FlutterPlugin.FlutterPluginBinding =
        Mockito.mock(FlutterPlugin.FlutterPluginBinding::class.java).also {
            Mockito.`when`(it.binaryMessenger).thenReturn(Mockito.mock(BinaryMessenger::class.java))
            Mockito.`when`(it.platformViewRegistry).thenReturn(Mockito.mock(PlatformViewRegistry::class.java))
            Mockito.`when`(it.applicationContext).thenReturn(Mockito.mock(Context::class.java))
        }

    private fun mockResult(): MethodChannel.Result {
        return Mockito.mock(MethodChannel.Result::class.java)
    }
}
