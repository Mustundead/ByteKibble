import XCTest
import Sparkle
@testable import ByteKibble

final class AppUpdaterTests: XCTestCase {
    @MainActor
    func testUnbundledTestsCannotStartProductionUpdater() {
        let updater = AppUpdater()
        updater.start()
        XCTAssertFalse(updater.canCheck)
        updater.setAutomaticChecks(true)
        XCTAssertFalse(updater.automaticChecks)
        updater.check() // No dialog/network/update installation in a test host.
    }

    func testBuildNumbersAdvanceEvenWithUnchangedMarketingVersion() {
        let comparator = SUStandardVersionComparator.default
        XCTAssertEqual(comparator.compareVersion("47", toVersion: "46"), .orderedDescending)
        XCTAssertEqual(comparator.compareVersion("47", toVersion: "47"), .orderedSame)
        XCTAssertEqual(comparator.compareVersion("47", toVersion: "48"), .orderedAscending)
    }
}
