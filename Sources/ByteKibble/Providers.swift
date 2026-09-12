import Foundation

/// 从各个客户端扫描可用订阅：
/// - 守候网络（SNTP）官方客户端：plist 缓存，信息最全（含重置日、套餐名）
/// - Clash Verge (Rev)：profiles.yaml 里的订阅 URL
/// - ClashX / ClashX Meta：defaults 里的 kRemoteConfigs（JSON 数组）
/// - 手动添加：用户粘贴的任意机场订阅链接
enum Providers {
    static func scanAll() -> [SubTarget] {
        let list = sntp() + verge() + clashX() + custom()
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
        let sample = QuotaSample(
            uploaded: i64(si["u"]),
            downloaded: i64(si["d"]),
            total: i64(si["transfer_enable"]),
            expireAt: Date(timeIntervalSince1970: Double(i64(si["expired_at"]))),
            resetDay: si["reset_day"] as? Int,
            planName: plan,
            fetchedAt: Date(),
            source: .cache
        )
        return [SubTarget(id: url, name: plan ?? "守候网络", origin: "sntp", url: url, cached: sample)]
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
                guard let url = m.first else { return nil }
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

    private static func custom() -> [SubTarget] {
        guard let arr = UserDefaults.standard.array(forKey: customKey) as? [[String: String]] else { return [] }
        return arr.compactMap { d in
            guard let url = d["url"], url.hasPrefix("http") else { return nil }
            return SubTarget(id: url, name: d["name"] ?? host(url), origin: "custom", url: url, cached: nil)
        }
    }

    static func addCustom(url: String) {
        guard url.hasPrefix("http") else { return }
        let ud = UserDefaults.standard
        var arr = (ud.array(forKey: customKey) as? [[String: String]]) ?? []
        guard !arr.contains(where: { $0["url"] == url }) else { return }
        arr.append(["url": url, "name": host(url)])
        ud.set(arr, forKey: customKey)
    }

    static func removeCustom(url: String) {
        let ud = UserDefaults.standard
        var arr = (ud.array(forKey: customKey) as? [[String: String]]) ?? []
        arr.removeAll { $0["url"] == url }
        ud.set(arr, forKey: customKey)
    }

    // MARK: - 工具

    /// 用 token 参数做去重键：同一账号在不同客户端里签名参数不同但 token 相同
    private static func dedupeKey(_ url: String) -> String {
        if let c = URLComponents(string: url),
           let token = c.queryItems?.first(where: { $0.name == "token" })?.value, !token.isEmpty {
            return token
        }
        return url
    }

    private static func host(_ url: String) -> String {
        URLComponents(string: url)?.host ?? url
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
