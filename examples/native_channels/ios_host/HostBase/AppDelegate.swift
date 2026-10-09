import Flutter
import FlutterPluginRegistrant
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var engine: FlutterEngine?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let engine = FlutterEngine(name: "jolibox_shared_flutter")
        engine.run()
        GeneratedPluginRegistrant.register(with: engine)
        // Both targets use the same Flutter module. There is no ad registrar here.
        FlutterMethodChannel(name: "jolibox_native_channels/host", binaryMessenger: engine.binaryMessenger)
            .setMethodCallHandler { call, result in
                result(call.method == "waitForHostReady" ? nil : FlutterMethodNotImplemented)
            }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        window.makeKeyAndVisible()
        self.window = window
        self.engine = engine
        return true
    }
}
