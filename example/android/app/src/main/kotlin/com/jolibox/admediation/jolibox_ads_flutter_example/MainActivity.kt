package com.jolibox.admediation.jolibox_ads_flutter_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INITIALIZATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitializationState" -> result.success(ExampleAdsInitialization.snapshot())
                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val INITIALIZATION_CHANNEL = "jolibox_ads_flutter_example/initialization"
    }
}
