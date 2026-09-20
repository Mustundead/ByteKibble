import SwiftUI
import WidgetKit

@MainActor @Observable final class WidgetSharing {
    var selection: String {
        didSet { defaults.set(selection, forKey: "widget.selection") }
    }
    private(set) var error: String?
    private let defaults: UserDefaults
    private let fileURL: URL?
    private let reload: () -> Void
    init(defaults: UserDefaults = .standard, fileURL: URL? = WidgetSnapshotFile.url,
         reload: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotFile.kind) }) {
        self.defaults = defaults
        self.fileURL = fileURL
        self.reload = reload
        selection = defaults.string(forKey: "widget.selection") ?? ""
    }
    func update(_ items: [Subscription], demo: Bool) {
        guard !demo else { return }
        guard let url = fileURL else {
            error = String(localized: "无法访问小组件共享空间。请重新打开 App 后重试。")
            return
        }
        let reading = items.first { $0.id.uuidString == selection }?.reading
        let snapshot = reading.map { WidgetSnapshot(remaining: $0.remaining, total: $0.total, observed: $0.observed) }
        do {
            if snapshot != WidgetSnapshotFile.read(from: url) || (snapshot == nil && FileManager.default.fileExists(atPath: url.path)) {
                try WidgetSnapshotFile.write(snapshot, to: url)
                reload()
            }
            error = nil
        } catch {
            self.error = String(localized: "未能更新小组件快照，可能仍显示旧读数。请重新打开 App 后重试。")
        }
    }
}
