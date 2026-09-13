import Foundation
import SwiftUI
import AppKit

struct QuotaSample: Equatable {
    enum Source: String {
        case cache = "客户端缓存"
        case live = "实时查询"

        var displayName: String { L10n.t(rawValue) }
    }

    var uploaded: Int64?
    var downloaded: Int64?
    var total: Int64
    var expireAt: Date?
    var resetDay: Int?
    var planName: String?
    /// nil means the client did not supply a trustworthy update time.
    var fetchedAt: Date?
    var source: Source
    /// SIP008 reports aggregate usage, never an upload/download breakdown.
    var aggregateUsed: Int64? = nil

    var used: Int64 {
        if let aggregateUsed { return aggregateUsed }
        guard let uploaded, let downloaded else { return 0 }
        let sum = uploaded.addingReportingOverflow(downloaded)
        return sum.overflow ? Int64.max : sum.partialValue
    }
    var remaining: Int64 { max(total - used, 0) }
    var usedRatio: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct SubTarget: Identifiable, Equatable {
    /// 稳定 ID：归一化后的订阅 URL
    let id: String
    let name: String
    /// 数据来自哪个客户端
    let origin: String
    let url: String
    /// 该客户端本地已缓存的样本（可能为空）
    let cached: QuotaSample?
}

/// 剩余流量预警等级：只用 主色（暗色主题下为白色）/ 橙 / 红 三档
enum WarningLevel {
    case normal, warn, danger

    static func level(remainingRatio r: Double) -> WarningLevel {
        if r < 0.10 { return .danger }
        if r < 0.2 { return .warn }
        return .normal
    }

    /// normal 用语义主色：暗色主题下呈现白色，浅色主题下自动变为深色，两种主题都可读
    var color: Color {
        switch self {
        case .normal: return .primary
        case .warn:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? .systemOrange : NSColor(srgbRed: 0.62, green: 0.31, blue: 0, alpha: 1)
            })
        case .danger:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? .systemRed : NSColor(srgbRed: 0.78, green: 0.12, blue: 0.14, alpha: 1)
            })
        }
    }
}
