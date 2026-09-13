import Foundation

/// 通过订阅链接的 `subscription-userinfo` 响应头查询流量（Clash / Quantumult）；
/// 没有响应头时读取 Shadowsocks SIP008 的合计用量字段。
/// 三个要点：
/// 1. 订阅域名直连经常不通，依次尝试直连和常见本地代理混合端口；
/// 2. 保留系统 TLS 证书验证，并拒绝降级到 HTTP 的重定向；
/// 3. 面板通常按 User-Agent 决定是否下发流量头，使用 clash-verge UA。
enum Fetcher {
    struct Failure: Error {
        let message: String
        var priority: Int = 1
    }

    /// 0 = 直连；本机 HTTP 代理：守候网络、ClashX、Verge、Surge。
    static let transports: [Int] = [0, 7899, 7890, 7897, 6152]
    private actor TransportMemory {
        private var ports: [String: Int] = [:]
        func port(for host: String) -> Int? { ports[host] }
        func remember(_ port: Int, for host: String) {
            if ports.count > 32 { ports.removeAll() }
            ports[host] = port
        }
    }
    private static let transportMemory = TransportMemory()

    private final class SecureRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(request.url?.scheme?.lowercased() == "https" ? request : nil)
        }
    }

    static func fetch(url: String) async throws -> QuotaSample {
        guard let parsed = Providers.validatedURL(url), let host = parsed.host else {
            throw Failure(message: L10n.t("请输入有效的 HTTPS 订阅链接。"))
        }
        let goodPort = await transportMemory.port(for: host)
        let order: [Int] = goodPort.map { g in [g] + transports.filter { $0 != g } } ?? transports
        var last = Failure(message: L10n.t("无法连接。请检查网络和代理客户端后重试。"))
        for port in order {
            do {
                let sample = try await attempt(url: url, port: port)
                await transportMemory.remember(port, for: host)
                return sample
            } catch {
                // Never include a raw URLSession error: it can contain a subscription token.
                let failure = (error as? Failure) ?? Failure(message: L10n.t("无法连接。请检查网络和代理客户端后重试。"))
                if failure.priority >= last.priority { last = failure }
            }
        }
        throw last
    }

    static func attempt(url: String, port: Int) async throws -> QuotaSample {
        guard let u = Providers.validatedURL(url) else { throw Failure(message: L10n.t("请输入有效的 HTTPS 订阅链接。")) }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 6
        cfg.timeoutIntervalForResource = 10
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.connectionProxyDictionary = ["HTTPEnable": 0, "HTTPSEnable": 0]
        if port != 0 {
            cfg.connectionProxyDictionary = [
                "HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": port,
                "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": port,
            ]
        }
        let session = URLSession(configuration: cfg, delegate: SecureRedirects(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var req = URLRequest(url: u)
        req.setValue("clash-verge/1.7.7", forHTTPHeaderField: "User-Agent")
        // GET：部分面板对 HEAD 不返回 userinfo 头；配置体通常只有几百 KB
        let resp: URLResponse
        let data: Data
        do { (data, resp) = try await session.data(for: req) }
        catch let error as URLError {
            switch error.code {
            case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid, .secureConnectionFailed:
                throw Failure(message: L10n.t("无法验证订阅服务器的安全连接。请联系服务商检查证书。"), priority: 2)
            default:
                throw Failure(message: L10n.t("无法连接。请检查网络和代理客户端后重试。"))
            }
        }
        guard let http = resp as? HTTPURLResponse else { throw Failure(message: L10n.t("订阅服务器返回了无效响应。")) }
        guard (200..<300).contains(http.statusCode) else { throw Failure(message: L10n.f("订阅服务器返回 HTTP %@。请检查链接或联系服务商。", String(http.statusCode)), priority: 3) }

        return try parseResponse(header: http.value(forHTTPHeaderField: "Subscription-Userinfo"), data: data)
    }

    /// An explicit header remains authoritative, including malformed headers.
    /// Never execute subscription contents or store node credentials.
    static func parseResponse(header: String?, data: Data) throws -> QuotaSample {
        if let header { return try parse(header: header) }
        return try parseSIP008(data: data)
    }

    static func parseSIP008(data: Data) throws -> QuotaSample {
        struct Subscription: Decodable {
            let version: Int
            // Only quota fields are read. Node credentials are not decoded or retained.
            let servers: [Server]
            let bytes_used: Int64
            let bytes_remaining: Int64
            struct Server: Decodable { let id: String }
        }
        guard let subscription = try? JSONDecoder().decode(Subscription.self, from: data),
              subscription.version == 1,
              subscription.bytes_used >= 0, subscription.bytes_remaining >= 0 else {
            throw Failure(message: L10n.t("订阅未提供流量信息。请联系服务商确认支持情况。"), priority: 3)
        }
        let total = subscription.bytes_used.addingReportingOverflow(subscription.bytes_remaining)
        guard !total.overflow, total.partialValue > 0 else {
            throw Failure(message: L10n.t("订阅流量信息不完整，无法计算剩余量。"), priority: 3)
        }
        return QuotaSample(uploaded: nil, downloaded: nil, total: total.partialValue,
                           fetchedAt: Date(), source: .live, aggregateUsed: subscription.bytes_used)
    }

    static func parse(header: String) throws -> QuotaSample {
        var dict: [String: Int64] = [:]
        for part in header.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let key = pair.first?.lowercased(), ["upload", "download", "total", "expire"].contains(key) else { continue }
            guard pair.count == 2, let value = Int64(pair[1]), value >= 0, dict[key] == nil else {
                throw Failure(message: L10n.t("订阅流量信息不完整，无法计算剩余量。"), priority: 3)
            }
            dict[key] = value
        }
        guard let total = dict["total"], total > 0,
              let upload = dict["upload"], let download = dict["download"] else {
            throw Failure(message: L10n.t("订阅流量信息不完整，无法计算剩余量。"), priority: 3)
        }
        return QuotaSample(
            uploaded: upload,
            downloaded: download,
            total: total,
            expireAt: dict["expire"].flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil },
            resetDay: nil,
            planName: nil,
            fetchedAt: Date(),
            source: .live
        )
    }
}
