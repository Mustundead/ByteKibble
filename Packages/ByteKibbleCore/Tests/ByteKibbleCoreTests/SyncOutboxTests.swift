import XCTest
@testable import ByteKibbleCore

final class SyncOutboxTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ByteKibble-outbox-test-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    func testSurvivesRestartAndSeparatesAccounts() async throws {
        let dir = try directory(), record = SyncRecord(name: "Offline")
        let first = try SyncOutbox(directory: dir, accountID: "a")
        try await first.enqueue(record, base: nil)
        let restored = try SyncOutbox(directory: dir, accountID: "a")
        let rows = await restored.pending()
        XCTAssertEqual(rows.map(\.record), [record])
        let other = try SyncOutbox(directory: dir, accountID: "b")
        let empty = await other.pending()
        XCTAssertTrue(empty.isEmpty)
    }

    func testLateSuccessPreservesNewEditAndIgnoresRepeatedCallback() async throws {
        let outbox = try SyncOutbox(directory: directory(), accountID: "a")
        let first = SyncRecord(name: "First")
        try await outbox.enqueue(first, base: nil)
        let maybeUpload = await outbox.beginUpload(id: first.id)
        let upload = try XCTUnwrap(maybeUpload)
        let duplicate = await outbox.beginUpload(id: first.id)
        XCTAssertNil(duplicate)
        var second = first; second.name = "Second"; second.revision = UUID()
        try await outbox.enqueue(second, base: nil)
        try await outbox.acknowledge(upload)
        let pending = await outbox.pending()
        XCTAssertEqual(pending.first?.record, second)
        XCTAssertEqual(pending.first?.base, first)
        let maybeNext = await outbox.beginUpload(id: first.id)
        let next = try XCTUnwrap(maybeNext)
        try await outbox.acknowledge(next)
        try await outbox.acknowledge(upload)
        let empty = await outbox.pending()
        XCTAssertTrue(empty.isEmpty)
    }

    func testFailureRetainsDeletionAndRetryGetsNewToken() async throws {
        let outbox = try SyncOutbox(directory: directory(), accountID: "a")
        let base = SyncRecord(name: "Original")
        var deleted = base; deleted.deleted = true; deleted.revision = UUID()
        try await outbox.enqueue(deleted, base: base)
        let maybeFirst = await outbox.beginUpload(id: base.id)
        let first = try XCTUnwrap(maybeFirst)
        await outbox.failed(first)
        let maybeRetry = await outbox.beginUpload(id: base.id)
        let retry = try XCTUnwrap(maybeRetry)
        XCTAssertNotEqual(first.token, retry.token)
        try await outbox.acknowledge(first)
        let pending = await outbox.pending()
        XCTAssertEqual(pending.first?.record, deleted)
        try await outbox.acknowledge(retry)
        let empty = await outbox.pending()
        XCTAssertTrue(empty.isEmpty)
    }

    func testDiskFailureDoesNotPublishUnsavedState() async throws {
        let dir = try directory()
        let outbox = try SyncOutbox(directory: dir, accountID: "a")
        let first = SyncRecord(name: "First")
        try await outbox.enqueue(first, base: nil)
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).first)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        var second = first; second.revision = UUID(); second.name = "Second"
        do { try await outbox.enqueue(second, base: nil); XCTFail("Expected persistence failure") } catch {}
        let pending = await outbox.pending()
        XCTAssertEqual(pending.first?.record, first)
    }

    func testCorruptArchiveIsNotSilentlyDiscarded() async throws {
        let dir = try directory()
        let outbox = try SyncOutbox(directory: dir, accountID: "a")
        try await outbox.enqueue(SyncRecord(name: "Saved"), base: nil)
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).first)
        try Data("invalid".utf8).write(to: file)
        XCTAssertThrowsError(try SyncOutbox(directory: dir, accountID: "a"))
        XCTAssertEqual(try Data(contentsOf: file), Data("invalid".utf8))
    }
}
