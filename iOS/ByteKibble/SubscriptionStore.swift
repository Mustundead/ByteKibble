import Foundation
import Security
import SwiftUI
import UserNotifications
import BackgroundTasks

struct Subscription: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var reading: QuotaReading?
    var history: [QuotaReading] = []
    var reset: Date?
    var historyPaused: Bool? = nil
    var syncAccount: String? = nil
    var syncRecord: SyncRecord? = nil
}

enum Vault {
    static let service = "com.mulabs.bytekibble.ios.subscription"
    static func query(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: id.uuidString, kSecAttrSynchronizable as String: false]
    }
    static func save(_ url: URL, id: UUID) throws {
        var item = query(id)
        item[kSecValueData as String] = Data(url.absoluteString.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw QuotaError.keychain(status) }
        guard try read(id) == url else { try? remove(id); throw QuotaError.storage }
    }
    static func read(_ id: UUID) throws -> URL {
        var item = query(id)
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(item as CFDictionary, &value)
        guard status == errSecSuccess else { throw QuotaError.keychain(status) }
        guard let data = value as? Data, let text = String(data: data, encoding: .utf8),
              let url = SubscriptionLink.https(text) else { throw QuotaError.storage }
        return url
    }
    static func remove(_ id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw QuotaError.keychain(status) }
    }
}

