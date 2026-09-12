import Foundation

/// 本地化：以简体中文文案为 key，缺表时自动回退 key 本身（即简体）
enum L10n {
    static func t(_ key: String) -> String {
        Bundle.module.localizedString(forKey: key, value: key, table: nil)
    }

    static func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    static var refresh: String { t("刷新") }
    static var launchAtLogin: String { t("开机启动") }
    static var quit: String { t("退出") }
    static var add: String { t("添加") }
    static var removeManualSub: String { t("删除当前手动订阅") }
    static var remainingTraffic: String { t("剩余流量") }
    static var addSubTitle: String { t("添加订阅") }
    static var addSubSubtitle: String { t("粘贴任意机场订阅链接，兼容 Clash 客户端") }
    static var resetTile: String { t("流量重置") }
    static var expireTile: String { t("套餐到期") }
    static var uploadTile: String { t("上行流量") }
    static var downloadTile: String { t("下行流量") }
    static var resetToday: String { t("今天重置") }
    static var emptyTitle: String { t("未找到订阅数据") }
    static var emptyBody: String { t("自动检测 Clash Verge / ClashX Meta / 守候网络 客户端，或在下方粘贴任意机场订阅链接。") }
    static var liveFailed: String { t("实时查询失败，当前显示缓存数据") }
    static var noSubscription: String { t("无订阅") }
    static var today: String { t("今天") }
    static var originSntp: String { t("守候网络客户端") }
    static var originCustom: String { t("手动添加") }

    static func used(_ v: String) -> String { f("已用 %@", v) }
    static func usedPercent(_ p: String) -> String { f("已用 %@", p) }
    static func total(_ v: String) -> String { f("总量 %@", v) }
    static func daysAfter(_ s: String) -> String { f("%@后", s) }
    static func inDays(_ n: Int) -> String { f("%@ 天后", "\(n)") }
    static func cdDays(_ n: Int) -> String { f("%@天", "\(n)") }
    static func cdHours(_ n: Int) -> String { f("%@小时", "\(n)") }
    static func cdMinutes(_ n: Int) -> String { f("%@分钟", "\(n)") }

    /// 中文界面倒计时后缀带「后」，其他语言直接用自带单位（4d / 4日 / 4일）
    static var appendsSuffix: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }
}
