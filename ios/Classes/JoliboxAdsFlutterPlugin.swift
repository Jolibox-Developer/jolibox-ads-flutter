@preconcurrency import Flutter
@preconcurrency import JoliboxAdMediation
import UIKit

@MainActor
public final class JoliboxAdsFlutterPlugin: NSObject, @preconcurrency FlutterPlugin, JoliboxAdsEventDelegate {
    private static let channelName = "jolibox_ads_flutter"
    private static let bannerViewType = "jolibox_ads_flutter/banner"

    @MainActor
    private enum FullscreenAd {
        case interstitial(JoliboxInterstitialAd)
        case rewarded(JoliboxRewardedAd)

        var format: JoliboxAdsFormat {
            switch self {
            case .interstitial: .interstitial
            case .rewarded: .rewarded
            }
        }

        func show(from controller: UIViewController) throws {
            switch self {
            case let .interstitial(ad): try ad.show(from: controller)
            case let .rewarded(ad): try ad.show(from: controller)
            }
        }

        func invalidate() {
            switch self {
            case let .interstitial(ad): ad.invalidate()
            case let .rewarded(ad): ad.invalidate()
            }
        }
    }

    private struct ShowState {
        let id: String
        let ad: FullscreenAd
        let result: FlutterResult
    }

    private var channel: FlutterMethodChannel?
    private var ads: [String: FullscreenAd] = [:]
    private var showing: ShowState?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = JoliboxAdsFlutterPlugin()
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        plugin.channel = channel
        registrar.addMethodCallDelegate(plugin, channel: channel)
        registrar.register(
            JoliboxBannerPlatformViewFactory(
                messenger: registrar.messenger(),
                presenter: { Self.activePresenter() }
            ),
            withId: bannerViewType
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "initialize":
            initialize(arguments: arguments, result: result)
        case "loadInterstitial":
            loadInterstitial(scene: value(arguments, "scene"), result: result)
        case "loadRewarded":
            loadRewarded(scene: value(arguments, "scene"), result: result)
        case "show":
            show(id: value(arguments, "adId"), result: result)
        case "disposeAd":
            dispose(id: value(arguments, "adId"), result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(arguments: [String: Any], result: @escaping FlutterResult) {
        let source = value(arguments, "joliSource")
        guard let environment = MediationEnvironment(rawValue: value(arguments, "environment")) else {
            result(error("INVALID_ARGUMENT", "environment must be staging or production."))
            return
        }
        JoliboxAds.initialize(joliSource: source, environment: environment) { response in
            switch response {
            case .success:
                result(nil)
            case .failure(let error):
                result(self.error(error))
            }
        }
    }

    private func loadInterstitial(scene: String, result: @escaping FlutterResult) {
        guard !scene.isEmpty else {
            result(error("INVALID_ARGUMENT", "scene is required."))
            return
        }
        let ad = JoliboxInterstitialAd()
        ad.delegate = self
        Task { @MainActor [weak self, ad] in
            guard let self else { return }
            do {
                try await ad.load(scene: scene)
                let id = UUID().uuidString
                ads[id] = .interstitial(ad)
                result(id)
            } catch {
                result(self.error(error))
            }
        }
    }

    private func loadRewarded(scene: String, result: @escaping FlutterResult) {
        guard !scene.isEmpty else {
            result(error("INVALID_ARGUMENT", "scene is required."))
            return
        }
        let ad = JoliboxRewardedAd()
        ad.delegate = self
        Task { @MainActor [weak self, ad] in
            guard let self else { return }
            do {
                try await ad.load(scene: scene)
                let id = UUID().uuidString
                ads[id] = .rewarded(ad)
                result(id)
            } catch {
                result(self.error(error))
            }
        }
    }

    private func show(id: String, result: @escaping FlutterResult) {
        guard showing == nil else {
            result(error("SHOW_IN_PROGRESS", "A fullscreen ad is already presenting."))
            return
        }
        guard let ad = ads.removeValue(forKey: id) else {
            result(error("AD_NOT_FOUND", "The loaded ad is missing, disposed, or already shown."))
            return
        }
        guard let presenter = Self.activePresenter(), presenter.viewIfLoaded?.window != nil else {
            ads[id] = ad
            result(error("ACTIVITY_REQUIRED", "The Flutter presenter is not attached to an active window."))
            return
        }
        showing = ShowState(id: id, ad: ad, result: result)
        do {
            try ad.show(from: presenter)
        } catch {
            showing = nil
            ad.invalidate()
            result(self.error(error))
        }
    }

    private func dispose(id: String, result: FlutterResult) {
        if let ad = ads.removeValue(forKey: id) {
            ad.invalidate()
            result(nil)
            return
        }
        if showing?.id == id {
            result(nil)
            return
        }
        result(error("AD_NOT_FOUND", "The loaded ad is missing, disposed, or already shown."))
    }

    public func joliboxAdDidLoad(scene: String, format: JoliboxAdsFormat) {}
    public func joliboxAdWillPresent(scene: String, format: JoliboxAdsFormat) { emit("onAdShowedFullScreenContent", format: format) }
    public func joliboxAdDidImpression(scene: String, format: JoliboxAdsFormat) { emit("onAdImpression", format: format) }
    public func joliboxAdDidClick(scene: String, format: JoliboxAdsFormat) { emit("onAdClicked", format: format) }
    public func joliboxAdDidEarnReward(scene: String, format: JoliboxAdsFormat) { emit("onUserEarnedReward", format: format) }

    public func joliboxAdDidDismiss(scene: String, format: JoliboxAdsFormat) {
        guard let state = showing, state.ad.format == format else { return }
        emit("onAdDismissedFullScreenContent", format: format)
        finishShowing(state, value: nil)
    }

    public func joliboxAdDidFail(scene: String, format: JoliboxAdsFormat, error: Error) {
        guard let state = showing, state.ad.format == format else { return }
        emit("onAdFailedToShowFullScreenContent", format: format, error: error)
        finishShowing(state, value: self.error(error))
    }

    private func finishShowing(_ state: ShowState, value: Any?) {
        guard showing?.id == state.id else { return }
        showing = nil
        state.ad.invalidate()
        state.result(value)
    }

    private func emit(_ method: String, format: JoliboxAdsFormat, error: Error? = nil) {
        guard let state = showing, state.ad.format == format else { return }
        var values: [String: Any] = ["adId": state.id]
        if let error {
            values["code"] = errorCode(error)
            values["message"] = error.localizedDescription
        }
        channel?.invokeMethod(method, arguments: values)
    }

    private func value(_ arguments: [String: Any], _ key: String) -> String {
        (arguments[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func error(_ error: Error) -> FlutterError {
        FlutterError(code: errorCode(error), message: error.localizedDescription, details: nil)
    }

    private func error(_ code: String, _ message: String) -> FlutterError {
        FlutterError(code: code, message: message, details: nil)
    }

    private func errorCode(_ error: Error) -> String {
        (error as? JoliboxAdsError)?.code.rawValue ?? "AD_OPERATION_FAILED"
    }

    private static func activePresenter() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: { $0.isKeyWindow })
        return topViewController(window?.rootViewController)
    }

    private static func topViewController(_ controller: UIViewController?) -> UIViewController? {
        if let navigation = controller as? UINavigationController {
            return topViewController(navigation.visibleViewController)
        }
        if let tab = controller as? UITabBarController {
            return topViewController(tab.selectedViewController)
        }
        if let presented = controller?.presentedViewController {
            return topViewController(presented)
        }
        return controller
    }
}
