@preconcurrency import Flutter
@preconcurrency import JoliboxAdMediation
import UIKit

@MainActor
final class JoliboxBannerPlatformViewFactory: NSObject, @preconcurrency FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let presenter: () -> UIViewController?

    init(messenger: FlutterBinaryMessenger, presenter: @escaping () -> UIViewController?) {
        self.messenger = messenger
        self.presenter = presenter
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        JoliboxBannerPlatformView(
            frame: frame,
            messenger: messenger,
            viewId: viewId,
            arguments: args as? [String: Any] ?? [:],
            presenter: presenter
        )
    }
}

@MainActor
final class JoliboxBannerPlatformView: NSObject, @preconcurrency FlutterPlatformView, JoliboxAdsEventDelegate {
    private let container: UIView
    private let scene: String
    private let size: JoliboxBannerSize?
    private let presenter: () -> UIViewController?
    private let channel: FlutterMethodChannel
    private var ad: JoliboxBannerAd?

    init(
        frame: CGRect,
        messenger: FlutterBinaryMessenger,
        viewId: Int64,
        arguments: [String: Any],
        presenter: @escaping () -> UIViewController?
    ) {
        container = UIView(frame: frame)
        scene = (arguments["scene"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        size = Self.size(arguments["size"] as? String)
        self.presenter = presenter
        channel = FlutterMethodChannel(name: "jolibox_ads_flutter/banner/\(viewId)", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            switch call.method {
            case "loadBanner":
                self.load(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView { container }

    private func load(result: @escaping FlutterResult) {
        guard !scene.isEmpty, let size else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "A valid scene and banner size are required.", details: nil))
            return
        }
        ad?.invalidate()
        let banner = JoliboxBannerAd()
        banner.delegate = self
        ad = banner
        Task { @MainActor [weak self, banner] in
            guard let self else { return }
            do {
                try await banner.load(scene: self.scene, size: size, rootViewController: self.presenter())
                guard self.ad === banner, let view = banner.view else { return }
                view.frame = self.container.bounds
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.container.addSubview(view)
                result(nil)
            } catch {
                result(self.error(error))
            }
        }
    }

    func dispose() {
        ad?.invalidate()
        ad = nil
        channel.setMethodCallHandler(nil)
    }

    func joliboxAdDidLoad(scene: String, format: JoliboxAdsFormat) { emit("onLoaded") }
    func joliboxAdWillPresent(scene: String, format: JoliboxAdsFormat) { emit("onOpened") }
    func joliboxAdDidImpression(scene: String, format: JoliboxAdsFormat) { emit("onImpression") }
    func joliboxAdDidClick(scene: String, format: JoliboxAdsFormat) { emit("onClicked") }
    func joliboxAdDidEarnReward(scene: String, format: JoliboxAdsFormat) {}
    func joliboxAdDidDismiss(scene: String, format: JoliboxAdsFormat) { emit("onClosed") }
    func joliboxAdDidFail(scene: String, format: JoliboxAdsFormat, error: Error) {}

    private func emit(_ method: String, error: Error? = nil) {
        var values: [String: Any] = [:]
        if let error {
            values["code"] = (error as? JoliboxAdsError)?.code.rawValue ?? "AD_LOAD_FAILED"
            values["message"] = error.localizedDescription
        }
        channel.invokeMethod(method, arguments: values)
    }

    private func error(_ error: Error) -> FlutterError {
        FlutterError(
            code: (error as? JoliboxAdsError)?.code.rawValue ?? "AD_LOAD_FAILED",
            message: error.localizedDescription,
            details: nil
        )
    }

    private static func size(_ value: String?) -> JoliboxBannerSize? {
        switch value {
        case "banner": .banner
        case "largeBanner": .largeBanner
        case "mediumRectangle": .mediumRectangle
        default: nil
        }
    }
}
