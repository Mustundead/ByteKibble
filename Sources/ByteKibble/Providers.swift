import Foundation

/// 从各个客户端扫描可用订阅：
/// - 守候网络（SNTP）官方客户端：plist 缓存，信息最全（含重置日、套餐名）
/// - Clash Verge (Rev)：profiles.yaml 里的订阅 URL
/// - ClashX / ClashX Meta：defaults 里的 kRemoteConfigs（JSON 数组）
/// - 手动添加：用户粘贴的任意机场订阅链接
enum Providers {
    static func scanAll(defaults: UserDefaults = .standard, store: CredentialStore = productionCredentialStore, onStorageFailure: (() -> Void)? = nil) -> [SubTarget] {
        let list = sntp() + verge() + clashX() + custom(defaults: defaults, store: store, onStorageFailure: onStorageFailure)
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

    static func custom(defaults: UserDefaults = .standard, store: CredentialStore = productionCredentialStore, onStorageFailure: (() -> Void)? = nil) -> [SubTarget] {
        let migrated = migrateLegacy(defaults: defaults, store: store)
        if !migrated { onStorageFailure?() }
        guard let arr = defaults.array(forKey: customKey) as? [[String: String]] else { return [] }
        var missing = false
        let result = arr.compactMap { d -> SubTarget? in
            if let url = d["url"], validatedURL(url) != nil {
                return SubTarget(id: url, name: d["name"] ?? host(url), origin: "custom", url: url, cached: nil)
            }
            guard let id = d["id"] else { return nil }
            guard let url = store.read(for: id), validatedURL(url) != nil else { missing = true; return nil }
            return SubTarget(id: id, name: d["name"] ?? host(url), origin: "custom", url: url, cached: nil)
        }
        if missing { onStorageFailure?() }
        return result
    }

    @discardableResult static func addCustom(url: String, defaults: UserDefaults = .standard, store: CredentialStore = productionCredentialStore) -> Bool {
        guard validatedURL(url) != nil else { return false }
        guard migrateLegacy(defaults: defaults, store: store) else { return false }
        let ud = defaults
        var arr = (ud.array(forKey: customKey) as? [[String: String]]) ?? []
        let id = "subscription." + secureIdentifier(url)
        guard store.write(url, for: id) else { return false }
        guard !arr.contains(where: { $0["id"] == id }) else { return true }
        arr.append(["id": id, "name": host(url)])
        ud.set(arr, forKey: customKey)
        return true
    }

    @discardableResult static func removeCustom(url: String, defaults: UserDefaults = .standard, store: CredentialStore = productionCredentialStore) -> Bool {
        let ud = defaults
        var arr = (ud.array(forKey: customKey) as? [[String: String]]) ?? []
        let id = "subscription." + secureIdentifier(url)
        guard store.remove(for: id) else { return false }
        arr.removeAll { $0["id"] == id || $0["url"] == url }
        ud.set(arr, forKey: customKey)
        return true
    }

    @discardableResult private static func migrateLegacy(defaults: UserDefaults, store: CredentialStore) -> Bool {
        guard let old = defaults.array(forKey: customKey) as? [[String: String]], old.contains(where: { $0["url"] != nil }) else { return true }
        var migrated: [[String: String]] = []
        for item in old {
            if item["url"] == nil, let id = item["id"] { migrated.append(["id": id, "name": item["name"] ?? L10n.t("订阅")]); continue }
            guard let url = item["url"] else { return false }
            let id = "subscription." + secureIdentifier(url)
            if let existing = store.read(for: id), existing != url { return false }
            guard store.write(url, for: id) else { return false }
            migrated.append(["id": id, "name": item["name"] ?? host(url)])
        }
        defaults.set(migrated, forKey: customKey)
        return true
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

    /// Extract a subscription address only. Never open client actions or execute configuration.
    static func subscriptionURL(from input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: { $0.isNewline }) else { return nil }
        if let c = URLComponents(string: text), let scheme = c.scheme?.lowercased() {
            // Stash universal links are commands, not quota endpoints. Reject all
            // unsupported commands rather than querying the wrapper service.
            if scheme == "https", c.host?.lowercased() == "link.stash.ws" {
                let prefix = "/install-config/"
                guard c.user == nil, c.password == nil, c.port == nil,
                      c.fragment == nil, c.query == nil,
                      c.percentEncodedPath.hasPrefix(prefix) else { return nil }
                let target = "https://" + c.percentEncodedPath.dropFirst(prefix.count)
                return validatedURL(target) == nil ? nil : target
            }
            if ["stash", "clash", "surge", "surgeconfig", "hiddify", "sing-box", "loon"].contains(scheme) {
                guard c.user == nil, c.password == nil, c.port == nil,
                      !text.contains(where: { $0.isWhitespace }) else { return nil }
                if scheme == "hiddify", c.host == "import" {
                    // The fragment is Hiddify's display name, not part of the URL.
                    let target = String(c.percentEncodedPath.dropFirst())
                        + (c.percentEncodedQuery.map { "?" + $0 } ?? "")
                    return validatedURL(target) == nil ? nil : target
                }
                let action = (c.host?.isEmpty == false) ? c.host! : String(c.path.dropFirst())
                if scheme == "loon" {
                    guard action == "import", c.path.isEmpty,
                          let items = c.queryItems, items.count == 1,
                          ["sub", "nodelist"].contains(items[0].name),
                          let target = items[0].value, validatedURL(target) != nil else { return nil }
                    return target
                }
                let expectedAction = scheme == "sing-box" ? "import-remote-profile" : "install-config"
                guard (c.host?.isEmpty != false || c.path.isEmpty || c.path == "/"),
                      action == expectedAction || (scheme == "hiddify" && action == "install-sub"),
                      let items = c.queryItems,
                      items.filter({ $0.name == "url" }).count == 1,
                      let target = items.first(where: { $0.name == "url" })?.value,
                      validatedURL(target) != nil else { return nil }
                return target
            }
        }
        if validatedURL(text) != nil { return text }
        let parts = text.split(whereSeparator: { $0.isWhitespace })
        guard parts.count >= 2, parts[0] == "#!MANAGED-CONFIG" else { return nil }
        let url = String(parts[1])
        return validatedURL(url) == nil ? nil : url
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
