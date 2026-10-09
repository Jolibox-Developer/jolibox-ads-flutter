import Flutter
import JoliboxFlutterAdsBridgeAdMob
import XCTest

final class BridgeLifecycleTests: XCTestCase {
    private let pluginKey = "JoliboxFlutterAdsBridgeAdMob"

    @MainActor
    func testRegistrationIsPerEngineAndIdempotent() {
        let first = FlutterEngine(name: "first-test-engine")
        let second = FlutterEngine(name: "second-test-engine")
        XCTAssertTrue(first.run())
        XCTAssertTrue(second.run())
        JoliboxAdsFlutterPlugin.register(with: first)
        JoliboxAdsFlutterPlugin.register(with: second)
        let firstPlugin = first.valuePublished(byPlugin: pluginKey) as? JoliboxAdsFlutterPlugin
        let secondPlugin = second.valuePublished(byPlugin: pluginKey) as? JoliboxAdsFlutterPlugin
        XCTAssertNotNil(firstPlugin)
        XCTAssertNotNil(secondPlugin)
        XCTAssertFalse(firstPlugin === secondPlugin)
        JoliboxAdsFlutterPlugin.register(with: first)
        XCTAssertTrue(firstPlugin === first.valuePublished(byPlugin: pluginKey) as? JoliboxAdsFlutterPlugin)
    }

    @MainActor
    func testDetachedEngineRejectsFurtherCalls() {
        var engine: FlutterEngine? = FlutterEngine(name: "detach-test-engine")
        XCTAssertTrue(engine?.run() == true)
        JoliboxAdsFlutterPlugin.register(with: engine!)
        guard let plugin = engine?.valuePublished(byPlugin: pluginKey) as? JoliboxAdsFlutterPlugin else {
            XCTFail("Bridge not published to its engine")
            return
        }
        weak let releasedEngine = engine
        engine = nil
        XCTAssertNil(releasedEngine)
        var response: Any?
        plugin.handle(FlutterMethodCall(methodName: "getCapabilities", arguments: nil)) {
            response = $0
        }
        XCTAssertEqual((response as? FlutterError)?.code, "ENGINE_DETACHED")
    }
}
