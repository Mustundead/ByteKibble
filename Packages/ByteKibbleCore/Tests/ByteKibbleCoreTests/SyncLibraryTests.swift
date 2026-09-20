import XCTest
@testable import ByteKibbleCore

private final class TestSyncVault: SyncCredentialAccess {
    var values: [String: URL] = [:]
    func save(_ url: URL, recordID: UUID, revision: UUID) throws { values["\(recordID)/\(revision)"] = url }
    func read(recordID: UUID, revision: UUID) throws -> URL {
        guard let value = values["\(recordID)/\(revision)"] else { throw SyncValidationError.missingCredential }
        return value
    }
}
@MainActor private final class TestSyncTransport: SubscriptionSyncTransport {
    var records: [SyncRecord] = []
    var deleted: Set<UUID> = []
    var uploads: [SyncRecord] = []
    var onUpload: (() -> Void)?
    func enable() async throws -> String { "test-account" }
    func disable() {}
    func prepareZone() async throws {}
    func upload(_ entry: SyncOutbox.Entry) async throws -> SyncRecord {
        uploads.append(entry.record); onUpload?(); return entry.record
    }
    func download(into inbox: SyncInbox) async throws {
        try await inbox.receive(records: records, deletedIDs: deleted, failedIDs: [], cursor: Data([1]))
    }
}

@MainActor final class SyncLibraryTests: XCTestCase {
    func testOpeningSyncLibraryDoesNotInitializeCloudKitContainer() throws {
        // XCTest has no iCloud entitlement. This must remain safe for the
        // manual-transfer screen in local/ad-hoc macOS builds.
        let library = SyncLibrary(directory: try directory(), accessGroup: "test")
        XCTAssertNil(library.accountScope)
        XCTAssertTrue(library.rows.isEmpty)
    }

    func testDifferentAccountDoesNotLoadApprovedReplica() async throws {
        let library = SyncLibrary(directory: try directory(), accessGroup: "test", transport: TestSyncTransport(), credentials: { _, _ in TestSyncVault() })
        do { try await library.connect(expectedScope: "another-account"); XCTFail("Must reject account change") }
        catch SyncValidationError.accountChanged { }
        XCTAssertNil(library.accountScope)
        XCTAssertTrue(library.rows.isEmpty)
    }
    func testRemoteDeletionWaitsForExplicitLocalRetention() async throws {
        let transport = TestSyncTransport(), vault = TestSyncVault(), record = SyncRecord(name: "Keep locally")
        let library = SyncLibrary(directory: try directory(), accessGroup: "test", transport: transport, credentials: { _, _ in vault })
        try await library.connect()
        try library.stage(record, url: URL(string: "https://example.com/sub")!)
        try await library.synchronize()
        transport.deleted = [record.id]
        try await library.synchronize()
        XCTAssertEqual(library.remoteDeleted, [record.id])
        XCTAssertEqual(library.rows.count, 1)
        XCTAssertNil(library.rows.first?.conflict)
        try await library.keepLocalAfterRemoteDeletion(record.id)
        XCTAssertTrue(library.rows.isEmpty)
        XCTAssertTrue(library.remoteDeleted.isEmpty)
        XCTAssertNoThrow(try vault.read(recordID: record.id, revision: record.credentialRevision))
    }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ByteKibble-library-test-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }
    func testSelectedRecordPersistsAndNoCredentialLeaksIntoReplica() async throws {
        let directory = try directory(), transport = TestSyncTransport(), vault = TestSyncVault()
        let library = SyncLibrary(directory: directory, accessGroup: "test", transport: transport, credentials: { _, _ in vault })
        try await library.connect()
        XCTAssertTrue(transport.uploads.isEmpty)
        let record = SyncRecord(name: "Selected")
        try library.stage(record, url: URL(string: "https://example.com/secret-token")!)
        library.disconnect()
        try await library.connect()
        XCTAssertEqual(library.rows.map(\.record), [record])
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in files { XCTAssertFalse(String(decoding: try Data(contentsOf: file), as: UTF8.self).contains("secret-token")) }
        try await library.synchronize()
        XCTAssertEqual(transport.uploads, [record])
        XCTAssertEqual(library.rows.first?.base, record)
    }
    func testIncomingCredentialCanArriveLaterWithoutLosingMetadata() async throws {
        let transport = TestSyncTransport(), vault = TestSyncVault(), record = SyncRecord(name: "Incoming")
        transport.records = [record]
        let library = SyncLibrary(directory: try directory(), accessGroup: "test", transport: transport, credentials: { _, _ in vault })
        try await library.connect(); try await library.synchronize()
        XCTAssertEqual(library.rows.first?.record, record)
        XCTAssertEqual(library.waiting, [record.id]); XCTAssertNil(library.lastSuccess)
        try vault.save(URL(string: "https://example.com/sub")!, recordID: record.id, revision: record.credentialRevision)
        transport.records = []
        try await library.synchronize()
        XCTAssertTrue(library.waiting.isEmpty); XCTAssertNotNil(library.lastSuccess)
    }
    func testConcurrentEditsRequireExplicitChoice() async throws {
        let transport = TestSyncTransport(), vault = TestSyncVault(), original = SyncRecord(name: "Original")
        let library = SyncLibrary(directory: try directory(), accessGroup: "test", transport: transport, credentials: { _, _ in vault })
        let url = URL(string: "https://example.com/sub")!
        try await library.connect(); try library.stage(original, url: url); try await library.synchronize()
        var local = original; local.revision = UUID(); local.name = "Local"
        var remote = original; remote.revision = UUID(); remote.name = "Remote"
        try library.stage(local, url: url); transport.records = [remote]
        try await library.synchronize()
        XCTAssertEqual(library.rows.first?.conflict, remote)
        XCTAssertEqual(transport.uploads.count, 1)
        try library.resolve(id: original.id, useRemote: true)
        XCTAssertEqual(library.rows.first?.record, remote)
        XCTAssertNil(library.rows.first?.conflict)
    }
    func testDisconnectDuringUploadRejectsLateSuccess() async throws {
        let transport = TestSyncTransport(), vault = TestSyncVault()
        let library = SyncLibrary(directory: try directory(), accessGroup: "test", transport: transport, credentials: { _, _ in vault })
        try await library.connect()
        try library.stage(SyncRecord(name: "Pending"), url: URL(string: "https://example.com/sub")!)
        transport.onUpload = { library.disconnect() }
        do { try await library.synchronize(); XCTFail("Expected stale session rejection") } catch {}
        XCTAssertNil(library.accountScope); XCTAssertTrue(library.rows.isEmpty); XCTAssertNil(library.lastSuccess)
    }
}
