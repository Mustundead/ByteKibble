import XCTest
@testable import ByteKibble

final class WelcomeTests: XCTestCase {
    func testFirstLaunchCompletionAndRelaunchPreserveOtherPreferences() {
        let domain = "com.bytekibble.tests.welcome.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("keep-selection", forKey: "selectedTargetID")
        defaults.set(["keep-subscription"], forKey: "customTargets")
        let state = WelcomeState(defaults: defaults)
        XCTAssertTrue(state.shouldPresent)
        XCTAssertNil(defaults.object(forKey: WelcomeState.key))
        state.complete()
        XCTAssertFalse(WelcomeState(defaults: defaults).shouldPresent)
        state.complete()
        XCTAssertEqual(defaults.string(forKey: "selectedTargetID"), "keep-selection")
        XCTAssertEqual(defaults.stringArray(forKey: "customTargets"), ["keep-subscription"])
    }
}
