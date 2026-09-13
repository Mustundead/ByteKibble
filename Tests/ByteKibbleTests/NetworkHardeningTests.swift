import XCTest
@testable import ByteKibble

private final class QuotaProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let headers: [String: String]
        if path == "/header" { headers = ["Subscription-Userinfo": "upload=0; download=0; total=100", "Content-Length": "999999999", "Content-Type": "application/octet-stream"] }
        else if path == "/declared" { headers = ["Content-Length": "999999999"] }
        else { headers = [:] }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: path == "/unauthorized" ? 401 : 200, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        if path == "/header" || path == "/hang" { return }
        if path == "/chunked" {
            client?.urlProtocol(self, didLoad: Data(repeating: 32, count: Fetcher.maximumBodyBytes + 1))
        } else if path == "/sip" {
            client?.urlProtocol(self, didLoad: Data(#"{"version":1,"servers":[],"bytes_used":10,"bytes_remaining":90}"#.utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class NetworkHardeningTests: XCTestCase {
    func testRealSocketHeadersReturnBeforeBodyCompletes() async throws {
        let server = Process()
        server.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        server.arguments = ["-u", "-c", #"""
import socket, time
with socket.socket() as listener:
    listener.bind(('127.0.0.1', 0))
    listener.listen(1)
    print(listener.getsockname()[1], flush=True)
    connection, _ = listener.accept()
    with connection:
        connection.recv(4096)
        connection.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nSubscription-Userinfo: upload=0; download=0; total=100\r\nContent-Length: 999999999\r\n\r\n')
        # CFNetwork may sniff an initial body prefix before delivering headers.
        connection.sendall(b'x' * 1024)
        time.sleep(5)
"""#]
        let output = Pipe()
        server.standardOutput = output
        server.standardError = FileHandle.nullDevice
        try server.run()
        defer { if server.isRunning { server.terminate(); server.waitUntilExit() } }
        let port = try XCTUnwrap(String(data: output.fileHandleForReading.availableData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines))
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = ["HTTPEnable": 0, "HTTPSEnable": 0]
        config.timeoutIntervalForResource = 3
        let start = Date()
        // HTTP is confined to this loopback fixture. Production Fetcher accepts HTTPS only.
        let result = try await QuotaRequest().run(URLRequest(url: URL(string: "http://127.0.0.1:\(port)/")!), configuration: config)
        XCTAssertEqual(result.total, 100)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
    }

    func testRedirectsRequireSameHTTPSOrigin() {
        let source = URL(string: "https://example.com/sub?token=secret")!
        XCTAssertTrue(Fetcher.redirectAllowed(from: source, to: URL(string: "https://EXAMPLE.com:443/new")))
        for target in ["http://example.com/new", "https://evil.example/new", "https://example.com:444/new", "https://user@example.com/new", "https://example.com/new#fragment"] {
            XCTAssertFalse(Fetcher.redirectAllowed(from: source, to: URL(string: target)))
        }
    }

    func testHeaderReturnsWithoutReadingHugeBodyAndSIP008StillWorks() async throws {
        let header = try await Fetcher.attempt(url: "https://test.example/header", port: 0, protocolClasses: [QuotaProtocol.self])
        XCTAssertEqual(header.total, 100)
        let sip = try await Fetcher.attempt(url: "https://test.example/sip", port: 0, protocolClasses: [QuotaProtocol.self])
        XCTAssertEqual(sip.remaining, 90)
    }

    func testDeclaredAndActualBodyLimitsAndHTTPFailure() async {
        for path in ["declared", "chunked", "unauthorized"] {
            do {
                _ = try await Fetcher.attempt(url: "https://test.example/\(path)", port: 0, protocolClasses: [QuotaProtocol.self])
                XCTFail("Expected rejection: \(path)")
            } catch let failure as Fetcher.Failure {
                XCTAssertFalse(failure.retryable)
            } catch { XCTFail("Unexpected error type") }
        }
    }

    func testOnlyTransientTransportFailuresRetry() async throws {
        var calls = 0
        do {
            _ = try await Fetcher.fetch(url: "https://test.example", order: [0, 1, 2]) { _, _ in
                calls += 1
                throw Fetcher.Failure(message: "HTTP 401")
            }
        } catch {}
        XCTAssertEqual(calls, 1)
        calls = 0
        do {
            _ = try await Fetcher.fetch(url: "https://test.example", order: [0, 1, 2]) { _, _ in
                calls += 1
                throw Fetcher.Failure(message: "timeout", retryable: true)
            }
        } catch {}
        XCTAssertEqual(calls, 3)
    }

    func testCancellationNeverRetries() async {
        var calls = 0
        do {
            _ = try await Fetcher.fetch(url: "https://test.example", order: [0, 1]) { _, _ in
                calls += 1
                throw CancellationError()
            }
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(calls, 1)
    }

    func testStreamingRequestCancellationCompletesPromptly() async {
        let operation = Task {
            try await Fetcher.attempt(url: "https://test.example/hang", port: 0, protocolClasses: [QuotaProtocol.self])
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        let start = Date()
        operation.cancel()
        do { _ = try await operation.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
    }
}
