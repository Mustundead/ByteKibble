import Foundation
import Combine
import SwiftUI

@MainActor
final class ViewModel: ObservableObject {
    /// 预览渲染模式：不扫描真实数据、不触发刷新
    var isPreview = false
    @Published var targets: [SubTarget] = []
    /// 各订阅最新样本（实时查询结果会覆盖缓存）
    @Published var samples: [String: QuotaSample] = [:]
    @Published var selectedID: String {
        didSet { UserDefaults.standard.set(selectedID, forKey: "selectedTargetID") }
    }
    @Published var fetching = false
    @Published var statusLine: String?
    @Published var now = Date()

    private var timer: AnyCancellable?
    private var tickCount = 0
    private var lastLiveFetch: Date?
    private var lastFetchFailed = false
    /// 定时器 30 秒一跳：每 2 跳（1 分钟）重试失败的拉取，每 30 跳（15 分钟）定时实时刷新，每 60 跳（30 分钟）重扫本地客户端
    private let retryEvery = 2
    private let liveEvery = 30
    private let rescanEvery = 60
    private var activity: NSObjectProtocol?

    init(preview: Bool = false) {
        isPreview = preview
        selectedID = UserDefaults.standard.string(forKey: "selectedTargetID") ?? ""
        rescan()
        if !preview {
            // 菜单栏应用无可见窗口时会被 macOS App Nap 休眠，定时器停摆导致数据不及时，这里显式保持活跃
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiatedAllowingIdleSystemSleep],
                reason: "ByteKibble 定时刷新流量数据")
            Task { await refreshLive() }
            timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
                .sink { [weak self] t in
                    guard let self else { return }
                    self.now = t
                    self.tickCount += 1
                    if self.tickCount % self.rescanEvery == 0 { self.rescan() }
                    let scheduled = self.tickCount % self.liveEvery == 0
                    let retry = self.lastFetchFailed && self.tickCount % self.retryEvery == 0
                    if scheduled || retry { Task { await self.refreshLive() } }
                }
        }
    }

    deinit {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
    }

    var selected: SubTarget? {
        targets.first { $0.id == selectedID } ?? targets.first
    }

    func sample(for t: SubTarget) -> QuotaSample? {
        let a = t.cached
        let b = samples[t.id]
        switch (a, b) {
        case (nil, nil): return nil
        case (nil, .some(let x)): return x
        case (.some(let x), nil): return x
        case (.some(let x), .some(let y)): return x.fetchedAt <= y.fetchedAt ? y : x
        }
    }

    /// 菜单栏：剩余流量数值
    var menubarValueText: String {
        guard let t = selected, let s = sample(for: t) else { return L10n.noSubscription }
        return Fmt.bytes(s.remaining)
    }

    /// 菜单栏：饼状进度环的已用比例
    var menubarUsedRatio: Double {
        guard let t = selected, let s = sample(for: t), s.total > 0 else { return 0 }
        return Double(s.used) / Double(s.total)
    }

    /// 菜单栏：重置倒计时（无重置数据的订阅源返回 nil，标签里零宽隐藏）
    var menubarDaysText: String? {
        guard let t = selected, let s = sample(for: t), let rd = s.resetDay else { return nil }
        return countdownText(days: rd, now: now)
    }

    /// 倒计时显示规则：天 > 小时 > 分钟。
    /// reset_day 是「距重置的天数」（按日历日差），重置时刻按重置日的零点计算；
    /// 剩余超过 24h 用向上取整的天数（与官方客户端口径一致），不足 1 天显示小时，不足 1 小时显示分钟。
    /// 重置磁贴副标题：整句本地化（天/小时/分钟各自整句，不做跨语言拼接）
    func resetSubText(days: Int, now: Date) -> String {
        let target = Calendar.current.startOfDay(for: now).addingTimeInterval(TimeInterval(days) * 86400)
        let d = target.timeIntervalSince(now)
        if d <= 0 { return L10n.resetToday }
        if d > 86400 { return L10n.inDays(Int(ceil(d / 86400))) }
        if d > 3600 { return L10n.inHours(Int(d / 3600)) }
        return L10n.inMinutes(max(1, Int(d / 60)))
    }

    func countdownText(days: Int, now: Date) -> String {
        let target = Calendar.current.startOfDay(for: now).addingTimeInterval(TimeInterval(days) * 86400)
        let d = target.timeIntervalSince(now)
        if d <= 0 { return "今天" }
        if d > 86400 { return "\(Int(ceil(d / 86400)))天" }
        if d > 3600 { return "\(Int(d / 3600))小时" }
        return "\(max(1, Int(d / 60)))分钟"
    }

    /// 菜单栏/面板预警等级
    var warningLevel: WarningLevel {
        guard let t = selected, let s = sample(for: t), s.total > 0 else { return .normal }
        return WarningLevel.level(remainingRatio: Double(s.remaining) / Double(s.total))
    }

    func menuOpened() {
        guard !isPreview else { return }
        rescan()
        Task { await refreshLive() }
    }

    func rescan() {
        guard !isPreview else { return }
        targets = Providers.scanAll()
        if !targets.contains(where: { $0.id == selectedID }) {
            selectedID = targets.first(where: { $0.cached != nil })?.id ?? targets.first?.id ?? ""
        }
    }

    func refreshLive() async {
        guard !fetching, let t = selected else { return }
        fetching = true
        statusLine = nil
        defer { fetching = false }
        do {
            var s = try await Fetcher.fetch(url: t.url)
            // 实时头里没有的字段（套餐名、重置日）用客户端缓存补齐
            if let c = t.cached {
                if s.planName == nil { s.planName = c.planName }
                if s.resetDay == nil { s.resetDay = c.resetDay }
            }
            samples[t.id] = s
            lastLiveFetch = Date()
            lastFetchFailed = false
        } catch {
            lastFetchFailed = true
            statusLine = "实时查询失败，当前显示缓存数据"
        }
    }

    func addCustom(url: String) {
        Providers.addCustom(url: url.trimmingCharacters(in: .whitespacesAndNewlines))
        rescan()
        if let t = targets.last(where: { $0.origin == "手动添加" }) {
            selectedID = t.id
        }
        Task { await refreshLive() }
    }

    func removeCustom(id: String) {
        Providers.removeCustom(url: id)
        if selectedID == id { selectedID = "" }
        rescan()
    }
}
