import Foundation
import SwiftUI

struct QuotaSample: Equatable {
    enum Source: String {
        case cache = "客户端缓存"
        case live = "实时查询"
    }

    var uploaded: Int64
    var downloaded: Int64
    var total: Int64
    var expireAt: Date?
    var resetDay: Int?
    var planName: String?
    var fetchedAt: Date
    var source: Source

    var used: Int64 { uploaded + downloaded }
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
        if r < 0.07 { return .danger }
        if r < 0.2 { return .warn }
        return .normal
    }

    /// normal 用语义主色：暗色主题下呈现白色，浅色主题下自动变为深色，两种主题都可读
    var color: Color {
        switch self {
        case .normal: return .primary
        case .warn: return .orange
        case .danger: return .red
        }
    }
}
