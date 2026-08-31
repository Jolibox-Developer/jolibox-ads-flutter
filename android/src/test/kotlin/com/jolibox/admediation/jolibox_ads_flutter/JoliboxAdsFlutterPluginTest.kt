package com.jolibox.admediation.jolibox_ads_flutter

import com.jolibox.admediation.api.JoliboxAdError
import com.jolibox.admediation.api.JoliboxAdErrorCode
import com.jolibox.admediation.api.MediationEnvironment
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
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

    private fun mockResult(): MethodChannel.Result {
        return Mockito.mock(MethodChannel.Result::class.java)
    }
}
