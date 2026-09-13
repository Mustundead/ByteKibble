import Foundation

/// 从各个客户端扫描可用订阅：
/// - 守候网络（SNTP）官方客户端：plist 缓存，信息最全（含重置日、套餐名）
/// - Clash Verge (Rev)：profiles.yaml 里的订阅 URL
/// - ClashX / ClashX Meta：defaults 里的 kRemoteConfigs（JSON 数组）
/// - 手动添加：用户粘贴的任意机场订阅链接
enum Providers {
    static func scanAll(defaults: UserDefaults = .standard) -> [SubTarget] {
        let list = sntp() + verge() + clashX() + custom(defaults: defaults)
        var out: [SubTarget] = []
        for t in list {
            let key = dedupeKey(t.url)
            if let i = out.firstIndex(where: { dedupeKey($0.url) == key }) {
                // 同一订阅只保留信息最全的一份（优先带缓存、优先官方客户端）
                let old = out[i]
                let better = (old.cached == nil && t.cached != nil) || (old.origin != "sntp" && t.origin == "sntp")
                out[i] = better ? t : old
            } else {
                out.append(t)
            }
        }
        return out
    }

    // MARK: - 守候网络 (SNTP)

    private static func sntp() -> [SubTarget] {
        guard let d = UserDefaults(suiteName: "com.sntp"),
              let raw = d.string(forKey: "flutter.sntp_user_data_cache"),
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let si = obj["subscribeInfo"] as? [String: Any],
              let url = si["subscribe_url"] as? String, url.hasPrefix("http")
        else { return [] }

        let plan = (si["plan"] as? [String: Any])?["name"] as? String
        let sample = clientSample(si)
        return [SubTarget(id: url, name: plan ?? "守候网络", origin: "sntp", url: url, cached: sample)]
    }

    static func clientSample(_ info: [String: Any]) -> QuotaSample? {
        guard let upload = nonnegativeInteger(info["u"]),
              let download = nonnegativeInteger(info["d"]),
              let total = nonnegativeInteger(info["transfer_enable"]), total > 0 else { return nil }
        let expiry = nonnegativeInteger(info["expired_at"])
        let reset = nonnegativeInteger(info["reset_day"]).flatMap { (0...40).contains($0) ? Int($0) : nil }
        return QuotaSample(uploaded: upload, downloaded: download, total: total,
                           expireAt: expiry.flatMap { $0 > 0 ? Date(timeIntervalSince1970: Double($0)) : nil },
                           resetDay: reset, planName: (info["plan"] as? [String: Any])?["name"] as? String,
                           fetchedAt: nil, source: .cache)
    }

    private static func nonnegativeInteger(_ value: Any?) -> Int64? {
        guard let value else { return nil }
        let text: String
        if let string = value as? String { text = string }
        else if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            text = number.stringValue
        } else { return nil }
        guard let result = Int64(text), result >= 0 else { return nil }
        return result
    }

    // MARK: - Clash Verge (Rev)

    private static func verge() -> [SubTarget] {
        let candidates = [
            "~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/profiles.yaml",
            "~/Library/Application Support/clash-verge/profiles.yaml",
        ]
        var targets: [SubTarget] = []
        for c in candidates {
            let path = (c as NSString).expandingTildeInPath
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            targets += regexMatches(#"url:\s*["']?(https?://[^\s"']+)"#, in: text).compactMap { m in
                guard m.count > 1 else { return nil }
                let url = m[1]
                return SubTarget(id: url, name: host(url), origin: "verge", url: url, cached: nil)
            }
        }
        return targets
    }

    // MARK: - ClashX / ClashX Meta

    private static func clashX() -> [SubTarget] {
        let domains = ["com.metacubex.ClashX.meta", "com.west2online.ClashX", "com.west2online.ClashXPro"]
        var targets: [SubTarget] = []
        for domain in domains {
            guard let d = UserDefaults(suiteName: domain),
                  let data = d.data(forKey: "kRemoteConfigs") else { continue }
            var arr: [[String: Any]] = []
            if let o = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                arr = o
            } else if let o = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]] {
                arr = o
            }
            let origin = domain.contains("metacubex") ? "clashx" : "clashx"
            targets += arr.compactMap { e in
                guard let url = e["url"] as? String, url.hasPrefix("http") else { return nil }
                let name = (e["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                return SubTarget(id: url, name: name ?? host(url), origin: origin, url: url, cached: nil)
            }
        }
        return targets
    }

    // MARK: - 手动添加

    private static let customKey = "customTargets"

    static func custom(defaults: UserDefaults = .standard) -> [SubTarget] {
        guard let arr = defaults.array(forKey: customKey) as? [[String: String]] else { return [] }
        return arr.compactMap { d in
            guard let url = d["url"], url.hasPrefix("http") else { return nil }
            return SubTarget(id: url, name: d["name"] ?? host(url), origin: "custom", url: url, cached: nil)
        }
    }

    static func addCustom(url: String, defaults: UserDefaults = .standard) {
        guard validatedURL(url) != nil else { return }
        let ud = defaults
        var arr = (ud.array(forKey: customKey) as? [[String: String]]) ?? []
        guard !arr.contains(where: { $0["url"] == url }) else { return }
        arr.append(["url": url, "name": host(url)])
        ud.set(arr, forKey: customKey)
    }

    static func removeCustom(url: String, defaults: UserDefaults = .standard) {
        let ud = defaults
        var arr = (ud.array(forKey: customKey) as? [[String: String]]) ?? []
        arr.removeAll { $0["url"] == url }
        ud.set(arr, forKey: customKey)
    }

    // MARK: - 工具

    /// 用 token 参数做去重键：同一账号在不同客户端里签名参数不同但 token 相同
    static func dedupeKey(_ url: String) -> String {
        if let c = URLComponents(string: url),
           let token = c.queryItems?.first(where: { $0.name == "token" })?.value, !token.isEmpty {
            return "\(c.scheme ?? "")://\(c.host ?? ""):\(c.port ?? 443)\(c.path)|\(token)"
        }
        return url
    }

    private static func host(_ url: String) -> String {
        URLComponents(string: url)?.host ?? L10n.t("订阅")
    }

    static func validatedURL(_ text: String) -> URL? {
        guard let c = URLComponents(string: text), c.scheme?.lowercased() == "https",
              let host = c.host, !host.isEmpty, c.user == nil, c.password == nil,
              c.fragment == nil, !text.contains(where: { $0.isWhitespace }),
              let url = c.url else { return nil }
        return url
    }

    private static func i64(_ any: Any?) -> Int64 {
        (any as? NSNumber)?.int64Value ?? Int64(any as? String ?? "0") ?? 0
    }

    static func regexMatches(_ pattern: String, in text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).compactMap { i in
                i < m.numberOfRanges && m.range(at: i).location != NSNotFound ? ns.substring(with: m.range(at: i)) : nil
            }
        }
    }
}
