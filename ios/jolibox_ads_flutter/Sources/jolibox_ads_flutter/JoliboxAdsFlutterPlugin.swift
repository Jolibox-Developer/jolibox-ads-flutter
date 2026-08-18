@preconcurrency import Flutter
@preconcurrency import JoliboxSDKAll
import UIKit

@MainActor
@objc(JoliboxAdsFlutterPlugin)
public final class JoliboxAdsFlutterPlugin: NSObject, @preconcurrency FlutterPlugin, @preconcurrency JoliboxAdsEventDelegate {
    static let channelName = "jolibox_ads_flutter"
    static let bannerViewType = "jolibox_ads_flutter/banner"

    @MainActor
    private enum FullscreenAd {
        case interstitial(JoliboxInterstitialAd)
        case rewarded(JoliboxRewardedAd)

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
        var clicked = false
        var rewarded = false
    }

    private let presenter: () -> UIViewController?
    private var channel: FlutterMethodChannel?
    private var ads: [String: FullscreenAd] = [:]
    private var showing: [JoliboxAdsFormat: ShowState] = [:]

    static func register(with engine: FlutterEngine, presenter: @escaping () -> UIViewController?) {
        guard let registrar = engine.registrar(forPlugin: "JoliboxAdsFlutterHostBridge") else { return }
        let bridge = JoliboxAdsFlutterPlugin(presenter: presenter)
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        bridge.channel = channel
        registrar.addMethodCallDelegate(bridge, channel: channel)
        registrar.register(
            JoliboxAdsBannerViewFactory(messenger: registrar.messenger(), presenter: presenter),
            withId: bannerViewType
        )
    }

    init(presenter: @escaping () -> UIViewController?) {
        self.presenter = presenter
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        register(with: registrar, presenter: { UIApplication.shared.activeKeyWindow?.rootViewController })
    }

    private static func register(with registrar: FlutterPluginRegistrar, presenter: @escaping () -> UIViewController?) {
        let bridge = JoliboxAdsFlutterPlugin(presenter: presenter)
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        bridge.channel = channel
        registrar.addMethodCallDelegate(bridge, channel: channel)
        registrar.register(
            JoliboxAdsBannerViewFactory(messenger: registrar.messenger(), presenter: presenter),
            withId: bannerViewType
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "loadInterstitial": loadInterstitial(scene: string(arguments, "scene"), result: result)
        case "loadRewarded": loadRewarded(scene: string(arguments, "scene"), result: result)
        case "show": show(id: string(arguments, "adId"), result: result)
        case "disposeAd": dispose(id: string(arguments, "adId"), result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func loadInterstitial(scene: String, result: @escaping FlutterResult) {
        guard !scene.isEmpty else { result(error("ADS_INVALID_ARGUMENT", "scene is required")); return }
        let ad = JoliboxInterstitialAd()
        ad.delegate = self
        Task { @MainActor [weak self, ad] in
            guard let self else { return }
            do {
                try await ad.load(scene: scene)
                let id = UUID().uuidString
                self.ads[id] = .interstitial(ad)
                result(id)
            } catch {
                result(self.error(error))
            }
        }
    }

    private func loadRewarded(scene: String, result: @escaping FlutterResult) {
        guard !scene.isEmpty else { result(error("ADS_INVALID_ARGUMENT", "scene is required")); return }
        let ad = JoliboxRewardedAd()
        ad.delegate = self
        Task { @MainActor [weak self, ad] in
            guard let self else { return }
            do {
                try await ad.load(scene: scene)
                let id = UUID().uuidString
                self.ads[id] = .rewarded(ad)
                result(id)
            } catch {
                result(self.error(error))
            }
        }
    }

    private func show(id: String, result: @escaping FlutterResult) {
        guard let ad = ads.removeValue(forKey: id) else {
            result(error("ADS_AD_NOT_FOUND", "The fullscreen ad is missing or already consumed"))
            return
        }
        let format = format(of: ad)
        guard showing[format] == nil else {
            ads[id] = ad
            result(error("ADS_SHOW_IN_PROGRESS", "An ad of this format is already presenting"))
            return
        }
        guard let controller = presenter(), controller.viewIfLoaded?.window != nil else {
            ad.invalidate()
            result(error("ADS_PRESENTER_INVALID", "The Flutter presenter is not attached to an active window"))
            return
        }
        showing[format] = ShowState(id: id, ad: ad, result: result)
        do {
            try ad.show(from: controller)
        } catch {
            showing.removeValue(forKey: format)
            ad.invalidate()
            result(self.error(error))
        }
    }

    private func dispose(id: String, result: FlutterResult) {
        ads.removeValue(forKey: id)?.invalidate()
        result(nil)
    }

    public func joliboxAdDidLoad(scene: String, format: JoliboxAdsFormat) {}
    public func joliboxAdWillPresent(scene: String, format: JoliboxAdsFormat) { emit("onAdShowedFullScreenContent", format) }
    public func joliboxAdDidImpression(scene: String, format: JoliboxAdsFormat) { emit("onAdImpression", format) }
    public func joliboxAdDidClick(scene: String, format: JoliboxAdsFormat) {
        guard var state = showing[format] else { return }
        state.clicked = true
        showing[format] = state
        emit("onAdClicked", format)
    }
    public func joliboxAdDidEarnReward(scene: String, format: JoliboxAdsFormat, amount: Int, type: String) {
        guard var state = showing[format] else { return }
        state.rewarded = true
        showing[format] = state
        emit("onUserEarnedReward", format)
    }
    public func joliboxAdDidDismiss(scene: String, format: JoliboxAdsFormat) {
        emit("onAdDismissedFullScreenContent", format)
        guard let state = showing.removeValue(forKey: format) else { return }
        state.ad.invalidate()
        state.result(["clicked": state.clicked, "rewarded": state.rewarded])
    }
    public func joliboxAdDidFail(scene: String, format: JoliboxAdsFormat, error: Error) {
        emit("onAdFailedToShowFullScreenContent", format, error: error)
        guard let state = showing.removeValue(forKey: format) else { return }
        state.ad.invalidate()
        state.result(self.error(error))
    }

    private func emit(_ method: String, _ format: JoliboxAdsFormat, error: Error? = nil) {
        guard let state = showing[format] else { return }
        var values: [String: Any] = ["adId": state.id]
        if let error {
            values["code"] = errorCode(error)
            values["message"] = error.localizedDescription
        }
        channel?.invokeMethod(method, arguments: values)
    }

    private func format(of ad: FullscreenAd) -> JoliboxAdsFormat {
        switch ad {
        case .interstitial: return .interstitial
        case .rewarded: return .rewarded
        }
    }

    private func string(_ values: [String: Any], _ key: String) -> String {
        (values[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func error(_ code: String, _ message: String) -> FlutterError { FlutterError(code: code, message: message, details: nil) }
    private func error(_ value: Error) -> FlutterError { FlutterError(code: errorCode(value), message: value.localizedDescription, details: nil) }
    private func errorCode(_ value: Error) -> String { (value as? JoliboxAdsError)?.code.rawValue ?? "ADS_OPERATION_FAILED" }
}

private extension UIApplication {
    var activeKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: { $0.isKeyWindow })
    }
}
