import Foundation

/// 通过订阅链接的 `subscription-userinfo` 响应头实时查询流量（Clash 通用做法）。
/// 三个要点：
/// 1. 订阅域名直连经常不通，依次尝试直连和常见本地代理混合端口；
/// 2. 部分机场 TLS 配置不规范，需对订阅域放行证书校验（与 curl -k、各类客户端行为一致）；
/// 3. 面板通常按 User-Agent 决定是否下发流量头，使用 clash-verge UA。
enum Fetcher {
    struct Failure: Error { let message: String }

    /// 0 = 直连；其余为各家客户端默认混合端口（守候网络 7899、ClashX 7890、Verge 7897）
    private static let transports: [Int] = [0, 7899, 7890, 7897]
    private static var goodPort: Int?

    private final class TrustSubscriptionTLS: NSObject, URLSessionDelegate {
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }

    static func fetch(url: String) async throws -> QuotaSample {
        let order: [Int] = goodPort.map { g in [g] + transports.filter { $0 != g } } ?? transports
        var last = Failure(message: "未知错误")
        for port in order {
            do {
                let sample = try await attempt(url: url, port: port)
                goodPort = port
                return sample
            } catch {
                last = (error as? Failure) ?? Failure(message: String(describing: error))
            }
        }
        throw last
    }

    private static func attempt(url: String, port: Int) async throws -> QuotaSample {
        guard let u = URL(string: url) else { throw Failure(message: "订阅链接无效") }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 6
        cfg.timeoutIntervalForResource = 10
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        if port != 0 {
            cfg.connectionProxyDictionary = [
                "HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": port,
                "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": port,
            ]
        }
        let session = URLSession(configuration: cfg, delegate: TrustSubscriptionTLS(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var req = URLRequest(url: u)
        req.setValue("clash-verge/1.7.7", forHTTPHeaderField: "User-Agent")
        // GET：部分面板对 HEAD 不返回 userinfo 头；配置体通常只有几百 KB
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw Failure(message: "非 HTTP 响应") }
        guard (200..<300).contains(http.statusCode) else { throw Failure(message: "HTTP \(http.statusCode)") }

        guard let header = http.value(forHTTPHeaderField: "Subscription-Userinfo") else {
            throw Failure(message: "响应中没有流量信息")
        }
        var dict: [String: Int64] = [:]
        for m in Providers.regexMatches(#"([A-Za-z]+)\s*=\s*(\d+)"#, in: header) {
            guard m.count >= 3, let v = Int64(m[2]) else { continue }
            dict[m[1].lowercased()] = v
        }
        guard let total = dict["total"] else { throw Failure(message: "流量头缺少 total") }
        return QuotaSample(
            uploaded: dict["upload"] ?? 0,
            downloaded: dict["download"] ?? 0,
            total: total,
            expireAt: dict["expire"].map { Date(timeIntervalSince1970: TimeInterval($0)) },
            resetDay: nil,
            planName: nil,
            fetchedAt: Date(),
            source: .live
        )
    }
}
