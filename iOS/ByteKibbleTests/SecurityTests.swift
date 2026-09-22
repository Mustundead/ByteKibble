import XCTest
import UserNotifications
import CloudKit
import CoreImage
import UIKit
@testable import ByteKibble

private final class LocalSyncFixtureVault: SyncCredentialAccess {
    let url = URL(string: "https://example.invalid/local-deletion-test")!
    func save(_ url: URL, recordID: UUID, revision: UUID) throws { }
    func read(recordID: UUID, revision: UUID) throws -> URL { url }
}
@MainActor private final class LocalSyncFixtureTransport: SubscriptionSyncTransport {
    let record = SyncRecord(name: "Synthetic local retention")
    func enable() async throws -> String { "local-deletion-account" }
    func disable() { }
    func prepareZone() async throws { }
    func upload(_ entry: SyncOutbox.Entry) async throws -> SyncRecord { throw QuotaError.invalidResponse }
    func download(into inbox: SyncInbox) async throws {
        try await inbox.receive(records: [record], deletedIDs: [], failedIDs: [], cursor: nil)
    }
}

final class MockSubscriptionProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let header = path == "/header" ? ["subscription-userinfo": "upload=0;download=0;total=100"] : [:]
        let status = path == "/unauthorized" ? 401 : 200
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: header)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if path == "/oversized" {
            client?.urlProtocol(self, didLoad: Data(count: QuotaParser.maximumBodyBytes + 1))
        } else {
            client?.urlProtocol(self, didLoad: Data(#"{"version":1,"servers":[],"bytes_used":80,"bytes_remaining":20}"#.utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

final class SecurityTests: XCTestCase {
    @MainActor func testDemoStoreIsEphemeralAndHasNoRealSubscriptionAccess() async throws {
        let store = SubscriptionStore(demo: true)
        XCTAssertTrue(store.demo)
        XCTAssertTrue(store.recordsAvailable)
        let item = try XCTUnwrap(store.items.first)
        XCTAssertEqual(item.name, String(localized: "演示订阅"))
        XCTAssertEqual(item.reading?.total, 100 * 1_073_741_824)
        XCTAssertEqual(item.reading?.used, 0)
        let before = store.items
        await store.refresh(item.id)
        XCTAssertEqual(store.items, before, "演示刷新不得发起订阅请求或改变示例数据")
        try store.rename("临时演示", id: item.id)
        XCTAssertEqual(store.items.first?.name, "临时演示")
        XCTAssertEqual(store.items.first?.reading?.total, item.reading?.total)
        XCTAssertEqual(store.items.first?.history.count, item.history.count)
    }

    func testQRImageDecoderRecognizesFixtureAndRejectsUnsafeImages() throws {
        let payload = "https://example.invalid/bytekibble-camera-acceptance"
        let generator = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator"))
        generator.setValue(Data(payload.utf8), forKey: "inputMessage")
        let code = try XCTUnwrap(generator.outputImage).transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        let pixels = try XCTUnwrap(context.createCGImage(code, from: code.extent))
        let png = try XCTUnwrap(UIImage(cgImage: pixels).pngData())
        XCTAssertEqual(try SubscriptionImageDecoder.payloads(in: png), [payload])
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "synthetic-subscription-qr"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertThrowsError(try SubscriptionImageDecoder.payloads(in: Data("not an image".utf8)))
        XCTAssertThrowsError(try SubscriptionImageDecoder.payloads(in: Data(count: 10 * 1024 * 1024 + 1)))
        let wide = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 16_385, height: 1))
        let widePixels = try XCTUnwrap(context.createCGImage(wide, from: wide.extent))
        let widePNG = try XCTUnwrap(UIImage(cgImage: widePixels).pngData())
        XCTAssertThrowsError(try SubscriptionImageDecoder.payloads(in: widePNG))
    }
    @MainActor func testLocalDeletionDoesNotReappearFromCloud() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let transport = LocalSyncFixtureTransport()
        defer {
            try? Vault.remove(transport.record.id)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = SubscriptionStore(storageURL: directory.appendingPathComponent("store.json"))
        let sync = SyncLibrary(directory: directory.appendingPathComponent("sync"), accessGroup: "test", transport: transport,
                               credentials: { _, _ in LocalSyncFixtureVault() })
        try await sync.connect(); try await sync.synchronize(); try store.applySync(sync)
        XCTAssertEqual(store.items.count, 1)
        try store.remove(transport.record.id)
        let restored = SubscriptionStore(storageURL: directory.appendingPathComponent("store.json"))
        try await sync.synchronize(); try restored.applySync(sync)
        XCTAssertTrue(restored.items.isEmpty)
        XCTAssertEqual(sync.rows.count, 1, "Local deletion must not delete cloud records")
    }
    @MainActor func testCloudSyntheticCrossDeviceDelivery() async throws {
        guard let text = ProcessInfo.processInfo.environment["BYTEKIBBLE_CLOUD_FIXTURE_ID"], let id = UUID(uuidString: text) else {
            throw XCTSkip("Requires an explicitly created synthetic Mac fixture")
        }
        let transport = CloudSyncTransport()
        defer { transport.disable() }
        let account = try await transport.enable()
        let database = CKContainer(identifier: "iCloud.com.mulabs.bytekibble").privateCloudDatabase
        let record = try CloudSyncCodec.decode(await database.record(for: .init(recordName: text, zoneID: CloudSyncCodec.zoneID)))
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.name, "ByteKibble QA — synthetic")
        XCTAssertEqual(record.reading?.observed, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(record.reading?.remaining, 100)
        let vault = try SyncCredentialVault(accessGroup: "46P646AZCB.com.mulabs.bytekibble.sync", accountID: account)
        let url = try vault.read(recordID: id, revision: id)
        XCTAssertEqual(url.absoluteString, "https://example.invalid/bytekibble-acceptance/" + text)
    }
    func testShareHandoffDoesNotOverwritePendingCredential() throws {
        guard try PendingSharedLink.read() == nil else { throw XCTSkip("Preserve an existing user handoff") }
        let first = "https://example.com/share-test-\(UUID())"
        defer { try? PendingSharedLink.remove(matching: first) }
        try PendingSharedLink.save(first)
        XCTAssertThrowsError(try PendingSharedLink.save("https://example.com/second"))
        XCTAssertEqual(try PendingSharedLink.read(), first)
        try PendingSharedLink.remove(matching: "https://example.com/second")
        XCTAssertEqual(try PendingSharedLink.read(), first)
        try PendingSharedLink.remove(matching: first)
        XCTAssertNil(try PendingSharedLink.read())
    }
    @MainActor func testManualImportRejectsUnsafeURLWithoutPartialChanges() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SubscriptionStore(storageURL: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertThrowsError(try store.importEntries([
            .init(record: SyncRecord(name: "Valid"), subscriptionURL: URL(string: "https://example.com/\(UUID())")!),
            .init(record: SyncRecord(name: "Invalid"), subscriptionURL: URL(string: "http://example.com/sub")!)
        ]))
        XCTAssertTrue(store.items.isEmpty)
    }
    @MainActor func testEncryptedImportPreservesOriginalAndObservationTime() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SubscriptionStore(storageURL: file)
        defer {
            for item in store.items { try? Vault.remove(item.id) }
            try? FileManager.default.removeItem(at: file)
        }
        let url = URL(string: "https://example.com/test-\(UUID())")!
        let observed = Date(timeIntervalSince1970: 1_700_000_000)
        let reading = QuotaReading(upload: nil, download: nil, total: 100, used: 20, expires: nil, observed: observed)
        let record = SyncRecord(name: "Imported", reset: observed, historyPaused: true, reading: reading, history: [reading])
        try store.importEntries([.init(record: record, subscriptionURL: url)])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].reading?.observed, observed)
        XCTAssertEqual(store.items[0].history, [reading])
        XCTAssertNil(store.items[0].syncAccount)
        var duplicate = record; duplicate.name = "Do not overwrite"
        try store.importEntries([.init(record: duplicate, subscriptionURL: url)])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].name, "Imported")
        let restored = SubscriptionStore(storageURL: file)
        XCTAssertEqual(restored.items, store.items)
        XCTAssertFalse(String(decoding: try Data(contentsOf: file), as: UTF8.self).contains(url.absoluteString))
    }
    @MainActor func testCloudCapabilityProbe() async throws {
        guard ProcessInfo.processInfo.environment["BYTEKIBBLE_CLOUD_PROBE"] == "1" else {
            throw XCTSkip("Explicit device-only capability probe; no subscription data is read or uploaded")
        }
        let transport = CloudSyncTransport()
        defer { transport.disable() }
        let account = try await transport.enable()
        XCTAssertFalse(account.isEmpty)
    }
    func testHistoryWindowPreservesUnknownAndCalendarBounds() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 12)))
        let boundary = try XCTUnwrap(calendar.date(byAdding: .day, value: -7, to: now))
        func row(_ date: Date, used: Int64? = 0) -> QuotaReading {
            QuotaReading(upload: nil, download: nil, total: 100, used: used, expires: nil, observed: date)
        }
        let unknown = row(now, used: nil)
        let zero = row(boundary, used: 100)
        let outside = row(boundary.addingTimeInterval(-1))
        let future = row(now.addingTimeInterval(1))
        let input = [unknown, outside, future, zero]
        let week = HistoryRecords.window(input, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(week, [zero, unknown])
        XCTAssertEqual(week[0].remaining, 0)
        XCTAssertNil(week[1].remaining)
        XCTAssertEqual(HistoryRecords.window(input, days: 30, now: now, calendar: calendar), [outside, zero, unknown])
        XCTAssertTrue(HistoryRecords.window(input, days: 0, now: now, calendar: calendar).isEmpty)
        XCTAssertEqual(input, [unknown, outside, future, zero])
    }
    func testHistoryRetentionPauseAndCSVContract() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let reading = QuotaReading(upload: nil, download: nil, total: 100, used: 0, expires: nil, observed: now)
        let old = QuotaReading(upload: 1, download: 1, total: 100, used: 2, expires: nil, observed: now.addingTimeInterval(-91 * 86400))
        XCTAssertTrue(HistoryRecords.appending(reading, to: [old], enabled: false, now: now).isEmpty)
        XCTAssertEqual(HistoryRecords.appending(reading, to: [old], enabled: true, now: now), [reading])
        XCTAssertEqual(HistoryRecords.retained(Array(repeating: reading, count: 2001), now: now).count, 2000)
        let csv = HistoryRecords.csv([reading])
        XCTAssertTrue(csv.contains(",,,0,100,100\r\n"))
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, 3)
        XCTAssertTrue(csv.hasPrefix("observed_utc,upload_bytes,download_bytes,used_bytes,total_bytes,remaining_bytes\r\n"))
        XCTAssertFalse(csv.contains("https:"))
        let document = HistoryCSVDocument(text: csv)
        XCTAssertEqual(document.text, csv)
    }
    @MainActor func testHistoryClearPreservesSubscriptionAndOtherRecords() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let reading = QuotaReading(upload: 0, download: 1, total: 100, used: 1, expires: nil)
        let item = Subscription(id: UUID(), name: "First", reading: reading, history: [reading], reset: .now)
        let other = Subscription(id: UUID(), name: "Second", reading: reading, history: [reading])
        try JSONEncoder().encode([item, other]).write(to: file)
        let store = SubscriptionStore(storageURL: file)
        XCTAssertNil(store.items[0].historyPaused)
        try store.setHistoryRecording(false, id: item.id)
        XCTAssertEqual(store.items[0].history, [reading])
        try store.clearHistory(id: item.id)
        let loaded = SubscriptionStore(storageURL: file)
        XCTAssertTrue(loaded.items[0].history.isEmpty)
        XCTAssertEqual(loaded.items[0].reading, reading)
        XCTAssertEqual(loaded.items[0].reset, item.reset)
        XCTAssertEqual(loaded.items[0].historyPaused, true)
        XCTAssertEqual(loaded.items[1], other)
        try loaded.setHistoryRecording(true, id: item.id)
        XCTAssertEqual(loaded.items[0].historyPaused, false)
        // A failed atomic write must leave the in-memory history untouched.
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        XCTAssertThrowsError(try loaded.clearHistory(id: other.id))
        XCTAssertEqual(loaded.items[1], other)
    }
    @MainActor func testUnreadableSourcePreservesDerivedStateAndExplicitDisableWorks() async throws {
        let suite = "test.derived.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let snapshotFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: snapshotFile)
        }
        let reading = QuotaReading(upload: 95, download: 0, total: 100, used: 95, expires: nil)
        let item = Subscription(id: UUID(), name: "Fixture", reading: reading)
        let validData = try JSONEncoder().encode([item])
        try validData.write(to: source)
        let delivery = MockReminderDelivery()
        let reminders = ReminderSettings(defaults: defaults, service: delivery)
        reminders.enabled = true
        let widgets = WidgetSharing(defaults: defaults, fileURL: snapshotFile, reload: {})
        widgets.selection = item.id.uuidString
        DerivedStateCoordinator.reconcile(store: SubscriptionStore(storageURL: source), reminders: reminders, widgets: widgets)
        await reminders.waitUntilSettled()
        XCTAssertEqual(delivery.requests.count, 1)
        let snapshot = try Data(contentsOf: snapshotFile)
        try Data("broken".utf8).write(to: source)
        let unavailable = SubscriptionStore(storageURL: source)
        XCTAssertFalse(unavailable.recordsAvailable)
        unavailable.storageError = nil // Dismissing an alert must not change source validity.
        XCTAssertFalse(unavailable.recordsAvailable)
        DerivedStateCoordinator.reconcile(store: unavailable, reminders: reminders, widgets: widgets)
        await reminders.waitUntilSettled()
        XCTAssertEqual(delivery.requests.count, 1)
        XCTAssertEqual(try Data(contentsOf: snapshotFile), snapshot)
        XCTAssertThrowsError(try unavailable.add(name: "Blocked", text: "https://fixture.invalid/blocked"))
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "broken")
        reminders.enabled = false; widgets.selection = ""
        DerivedStateCoordinator.reconcile(store: unavailable, reminders: reminders, widgets: widgets)
        await reminders.waitUntilSettled()
        XCTAssertTrue(delivery.requests.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: snapshotFile.path))
        try validData.write(to: source)
        unavailable.retryProtectedLoad()
        XCTAssertTrue(unavailable.recordsAvailable)
        XCTAssertEqual(unavailable.items, [item])
        widgets.selection = item.id.uuidString
        DerivedStateCoordinator.reconcile(store: unavailable, reminders: reminders, widgets: widgets)
        XCTAssertEqual(WidgetSnapshotFile.read(from: snapshotFile)?.remaining, 5)
    }
    @MainActor func testSerialRefreshRechecksGateAndCancellation() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let first = Subscription(id: UUID(), name: "First", reading: nil)
        let second = Subscription(id: UUID(), name: "Second", reading: nil)
        try JSONEncoder().encode([first, second]).write(to: file)
        let store = SubscriptionStore(storageURL: file)
        var calls = 0
        await store.refreshAll(while: { calls += 1; return calls == 1 })
        XCTAssertEqual(calls, 2)
        XCTAssertNotNil(store.errors[first.id], "First fixture has no Keychain credential; no network is used")
        XCTAssertNil(store.errors[second.id], "Closed gate must prevent even credential access")
        XCTAssertTrue(store.loading.isEmpty)
        let fresh = SubscriptionStore(storageURL: file)
        let task = Task { @MainActor in await fresh.refreshAll(while: { XCTFail("Cancelled work must not enter gate"); return true }) }
        task.cancel()
        await task.value
        XCTAssertTrue(fresh.errors.isEmpty)
    }
    func testWelcomePreferenceIsOptionalAndIsolated() {
        let suite = "test.welcome.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preference = WelcomePreference(defaults: defaults)
        defaults.set("keep", forKey: "unrelated")
        XCTAssertTrue(preference.shouldPresent(demo: false, hasSubscriptions: false))
        XCTAssertFalse(preference.shouldPresent(demo: true, hasSubscriptions: false))
        XCTAssertFalse(preference.shouldPresent(demo: false, hasSubscriptions: true))
        XCTAssertNil(defaults.object(forKey: "welcome.completed"))
        preference.complete()
        XCTAssertFalse(WelcomePreference(defaults: defaults).shouldPresent(demo: false, hasSubscriptions: false))
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "keep")
    }
    @MainActor func testWidgetOptInDemoIsolationAndDeletion() throws {
        XCTAssertNotNil(WidgetSnapshotFile.url, "Host app must have an App Group container")
        let suite = "test.widget.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url) }
        var reloads = 0
        let sharing = WidgetSharing(defaults: defaults, fileURL: url, reload: { reloads += 1 })
        let item = Subscription(id: UUID(), name: "private-provider", reading: QuotaReading(upload: 0, download: 0, total: 100, used: 0, expires: nil))
        sharing.update([item], demo: false)
        XCTAssertNil(WidgetSnapshotFile.read(from: url))
        sharing.selection = item.id.uuidString
        sharing.update([item], demo: true)
        XCTAssertNil(WidgetSnapshotFile.read(from: url))
        sharing.update([item], demo: false)
        XCTAssertEqual(WidgetSnapshotFile.read(from: url)?.remaining, 100)
        XCTAssertEqual(reloads, 1)
        sharing.update([item], demo: false)
        XCTAssertEqual(reloads, 1)
        sharing.update([], demo: false)
        XCTAssertNil(WidgetSnapshotFile.read(from: url))
        XCTAssertEqual(reloads, 2)
        sharing.update([item], demo: false)
        sharing.selection = ""
        sharing.update([item], demo: false)
        XCTAssertNil(WidgetSnapshotFile.read(from: url))
        XCTAssertNil(sharing.error)
    }
    func testWidgetSnapshotRoundTripPrivacyAndRemoval() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let snapshot = WidgetSnapshot(remaining: 10, total: 100, observed: .now)
        try WidgetSnapshotFile.write(snapshot, to: url)
        XCTAssertEqual(WidgetSnapshotFile.read(from: url), snapshot)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        XCTAssertEqual(Set(object.keys), Set(["remaining", "total", "observed"]))
        XCTAssertFalse(snapshot.isStale(at: snapshot.observed.addingTimeInterval(3599)))
        XCTAssertTrue(snapshot.isStale(at: snapshot.observed.addingTimeInterval(3600)))
        XCTAssertTrue(snapshot.isStale(at: snapshot.observed.addingTimeInterval(-1)))
        try WidgetSnapshotFile.write(nil, to: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(WidgetSnapshotFile.read(from: url))
    }
    func testWidgetRejectsInvalidAndOversizedSnapshots() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try WidgetSnapshotFile.write(WidgetSnapshot(remaining: -1, total: 100, observed: .now), to: url))
        XCTAssertThrowsError(try WidgetSnapshotFile.write(WidgetSnapshot(remaining: 101, total: 100, observed: .now), to: url))
        try WidgetSnapshotFile.write(WidgetSnapshot(remaining: 0, total: 0, observed: .now), to: url)
        XCTAssertEqual(WidgetSnapshotFile.read(from: url)?.remaining, 0)
        try Data(repeating: 32, count: 4097).write(to: url)
        XCTAssertNil(WidgetSnapshotFile.read(from: url))
    }
    @MainActor func testReminderPrivacyDedupAndRemoval() async {
        let suite = "test.reminders.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delivery = MockReminderDelivery()
        let reminders = ReminderSettings(defaults: defaults, service: delivery)
        reminders.enabled = true
        let reading = QuotaReading(upload: 95, download: 0, total: 100, used: 95, expires: nil)
        let item = Subscription(id: UUID(), name: "secret-provider-name", reading: reading)
        reminders.reconcile([item]); await reminders.waitUntilSettled()
        XCTAssertEqual(delivery.requests.count, 1)
        XCTAssertFalse(delivery.requests.values.first!.content.body.contains(item.name))
        reminders.reconcile([item]); await reminders.waitUntilSettled()
        XCTAssertEqual(delivery.addCount, 1)
        XCTAssertEqual(delivery.requests.count, 1, "Reconciliation must preserve a pending low-quota alert")
        reminders.enabled = false
        reminders.reconcile([item]); await reminders.waitUntilSettled()
        XCTAssertTrue(delivery.requests.isEmpty)
        reminders.reconcile([]); await reminders.waitUntilSettled()
        XCTAssertNil(defaults.dictionary(forKey: "reminders.cooldowns")?[item.id.uuidString])
    }
    @MainActor func testReminderDenialAndDateCancellation() async {
        let suite = "test.reminders.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delivery = MockReminderDelivery()
        let reminders = ReminderSettings(defaults: defaults, service: delivery)
        reminders.enabled = true
        let item = Subscription(id: UUID(), name: "Date", reading: nil, reset: Date.now.addingTimeInterval(86400))
        delivery.status = .denied
        reminders.reconcile([item]); await reminders.waitUntilSettled()
        XCTAssertTrue(delivery.requests.isEmpty)
        delivery.status = .authorized
        reminders.reconcile([item]); await reminders.waitUntilSettled()
        XCTAssertEqual(delivery.requests.count, 1)
        reminders.reconcile([]); await reminders.waitUntilSettled()
        XCTAssertTrue(delivery.requests.isEmpty)
    }
    func testHeaderStopsAndBodyQuotaWorks() async throws {
        let header = try await QuotaClient().fetch(URL(string: "https://fixture.invalid/header")!, protocolClasses: [MockSubscriptionProtocol.self])
        XCTAssertEqual(header.remaining, 100)
        let body = try await QuotaClient().fetch(URL(string: "https://fixture.invalid/body")!, protocolClasses: [MockSubscriptionProtocol.self])
        XCTAssertEqual(body.remaining, 20)
        XCTAssertNil(body.upload)
    }
    func testNetworkBoundsAndHTTPFailure() async {
        for path in ["oversized", "unauthorized"] {
            do {
                _ = try await QuotaClient().fetch(URL(string: "https://fixture.invalid/" + path)!, protocolClasses: [MockSubscriptionProtocol.self])
                XCTFail("Expected rejection")
            } catch {
                XCTAssertEqual(error as? QuotaError, path == "oversized" ? .tooLarge : .http(401))
            }
        }
    }
    @MainActor func testCredentialRoundTripMetadataAndDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("records.json")
        let store = SubscriptionStore(storageURL: file)
        let url = "https://fixture.invalid/sub?token=test-only-credential"
        let id = try store.add(name: "Test", text: url)
        defer { try? Vault.remove(id) }
        XCTAssertEqual(try Vault.read(id).absoluteString, url)
        let metadata = try String(contentsOf: file, encoding: .utf8)
        XCTAssertFalse(metadata.contains("test-only-credential"))
        XCTAssertFalse(metadata.contains("fixture.invalid"))
        XCTAssertEqual(try store.add(name: "Duplicate", text: url), id)
        XCTAssertEqual(store.items.count, 1)
        let reloaded = SubscriptionStore(storageURL: file)
        XCTAssertEqual(reloaded.items.first?.id, id)
        try reloaded.remove(id)
        XCTAssertThrowsError(try Vault.read(id))
        XCTAssertTrue(SubscriptionStore(storageURL: file).items.isEmpty)
    }
    @MainActor func testFailedMetadataWriteRemovesNewCredentialAndPreservesExisting() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("records.json")
        let store = SubscriptionStore(storageURL: file)
        let id = try store.add(name: "Existing", text: "https://fixture.invalid/sub")
        defer { try? Vault.remove(id) }
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.remove(id))
        XCTAssertEqual(try Vault.read(id).absoluteString, "https://fixture.invalid/sub")
        XCTAssertEqual(store.items.count, 1)
        XCTAssertThrowsError(try store.add(name: "New", text: "https://fixture.invalid/new"))
        XCTAssertEqual(store.items.count, 1)
    }
    @MainActor func testCorruptMetadataIsNotOverwritten() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let original = Data("invalid-json".utf8)
        try original.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let store = SubscriptionStore(storageURL: file)
        XCTAssertNotNil(store.storageError)
        XCTAssertThrowsError(try store.add(name: "Test", text: "https://fixture.invalid/sub"))
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
}

@MainActor final class MockReminderDelivery: ReminderDelivery {
    var requests: [String: UNNotificationRequest] = [:]
    var addCount = 0
    var status = UNAuthorizationStatus.authorized
    func authorization() async -> UNAuthorizationStatus { status }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { status == .authorized }
    func pendingNotificationRequests() async -> [UNNotificationRequest] { Array(requests.values) }
    func deliveredNotifications() async -> [UNNotification] { [] }
    func removePendingNotificationRequests(withIdentifiers ids: [String]) { for id in ids { requests[id] = nil } }
    func removeDeliveredNotifications(withIdentifiers: [String]) { }
    func add(_ request: UNNotificationRequest) async throws { requests[request.identifier] = request; addCount += 1 }
}
