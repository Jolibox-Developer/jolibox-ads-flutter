package com.jolibox.admediation.jolibox_ads_flutter_example

import android.app.Application
import android.util.Log
import com.jolibox.admediation.JoliboxAds
import com.jolibox.admediation.api.InitializationCallback
import com.jolibox.admediation.api.JoliboxAdError
import com.jolibox.admediation.api.MediationEnvironment

class ExampleApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ExampleAdsInitialization.start(this)
    }
}

internal object ExampleAdsInitialization {
    private const val tag = "JoliboxAdsExample"

    @Volatile
    private var state = "initializing"

    @Volatile
    private var message = "Native SDK initialization is starting."

    fun start(application: Application) {
        val joliSource = BuildConfig.JOLIBOX_JOLI_SOURCE.trim()
        if (joliSource.isEmpty() || joliSource.startsWith("YOUR_")) {
            update(
                state = "notConfigured",
                message = "Set jolibox.joliSource in android/local.properties before running the example.",
            )
            return
        }

        val environment = when (BuildConfig.JOLIBOX_MEDIATION_ENVIRONMENT.lowercase()) {
            "production" -> MediationEnvironment.PRODUCTION
            else -> MediationEnvironment.STAGING
        }
        update("initializing", "Initializing native SDK for ${environment.name.lowercase()}.")
        JoliboxAds.initialize(application, joliSource, environment, object : InitializationCallback {
            override fun onInitialized() {
                update("ready", "Native SDK initialization succeeded.")
            }

            override fun onInitializationFailed(error: JoliboxAdError) {
                update("failed", "Native SDK initialization failed: ${error.code} (${error.message})")
            }
        })
    }

    fun snapshot(): Map<String, String> = mapOf("state" to state, "message" to message)

    private fun update(state: String, message: String) {
        this.state = state
        this.message = message
        Log.i(tag, message)
    }
}
