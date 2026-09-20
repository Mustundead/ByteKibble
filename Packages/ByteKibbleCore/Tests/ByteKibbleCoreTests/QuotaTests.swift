import XCTest
@testable import ByteKibbleCore

final class QuotaTests: XCTestCase {
    func testReminderFreshnessAndCooldown() {
        let now = Date(timeIntervalSince1970: 200000)
        let low = QuotaReading(upload: 91, download: 0, total: 100, used: 91, expires: nil, observed: now)
        XCTAssertTrue(ReminderPolicy.shouldWarn(reading: low, lastAlert: nil, now: now))
        XCTAssertFalse(ReminderPolicy.shouldWarn(reading: low, lastAlert: now, now: now))
        XCTAssertFalse(ReminderPolicy.shouldWarn(reading: low, lastAlert: nil, now: now.addingTimeInterval(3601)))
        XCTAssertFalse(ReminderPolicy.shouldWarn(reading: nil, lastAlert: nil, now: now))
        XCTAssertNil(ReminderPolicy.deadline(now.addingTimeInterval(-86400), now: now))
        XCTAssertNotNil(ReminderPolicy.deadline(now.addingTimeInterval(86400), now: now))
    }
    func testWarningBoundary() {
        XCTAssertEqual(QuotaWarning(remainingRatio: 0.099), .critical)
        XCTAssertEqual(QuotaWarning(remainingRatio: 0.1), .low)
        XCTAssertEqual(QuotaWarning(remainingRatio: 0.2), .normal)
        XCTAssertEqual(QuotaWarning(remainingRatio: nil), .unknown)
    }
    func testClientWrappersDoNotExecuteOrChangeTokens() throws {
        for link in ["surge:///install-config?url=https%3A%2F%2Fexample.com%2Fsub", "sing-box://import-remote-profile?url=https%3A%2F%2Fexample.com%2Fsub", "loon://import?sub=https%3A%2F%2Fexample.com%2Fsub", "https://link.stash.ws/install-config/https%3A%2F%2Fexample.com%2Fsub"] {
            XCTAssertEqual(try SubscriptionLink.parse(link).absoluteString, "https://example.com/sub")
        }
        XCTAssertEqual(try SubscriptionLink.parse("hiddify://import/https://example.com/sub?token=a%2Fb#Name").absoluteString, "https://example.com/sub?token=a%2Fb")
        XCTAssertThrowsError(try SubscriptionLink.parse("stash://install-config?url=https://one.com&url=https://two.com"))
    }
    func testFullQuota() throws {
        let r = try QuotaParser.parse(header: "upload=0; download=0; total=1073741824", body: Data())
        XCTAssertEqual(r.remaining, 1073741824); XCTAssertEqual(r.remainingRatio, 1)
    }
    func testPartialIsNotZero() throws {
        let r = try QuotaParser.parse(header: "total=100; upload=10", body: Data())
        XCTAssertNil(r.used); XCTAssertNil(r.remaining)
        XCTAssertNil(try QuotaParser.parse(header: "total=0; upload=0; download=0", body: Data()).remaining)
    }
    func testMalformedAndOverflowRejected() {
        for header in ["total=1;total=2", "upload=-1", "upload=x", "upload=9223372036854775807;download=1", "upload="] {
            XCTAssertThrowsError(try QuotaParser.parse(header: header, body: Data()))
        }
    }
    func testSIP008DoesNotInventUpload() throws {
        let data = Data(#"{"version":1,"servers":[],"bytes_used":80,"bytes_remaining":20}"#.utf8)
        let r = try QuotaParser.parse(header: nil, body: data)
        XCTAssertEqual(r.remaining, 20); XCTAssertNil(r.upload); XCTAssertNil(r.download)
        XCTAssertThrowsError(try QuotaParser.parse(header: "total=broken", body: data))
    }
    func testBounds() {
        XCTAssertThrowsError(try QuotaParser.parse(header: nil, body: Data(count: QuotaParser.maximumBodyBytes + 1)))
        XCTAssertThrowsError(try SubscriptionLink.parse("https://example.com/" + String(repeating: "x", count: 16_384)))
    }
    func testImportAndRedirectPolicy() throws {
        let url = "https://example.com/sub?token=secret"
        XCTAssertEqual(try SubscriptionLink.parse(url).absoluteString, url)
        XCTAssertEqual(try SubscriptionLink.parse("#!MANAGED-CONFIG " + url + " interval=3600").absoluteString, url)
        XCTAssertEqual(try SubscriptionLink.parse("stash://install-config?url=https%3A%2F%2Fexample.com%2Fsub%3Ftoken%3Dsecret").absoluteString, url)
        for bad in ["http://example.com", "https://user:pass@example.com", "ss://secret", url + "\nhttps://other.com", url + "#fragment"] {
            XCTAssertThrowsError(try SubscriptionLink.parse(bad))
        }
        XCTAssertFalse(SubscriptionLink.allowsRedirect(from: URL(string: url)!, to: URL(string: "https://other.com")!))
        XCTAssertFalse(SubscriptionLink.allowsRedirect(from: URL(string: url)!, to: URL(string: "http://example.com")!))
        XCTAssertTrue(SubscriptionLink.allowsRedirect(from: URL(string: url)!, to: URL(string: "https://example.com/next")!))
    }
}
