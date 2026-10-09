@preconcurrency import Flutter
@preconcurrency import JoliboxAdMediation
import UIKit

/// Register once on the host-owned engine after run(), before Dart probes capabilities.
@MainActor
public final class JoliboxAdsFlutterPlugin: NSObject, @preconcurrency FlutterPlugin, JoliboxAdsEventDelegate {
    private static let pluginKey = "JoliboxFlutterAdsBridgeAdMob"
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
    private var bannerFactory: JoliboxBannerPlatformViewFactory?
    private var presenter: () -> UIViewController? = { nil }
    private var attached = true
    private var pendingLoads: [UUID: FlutterResult] = [:]
    private var pendingInitialization: [UUID: FlutterResult] = [:]
    private var ads: [String: FullscreenAd] = [:]
    private var showing: ShowState?

    /// The native host calls this for each ads-enabled engine after engine.run().
    /// Dart must await a host-ready handshake before its first capability probe.
    public static func register(with engine: FlutterEngine) {
        guard !engine.hasPlugin(pluginKey),
              let registrar = engine.registrar(forPlugin: pluginKey) else { return }
        install(with: registrar, presenter: { [weak engine] in
            guard let controller = engine?.viewController,
                  controller.viewIfLoaded?.window != nil else { return nil }
            return topViewController(controller)
        })
    }

    /// FlutterPlugin conformance for callers using a registrar directly. Fullscreen presentation
    /// requires the engine overload above so that it remains scoped to the owning FlutterEngine.
    public static func register(with registrar: FlutterPluginRegistrar) {
        install(with: registrar, presenter: { nil })
    }

    private static func install(with registrar: FlutterPluginRegistrar, presenter: @escaping () -> UIViewController?) {
        let plugin = JoliboxAdsFlutterPlugin()
        plugin.presenter = presenter
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        plugin.channel = channel
        registrar.addMethodCallDelegate(plugin, channel: channel)
        let factory = JoliboxBannerPlatformViewFactory(messenger: registrar.messenger(), presenter: presenter)
        plugin.bannerFactory = factory
        registrar.register(factory, withId: bannerViewType)
        // Flutter only sends detachFromEngine to instances published by the registrar.
        registrar.publish(plugin)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        attached = false
        bannerFactory?.detach()
        bannerFactory = nil
        pendingLoads.values.forEach { $0(error("ENGINE_DETACHED", "The Flutter engine was detached.")) }
        pendingLoads.removeAll()
        pendingInitialization.values.forEach { $0(error("ENGINE_DETACHED", "The Flutter engine was detached.")) }
        pendingInitialization.removeAll()
        ads.values.forEach { $0.invalidate() }
        ads.removeAll()
        if let state = showing {
            showing = nil
            state.ad.invalidate()
            state.result(error("ENGINE_DETACHED", "The Flutter engine was detached."))
        }
        channel = nil
        presenter = { nil }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard attached else {
            result(error("ENGINE_DETACHED", "The Flutter engine was detached."))
            return
        }
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "getCapabilities":
            result(["protocolVersion": 1, "provider": "admob", "banner": true,
                    "interstitial": true, "rewarded": true])
        case "initialize": initialize(arguments: arguments, result: result)
        case "loadInterstitial": loadInterstitial(scene: value(arguments, "scene"), result: result)
        case "loadRewarded": loadRewarded(scene: value(arguments, "scene"), result: result)
        case "show": show(id: value(arguments, "adId"), result: result)
        case "disposeAd": dispose(id: value(arguments, "adId"), result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func initialize(arguments: [String: Any], result: @escaping FlutterResult) {
        guard let environment = MediationEnvironment(rawValue: value(arguments, "environment")) else {
            result(error("INVALID_ARGUMENT", "environment must be staging or production."))
            return
        }
        let token = UUID()
        pendingInitialization[token] = result
        JoliboxAds.initialize(joliSource: value(arguments, "joliSource"), environment: environment) { [weak self] response in
            guard let self, let completion = self.pendingInitialization.removeValue(forKey: token) else { return }
            switch response {
            case .success: completion(nil)
            case .failure(let cause): completion(self.error(cause))
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
        let token = UUID()
        pendingLoads[token] = result
        Task { @MainActor [weak self, ad] in
            do {
                try await ad.load(scene: scene)
                guard let self, self.attached, let completion = self.pendingLoads.removeValue(forKey: token) else {
                    ad.invalidate()
                    return
                }
                let id = UUID().uuidString
                self.ads[id] = .interstitial(ad)
                completion(id)
            } catch {
                ad.invalidate()
                guard let self, let completion = self.pendingLoads.removeValue(forKey: token) else { return }
                completion(self.error(error))
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
        let token = UUID()
        pendingLoads[token] = result
        Task { @MainActor [weak self, ad] in
            do {
                try await ad.load(scene: scene)
                guard let self, self.attached, let completion = self.pendingLoads.removeValue(forKey: token) else {
                    ad.invalidate()
                    return
                }
                let id = UUID().uuidString
                self.ads[id] = .rewarded(ad)
                completion(id)
            } catch {
                ad.invalidate()
                guard let self, let completion = self.pendingLoads.removeValue(forKey: token) else { return }
                completion(self.error(error))
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
        guard let controller = presenter(), controller.viewIfLoaded?.window != nil else {
            ads[id] = ad
            result(error("ACTIVITY_REQUIRED", "This engine's Flutter presenter is not attached to a window."))
            return
        }
        showing = ShowState(id: id, ad: ad, result: result)
        do {
            try ad.show(from: controller)
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
        } else if showing?.id == id {
            result(nil)
        } else {
            result(error("AD_NOT_FOUND", "The loaded ad is missing, disposed, or already shown."))
        }
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
        guard attached, let state = showing, state.ad.format == format else { return }
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

    private static func topViewController(_ controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topViewController(presented)
        }
        if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
            return topViewController(visible)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(selected)
        }
        return controller
    }
}