@MainActor @Observable final class SubscriptionStore {
    private(set) var items: [Subscription] = []
    private(set) var loading: Set<UUID> = []
    private(set) var errors: [UUID: String] = [:]
    var storageError: String?
    let demo: Bool
    private var file: URL?
    private var loadFailed = false
    var recordsAvailable: Bool { !loadFailed && (demo || file != nil) }
    func retryProtectedLoad() {
        guard loadFailed, let file, UIApplication.shared.isProtectedDataAvailable else { return }
        do {
            items = try JSONDecoder().decode([Subscription].self, from: Data(contentsOf: file))
            loadFailed = false; storageError = nil
        } catch { }
    }
    init(demo: Bool = false, storageURL: URL? = nil) {
        self.demo = demo
        if demo {
            let reading = QuotaReading(upload: 0, download: 0, total: 100 * 1_073_741_824, used: 0,
                                       expires: Calendar.current.date(byAdding: .day, value: 180, to: .now))
            items = [.init(id: UUID(), name: String(localized: "演示订阅"), reading: reading, history: [reading])]
            return
        }
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true)
            file = storageURL ?? directory.appendingPathComponent("subscriptions-v1.json")
            if let file, FileManager.default.fileExists(atPath: file.path) {
                items = try JSONDecoder().decode([Subscription].self, from: Data(contentsOf: file))
            }
        } catch { loadFailed = true; storageError = String(localized: "无法读取本机记录。原文件已保留，请稍后重新打开。") }
    }
    private func persist(_ next: [Subscription]) throws {
        guard !loadFailed else { throw QuotaError.storage }
        if demo { items = next; return }
        guard let file else { throw QuotaError.storage }
        do {
            try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtection])
            items = next
        } catch { throw QuotaError.storage }
    }
    func add(name: String, text: String) throws -> UUID {
        guard !demo, recordsAvailable else { throw QuotaError.storage }
        let url = try SubscriptionLink.parse(text)
        // Exact credential comparison; never merge different tokens at one provider.
        for item in items where (try? Vault.read(item.id)) == url { return item.id }
        let id = UUID()
        try Vault.save(url, id: id)
        // Do not default to a hostname: URLs can contain credentials in any component.
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do { try persist(items + [.init(id: id, name: displayName.isEmpty ? String(localized: "我的订阅") : String(displayName.prefix(80)))]) }
        catch { try? Vault.remove(id); throw error }
        return id
    }
    func refresh(_ id: UUID) async {
        guard recordsAvailable, !loading.contains(id), items.contains(where: { $0.id == id }) else { return }
        if demo { return }
        loading.insert(id); errors[id] = nil
        defer { loading.remove(id) }
        do {
            let url = try Vault.read(id)
            let reading = try await QuotaClient().fetch(url)
            try Task.checkCancellation()
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            var next = items
            next[index].reading = reading
            next[index].history = HistoryRecords.appending(reading, to: next[index].history, enabled: next[index].historyPaused != true)
            try persist(next)
        } catch is CancellationError { }
        catch { if items.contains(where: { $0.id == id }) { errors[id] = Self.message(error) } }
    }
    func refreshAll(while allowed: @MainActor () -> Bool = { true }) async {
        // Serial requests avoid bursts and preserve independent results.
        for id in items.map(\.id) {
            if Task.isCancelled || !recordsAvailable || !allowed() { return }
            await refresh(id)
        }
    }
    func setReset(_ date: Date?, id: UUID) throws {
        var next = items
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        next[index].reset = date
        try persist(next)
    }
    func setHistoryRecording(_ enabled: Bool, id: UUID) throws {
        var next = items
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        next[index].historyPaused = !enabled
        try persist(next)
    }
    func clearHistory(id: UUID) throws {
        var next = items
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        next[index].history = []
        try persist(next)
    }
    func rename(_ name: String, id: UUID) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = items.firstIndex(where: { $0.id == id }) else { return }
        var next = items; next[index].name = String(name.prefix(80))
        try persist(next)
    }
    func move(from offsets: IndexSet, to destination: Int) {
        var next = items; next.move(fromOffsets: offsets, toOffset: destination)
        do { try persist(next) } catch { storageError = Self.message(error) }
    }
    func remove(_ id: UUID) throws {
        guard recordsAvailable else { throw QuotaError.storage }
        // Persist suppression before deletion. A failed deletion leaves the visible
        // item intact; a successful deletion cannot be undone by a later cloud fetch.
        if let item = items.first(where: { $0.id == id }), let scope = item.syncAccount {
            var ignored = try ignoredSyncRecords()
            ignored.insert(scope + "/" + id.uuidString)
            guard ignored.count <= 4096, let file else { throw QuotaError.storage }
            try JSONEncoder().encode(ignored).write(to: file.appendingPathExtension("ignored-sync"), options: [.atomic, .completeFileProtection])
        }
        // Keep metadata if Keychain deletion fails; users can retry the exact item.
        let originalURL = demo ? nil : try Vault.read(id)
        if !demo { try Vault.remove(id) }
        do { try persist(items.filter { $0.id != id }) }
        catch {
            if let originalURL { try Vault.save(originalURL, id: id) }
            throw error
        }
        errors[id] = nil
    }
    static func message(_ error: Error) -> String {
        switch error as? QuotaError {
        case .invalidLink: return String(localized: "请输入有效的 HTTPS 订阅链接，或受支持的客户端导入链接。")
        case .invalidResponse: return String(localized: "服务商未提供可识别的流量数据。已保留上次读数。")
        case .tooLarge: return String(localized: "订阅响应超过 2 MiB。请联系服务商提供流量响应头。")
        case .unsafeRedirect: return String(localized: "已阻止跨域或不安全的重定向。请使用服务商的最终 HTTPS 链接。")
        case .http(let status): return String(localized: "服务商返回 HTTP \(status)。已保留上次读数。")
        case .keychain: return String(localized: "无法访问本机钥匙串。请解锁设备后重试。")
        case .storage: return String(localized: "无法保存本机记录。请检查可用存储空间后重试。")
        default: return String(localized: "未能连接服务商。请检查网络后重试，仍显示上次读数。")
        }
    }

    func stageSyncChanges(in library: SyncLibrary) throws {
        guard !demo, recordsAvailable, let scope = library.accountScope else { return }
        for item in items where item.syncAccount == scope {
            guard let previous = item.syncRecord else { continue }
            var record = previous
            record.name = item.name; record.reading = item.reading; record.history = item.history
            record.reset = item.reset; record.historyPaused = item.historyPaused == true
            if record != previous || !library.rows.contains(where: { $0.id == item.id }) {
                if record != previous { record.revision = UUID() }
                try library.stage(record, url: Vault.read(item.id))
                var next = items
                if let index = next.firstIndex(where: { $0.id == item.id }) { next[index].syncRecord = record }
                try persist(next)
            }
        }
    }

    func share(_ id: UUID, with library: SyncLibrary) throws {
        guard !demo, recordsAvailable, let scope = library.accountScope,
              let index = items.firstIndex(where: { $0.id == id }) else { throw QuotaError.storage }
        let item = items[index]
        let record = SyncRecord(id: id, name: item.name, reset: item.reset,
                                historyPaused: item.historyPaused == true, reading: item.reading, history: item.history)
        var next = items; next[index].syncAccount = scope; next[index].syncRecord = record
        try persist(next)
        try library.stage(record, url: Vault.read(id))
    }

    func applySync(_ library: SyncLibrary) throws {
        guard !demo, recordsAvailable, let scope = library.accountScope else { return }
        let ignored = try ignoredSyncRecords()
        for row in library.rows where row.conflict == nil && !library.waiting.contains(row.id) {
            let record = row.record
            // Removing a local subscription does not authorize removal on other devices.
            // Cloud tombstones remain visible for an explicit conflict/deletion decision.
            guard !record.deleted else { continue }
            let url = try library.credential(for: record)
            var next = items
            if let index = next.firstIndex(where: { $0.id == row.id }) {
                guard next[index].syncAccount == scope else { continue }
                if let previous = next[index].syncRecord {
                    let current = next[index]
                    guard current.name == previous.name, current.reading == previous.reading,
                          current.history == previous.history, current.reset == previous.reset,
                          (current.historyPaused == true) == previous.historyPaused else { continue }
                }
                guard try Vault.read(row.id) == url else { throw SyncValidationError.invalidRecord }
                next[index].name = record.name; next[index].reading = record.reading
                next[index].history = record.history; next[index].reset = record.reset
                next[index].historyPaused = record.historyPaused; next[index].syncRecord = record
                try persist(next)
            } else {
                guard !ignored.contains(scope + "/" + row.id.uuidString) else { continue }
                try Vault.save(url, id: row.id)
                next.append(Subscription(id: row.id, name: record.name, reading: record.reading,
                                         history: record.history, reset: record.reset, historyPaused: record.historyPaused,
                                         syncAccount: scope, syncRecord: record))
                do { try persist(next) } catch { try? Vault.remove(row.id); throw error }
            }
        }
    }

    func exportEntries() throws -> [ManualTransferCodec.Entry] {
        guard !demo, recordsAvailable else { throw QuotaError.storage }
        return try items.map { item in
            .init(record: SyncRecord(name: item.name, reset: item.reset, historyPaused: item.historyPaused == true,
                                     reading: item.reading, history: item.history), subscriptionURL: try Vault.read(item.id))
        }
    }

    private func ignoredSyncRecords() throws -> Set<String> {
        guard let file else { throw QuotaError.storage }
        let path = file.appendingPathExtension("ignored-sync")
        guard FileManager.default.fileExists(atPath: path.path) else { return [] }
        guard try path.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max <= 512 * 1024 else { throw QuotaError.storage }
        let result = try JSONDecoder().decode(Set<String>.self, from: Data(contentsOf: path))
        guard result.count <= 4096 else { throw QuotaError.storage }
        return result
    }

    func stopSharing(_ id: UUID) throws {
        var next = items
        guard let index = next.firstIndex(where: { $0.id == id }) else { return }
        next[index].syncAccount = nil; next[index].syncRecord = nil
        try persist(next)
    }

    func importEntries(_ entries: [ManualTransferCodec.Entry]) throws {
        guard !demo, recordsAvailable else { throw QuotaError.storage }
        guard entries.count <= 256 else { throw QuotaError.tooLarge }
        var next = items, inserted: [UUID] = []
        do {
            for entry in entries {
                _ = try entry.record.validated()
                guard entry.subscriptionURL.absoluteString.utf8.count <= 16_384,
                      try SubscriptionLink.parse(entry.subscriptionURL.absoluteString) == entry.subscriptionURL else { throw QuotaError.invalidLink }
                if try next.contains(where: { try Vault.read($0.id) == entry.subscriptionURL }) { continue }
                let id = UUID(), record = entry.record
                try Vault.save(entry.subscriptionURL, id: id); inserted.append(id)
                next.append(Subscription(id: id, name: record.name, reading: record.reading, history: record.history,
                                         reset: record.reset, historyPaused: record.historyPaused))
            }
            try persist(next)
        } catch { for id in inserted { try? Vault.remove(id) }; throw error }
    }
}

