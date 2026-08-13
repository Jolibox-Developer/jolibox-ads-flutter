import Flutter
import Jolibox
import UIKit

@MainActor
final class JoliboxAdsBannerViewFactory: NSObject, @preconcurrency FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let presenter: () -> UIViewController?

    init(messenger: FlutterBinaryMessenger, presenter: @escaping () -> UIViewController?) {
        self.messenger = messenger
        self.presenter = presenter
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }

    func create(withFrame frame: CGRect, viewIdentifier viewID: Int64, arguments args: Any?) -> FlutterPlatformView {
        JoliboxAdsBannerPlatformView(
            frame: frame,
            viewID: viewID,
            arguments: args as? [String: Any] ?? [:],
            messenger: messenger,
            presenter: presenter
        )
    }
}

@MainActor
final class JoliboxAdsBannerPlatformView: NSObject, @preconcurrency FlutterPlatformView, @preconcurrency JoliboxAdsEventDelegate {
    private let container: UIView
    private let channel: FlutterMethodChannel
    private let scene: String
    private let sizeName: String
    private let presenter: () -> UIViewController?
    private let banner = JoliboxBannerAd()
    private var started = false
    private var disposed = false

    init(frame: CGRect, viewID: Int64, arguments: [String: Any], messenger: FlutterBinaryMessenger, presenter: @escaping () -> UIViewController?) {
        container = UIView(frame: frame)
        channel = FlutterMethodChannel(name: "jolibox_ads_flutter/banner/\(viewID)", binaryMessenger: messenger)
        scene = (arguments["scene"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        sizeName = arguments["size"] as? String ?? "banner"
        self.presenter = presenter
        super.init()
        banner.delegate = self
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(FlutterError(code: "ADS_VIEW_DISPOSED", message: "Banner view was released", details: nil)); return }
            guard call.method == "loadBanner" else { result(FlutterMethodNotImplemented); return }
            self.load(result: result)
        }
    }

    func view() -> UIView { container }

    func dispose() {
        disposed = true
        channel.setMethodCallHandler(nil)
        banner.invalidate()
        container.subviews.forEach { $0.removeFromSuperview() }
    }

    private func load(result: @escaping FlutterResult) {
        guard !disposed else { result(FlutterError(code: "ADS_VIEW_DISPOSED", message: "Banner view was released", details: nil)); return }
        guard !started else { result(nil); return }
        guard !scene.isEmpty, let controller = presenter(), controller.viewIfLoaded?.window != nil else {
            result(FlutterError(code: "ADS_PRESENTER_INVALID", message: "A foreground Flutter presenter is required", details: nil))
            return
        }
        started = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.banner.load(scene: self.scene, size: self.bannerSize(), rootViewController: controller)
                result(nil)
            } catch {
                self.started = false
                result(FlutterError(code: self.errorCode(error), message: error.localizedDescription, details: nil))
            }
        }
    }

    func joliboxAdDidLoad(scene: String, format: JoliboxAdsFormat) {
        guard !disposed, let bannerView = banner.view else { return }
        bannerView.removeFromSuperview()
        container.subviews.forEach { $0.removeFromSuperview() }
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bannerView.topAnchor.constraint(equalTo: container.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        channel.invokeMethod("onLoaded", arguments: nil)
    }

    func joliboxAdDidFail(scene: String, format: JoliboxAdsFormat, error: Error) { channel.invokeMethod("onFailedToLoad", arguments: errorValues(error)) }
    func joliboxAdDidImpression(scene: String, format: JoliboxAdsFormat) { channel.invokeMethod("onImpression", arguments: nil) }
    func joliboxAdDidClick(scene: String, format: JoliboxAdsFormat) { channel.invokeMethod("onClicked", arguments: nil) }
    func joliboxAdWillPresent(scene: String, format: JoliboxAdsFormat) { channel.invokeMethod("onOpened", arguments: nil) }
    func joliboxAdDidDismiss(scene: String, format: JoliboxAdsFormat) { channel.invokeMethod("onClosed", arguments: nil) }
    func joliboxAdDidEarnReward(scene: String, format: JoliboxAdsFormat, amount: Int, type: String) {}

    private func bannerSize() -> JoliboxBannerSize {
        switch sizeName {
        case "largeBanner": return .fixed(width: 320, height: 100)
        case "mediumRectangle": return .fixed(width: 300, height: 250)
        default: return .fixed(width: 320, height: 50)
        }
    }

    private func errorValues(_ error: Error) -> [String: Any] { ["code": errorCode(error), "message": error.localizedDescription] }
    private func errorCode(_ error: Error) -> String { (error as? JoliboxAdsError)?.code.rawValue ?? "ADS_LOAD_FAILED" }
}
