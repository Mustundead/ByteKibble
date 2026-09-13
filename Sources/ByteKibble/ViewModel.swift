import Foundation
import Combine
import SwiftUI

@MainActor
final class ViewModel: ObservableObject {
    var isPreview: Bool
    @Published var targets: [SubTarget] = []
    @Published var samples: [String: QuotaSample] = [:]
    @Published var selectedID: String {
        didSet {
            guard !isPreview, oldValue != selectedID else { return }
            defaults.set(selectedID.isEmpty ? "" : Providers.persistenceID(selectedID), forKey: "selectedTargetID")
            if automaticRefresh { Task { await refreshLive() } }
        }
    }
    @Published private(set) var loading: Set<String> = []
    @Published private(set) var failures: [String: String] = [:]
    @Published var now = Date()
    @Published private(set) var removedTarget: SubTarget?
    @Published private(set) var notice: String?
    @Published private var storageFailure: String?
    private var timer: AnyCancellable?
    private var tickCount = 0
    private var requestIDs: [String: UUID] = [:]
    private var requests: [String: Task<QuotaSample, Error>] = [:]
    private var retryCounts: [String: Int] = [:]
    private var nextAutomaticRefresh: [String: Date] = [:]
    private let defaults: UserDefaults
    private let scan: (() -> [SubTarget])?
    private let credentialStore: CredentialStore
    private let fetch: (String) async throws -> QuotaSample
    private let automaticRefresh: Bool
    @Published private var manualResetDates: [String: Double] = [:]
    private var removedResetDate: Date?
    private static let resetDatesKey = "manualResetDates"

