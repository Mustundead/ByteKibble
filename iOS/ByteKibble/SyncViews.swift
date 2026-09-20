import SwiftUI
import UniformTypeIdentifiers

struct SyncSettingsView: View {
    @EnvironmentObject private var sync: SyncLibrary
    @Environment(SubscriptionStore.self) private var store
    @State private var consent = false
    @State private var message: String?
    var body: some View {
        List {
            Section {
                SyncRouteIllustration().listRowSeparator(.hidden)
                Label("先在 Mac 上同步", systemImage: "1.circle")
                DisclosureGroup("连接前需要什么") {
                    Text("在 macOS 版 ByteKibble 中开启 iCloud，并选择要同步的订阅。两台设备须登录同一 Apple 账户并开启 iCloud 钥匙串，iPhone 才能收到这些数据。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section {
                if sync.accountScope == nil {
                    Button("开启 iCloud 同步") { consent = true }
                        .disabled(store.demo || sync.busy)
                } else {
                    Button("立即同步") { synchronize() }.disabled(sync.busy)
                    Button("关闭此设备的同步", role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "sync.approvedAccount")
                        sync.disconnect()
                    }.disabled(sync.busy)
                    if let date = sync.lastSuccess {
                        LabeledContent("上次同步") { Text(date, style: .relative) }
                    }
                }
                if sync.busy { ProgressView("正在同步") }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                if !sync.waiting.isEmpty {
                    Text("部分数据仍在等待。请确认 iCloud 钥匙串已开启，解锁设备后再次同步。现有订阅会保留。")
                }
            }
            Section {
                HStack(spacing: 18) {
                    Label("链接", systemImage: "key")
                    Label("读数", systemImage: "chart.pie")
                    Label("历史", systemImage: "clock")
                }.font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                DisclosureGroup("同步哪些数据") {
                    Text("同步名称、链接、流量读数、历史记录和手动重置日期。同步不会刷新服务商读数。关闭后，本机和 iCloud 的现有数据均保留。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if sync.accountScope != nil {
                Section("从此 iPhone 同步") {
                    ForEach(store.items) { item in
                        if item.syncAccount == sync.accountScope {
                            Label(item.name, systemImage: "checkmark.icloud")
                        } else {
                            Button {
                                if perform({ try store.share(item.id, with: sync) }) { synchronize() }
                            } label: {
                                Label(item.name, systemImage: "icloud.and.arrow.up")
                            }.disabled(sync.busy)
                        }
                    }
                }
                ForEach(sync.rows.filter { $0.conflict != nil }) { row in
                    Section(row.record.name) {
                        Text("两台设备都修改了此订阅。请选择要保留的版本。")
                        Button("保留此设备版本") { resolve(row.id, remote: false) }
                        Button("使用 iCloud 版本") { resolve(row.id, remote: true) }
                    }.disabled(sync.busy)
                }
                ForEach(Array(sync.remoteDeleted).sorted { $0.uuidString < $1.uuidString }, id: \.self) { id in
                    Section {
                        Text("此订阅已从 iCloud 移除。本机副本仍保留。")
                        Button("保留本机副本并停止同步") {
                            Task {
                                do { try store.stopSharing(id); try await sync.keepLocalAfterRemoteDeletion(id) }
                                catch { message = String(localized: "未能保存同步更改。现有数据已保留，请解锁设备后重试。") }
                            }
                        }.disabled(sync.busy)
                    }
                }
            }
        }.navigationTitle("iCloud 同步")
            .confirmationDialog("开启 iCloud 同步？", isPresented: $consent, titleVisibility: .visible) {
                Button("开启并接收数据") {
                    Task {
                        do {
                            try await sync.connect()
                            UserDefaults.standard.set(sync.accountScope, forKey: "sync.approvedAccount")
                            synchronize()
                        }
                        catch { message = String(localized: "未能连接 iCloud。请检查 Apple 账户、网络和 iCloud 权限后重试。") }
                    }
                }
            } message: {
                Text("订阅数据使用你的 iCloud 私有数据库，链接使用 iCloud 钥匙串。此 iPhone 的现有订阅不会自动上传，你可以逐个选择。")
            }
    }
    @discardableResult private func perform(_ action: () throws -> Void) -> Bool {
        do { try action(); message = nil; return true }
        catch { message = String(localized: "未能保存同步更改。现有数据已保留，请解锁设备后重试。"); return false }
    }
    private func resolve(_ id: UUID, remote: Bool) {
        perform { try sync.resolve(id: id, useRemote: remote); try store.applySync(sync) }
    }
    private func synchronize() {
        Task {
            do {
                try store.stageSyncChanges(in: sync)
                try await sync.synchronize()
                try store.applySync(sync)
                message = sync.rows.isEmpty ? String(localized: "iCloud 中还没有订阅。请先在 Mac 上选择订阅并同步。") : nil
            } catch { message = String(localized: "同步未完成。已保留现有数据，请检查网络或解锁设备后重试。") }
        }
    }
}

struct TransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              data.count <= ManualTransferCodec.maximumArchiveBytes else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct ManualTransferView: View {
    @Environment(SubscriptionStore.self) private var store
    @State private var document: TransferDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var key = ""
    @State private var exportKey = ""
    @State private var pending: [ManualTransferCodec.Entry]?
    @State private var message: String?
    var body: some View {
        List {
            Section {
                HStack(spacing: 24) {
                    VStack(spacing: 8) { SettingsSymbol(name: "lock.doc"); Text("加密文件") }
                    Image(systemName: "plus").foregroundStyle(.tertiary)
                    VStack(spacing: 8) { SettingsSymbol(name: "key"); Text("解密密钥") }
                }.font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 12)
                Label("文件和密钥，请分开保管", systemImage: "lock.shield").font(.subheadline)
                DisclosureGroup("了解手动传输") {
                    Text("优先使用 iCloud。无法使用时，可通过加密文件在设备间传输订阅。")
                    Text("文件包含订阅链接和记录。解密密钥单独提供，请勿将文件与密钥公开分享。")
                        .foregroundStyle(.secondary)
                }.font(.subheadline)
            }
            Section("导出") {
                Button("创建加密文件") {
                    do {
                        let key = ManualTransferCodec.TransferKey.generate()
                        let data = try ManualTransferCodec.encode(.init(entries: store.exportEntries()), key: key)
                        document = TransferDocument(data: data); exportKey = key.text; exporting = true
                    } catch { message = String(localized: "无法导出。请解锁设备并检查本机记录。") }
                }.disabled(store.demo || store.items.isEmpty)
                if !exportKey.isEmpty {
                    Text("解密密钥").font(.headline)
                    Text(exportKey).font(.caption.monospaced()).textSelection(.enabled)
                    Text("请单独保存密钥。离开此页面后，密钥不会保留。")
                }
            }
            Section("导入") {
                SecureField("粘贴解密密钥", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("选择加密文件") { importing = true }.disabled(key.isEmpty || store.demo)
                if let pending {
                    Text("已解密，可以导入。相同链接会跳过，不会覆盖现有订阅。")
                    Button("导入订阅") {
                        do { try store.importEntries(pending); self.pending = nil; key = ""; message = String(localized: "导入完成") }
                        catch { message = String(localized: "未能导入。原有订阅未被覆盖，请解锁设备后重试。") }
                    }
                    Button("取消", role: .cancel) { self.pending = nil }
                }
            }
            if let message { Section { Text(message).font(.footnote) } }
        }.navigationTitle("手动传输")
            .fileExporter(isPresented: $exporting, document: document, contentType: .data, defaultFilename: "ByteKibble.bytekibble") { result in
                if case .failure = result { message = String(localized: "文件未保存。你可以重新导出。") }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max <= ManualTransferCodec.maximumArchiveBytes else {
                        throw ManualTransferCodec.Error.tooLarge
                    }
                    pending = try ManualTransferCodec.decode(Data(contentsOf: url), key: .init(text: key.trimmingCharacters(in: .whitespacesAndNewlines))).entries
                    message = nil
                } catch { pending = nil; message = String(localized: "无法解密文件。请确认文件完整，并使用对应的解密密钥。") }
            }
    }
}
