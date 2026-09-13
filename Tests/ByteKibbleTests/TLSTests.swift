import XCTest
import Darwin
@testable import ByteKibble

final class TLSTests: XCTestCase {
    func testRealTLSHandshakeRejectsUntrustedCertificateWithoutLeakingToken() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ByteKibbleTLS-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let certificate = root.appendingPathComponent("certificate.pem").path
        let key = root.appendingPathComponent("key.pem").path
        let generate = Process()
        generate.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        generate.arguments = ["req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                              "-subj", "/CN=localhost", "-keyout", key, "-out", certificate]
        generate.standardOutput = FileHandle.nullDevice
        generate.standardError = FileHandle.nullDevice
        try generate.run()
        generate.waitUntilExit()
        XCTAssertEqual(generate.terminationStatus, 0)

        let port = try availableLocalPort()
        let server = Process()
        server.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        // System LibreSSL's s_server cannot bind a specific interface. This tiny
        // fixture binds loopback only and serves no files or real subscription data.
        server.arguments = ["-u", "-c", #"""
import socket, ssl, sys
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(sys.argv[1], sys.argv[2])
with socket.socket() as listener:
    listener.bind(('127.0.0.1', int(sys.argv[3])))
    listener.listen(5)
    print('ACCEPT', flush=True)
    while True:
        connection, _ = listener.accept()
        try:
            with context.wrap_socket(connection, server_side=True) as client:
                client.recv(4096)
                client.sendall(b'HTTP/1.1 200 OK\r\nSubscription-Userinfo: upload=0; download=1; total=100\r\nContent-Length: 0\r\n\r\n')
        except (ssl.SSLError, OSError):
            connection.close()
"""#, certificate, key, String(port)]
        let output = Pipe()
        server.standardOutput = output
        server.standardError = output
        try server.run()
        defer { if server.isRunning { server.terminate(); server.waitUntilExit() } }

        let ready = expectation(description: "TLS listener ready")
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if String(data: data, encoding: .utf8)?.contains("ACCEPT") == true {
                handle.readabilityHandler = nil
                ready.fulfill()
            }
        }
        await fulfillment(of: [ready], timeout: 5)
        output.fileHandleForReading.readabilityHandler = nil

        do {
            _ = try await Fetcher.attempt(url: "https://127.0.0.1:\(port)/?token=qa-secret-sentinel", port: 0)
            XCTFail("A self-signed server certificate must not be trusted")
        } catch let failure as Fetcher.Failure {
            XCTAssertEqual(failure.priority, 2)
            XCTAssertFalse(failure.message.contains("qa-secret-sentinel"))
            XCTAssertFalse(failure.message.contains("127.0.0.1"))
        }
    }

    private func availableLocalPort() throws -> UInt16 {
        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { Darwin.close(descriptor) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.getsockname(descriptor, $0, &length) }
        }
        guard nameResult == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return UInt16(bigEndian: address.sin_port)
    }
}
