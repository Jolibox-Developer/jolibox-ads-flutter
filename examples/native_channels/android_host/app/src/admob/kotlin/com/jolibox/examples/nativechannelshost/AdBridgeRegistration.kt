package com.jolibox.examples.nativechannelshost

import com.jolibox.admediation.jolibox_ads_flutter.JoliboxAdsFlutterPlugin
import io.flutter.embedding.engine.FlutterEngine

internal object AdBridgeRegistration {
    fun register(engine: FlutterEngine) {
        if (!engine.plugins.has(JoliboxAdsFlutterPlugin::class.java)) {
            engine.plugins.add(JoliboxAdsFlutterPlugin())
        }
    }
}
