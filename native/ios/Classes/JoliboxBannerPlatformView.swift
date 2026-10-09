@preconcurrency import Flutter
@preconcurrency import JoliboxAdMediation
import UIKit

@MainActor
private final class BannerContainerView: UIView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

@MainActor
final class JoliboxBannerPlatformViewFactory: NSObject, @preconcurrency FlutterPlatformViewFactory {
    private struct WeakView { weak var value: JoliboxBannerPlatformView? }

    private let messenger: FlutterBinaryMessenger
    private let presenter: () -> UIViewController?
    private var views: [WeakView] = []
    private var attached = true

    init(messenger: FlutterBinaryMessenger, presenter: @escaping () -> UIViewController?) {
        self.messenger = messenger
        self.presenter = presenter
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let view = JoliboxBannerPlatformView(
            frame: frame,
            messenger: messenger,
            viewId: viewId,
            arguments: args as? [String: Any] ?? [:],
            presenter: presenter
        )
        if attached {
            views.removeAll { $0.value == nil }
            views.append(WeakView(value: view))
        } else {
            view.dispose()
        }
        return view
    }

    func detach() {
        attached = false
        views.forEach { $0.value?.dispose() }
        views.removeAll()
    }
}

@MainActor
final class JoliboxBannerPlatformView: NSObject, @preconcurrency FlutterPlatformView, JoliboxAdsEventDelegate {
    private let container: BannerContainerView
    private let scene: String
    private let size: JoliboxBannerSize?
    private let presenter: () -> UIViewController?
    private let channel: FlutterMethodChannel
    private var ad: JoliboxBannerAd?
    private var pendingLoad: (ad: JoliboxBannerAd, result: FlutterResult)?
    private weak var pendingLoadedView: UIView?
    private var loadedEventEmitted = false
    private var disposed = false

    init(
        frame: CGRect,
        messenger: FlutterBinaryMessenger,
        viewId: Int64,
        arguments: [String: Any],
        presenter: @escaping () -> UIViewController?
    ) {
        container = BannerContainerView(frame: frame)
        scene = (arguments["scene"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        size = Self.size(arguments["size"] as? String)
        self.presenter = presenter
        channel = FlutterMethodChannel(name: "jolibox_ads_flutter/banner/\(viewId)", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "VIEW_DISPOSED", message: "The banner view was disposed.", details: nil))
                return
            }
            switch call.method {
            case "loadBanner": self.load(result: result)
            default: result(FlutterMethodNotImplemented)
            }
        }
    }

    deinit {
        pendingLoad?.result(FlutterError(code: "VIEW_DISPOSED", message: "The banner view was disposed.", details: nil))
        channel.setMethodCallHandler(nil)
        let loadedAd = ad
        Task { @MainActor in loadedAd?.invalidate() }
    }

    func view() -> UIView { container }

    private func load(result: @escaping FlutterResult) {
        guard !disposed else {
            result(FlutterError(code: "ENGINE_DETACHED", message: "The banner is detached.", details: nil))
            return
        }
        guard !scene.isEmpty, let size else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "A valid scene and banner size are required.", details: nil))
            return
        }
        cancelPendingLoad(code: "AD_LOAD_CANCELLED", message: "The banner was replaced.")
        clearPendingLoadedEvent()
        ad?.invalidate()
        container.subviews.forEach { $0.removeFromSuperview() }
        let banner = JoliboxBannerAd()
        banner.delegate = self
        ad = banner
        pendingLoad = (banner, result)
        Task { @MainActor [weak self, banner] in
            do {
                try await banner.load(scene: self?.scene ?? "", size: size, rootViewController: self?.presenter())
                guard let self, !self.disposed, self.ad === banner, let view = banner.view else {
                    banner.invalidate()
                    return
                }
                view.translatesAutoresizingMaskIntoConstraints = false
                self.container.addSubview(view)
                NSLayoutConstraint.activate([
                    view.leadingAnchor.constraint(equalTo: self.container.leadingAnchor),
                    view.trailingAnchor.constraint(equalTo: self.container.trailingAnchor),
                    view.topAnchor.constraint(equalTo: self.container.topAnchor),
                    view.bottomAnchor.constraint(equalTo: self.container.bottomAnchor),
                ])
                self.completeLoad(for: banner, value: nil)
                self.emitLoadedWhenLaidOut(owner: banner, view: view)
            } catch {
                banner.invalidate()
                guard let self, !self.disposed, self.ad === banner else { return }
                self.ad = nil
                self.completeLoad(for: banner, value: self.error(error))
            }
        }
    }

    func dispose() {
        guard !disposed else { return }
        disposed = true
        cancelPendingLoad(code: "ENGINE_DETACHED", message: "The banner's engine was detached.")
        clearPendingLoadedEvent()
        ad?.invalidate()
        ad = nil
        container.subviews.forEach { $0.removeFromSuperview() }
        channel.setMethodCallHandler(nil)
    }

    private func completeLoad(for owner: JoliboxBannerAd, value: Any?) {
        guard let pendingLoad, pendingLoad.ad === owner else { return }
        self.pendingLoad = nil
        pendingLoad.result(value)
    }

    private func cancelPendingLoad(code: String, message: String) {
        guard let pendingLoad else { return }
        self.pendingLoad = nil
        pendingLoad.result(FlutterError(code: code, message: message, details: nil))
    }

    func joliboxAdDidLoad(scene: String, format: JoliboxAdsFormat) {}
    func joliboxAdWillPresent(scene: String, format: JoliboxAdsFormat) { emit("onOpened") }
    func joliboxAdDidImpression(scene: String, format: JoliboxAdsFormat) { emit("onImpression") }
    func joliboxAdDidClick(scene: String, format: JoliboxAdsFormat) { emit("onClicked") }
    func joliboxAdDidEarnReward(scene: String, format: JoliboxAdsFormat) {}
    func joliboxAdDidDismiss(scene: String, format: JoliboxAdsFormat) { emit("onClosed") }
    func joliboxAdDidFail(scene: String, format: JoliboxAdsFormat, error: Error) {}

    private func emit(_ method: String) {
        guard !disposed else { return }
        channel.invokeMethod(method, arguments: [:])
    }

    private func emitLoadedWhenLaidOut(owner: JoliboxBannerAd, view: UIView) {
        clearPendingLoadedEvent()
        pendingLoadedView = view
        container.onLayout = { [weak self, weak owner, weak view] in
            guard let self, let owner, let view else { return }
            self.emitLoadedIfReady(owner: owner, view: view)
        }
        container.setNeedsLayout()
        container.layoutIfNeeded()
        emitLoadedIfReady(owner: owner, view: view)
    }

    private func emitLoadedIfReady(owner: JoliboxBannerAd, view: UIView) {
        guard !disposed, !loadedEventEmitted,
              ad === owner,
              pendingLoadedView === view,
              container.bounds.width > 0,
              container.bounds.height > 0,
              view.bounds.width > 0,
              view.bounds.height > 0 else { return }
        loadedEventEmitted = true
        container.onLayout = nil
        pendingLoadedView = nil
        channel.invokeMethod("onLoaded", arguments: [:])
    }

    private func clearPendingLoadedEvent() {
        container.onLayout = nil
        pendingLoadedView = nil
        loadedEventEmitted = false
    }

    private func error(_ error: Error) -> FlutterError {
        FlutterError(code: (error as? JoliboxAdsError)?.code.rawValue ?? "AD_LOAD_FAILED",
                     message: error.localizedDescription, details: nil)
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
