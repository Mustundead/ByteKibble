import XCTest
@testable import ByteKibble

final class SubscriptionCompatibilityTests: XCTestCase {
    func testSurgeManagedProfileLineExtractsOnlyHTTPSURL() {
        XCTAssertEqual(Providers.subscriptionURL(from: "#!MANAGED-CONFIG https://example.com/surge.conf?token=example interval=60 strict=true"),
                       "https://example.com/surge.conf?token=example")
        for invalid in ["#!MANAGED-CONFIG http://example.com/a", "#!MANAGED-CONFIG", "#!MANAGED-CONFIG file:///tmp/a",
                        "#!MANAGED-CONFIG https://example.com/a\n[Script]\nx=script-path=secret", "ss://example"] {
            XCTAssertNil(Providers.subscriptionURL(from: invalid))
        }
        XCTAssertTrue(Fetcher.transports.contains(6152))
    }

    func testSurgeProfileBodyIsNotUsedAsQuotaOrExecuted() throws {
        let profile = Data("#!MANAGED-CONFIG https://example.com/sub interval=60\n[Rule]\nFINAL,DIRECT".utf8)
        XCTAssertEqual(try Fetcher.parseResponse(header: "upload=10;download=20;total=100", data: profile).remaining, 70)
        XCTAssertThrowsError(try Fetcher.parseResponse(header: nil, data: profile))
    }
    private func body(_ fields: String) -> Data {
        Data("{\"version\":1,\"servers\":[],\(fields)}".utf8)
    }

    func testQuantumultOfficialHeaderWithOpaqueNodeBody() throws {
        let sample = try Fetcher.parseResponse(
            header: "upload=2375927198; download=12983696043; total=1099511627776; expire=1862111613",
            data: Data("ss://not-decoded-or-executed".utf8))
        XCTAssertEqual(sample.uploaded, 2375927198)
        XCTAssertEqual(sample.downloaded, 12983696043)
        XCTAssertEqual(sample.remaining, 1084152004535)
        XCTAssertEqual(sample.expireAt, Date(timeIntervalSince1970: 1862111613))
        XCTAssertNil(sample.resetDay)
        XCTAssertNil(sample.aggregateUsed)
    }

    func testSIP008AggregateDoesNotInventTrafficBreakdown() throws {
        let sample = try Fetcher.parseResponse(header: nil,
            data: body("\"bytes_used\":274877906944,\"bytes_remaining\":824633720832"))
        XCTAssertEqual(sample.used, 274877906944)
        XCTAssertEqual(sample.total, 1099511627776)
        XCTAssertEqual(sample.remaining, 824633720832)
        XCTAssertEqual(sample.usedRatio, 0.25)
        XCTAssertNil(sample.uploaded)
        XCTAssertNil(sample.downloaded)
        XCTAssertNil(sample.expireAt)
        XCTAssertNil(sample.resetDay)
        XCTAssertNotNil(sample.fetchedAt)
    }

    func testSIP008FullAndExhausted() throws {
        for used in [0, 100] {
            let sample = try Fetcher.parseSIP008(data: body("\"bytes_used\":\(used),\"bytes_remaining\":\(100-used)"))
            XCTAssertEqual(sample.remaining, Int64(100-used))
            XCTAssertEqual(sample.used, Int64(used))
        }
    }

    func testInvalidSIP008NeverBecomesZeroBalance() {
        for fields in [
            "\"bytes_used\":10", // Unlimited or missing quota is not zero remaining.
            "\"bytes_remaining\":90",
            "\"bytes_used\":0,\"bytes_remaining\":0",
            "\"bytes_used\":-1,\"bytes_remaining\":100",
            "\"bytes_used\":10,\"bytes_remaining\":-1",
            "\"bytes_used\":true,\"bytes_remaining\":100",
            "\"bytes_used\":1.5,\"bytes_remaining\":100",
            "\"bytes_used\":\"10\",\"bytes_remaining\":100",
            "\"bytes_used\":9223372036854775807,\"bytes_remaining\":1",
            "\"bytes_used\":9223372036854775808,\"bytes_remaining\":0"
        ] { XCTAssertThrowsError(try Fetcher.parseSIP008(data: body(fields)), fields) }
        for text in ["ss://example", "<html>error</html>",
                     "{\"bytes_used\":10,\"bytes_remaining\":90}",
                     "{\"version\":2,\"servers\":[],\"bytes_used\":10,\"bytes_remaining\":90}",
                     "{\"version\":1,\"servers\":{},\"bytes_used\":10,\"bytes_remaining\":90}"] {
            XCTAssertThrowsError(try Fetcher.parseSIP008(data: Data(text.utf8)))
        }
    }

    func testHeaderPrecedenceIncludingInvalidHeader() throws {
        let data = body("\"bytes_used\":90,\"bytes_remaining\":10")
        let sample = try Fetcher.parseResponse(header: "upload=1; download=2; total=100", data: data)
        XCTAssertEqual(sample.used, 3)
        XCTAssertThrowsError(try Fetcher.parseResponse(header: "total=100", data: data))
    }

    func testNodeCredentialsAndCustomQuotaFieldsAreIgnored() throws {
        let data = Data("""
        {"version":1,"servers":[{"id":"example","server":"example.com","password":"never-store"}],
        "bytes_used":10,"bytes_remaining":90,"upload":999,"expire":1862111613}
        """.utf8)
        let sample = try Fetcher.parseSIP008(data: data)
        XCTAssertEqual(sample.used, 10)
        XCTAssertNil(sample.uploaded)
        XCTAssertNil(sample.expireAt)
    }
}
