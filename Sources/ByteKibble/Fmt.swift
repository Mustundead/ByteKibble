import Foundation

enum Fmt {
    static func bytes(_ b: Int64) -> String {
        let v = Double(max(b, 0))
        let kb = 1024.0, mb = 1_048_576.0, gb = 1_073_741_824.0, tb = 1_099_511_627_776.0
        switch v {
        case ..<mb: return String(format: "%.0f KB", v / kb)
        case ..<gb: return String(format: "%.0f MB", v / mb)
        case ..<tb: return String(format: "%.1f GB", v / gb)
        default: return String(format: "%.2f TB", v / tb)
        }
    }

    static func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = L10n.locale
        f.dateStyle = .medium
        return f.string(from: d)
    }

    static func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = L10n.locale
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: d)
    }

    /// reset_day 的语义是「距下次流量重置的天数」（与守候网络官方客户端显示一致），据此推算重置日期
    static func nextReset(days: Int, from now: Date = Date()) -> Date? {
        guard (0...40).contains(days) else { return nil }
        return Calendar.current.date(byAdding: .day, value: days, to: now)
    }

    static func daysUntil(_ d: Date, now: Date = Date()) -> Int {
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day],
                                         from: cal.startOfDay(for: now),
                                         to: cal.startOfDay(for: d)).day ?? 0)
    }

    static func percent(_ ratio: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = L10n.locale
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: max(0, ratio))) ?? "—"
    }

    static func relative(_ date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = L10n.locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func ago(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "刚刚" }
        if s < 3600 { return "\(s / 60)分钟前" }
        if s < 86400 { return "\(s / 3600)小时前" }
        return "\(s / 86400)天前"
    }
}
