import AppKit
import SwiftUI
import ByteKibbleCore

@MainActor final class SyncWindow {
    static let shared = SyncWindow()
    private var window: NSWindow?
    func resume(vm: ViewModel) {
        guard UserDefaults.standard.string(forKey: "sync.approvedAccount") != nil else { return }
        show(vm: vm, visible: false)
    }
    func show(vm: ViewModel, visible: Bool = true) {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 650),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L10n.t("同步与传输")
        window.contentView = NSHostingView(rootView: MacSyncView(vm: vm))
        window.isReleasedWhenClosed = false; window.center()
        self.window = window
        if visible { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    }
}

struct MacSyncView: View {
    @ObservedObject var vm: ViewModel
    @StateObject private var sync = SyncLibrary(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ByteKibble/Sync"),
        accessGroup: "46P646AZCB.com.mulabs.bytekibble.sync")
    @State private var consent = false
    @State private var message: String?
    @State private var key = ""
    @State private var exportKey = ""
    private func t(_ key: String) -> String { L10n.t(key) }
    var body: some View {
        Form {
            Section {
                Text(t("先在 Mac 上选择订阅并同步，再在 iPhone 上开启 iCloud。两台设备须登录同一 Apple 账户并开启 iCloud 钥匙串。"))
                if sync.accountScope == nil {
                    Button(t("开启 iCloud 同步")) { consent = true }.disabled(vm.isPreview || sync.busy)
                } else {
                    Button(t("立即同步")) { synchronize() }.disabled(sync.busy)
                    Button(t("关闭此设备的同步")) {
                        UserDefaults.standard.removeObject(forKey: "sync.approvedAccount")
                        sync.disconnect()
                    }.disabled(sync.busy)
                }
                if sync.busy { ProgressView() }
                if let message { Text(message).font(.callout).foregroundStyle(.secondary) }
                if !sync.waiting.isEmpty { Text(t("部分数据仍在等待。请解锁设备并确认 iCloud 钥匙串已开启后重试。")) }
            } header: { Text("iCloud") }
            if sync.accountScope != nil {
                Section {
                    ForEach(vm.targets) { target in
                        Button {
                            do { try share(target); synchronize() } catch { message = t("未能保存同步更改。请解锁钥匙串后重试。") }
                        } label: { Label(target.name, systemImage: "icloud.and.arrow.up") }
                            .disabled(sync.busy)
                    }
                    ForEach(sync.rows.filter { $0.conflict != nil }) { row in
                        Text(row.record.name).font(.headline)
                        Text(t("两台设备都修改了此订阅。请选择要保留的版本。"))
                        Button(t("保留此设备版本")) { resolve(row.id, remote: false) }
                        Button(t("使用 iCloud 版本")) { resolve(row.id, remote: true) }
                    }
                    ForEach(Array(sync.remoteDeleted).sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
                        Text(t("此订阅已从 iCloud 移除。本机副本仍保留。"))
                        Button(t("保留本机副本并停止同步")) {
                            Task {
                                do {
                                    if let row = sync.rows.first(where: { $0.id == id }), let url = try? sync.credential(for: row.record) {
                                        vm.markShared(url.absoluteString, account: nil)
                                    }
                                    try await sync.keepLocalAfterRemoteDeletion(id)
                                } catch { message = t("未能保存同步更改。请解锁钥匙串后重试。") }
                            }
                        }.disabled(sync.busy)
                    }
                } header: { Text(t("选择要同步的订阅")) }
            }
            Section {
                Text(t("无法使用 iCloud 时，可通过加密文件传输订阅。文件和解密密钥请分开保存，不要公开分享。"))
                Button(t("导出当前订阅")) { exportSelected() }.disabled(vm.selected == nil || vm.isPreview)
                if !exportKey.isEmpty { Text(exportKey).font(.caption.monospaced()).textSelection(.enabled) }
                SecureField(t("粘贴解密密钥"), text: $key)
                Button(t("导入加密文件")) { importFile() }.disabled(key.isEmpty || vm.isPreview)
            } header: { Text(t("手动传输")) }
            Text(t("同步包含订阅链接、名称、读数、历史和手动重置日期。查询直接连接服务商，不发送到 MU LABS。关闭同步不会删除本机或 iCloud 数据。"))
                .font(.footnote).foregroundStyle(.secondary)
        }.formStyle(.grouped).padding().frame(minWidth: 440, minHeight: 560)
            .confirmationDialog(t("开启 iCloud 同步？"), isPresented: $consent) {
                Button(t("开启并接收数据")) {
                    Task {
                        // Plain SPM executables have no CloudKit entitlement; never
                        // invoke CKContainer account APIs from an unsupported artifact.
                        guard Bundle.main.object(forInfoDictionaryKey: "ByteKibbleCloudEnabled") as? Bool == true else {
                            message = t("此安装包尚未配置 iCloud 签名权限。可先使用加密手动传输。")
                            return
                        }
                        do {
                            try await sync.connect()
                            UserDefaults.standard.set(sync.accountScope, forKey: "sync.approvedAccount")
                            synchronize()
                        }
                        catch { message = t("未能连接 iCloud。请检查 Apple 账户、网络和签名权限。") }
                    }
                }
            } message: { Text(t("只同步你选择的订阅。其他客户端的配置不会被修改。")) }
            .task {
                guard !vm.isPreview, Bundle.main.object(forInfoDictionaryKey: "ByteKibbleCloudEnabled") as? Bool == true else { return }
                while !Task.isCancelled {
                    if !sync.busy, let scope = UserDefaults.standard.string(forKey: "sync.approvedAccount") {
                        do {
                            if sync.accountScope == nil { try await sync.connect(expectedScope: scope) }
                            if sync.accountScope == scope { synchronize() }
                        } catch SyncValidationError.accountChanged {
                            UserDefaults.standard.removeObject(forKey: "sync.approvedAccount")
                        } catch { message = t("未能连接 iCloud。请检查 Apple 账户、网络和签名权限。") }
                    }
                    do { try await Task.sleep(for: .seconds(300)) } catch { return }
                }
            }
    }
    private func record(_ target: SubTarget, previous: SyncRecord? = nil) -> SyncRecord {
        var value = previous ?? vm.transferredRecord(for: target) ?? SyncRecord(name: String(target.name.prefix(80)))
        if let sample = vm.sample(for: target), let observed = sample.fetchedAt {
            let reading = QuotaReading(upload: sample.uploaded, download: sample.downloaded, total: sample.total,
                                       used: sample.used, expires: sample.expireAt, observed: observed)
            if value.reading != reading && (value.reading.map { observed >= $0.observed } ?? true) {
                value.reading = reading
                if !value.historyPaused { value.history = Array((value.history + [reading]).suffix(2000)) }
            }
        }
        value.reset = vm.manualReset(for: target)
        if let previous, previous != value { value.revision = UUID() }
        return value
    }
    private func share(_ target: SubTarget) throws {
        guard let url = URL(string: target.url) else { throw SyncValidationError.invalidRecord }
        let previous = sync.rows.first { (try? sync.credential(for: $0.record)) == url }?.record
        vm.markShared(target.url, account: sync.accountScope)
        try sync.stage(record(target, previous: previous), url: url)
    }
    private func synchronize(stageLocal: Bool = true) {
        Task {
            do {
                let originals = Dictionary(uniqueKeysWithValues: vm.targets.map { ($0.url, (vm.sample(for: $0), vm.manualReset(for: $0))) })
                for row in sync.rows where stageLocal && row.conflict == nil {
                    if let url = try? sync.credential(for: row.record), vm.syncAccount(for: url.absoluteString) == sync.accountScope,
                       let target = vm.targets.first(where: { $0.url == url.absoluteString }) {
                        try sync.stage(record(target, previous: row.record), url: url)
                    }
                }
                try await sync.synchronize()
                for row in sync.rows where row.conflict == nil && !row.record.deleted && !sync.waiting.contains(row.id) {
                    let url = try sync.credential(for: row.record)
                    if let target = vm.targets.first(where: { $0.url == url.absoluteString }), let original = originals[target.url],
                       (vm.sample(for: target) != original.0 || vm.manualReset(for: target) != original.1) { continue }
                    try vm.acceptTransferred(row.record, url: url, syncAccount: sync.accountScope)
                }
                message = sync.rows.isEmpty ? t("尚未选择订阅。请在下方选择要同步的订阅。") : nil
            } catch { message = t("同步未完成。现有数据已保留，请检查网络或解锁钥匙串后重试。") }
        }
    }
    private func resolve(_ id: UUID, remote: Bool) {
        do { try sync.resolve(id: id, useRemote: remote); synchronize(stageLocal: false) }
        catch { message = t("未能保存同步更改。请解锁钥匙串后重试。") }
    }
    private func exportSelected() {
        guard let target = vm.selected, let url = URL(string: target.url) else { return }
        do {
            let key = ManualTransferCodec.TransferKey.generate()
            let data = try ManualTransferCodec.encode(.init(entries: [.init(record: record(target), subscriptionURL: url)]), key: key)
            let panel = NSSavePanel(); panel.nameFieldStringValue = "ByteKibble.bytekibble"
            guard panel.runModal() == .OK, let file = panel.url else { return }
            try data.write(to: file, options: .atomic); exportKey = key.text
        } catch { message = t("无法导出。请检查可用存储空间。") }
    }
    private func importFile() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let file = panel.url else { return }
        do {
            guard try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max <= ManualTransferCodec.maximumArchiveBytes else { throw ManualTransferCodec.Error.tooLarge }
            let archive = try ManualTransferCodec.decode(Data(contentsOf: file), key: .init(text: key.trimmingCharacters(in: .whitespacesAndNewlines)))
            let alert = NSAlert(); alert.messageText = t("导入订阅？")
            alert.informativeText = t("将添加文件中的订阅。已有相同链接会保留，不修改客户端配置。")
            alert.addButton(withTitle: t("导入")); alert.addButton(withTitle: t("取消"))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            for entry in archive.entries { try vm.acceptTransferred(entry.record, url: entry.subscriptionURL) }
            key = ""; message = t("导入完成")
        } catch { message = t("未能导入。请检查文件、密钥和钥匙串权限。已导入的订阅会保留。") }
    }
}
