import Flutter
import JoliboxAdMediation
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    ExampleAdsInitialization.shared.start()
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "jolibox_ads_flutter_example/initialization",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "getInitializationState" {
          result(ExampleAdsInitialization.shared.snapshot)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private final class ExampleAdsInitialization {
  static let shared = ExampleAdsInitialization()

  private(set) var state = "initializing"
  private(set) var message = "Native SDK initialization is starting."

  var snapshot: [String: String] {
    ["state": state, "message": message]
  }

  func start() {
    Task { @MainActor [weak self] in
      guard let self else { return }
      let source = (Bundle.main.object(forInfoDictionaryKey: "JoliboxJoliSource") as? String ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !source.isEmpty, !source.hasPrefix("YOUR_") else {
        update(
          state: "notConfigured",
          message: "Set JOLIBOX_JOLI_SOURCE in ios/Runner/Config/Jolibox.local.xcconfig before running the example."
        )
        return
      }

      let environmentValue = (Bundle.main.object(forInfoDictionaryKey: "JoliboxEnvironment") as? String ?? "staging")
        .lowercased()
      let environment: MediationEnvironment = environmentValue == "production" ? .production : .staging
      update(state: "initializing", message: "Initializing native SDK for \(environment.rawValue).")
      JoliboxAds.initialize(joliSource: source, environment: environment) { [weak self] response in
        switch response {
        case .success:
          self?.update(state: "ready", message: "Native SDK initialization succeeded.")
        case .failure(let error):
          self?.update(
            state: "failed",
            message: "Native SDK initialization failed: \(error.code.rawValue) (\(error.message))"
          )
        }
      }
    }
  }

  private func update(state: String, message: String) {
    self.state = state
    self.message = message
    NSLog("[Jolibox Ads Example] %@", message)
  }
}
