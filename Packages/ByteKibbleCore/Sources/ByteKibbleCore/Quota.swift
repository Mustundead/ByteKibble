import Foundation

public enum QuotaError: Error, Equatable {
    case invalidLink, invalidResponse, tooLarge, unsafeRedirect, http(Int), connection, storage, keychain(Int32)
}

public struct QuotaReading: Codable, Equatable, Sendable {
    public let upload: Int64?
    public let download: Int64?
    public let total: Int64?
    public let used: Int64?
    public let expires: Date?
    public let observed: Date
    public var remaining: Int64? {
        guard let total, let used else { return nil }
        return max(0, total - used)
    }
    public var remainingRatio: Double? {
        guard let remaining, let total, total > 0 else { return nil }
        return Double(remaining) / Double(total)
    }
    public init(upload: Int64?, download: Int64?, total: Int64?, used: Int64?, expires: Date?, observed: Date = .now) {
        self.upload = upload; self.download = download; self.total = total
        self.used = used; self.expires = expires; self.observed = observed
    }
}

public enum QuotaWarning: Equatable {
    case normal, low, critical, unknown
    public init(remainingRatio: Double?) {
        guard let ratio = remainingRatio, ratio.isFinite else { self = .unknown; return }
        self = ratio < 0.1 ? .critical : ratio < 0.2 ? .low : .normal
    }
}

public enum ReminderPolicy {
    public static func shouldWarn(reading: QuotaReading?, lastAlert: Date?, now: Date) -> Bool {
        guard let reading, let ratio = reading.remainingRatio, ratio < 0.1,
              reading.observed <= now, now.timeIntervalSince(reading.observed) < 3600 else { return false }
        return lastAlert.map { now.timeIntervalSince($0) >= 86400 } ?? true
    }
    public static func deadline(_ date: Date?, now: Date, calendar: Calendar = .current) -> Date? {
        guard let date, let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date), morning > now else { return nil }
        return morning
    }
}

public enum QuotaParser {
    public static let maximumBodyBytes = 2 * 1024 * 1024
    public static func parse(header: String?, body: Data, now: Date = .now) throws -> QuotaReading {
        if let header {
            var values: [String: Int64] = [:]
            for field in header.split(separator: ";") {
                let pair = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = pair[0].trimmingCharacters(in: .whitespaces).lowercased()
                guard ["upload", "download", "total", "expire"].contains(key) else { continue }
                guard pair.count == 2, values[key] == nil,
                      let number = Int64(pair[1].trimmingCharacters(in: .whitespaces)), number >= 0 else {
                    throw QuotaError.invalidResponse
                }
                values[key] = number
            }
            guard !values.isEmpty else { throw QuotaError.invalidResponse }
            var used: Int64?
            if let upload = values["upload"], let download = values["download"] {
                let sum = upload.addingReportingOverflow(download)
                guard !sum.overflow else { throw QuotaError.invalidResponse }
                used = sum.partialValue
            }
            let expiration = values["expire"].flatMap { $0 > 0 ? Date(timeIntervalSince1970: Double($0)) : nil }
            return .init(upload: values["upload"], download: values["download"],
                         total: values["total"].flatMap { $0 > 0 ? $0 : nil }, used: used, expires: expiration, observed: now)
        }
        guard body.count <= maximumBodyBytes else { throw QuotaError.tooLarge }
        struct SIP008: Decodable {
            let version: Int
            let servers: [Server]
            let bytes_used: Int64
            let bytes_remaining: Int64
            struct Server: Decodable { let id: String }
        }
        guard let object = try? JSONDecoder().decode(SIP008.self, from: body), object.version == 1,
              object.bytes_used >= 0, object.bytes_remaining >= 0 else { throw QuotaError.invalidResponse }
        let sum = object.bytes_used.addingReportingOverflow(object.bytes_remaining)
        guard !sum.overflow, sum.partialValue > 0 else { throw QuotaError.invalidResponse }
        return .init(upload: nil, download: nil, total: sum.partialValue, used: object.bytes_used, expires: nil, observed: now)
    }
}

public enum SubscriptionLink {
    public static func https(_ text: String) -> URL? {
        guard !text.contains(where: { $0.isWhitespace }), let c = URLComponents(string: text),
              c.scheme?.lowercased() == "https", let host = c.host, !host.isEmpty,
              c.user == nil, c.password == nil, c.fragment == nil else { return nil }
        return c.url
    }
    public static func parse(_ input: String) throws -> URL {
        guard input.utf8.count <= 16_384 else { throw QuotaError.invalidLink }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains("\n"), !text.contains("\r") else { throw QuotaError.invalidLink }
        if text.hasPrefix("#!MANAGED-CONFIG "), let part = text.split(whereSeparator: { $0.isWhitespace }).dropFirst().first,
           let url = https(String(part)) { return url }
        guard let c = URLComponents(string: text), c.user == nil, c.password == nil else { throw QuotaError.invalidLink }
        if c.host?.lowercased() == "link.stash.ws", c.scheme?.lowercased() == "https" {
            let prefix = "/install-config/"
            guard c.percentEncodedPath.hasPrefix(prefix), c.query == nil, c.fragment == nil, c.port == nil,
                  let decoded = String(c.percentEncodedPath.dropFirst(prefix.count)).removingPercentEncoding,
                  let url = https(decoded) else { throw QuotaError.invalidLink }
            return url
        }
        if let url = https(text) { return url }
        let scheme = c.scheme?.lowercased() ?? ""
        guard ["stash", "clash", "surge", "surgeconfig", "hiddify", "sing-box", "loon"].contains(scheme), c.port == nil else {
            throw QuotaError.invalidLink
        }
        let action = c.host?.isEmpty == false ? c.host! : String(c.path.dropFirst())
        if scheme == "hiddify", action == "import" {
            let payload = String(c.percentEncodedPath.dropFirst()) + (c.percentEncodedQuery.map { "?" + $0 } ?? "")
            if let url = https(payload) { return url }
            guard let decoded = payload.removingPercentEncoding, let url = https(decoded) else { throw QuotaError.invalidLink }
            return url
        }
        let expected = scheme == "loon" ? "import" : scheme == "sing-box" ? "import-remote-profile" : "install-config"
        guard action == expected, c.host?.isEmpty != false || c.path.isEmpty || c.path == "/" else { throw QuotaError.invalidLink }
        let candidates = (c.queryItems ?? []).filter { scheme == "loon" ? ["sub", "nodelist"].contains($0.name) : $0.name == "url" }
        guard candidates.count == 1, let text = candidates[0].value, let url = https(text) else { throw QuotaError.invalidLink }
        return url
    }
    public static func allowsRedirect(from: URL, to: URL) -> Bool {
        https(to.absoluteString) != nil && from.scheme?.lowercased() == "https" &&
        from.host?.lowercased() == to.host?.lowercased() && (from.port ?? 443) == (to.port ?? 443)
    }
}
