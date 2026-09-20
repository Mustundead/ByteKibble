import XCTest
@testable import ByteKibbleCore

final class SyncInboxTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ByteKibble-inbox-test-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    func testPageAndCursorSurviveRestartWithoutCredential() async throws {
        let dir = try directory(), record = SyncRecord(name: "Waiting")
        let inbox = try SyncInbox(directory: dir, accountID: "a")
        let failed = UUID()
        try await inbox.receive(records: [record], deletedIDs: [], failedIDs: [failed], cursor: Data([1]))
        let restored = try SyncInbox(directory: dir, accountID: "a")
        let state = await restored.snapshot()
        XCTAssertEqual(state.records[record.id], record)
        XCTAssertEqual(state.cursor, Data([1]))
        XCTAssertEqual(state.failedIDs, [failed])
        let other = try SyncInbox(directory: dir, accountID: "b")
        let empty = await other.snapshot()
        XCTAssertTrue(empty.records.isEmpty)
        XCTAssertNil(empty.cursor)
    }

    func testLateAcknowledgementAndExpiredCursorKeepNewRevision() async throws {
        let inbox = try SyncInbox(directory: directory(), accountID: "a")
        let first = SyncRecord(name: "First")
        var second = first; second.revision = UUID(); second.name = "Second"
        try await inbox.receive(records: [first], deletedIDs: [], failedIDs: [], cursor: Data([1]))
        try await inbox.receive(records: [second], deletedIDs: [], failedIDs: [], cursor: Data([2]))
        try await inbox.acknowledge(first)
        try await inbox.resetCursor()
        let state = await inbox.snapshot()
        XCTAssertEqual(state.records[first.id], second)
        XCTAssertNil(state.cursor)
        try await inbox.acknowledge(second)
        let empty = await inbox.snapshot()
        XCTAssertTrue(empty.records.isEmpty)
    }

    func testInvalidPageDoesNotAdvanceCursor() async throws {
        let inbox = try SyncInbox(directory: directory(), accountID: "a")
        let record = SyncRecord(name: "Saved")
        try await inbox.receive(records: [record], deletedIDs: [], failedIDs: [], cursor: Data([1]))
        do {
            try await inbox.receive(records: [record], deletedIDs: [record.id], failedIDs: [], cursor: Data([2]))
            XCTFail("Expected ambiguous page rejection")
        } catch {}
        let state = await inbox.snapshot()
        XCTAssertEqual(state.cursor, Data([1]))
        XCTAssertEqual(state.records[record.id], record)
    }

    func testDiskFailureRetainsPageAndCursor() async throws {
        let dir = try directory(), record = SyncRecord(name: "Saved")
        let inbox = try SyncInbox(directory: dir, accountID: "a")
        try await inbox.receive(records: [record], deletedIDs: [], failedIDs: [], cursor: Data([1]))
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).first)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        do {
            try await inbox.receive(records: [], deletedIDs: [record.id], failedIDs: [], cursor: Data([2]))
            XCTFail("Expected disk failure")
        } catch {}
        let state = await inbox.snapshot()
        XCTAssertEqual(state.records[record.id], record)
        XCTAssertEqual(state.cursor, Data([1]))
    }

    func testCancelledUploadCannotAcknowledgeRetriedWork() async throws {
        let outbox = try SyncOutbox(directory: directory(), accountID: "a")
        let record = SyncRecord(name: "Pending")
        try await outbox.enqueue(record, base: nil)
        let first = await outbox.beginUpload(id: record.id)
        let old = try XCTUnwrap(first)
        await outbox.cancelUploads()
        let second = await outbox.beginUpload(id: record.id)
        let retry = try XCTUnwrap(second)
        try await outbox.acknowledge(old)
        let pending = await outbox.pending()
        XCTAssertEqual(pending.map(\.record), [record])
        try await outbox.acknowledge(retry)
        let empty = await outbox.pending()
        XCTAssertTrue(empty.isEmpty)
    }
}
