package com.jolibox.examples.nativechannelshost

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class ChannelApplication : Application() {
    lateinit var flutterEngine: FlutterEngine
        private set

    override fun onCreate() {
        super.onCreate()
        flutterEngine = FlutterEngine(this)
        // Each flavor compiles its own wrapper. Register on THIS Engine before Dart runs.
        AdBridgeRegistration.register(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jolibox_native_channels/host")
            .setMethodCallHandler { call, result ->
                if (call.method == "waitForHostReady") result.success(null) else result.notImplemented()
            }
        flutterEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
    }

    override fun onTerminate() {
        flutterEngine.destroy()
        super.onTerminate()
    }
}
