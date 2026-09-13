import XCTest
@testable import ByteKibble

final class QuotaTests: XCTestCase {
    func testQuotaWarningThresholds() {
        for ratio in [1.0, 0.5, 0.2] {
            XCTAssertEqual(WarningLevel.level(remainingRatio: ratio), .normal)
        }
        for ratio in [0.1999, 0.1001, 0.10] {
            XCTAssertEqual(WarningLevel.level(remainingRatio: ratio), .warn)
        }
        for ratio in [0.0999, 0.0866, 0.07, 0, -0.1] {
            XCTAssertEqual(WarningLevel.level(remainingRatio: ratio), .danger)
        }
    }

    func testEstimatedResetDateUsesCalendarDays() throws {
        let calendar = Calendar.current
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 30, hour: 12)))
        let reset = try XCTUnwrap(Fmt.nextReset(days: 4, from: start))
        let parts = calendar.dateComponents([.year, .month, .day], from: reset)
        XCTAssertEqual(parts.year, 2027)
        XCTAssertEqual(parts.month, 1)
        XCTAssertEqual(parts.day, 3)
        XCTAssertEqual(Fmt.nextReset(days: 0, from: start), start)
        XCTAssertNil(Fmt.nextReset(days: -1, from: start))
        XCTAssertNil(Fmt.nextReset(days: 41, from: start))
    }

    func testIncompleteHeadersAreNotInventedAsZero() {
        for header in ["total=100", "total=0; upload=0; download=0", "total=100; upload=20",
                       "total=100oops; upload=1; download=1", "total=100; upload=-1; download=1",
                       "total=100; upload=1; upload=2; download=1"] {
            XCTAssertThrowsError(try Fetcher.parse(header: header))
        }
    }

    func testInvalidClientFieldsStayUnknown() {
        XCTAssertNil(Providers.clientSample(["u": "bad", "d": 10, "transfer_enable": 100]))
        XCTAssertNil(Providers.clientSample(["u": -1, "d": 10, "transfer_enable": 100]))
        XCTAssertNil(Providers.clientSample(["u": true, "d": 10, "transfer_enable": 100]))
        XCTAssertNil(Providers.clientSample(["u": 1.5, "d": 10, "transfer_enable": 100]))
        let sample = Providers.clientSample(["u": 0, "d": "10", "transfer_enable": 100, "expired_at": 0, "reset_day": 2])
        XCTAssertEqual(sample?.remaining, 90)
        XCTAssertEqual(sample?.resetDay, 2)
        XCTAssertNil(sample?.expireAt)
        XCTAssertNil(sample?.fetchedAt)
    }

    func testHeaderParsingAndOverQuota() throws {
        let sample = try Fetcher.parse(header: "upload=40; download=90; total=100; expire=0")
        XCTAssertEqual(sample.remaining, 0)
        XCTAssertEqual(sample.usedRatio, 1.3)
        XCTAssertNil(sample.expireAt)
        XCTAssertNil(sample.resetDay)
        XCTAssertNotNil(sample.fetchedAt)
        XCTAssertTrue(Fmt.percent(sample.usedRatio).contains("%"))
    }

    func testOverflowIsBounded() {
        let sample = QuotaSample(uploaded: .max, downloaded: 1, total: 100,
                                 fetchedAt: nil, source: .cache)
        XCTAssertEqual(sample.used, .max)
        XCTAssertEqual(sample.remaining, 0)
    }

    func testOnlyWellFormedHTTPSLinksAreAccepted() {
        for text in ["http://example.com/sub", "httpbad", "https://", "https://u:p@example.com/sub", "https://example.com/a b", "https://example.com/#secret"] {
            XCTAssertNil(Providers.validatedURL(text), text)
        }
        XCTAssertNotNil(Providers.validatedURL("https://example.com/sub?token=sample"))
    }

    func testDedupeNeverMergesDifferentProviders() {
        XCTAssertNotEqual(Providers.dedupeKey("https://a.example/sub?token=same"),
                          Providers.dedupeKey("https://b.example/sub?token=same"))
        XCTAssertNotEqual(Providers.dedupeKey("https://a.example/one?token=same"),
                          Providers.dedupeKey("https://a.example/two?token=same"))
        XCTAssertEqual(Providers.dedupeKey("https://a.example/sub?token=same&signature=1"),
                       Providers.dedupeKey("https://a.example/sub?token=same&signature=2"))
    }

    func testVergeRegexExtractsURLRatherThanYAMLField() {
        let matches = Providers.regexMatches(#"url:\s*["']?(https?://[^\s"']+)"#,
                                             in: "url: 'https://example.com/sub?token=sample'")
        XCTAssertEqual(matches.first?[1], "https://example.com/sub?token=sample")
    }
}

@MainActor
final class ViewModelTests: XCTestCase {
    private func target(_ name: String, cached: QuotaSample? = nil) -> SubTarget {
        let url = "https://\(name).example/sub"
        return SubTarget(id: url, name: name, origin: "custom", url: url, cached: cached)
    }
    private func sample(_ download: Int64, date: Date? = Date()) -> QuotaSample {
        QuotaSample(uploaded: 0, downloaded: download, total: 100,
                    resetDay: 2, fetchedAt: date, source: date == nil ? .cache : .live)
    }

    func testCacheReadCannotReplaceLiveResult() async {
        let cache = sample(10, date: nil)
        let live = sample(30)
        let t = target("a", cached: cache)
        let vm = ViewModel(preview: true, fetch: { _ in live })
        vm.targets = [t]; vm.selectedID = t.id
        await vm.refreshLive()
        XCTAssertEqual(vm.sample(for: t)?.downloaded, 30)
        vm.targets = [target("a", cached: cache)]
        XCTAssertEqual(vm.sample(for: vm.targets[0])?.downloaded, 30)
    }

