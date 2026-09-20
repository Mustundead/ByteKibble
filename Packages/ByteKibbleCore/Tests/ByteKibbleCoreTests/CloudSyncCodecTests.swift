import XCTest
import CloudKit
@testable import ByteKibbleCore

final class CloudSyncCodecTests: XCTestCase {
    func testEncryptedPayloadRoundTripAndNoPlainFields() throws {
        let value = SyncRecord(name: "Test subscription")
        let record = try CloudSyncCodec.encode(value)
        XCTAssertEqual(record.recordID.recordName, value.id.uuidString)
        XCTAssertEqual(record.recordID.zoneID, CloudSyncCodec.zoneID)
        XCTAssertNil(record["payloadV1"])
        XCTAssertNotNil(record.encryptedValues["payloadV1"])
        XCTAssertEqual(try CloudSyncCodec.decode(record), value)
    }
    func testWrongRecordIdentityAndZoneRejected() throws {
        let value = SyncRecord(name: "Test subscription")
        let wrong = CKRecord(recordType: CloudSyncCodec.recordType)
        wrong.encryptedValues["payloadV1"] = try value.encode() as NSData
        XCTAssertThrowsError(try CloudSyncCodec.decode(wrong))
        XCTAssertThrowsError(try CloudSyncCodec.encode(value, into: wrong))
    }
}
