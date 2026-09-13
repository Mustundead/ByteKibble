import XCTest
@testable import ByteKibble

@MainActor
final class SecurityViewModelTests: XCTestCase {
    func testLegacySelectionAndResetKeysMigrateAndRestore() throws {
        let domain = "ByteKibbleTests.security.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let url = "https://example.com/sub?token=secret-sentinel"
        // Reset dates are calendar days; avoid sub-microsecond Date/Unix-epoch
        // conversion noise in an equality assertion unrelated to migration.
        let date = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400 * 5))
        defaults.set([["url": url, "name": "Test"]], forKey: "customTargets")
        defaults.set(url, forKey: "selectedTargetID")
        defaults.set([Providers.dedupeKey(url): date.timeIntervalSince1970], forKey: "manualResetDates")
        let store = InMemoryCredentialStore()
        let vm = ViewModel(defaults: defaults, scan: { Providers.custom(defaults: defaults, store: store) }, credentialStore: store, automaticRefresh: false)
        XCTAssertEqual(vm.selected?.url, url)
        XCTAssertEqual(vm.manualResetDate, date)
        XCTAssertFalse(String(describing: defaults.persistentDomain(forName: domain)).contains("secret-sentinel"))
        let reopened = ViewModel(defaults: defaults, scan: { Providers.custom(defaults: defaults, store: store) }, credentialStore: store, automaticRefresh: false)
        XCTAssertEqual(reopened.manualResetDate, date)
        XCTAssertEqual(reopened.selected?.url, url)
    }

    func testRemovalCancelsActualFetchAndFailureKeepsRecord() async throws {
        let domain = "ByteKibbleTests.security.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = InMemoryCredentialStore()
        let started = expectation(description: "started")
        let cancelled = expectation(description: "cancelled")
        let vm = ViewModel(defaults: defaults, scan: { Providers.custom(defaults: defaults, store: store) }, credentialStore: store, automaticRefresh: false, fetch: { _ in
            started.fulfill()
            do { try await Task.sleep(nanoseconds: 5_000_000_000) }
            catch { cancelled.fulfill(); throw error }
            throw Fetcher.Failure(message: "Unexpected timeout")
        })
        XCTAssertTrue(vm.addCustom(url: "https://example.com/sub"))
        let id = try XCTUnwrap(vm.selected?.id)
        let operation = Task { await vm.refreshLive() }
        await fulfillment(of: [started], timeout: 2)
        store.failRemoves = true
        vm.removeCustom(id: id)
        XCTAssertEqual(vm.targets.count, 1)
        XCTAssertNotNil(vm.statusLine)
        store.failRemoves = false
        vm.removeCustom(id: id)
        await fulfillment(of: [cancelled], timeout: 2)
        await operation.value
        XCTAssertTrue(vm.loading.isEmpty)
        XCTAssertTrue(vm.failures.isEmpty)
        store.failWrites = true
        vm.undoRemoval()
        XCTAssertNotNil(vm.removedTarget)
        store.failWrites = false
        vm.undoRemoval()
        XCTAssertEqual(vm.targets.count, 1)
    }

    func testAutomaticFailureBackoffDoesNotBlockManualRefresh() async {
        var calls = 0
        let vm = ViewModel(preview: true, fetch: { _ in calls += 1; throw Fetcher.Failure(message: "HTTP 401") })
        vm.targets = [SubTarget(id: "test", name: "Test", origin: "custom", url: "https://example.com/sub", cached: nil)]
        vm.selectedID = "test"
        await vm.refreshLive()
        await vm.refreshLive(automatic: true)
        XCTAssertEqual(calls, 1)
        await vm.refreshLive()
        XCTAssertEqual(calls, 2)
    }
}