enum HistoryRecords {
    static func window(_ rows: [QuotaReading], days: Int, now: Date = .now, calendar: Calendar = .current) -> [QuotaReading] {
        guard [7, 30].contains(days), let start = calendar.date(byAdding: .day, value: -days, to: now) else { return [] }
        return retained(rows, now: now).filter { $0.observed >= start }.sorted { $0.observed < $1.observed }
    }
    static func retained(_ rows: [QuotaReading], now: Date = .now) -> [QuotaReading] {
        Array(rows.filter { $0.observed > now.addingTimeInterval(-90 * 86400) && $0.observed <= now }.suffix(2000))
    }
    static func appending(_ reading: QuotaReading, to rows: [QuotaReading], enabled: Bool, now: Date = .now) -> [QuotaReading] {
        retained(rows + (enabled ? [reading] : []), now: now)
    }
    static func csv(_ rows: [QuotaReading]) -> String {
        let formatter = ISO8601DateFormatter()
        func field(_ value: Int64?) -> String { value.map(String.init) ?? "" }
        let header = "observed_utc,upload_bytes,download_bytes,used_bytes,total_bytes,remaining_bytes"
        return ([header] + rows.map { row in
            [formatter.string(from: row.observed), field(row.upload), field(row.download), field(row.used), field(row.total), field(row.remaining)].joined(separator: ",")
        }).joined(separator: "\r\n") + "\r\n"
    }
}