    init(preview: Bool = false, defaults: UserDefaults = .standard,
         scan: (() -> [SubTarget])? = nil,
         credentialStore: CredentialStore = Providers.productionCredentialStore,
         automaticRefresh: Bool = true,
         fetch: @escaping (String) async throws -> QuotaSample = Fetcher.fetch) {
        self.isPreview = preview
        self.defaults = defaults
        self.scan = scan
        self.credentialStore = credentialStore
        self.fetch = fetch
        self.automaticRefresh = automaticRefresh
        manualResetDates = defaults.dictionary(forKey: Self.resetDatesKey) as? [String: Double] ?? [:]
        selectedID = preview ? "" : defaults.string(forKey: "selectedTargetID") ?? ""
        guard !preview else { return }
        manualResetDates = Dictionary(manualResetDates.map { (Providers.persistenceID($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
        defaults.set(manualResetDates, forKey: Self.resetDatesKey)
        if !selectedID.isEmpty {
            selectedID = Providers.persistenceID(selectedID)
            defaults.set(selectedID, forKey: "selectedTargetID")
        }
        rescan()
        guard automaticRefresh else { return }
        Task { await refreshLive() }
        timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                self.now = date
                self.tickCount += 1
                if self.tickCount % 60 == 0 { self.rescan() }
                if self.tickCount % 30 == 0 || (self.statusLine != nil && self.tickCount % 2 == 0) {
                    Task { await self.refreshLive(automatic: true) }
                }
            }
    }

    var selected: SubTarget? { targets.first { $0.id == selectedID } ?? targets.first }
    var fetching: Bool { selected.map { loading.contains($0.id) } ?? false }
    var statusLine: String? { storageFailure ?? selected.flatMap { failures[$0.id] } }

    func sample(for target: SubTarget) -> QuotaSample? {
        // Reading a cache again does not make it a newer measurement.
        samples[target.id] ?? target.cached
    }

    var menubarValueText: String {
        guard let t = selected else { return L10n.noSubscription }
        guard let s = sample(for: t) else { return L10n.t("待查询") }
        return Fmt.bytes(s.remaining)
    }
    var menubarUsedRatio: Double {
        guard let t = selected, let s = sample(for: t) else { return 0 }
        return s.usedRatio
    }
    // Client-reported reset days; display follows the original midnight convention.
    var menubarDaysText: String? {
        if manualResetDate != nil { return resetCountdown.map { "\($0)*" } }
        guard let target = selected, let sample = sample(for: target), let days = sample.resetDay else { return nil }
        return countdownText(days: days, now: now)
    }

    var manualResetDate: Date? {
        guard let target = selected,
              let timestamp = manualResetDates[Providers.persistenceID(Providers.dedupeKey(target.url))],
              timestamp.isFinite, timestamp > 0,
              timestamp < Date.distantFuture.timeIntervalSince1970 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    var resetCountdown: String? {
        if let date = manualResetDate {
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                              to: calendar.startOfDay(for: date)).day ?? 0
            if days < 0 { return L10n.t("日期已过") }
            if days == 0 { return L10n.today }
            return countdownText(days: days, now: now)
        }
        return selected.flatMap { sample(for: $0)?.resetDay }.map { countdownText(days: $0, now: now) }
    }

    /// Local, explicit override only. Never changes quota samples or provider configuration.
    func setManualResetDate(_ date: Date?) {
        guard !isPreview, let target = selected else { return }
        let key = Providers.persistenceID(Providers.dedupeKey(target.url))
        if let date {
            guard date.timeIntervalSince1970.isFinite,
                  date < Date.distantFuture,
                  Calendar.current.startOfDay(for: date) >= Calendar.current.startOfDay(for: now) else { return }
            manualResetDates[key] = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        } else { manualResetDates.removeValue(forKey: key) }
        defaults.set(manualResetDates, forKey: Self.resetDatesKey)
    }

    // Restored at the user's request: original client-day countdown presentation.
    func countdownText(days: Int, now: Date) -> String {
        let target = Calendar.current.startOfDay(for: now).addingTimeInterval(TimeInterval(days) * 86400)
        let remaining = target.timeIntervalSince(now)
        if remaining <= 0 { return L10n.today }
        if remaining > 86400 { return L10n.cdDays(Int(ceil(remaining / 86400))) }
        if remaining > 3600 { return L10n.cdHours(Int(remaining / 3600)) }
        return L10n.cdMinutes(max(1, Int(remaining / 60)))
    }
    var warningLevel: WarningLevel {
        guard let t = selected, let s = sample(for: t), s.total > 0 else { return .normal }
        return WarningLevel.level(remainingRatio: Double(s.remaining) / Double(s.total))
    }
    var accessibilitySummary: String {
        guard let t = selected, let s = sample(for: t) else { return menubarValueText }
        return "\(t.name), \(L10n.remainingTraffic) \(Fmt.bytes(s.remaining)), \(freshness(s))"
            + (manualResetDate != nil ? ", \(L10n.t("手动设置")), \(resetCountdown ?? "")" : "")
    }
    func freshness(_ sample: QuotaSample) -> String {
        guard let date = sample.fetchedAt else { return L10n.t("客户端缓存 · 更新时间未知") }
        if abs(now.timeIntervalSince(date)) < 60 { return L10n.t("刚刚更新") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = L10n.locale
        formatter.unitsStyle = .full
        return L10n.f("更新于 %@", formatter.localizedString(for: date, relativeTo: now))
    }
    func menuOpened() {
        guard !isPreview else { return }
        now = Date()
        rescan()
        Task { await refreshLive(automatic: true) }
    }
    func rescan() {
        guard !isPreview else { return }
        var storageFailed = false
        let discovered = scan?() ?? Providers.scanAll(defaults: defaults, store: credentialStore, onStorageFailure: { storageFailed = true })
        targets = discovered
        if storageFailed {
            storageFailure = L10n.t("无法访问钥匙串。原有订阅记录已保留，请解锁钥匙串后重试。")
        } else { storageFailure = nil }
        for id in Array(requests.keys) where !targets.contains(where: { $0.id == id }) {
            requests.removeValue(forKey: id)?.cancel()
            requestIDs[id] = nil
            loading.remove(id)
        }
        if let restored = targets.first(where: { Providers.persistenceID($0.id) == selectedID || Providers.persistenceID($0.url) == selectedID }) {
            selectedID = restored.id
        } else if !storageFailed, !targets.contains(where: { $0.id == selectedID }) {
            selectedID = targets.first?.id ?? ""
        }
    }
    func refreshLive(automatic: Bool = false) async {
        guard let t = selected, !loading.contains(t.id) else { return }
        if automatic, let next = nextAutomaticRefresh[t.id], Date() < next { return }
        let requestID = UUID()
        requestIDs[t.id] = requestID
        loading.insert(t.id)
        failures[t.id] = nil
        defer {
            if requestIDs[t.id] == requestID {
                loading.remove(t.id)
                requests[t.id] = nil
                requestIDs[t.id] = nil
            }
        }
        let operation = Task { try await fetch(t.url) }
        requests[t.id] = operation
        do {
            var sample = try await withTaskCancellationHandler {
                try await operation.value
            } onCancel: { operation.cancel() }
            try Task.checkCancellation()
            guard !operation.isCancelled else { return }
            guard requestIDs[t.id] == requestID, targets.contains(where: { $0.id == t.id }) else { return }
            sample.planName = sample.planName ?? t.cached?.planName
            sample.resetDay = sample.resetDay ?? t.cached?.resetDay
            samples[t.id] = sample
            now = Date()
            retryCounts[t.id] = nil
            nextAutomaticRefresh[t.id] = now.addingTimeInterval(60)
        } catch {
            if error is CancellationError || operation.isCancelled || Task.isCancelled { return }
            guard requestIDs[t.id] == requestID, targets.contains(where: { $0.id == t.id }) else { return }
            failures[t.id] = (error as? Fetcher.Failure)?.message ?? L10n.t("无法连接。请检查网络和代理客户端后重试。")
            let count = min((retryCounts[t.id] ?? 0) + 1, 5)
            retryCounts[t.id] = count
            let delay = (error as? Fetcher.Failure)?.retryable == true ? min(900, 60 * pow(2, Double(count - 1))) : 900
            nextAutomaticRefresh[t.id] = Date().addingTimeInterval(delay)
        }
    }
    @discardableResult
    func addCustom(url: String) -> Bool {
        guard !isPreview else { return false }
        guard let text = Providers.subscriptionURL(from: url) else { return false }
        if let existing = targets.first(where: { Providers.dedupeKey($0.url) == Providers.dedupeKey(text) }) {
            selectedID = existing.id
            notice = L10n.t("已选择已有订阅。")
            if automaticRefresh { Task { await refreshLive() } }
            return true
        }
        notice = nil
        guard Providers.addCustom(url: text, defaults: defaults, store: credentialStore) else {
            storageFailure = L10n.t("未能安全保存订阅。请解锁钥匙串后重试。")
            return false
        }
        rescan()
        selectedID = targets.first(where: { $0.url == text })?.id ?? selectedID
        if automaticRefresh { Task { await refreshLive() } }
        return true
    }
    func removeCustom(id: String) {
        guard !isPreview else { return }
        guard let target = targets.first(where: { $0.id == id && $0.origin == "custom" }) else { return }
        guard Providers.removeCustom(url: target.url, defaults: defaults, store: credentialStore) else {
            storageFailure = L10n.t("未能移除订阅。记录已保留，请解锁钥匙串后重试。")
            return
        }
        removedTarget = target
        let resetKey = Providers.persistenceID(Providers.dedupeKey(target.url))
        removedResetDate = manualResetDates[resetKey].map(Date.init(timeIntervalSince1970:))
        manualResetDates.removeValue(forKey: resetKey)
        defaults.set(manualResetDates, forKey: Self.resetDatesKey)
        requestIDs[id] = nil
        requests.removeValue(forKey: id)?.cancel()
        retryCounts[id] = nil
        nextAutomaticRefresh[id] = nil
        loading.remove(id)
        failures[id] = nil
        notice = nil
        rescan()
    }
    func undoRemoval() {
        guard let target = removedTarget else { return }
        guard addCustom(url: target.url) else { return }
        removedTarget = nil
        if let date = removedResetDate {
            manualResetDates[Providers.persistenceID(Providers.dedupeKey(target.url))] = date.timeIntervalSince1970
            defaults.set(manualResetDates, forKey: Self.resetDatesKey)
        }
        removedResetDate = nil
    }
}
