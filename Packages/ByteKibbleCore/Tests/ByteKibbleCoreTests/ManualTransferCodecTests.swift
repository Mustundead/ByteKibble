import XCTest
@testable import ByteKibbleCore

final class ManualTransferCodecTests: XCTestCase {
    private let url = URL(string: "https://example.com/subscription?token=abc")!

    func testRoundTripPreservesRecordsURLsAndTimestamps() throws {
        let observed = Date(timeIntervalSince1970: 1_726_000_123.75)
        let reading = QuotaReading(upload: 4, download: 6, total: 100, used: 10,
                                   expires: Date(timeIntervalSince1970: 1_727_000_000), observed: observed)
        let record = SyncRecord(name: "Primary", reset: Date(timeIntervalSince1970: 1_728_000_000),
                                reading: reading, history: [reading])
        let archive = ManualTransferCodec.Archive(entries: [.init(record: record, subscriptionURL: url)])
        let key = ManualTransferCodec.TransferKey.generate()

        let encoded = try ManualTransferCodec.encode(archive, key: key)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("Primary"))
        XCTAssertEqual(try ManualTransferCodec.decode(encoded, key: key), archive)
        XCTAssertEqual(try ManualTransferCodec.TransferKey(text: key.text).text, key.text)
    }

    func testWrongKeyAndTamperingAreRejected() throws {
        let archive = ManualTransferCodec.Archive(entries: [.init(record: SyncRecord(name: "Primary"), subscriptionURL: url)])
        let key = ManualTransferCodec.TransferKey.generate()
        let encoded = try ManualTransferCodec.encode(archive, key: key)
        XCTAssertThrowsError(try ManualTransferCodec.decode(encoded, key: .generate()))

        var tampered = encoded
        tampered[tampered.index(before: tampered.endIndex)] ^= 1
        XCTAssertThrowsError(try ManualTransferCodec.decode(tampered, key: key))
    }

    func testEntryBoundsInvalidURLsAndDuplicateRecordsAreRejected() throws {
        let key = ManualTransferCodec.TransferKey.generate()
        let duplicate = SyncRecord(name: "Primary")
        let duplicateArchive = ManualTransferCodec.Archive(entries: [
            .init(record: duplicate, subscriptionURL: url), .init(record: duplicate, subscriptionURL: url)
        ])
        XCTAssertThrowsError(try ManualTransferCodec.encode(duplicateArchive, key: key))

        let invalidURL = URL(string: "http://example.com/subscription")!
        XCTAssertThrowsError(try ManualTransferCodec.encode(.init(entries: [.init(record: duplicate, subscriptionURL: invalidURL)]), key: key))

        let entries = (0...ManualTransferCodec.maximumEntries).map { index in
            ManualTransferCodec.Entry(record: SyncRecord(name: "Subscription \(index)"), subscriptionURL: url)
        }
        XCTAssertThrowsError(try ManualTransferCodec.encode(.init(entries: entries), key: key))
        XCTAssertThrowsError(try ManualTransferCodec.decode(Data(repeating: 0, count: ManualTransferCodec.maximumArchiveBytes + 1), key: key))
    }
}