    func testRestoredMenubarCountdownPreservesSourceMetadata() {
        let t = target("a", cached: sample(10, date: nil))
        let vm = ViewModel(preview: true)
        vm.targets = [t]; vm.selectedID = t.id
        vm.now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(vm.menubarDaysText, L10n.cdDays(2))
        vm.now = vm.now.addingTimeInterval(86400)
        XCTAssertEqual(vm.menubarDaysText, L10n.cdDays(2))
        XCTAssertNil(vm.sample(for: t)?.fetchedAt)
        XCTAssertEqual(vm.sample(for: t)?.resetDay, 2)
        let midnight = Calendar.current.startOfDay(for: vm.now)
        XCTAssertEqual(vm.countdownText(days: 0, now: midnight), L10n.today)
        XCTAssertEqual(vm.countdownText(days: 1, now: midnight.addingTimeInterval(12 * 3600)), L10n.cdHours(12))
        XCTAssertEqual(vm.countdownText(days: 1, now: midnight.addingTimeInterval(23.5 * 3600)), L10n.cdMinutes(30))
    }

    func testFailureIsScopedToItsSubscription() async {
        let a = target("a"), b = target("b")
        let live = sample(20)
        let vm = ViewModel(preview: true, fetch: { url in
            if url == a.url { throw Fetcher.Failure(message: "A failed") }
            return live
        })
        vm.targets = [a, b]; vm.selectedID = a.id
        await vm.refreshLive()
        XCTAssertEqual(vm.statusLine, "A failed")
        XCTAssertNil(vm.sample(for: a))
        vm.selectedID = b.id
        XCTAssertNil(vm.statusLine)
        await vm.refreshLive()
        XCTAssertEqual(vm.sample(for: b)?.downloaded, 20)
        vm.selectedID = a.id
        XCTAssertEqual(vm.statusLine, "A failed")
    }

    func testSwitchWhileOldRequestPendingDoesNotBlockNewTarget() async {
        let a = target("a"), b = target("b")
        let live = sample(40)
        let started = expectation(description: "A started")
        var pending: CheckedContinuation<QuotaSample, Error>?
        let vm = ViewModel(preview: true, fetch: { url in
            if url == a.url {
                return try await withCheckedThrowingContinuation { continuation in
                    pending = continuation
                    started.fulfill()
                }
            }
            return live
        })
        vm.targets = [a, b]; vm.selectedID = a.id
        let request = Task { await vm.refreshLive() }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(vm.fetching)
        vm.selectedID = b.id
        XCTAssertFalse(vm.fetching)
        await vm.refreshLive()
        XCTAssertEqual(vm.sample(for: b)?.downloaded, 40)
        pending?.resume(throwing: Fetcher.Failure(message: "A failed"))
        await request.value
        XCTAssertNil(vm.statusLine)
        XCTAssertEqual(vm.failures[a.id], "A failed")
    }

    func testAddSelectRemoveUndoAndDeduplicateUsingIsolatedStore() async throws {
        let name = "ByteKibbleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = InMemoryCredentialStore()
        let live = sample(10)
        let vm = ViewModel(defaults: defaults,
                           scan: { Providers.custom(defaults: defaults, store: store) }, credentialStore: store,
                           automaticRefresh: false, fetch: { _ in live })
        XCTAssertTrue(vm.addCustom(url: "https://a.example/sub"))
        XCTAssertTrue(vm.addCustom(url: "https://b.example/sub"))
        XCTAssertEqual(vm.selected?.url, "https://b.example/sub")
        XCTAssertEqual(vm.targets.count, 2)
        XCTAssertTrue(vm.addCustom(url: "https://b.example/sub"))
        XCTAssertEqual(vm.targets.count, 2)
        let b = try XCTUnwrap(vm.selected)
        vm.removeCustom(id: b.id)
        XCTAssertEqual(vm.targets.count, 1)
        XCTAssertEqual(vm.selected?.url, "https://a.example/sub")
        XCTAssertNotNil(vm.removedTarget)
        vm.undoRemoval()
        XCTAssertEqual(vm.targets.count, 2)
        XCTAssertEqual(vm.selected?.url, b.url)
        XCTAssertNil(vm.removedTarget)
    }

    func testPreviewDoesNotWriteSelectionPreferences() throws {
        let name = "ByteKibbleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("real-selection", forKey: "selectedTargetID")
        let vm = ViewModel(preview: true, defaults: defaults)
        vm.selectedID = "preview-selection"
        XCTAssertEqual(defaults.string(forKey: "selectedTargetID"), "real-selection")
    }

    func testRemovedSubscriptionRejectsLateResponse() async throws {
        let name = "ByteKibbleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = InMemoryCredentialStore()
        Providers.addCustom(url: "https://a.example/sub", defaults: defaults, store: store)
        let started = expectation(description: "request started")
        var pending: CheckedContinuation<QuotaSample, Error>?
        let vm = ViewModel(defaults: defaults, scan: { Providers.custom(defaults: defaults, store: store) }, credentialStore: store,
                           automaticRefresh: false, fetch: { _ in
            try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                started.fulfill()
            }
        })
        let id = try XCTUnwrap(vm.selected?.id)
        let request = Task { await vm.refreshLive() }
        await fulfillment(of: [started], timeout: 2)
        vm.removeCustom(id: id)
        pending?.resume(returning: sample(20))
        await request.value
        XCTAssertNil(vm.samples[id])
        XCTAssertTrue(vm.loading.isEmpty)
        XCTAssertTrue(vm.targets.isEmpty)
    }
}
