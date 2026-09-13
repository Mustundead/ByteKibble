import XCTest
@testable import ByteKibble

@MainActor
final class ManualResetTests: XCTestCase {
    private func fixture(_ body: (UserDefaults, ViewModel, SubTarget) throws -> Void) throws {
        let domain = "ByteKibbleTests.reset.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        Providers.addCustom(url: "https://example.com/sub", defaults: defaults)
        let vm = ViewModel(defaults: defaults, scan: { Providers.custom(defaults: defaults) }, automaticRefresh: false)
        let target = try XCTUnwrap(vm.selected)
        vm.now = Date(timeIntervalSince1970: 1_800_000_000)
        vm.samples[target.id] = QuotaSample(uploaded: 10, downloaded: 20, total: 100, resetDay: 4, fetchedAt: vm.now, source: .live)
        try body(defaults, vm, target)
    }

    func testManualDatePersistsWithoutChangingProviderQuota() throws {
        try fixture { defaults, vm, target in
            let original = vm.samples[target.id]
            let date = Calendar.current.date(byAdding: .day, value: 7, to: vm.now)!
            vm.setManualResetDate(date)
            XCTAssertEqual(vm.manualResetDate, Calendar.current.startOfDay(for: date))
            XCTAssertTrue(vm.menubarDaysText?.hasSuffix("*") == true)
            XCTAssertEqual(vm.samples[target.id], original)
            let reopened = ViewModel(defaults: defaults, scan: { Providers.custom(defaults: defaults) }, automaticRefresh: false)
            XCTAssertEqual(reopened.manualResetDate, vm.manualResetDate)
        }
    }

    func testClearRestoresClientInformation() throws {
        try fixture { _, vm, _ in
            let original = vm.resetCountdown
            vm.setManualResetDate(Calendar.current.date(byAdding: .day, value: 7, to: vm.now))
            vm.setManualResetDate(nil)
            XCTAssertNil(vm.manualResetDate)
            XCTAssertEqual(vm.resetCountdown, original)
            XCTAssertFalse(vm.menubarDaysText?.hasSuffix("*") == true)
        }
    }

    func testExpiredDateDoesNotRollOrResetUsage() throws {
        try fixture { _, vm, target in
            vm.setManualResetDate(vm.now)
            XCTAssertEqual(vm.resetCountdown, L10n.today)
            vm.now = Calendar.current.date(byAdding: .day, value: 1, to: vm.now)!
            XCTAssertEqual(vm.resetCountdown, L10n.t("日期已过"))
            XCTAssertEqual(vm.samples[target.id]?.used, 30)
            XCTAssertNotNil(vm.manualResetDate)
        }
    }

    func testMonthYearAndDaylightSavingBoundariesUseCalendarDays() throws {
        try fixture { _, vm, _ in
            let calendar = Calendar.current
            for parts in [DateComponents(year: 2026, month: 12, day: 31, hour: 12),
                          DateComponents(year: 2028, month: 2, day: 28, hour: 12),
                          DateComponents(year: 2026, month: 3, day: 8, hour: 12)] {
                vm.now = calendar.date(from: parts)!
                let date = calendar.date(byAdding: .day, value: 2, to: vm.now)!
                vm.setManualResetDate(date)
                XCTAssertEqual(vm.resetCountdown, vm.countdownText(days: 2, now: vm.now))
            }
        }
    }

    func testOverrideIsScopedAndRemoveUndoRestoresIt() throws {
        try fixture { defaults, vm, target in
            vm.setManualResetDate(Calendar.current.date(byAdding: .day, value: 7, to: vm.now))
            let date = vm.manualResetDate
            XCTAssertTrue(vm.addCustom(url: "#!MANAGED-CONFIG https://other.example/sub interval=60"))
            XCTAssertNil(vm.manualResetDate)
            vm.selectedID = target.id
            vm.removeCustom(id: target.id)
            XCTAssertNil((defaults.dictionary(forKey: "manualResetDates") ?? [:])[Providers.dedupeKey(target.url)])
            vm.undoRemoval()
            XCTAssertEqual(vm.manualResetDate, date)
        }
    }

    func testPastAndNonfiniteDatesAreRejectedAndPreviewCannotWrite() throws {
        try fixture { defaults, vm, target in
            vm.setManualResetDate(vm.now.addingTimeInterval(-86400))
            vm.setManualResetDate(Date(timeIntervalSince1970: .infinity))
            XCTAssertNil(vm.manualResetDate)
            let preview = ViewModel(preview: true, defaults: defaults)
            preview.targets = [target]
            preview.setManualResetDate(Date().addingTimeInterval(86400))
            XCTAssertNil(preview.manualResetDate)
        }
    }
}
