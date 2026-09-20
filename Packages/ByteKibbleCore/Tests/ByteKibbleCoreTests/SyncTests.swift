import XCTest
import Security
@testable import ByteKibbleCore

final class SyncTests: XCTestCase {
    func testCredentialQueriesAreAccountAndRevisionScoped() throws {
        let id = UUID(), revision = UUID()
        let a = try SyncCredentialVault(accessGroup: "test.group", accountID: "test-account-a")
        let b = try SyncCredentialVault(accessGroup: "test.group", accountID: "test-account-b")
        let first = a.query(recordID: id, revision: revision)
        let other = b.query(recordID: id, revision: revision)
        XCTAssertNotEqual(first[kSecAttrService as String] as? String, other[kSecAttrService as String] as? String)
        XCTAssertEqual(first[kSecAttrSynchronizable as String] as? Bool, true)
        XCTAssertEqual(first[kSecAttrAccessGroup as String] as? String, "test.group")
        XCTAssertNil(first[kSecValueData as String])
        XCTAssertNotEqual(first[kSecAttrAccount as String] as? String,
                          a.query(recordID: id, revision: UUID())[kSecAttrAccount as String] as? String)
        XCTAssertThrowsError(try SyncCredentialVault(accessGroup: "", accountID: "account"))
    }
    func testMetadataRoundTripKeepsObservationTimeAndUnknowns() throws {
        let observed = Date(timeIntervalSince1970: 1_000_000)
        let reading = QuotaReading(upload: nil, download: nil, total: 100, used: 0, expires: nil, observed: observed)
        let record = SyncRecord(name: "Sample", reading: reading, history: [reading])
        let encoded = try record.encode()
        let decoded = try SyncRecord.decode(encoded)
        XCTAssertEqual(decoded, record)
        XCTAssertEqual(decoded.reading?.observed, observed)
        XCTAssertNil(decoded.reading?.upload)
        XCTAssertEqual(decoded.reading?.remaining, 100)
        let keys = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(Set(keys.keys), ["schemaVersion", "id", "revision", "credentialRevision", "name", "historyPaused", "reading", "history", "deleted"])
    }
    func testUnknownSchemaAndUnboundedRecordsRejected() throws {
        var record = SyncRecord(name: "Sample")
        record.schemaVersion = 2
        XCTAssertThrowsError(try record.encode())
        record.schemaVersion = 1; record.name = String(repeating: "a", count: 81)
        XCTAssertThrowsError(try record.encode())
        XCTAssertThrowsError(try SyncRecord.decode(Data(repeating: 0, count: 512 * 1024 + 1)))
    }
    func testSingleSidedChangesAndConflictAreExplicit() throws {
        let base = SyncRecord(name: "Sample")
        var local = base; local.name = "Local"; local.revision = UUID()
        var remote = base; remote.name = "Remote"; remote.revision = UUID()
        XCTAssertEqual(try SyncMerge.reconcile(base: base, local: local, remote: base), .upload(local))
        XCTAssertEqual(try SyncMerge.reconcile(base: base, local: base, remote: remote), .adopt(remote))
        XCTAssertEqual(try SyncMerge.reconcile(base: base, local: local, remote: remote), .conflict(local: local, remote: remote))
        remote.deleted = true
        XCTAssertEqual(try SyncMerge.reconcile(base: base, local: local, remote: remote), .conflict(local: local, remote: remote))
    }
    func testAccountSwitchAndDisableRejectOldWork() throws {
        var gate = SyncAccountGate()
        let first = try gate.enable(account: "test-account-a")
        try gate.validate(account: "test-account-a", generation: first)
        _ = try gate.enable(account: "test-account-b")
        XCTAssertThrowsError(try gate.validate(account: "test-account-a", generation: first))
        let second = gate.generation
        gate.disable()
        XCTAssertThrowsError(try gate.validate(account: "test-account-b", generation: second))
    }
    func testMalformedReadingRejectedWithoutChangingInput() throws {
        let row = QuotaReading(upload: Int64.max, download: 1, total: 100, used: nil, expires: nil)
        let record = SyncRecord(name: "Sample", reading: row)
        XCTAssertThrowsError(try record.encode())
        XCTAssertEqual(record.reading, row)
    }
}