@MainActor protocol ReminderDelivery {
    func authorization() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func deliveredNotifications() async -> [UNNotification]
    func removePendingNotificationRequests(withIdentifiers: [String])
    func removeDeliveredNotifications(withIdentifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}
@MainActor final class SystemReminderDelivery: ReminderDelivery {
    private let center = UNUserNotificationCenter.current()
    func authorization() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { try await center.requestAuthorization(options: options) }
    func pendingNotificationRequests() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func deliveredNotifications() async -> [UNNotification] { await center.deliveredNotifications() }
    func removePendingNotificationRequests(withIdentifiers ids: [String]) { center.removePendingNotificationRequests(withIdentifiers: ids) }
    func removeDeliveredNotifications(withIdentifiers ids: [String]) { center.removeDeliveredNotifications(withIdentifiers: ids) }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
}

@MainActor @Observable final class ReminderSettings {
    static let backgroundID = "com.mulabs.bytekibble.ios.refresh"
    var enabled: Bool { didSet { defaults.set(enabled, forKey: "reminders.enabled") } }
    var background: Bool { didSet { defaults.set(background, forKey: "refresh.enabled") } }
    private(set) var permission = UNAuthorizationStatus.notDetermined
    private(set) var message: String?
    private let defaults: UserDefaults
    private var cooldowns: [String: Date] {
        get { defaults.dictionary(forKey: "reminders.cooldowns") as? [String: Date] ?? [:] }
        set { defaults.set(newValue, forKey: "reminders.cooldowns") }
    }
    private let center: ReminderDelivery
    private var pending: [Subscription]?
    private var worker: Task<Void, Never>?
    init(defaults: UserDefaults = .standard, service: ReminderDelivery? = nil) {
        self.defaults = defaults
        self.center = service ?? SystemReminderDelivery()
        enabled = defaults.bool(forKey: "reminders.enabled")
        background = defaults.bool(forKey: "refresh.enabled")
    }
    func checkPermission() async { permission = await center.authorization() }
    func waitUntilSettled() async { await worker?.value }
    func enable() async {
        do {
            enabled = try await center.requestAuthorization(options: [.alert, .sound])
            await checkPermission()
            message = enabled ? nil : String(localized: "通知未获允许。你可以在系统设置中更改。")
        } catch { message = String(localized: "无法请求通知权限，请稍后重试。") }
    }
    func reconcile(_ items: [Subscription]) {
        pending = items
        guard worker == nil else { return }
        // Serial, coalesced reconciliation prevents an old async add surviving a newer deletion.
        worker = Task {
            while let next = pending {
                pending = nil
                await apply(next)
            }
            worker = nil
        }
    }
    private func apply(_ items: [Subscription]) async {
        await checkPermission()
        let ids = Set(items.map { $0.id.uuidString })
        cooldowns = cooldowns.filter { ids.contains($0.key) }
        let existing = await center.pendingNotificationRequests()
        let retainedLow = existing.filter { request in
            enabled && items.contains { "quota.\($0.id).low" == request.identifier && ($0.reading?.remainingRatio ?? 1) < 0.1 }
        }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: existing.filter {
            guard $0.identifier.hasPrefix("quota.") else { return false }
            let validLow = retainedLow.contains($0.identifier)
            return !enabled || !validLow
        }.map(\.identifier))
        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter {
            $0.request.identifier.hasPrefix("quota.") && (!enabled || !ids.contains($0.request.identifier.split(separator: ".").dropFirst().first.map(String.init) ?? ""))
        }.map { $0.request.identifier })
        guard enabled, permission == .authorized || permission == .provisional else { return }
        message = nil
        let now = Date.now
        var requests: [(Date, UNNotificationRequest, String?)] = []
        for item in items {
            for (kind, date) in [("reset", item.reset), ("expiry", item.reading?.expires)] {
                guard let date = ReminderPolicy.deadline(date, now: now) else { continue }
                let content = UNMutableNotificationContent()
                content.title = kind == "reset" ? String(localized: "手动重置日期提醒") : String(localized: "套餐到期日期提醒")
                content.body = kind == "reset" ? String(localized: "今天是你记录的重置日期。请打开 ByteKibble 核对，服务商流量不会被自动清零。") : String(localized: "已保存的套餐到期日期为今天。请打开 ByteKibble 查询最新状态。")
                let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)
                requests.append((date, UNNotificationRequest(identifier: "quota.\(item.id).\(kind)", content: content, trigger: trigger), nil))
            }
            let key = item.id.uuidString
            if ReminderPolicy.shouldWarn(reading: item.reading, lastAlert: cooldowns[key], now: now) {
                let content = UNMutableNotificationContent()
                content.title = String(localized: "剩余流量不足 10%")
                content.body = String(localized: "最近一次查询发现订阅流量偏低。打开 ByteKibble 查看读数与更新时间。")
                requests.append((now, UNNotificationRequest(identifier: "quota.\(item.id).low", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)), key))
            }
        }
        for (_, request, key) in requests.sorted(by: { $0.0 < $1.0 }).prefix(max(0, 32 - retainedLow.count)) {
            do { try await center.add(request); if let key { cooldowns[key] = now } }
            catch { message = String(localized: "部分提醒未能安排。请稍后重新打开此页面重试。") }
        }
    }
    func scheduleBackground() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundID)
        guard background else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundID)
        request.earliestBeginDate = Date.now.addingTimeInterval(3600)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { message = String(localized: "后台刷新暂不可用。仍可在 App 内手动刷新。") }
    }
}
