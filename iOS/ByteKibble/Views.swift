import SwiftUI
import PhotosUI
import Vision
import UniformTypeIdentifiers
import VisionKit
import AVFoundation
import Charts
import ImageIO

private func amount(_ bytes: Int64?) -> String {
    guard let bytes else { return "—" }
    return (Double(bytes) / 1_073_741_824).formatted(.number.precision(.fractionLength(1))) + " GiB"
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var incomingLink: String?
    @Environment(SubscriptionStore.self) private var store
    @State private var adding = false
    @State private var showingSync = false
    @State private var showingTransfer = false
    #if DEBUG
    @State private var showingShareAcceptance = false
    #endif
    @State private var search = ""
    @State private var welcoming = false
    @State private var addAfterWelcome = false
    private let welcomePreference = WelcomePreference()
    var body: some View {
        TabView {
            Tab("概览", systemImage: "chart.pie") {
                NavigationStack {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            if store.demo { Label("演示数据 · 不会查询真实订阅", systemImage: "eye").font(.footnote).foregroundStyle(.secondary) }
                            if store.items.isEmpty {
                                ContentUnavailableView {
                                    Label("流量，心中有数", systemImage: "chart.pie")
                                } description: {
                                    Text("先在 Mac 版 ByteKibble 中开启同步并选择订阅，再通过 iCloud 接收数据。")
                                } actions: {
                                    Button("通过 iCloud 同步", systemImage: "icloud") { showingSync = true }.buttonStyle(.glassProminent)
                                    Button("手动传输", systemImage: "lock.doc") { showingTransfer = true }.buttonStyle(.glass)
                                    Button("添加订阅") { adding = true }
                                }.padding(.top, 70)
                            }
                            ForEach(store.items) { item in
                                NavigationLink(value: item.id) { QuotaCard(item: item, error: store.errors[item.id], loading: store.loading.contains(item.id)) }
                                    .buttonStyle(.plain)
                            }
                        }.padding(20).frame(maxWidth: 720).frame(maxWidth: .infinity)
                    }
                    .background(Color(.systemGroupedBackground))
                    .navigationTitle("ByteKibble")
                    .toolbar { ToolbarItem(placement: .primaryAction) { Button("添加订阅", systemImage: "plus") { adding = true }.disabled(store.demo) } }
                    .navigationDestination(for: UUID.self) { DetailView(id: $0) }
                    .refreshable { await store.refreshAll() }
                }
            }
            Tab("订阅", systemImage: "square.stack") {
                NavigationStack {
                    List {
                        ForEach(store.items.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in
                            NavigationLink(value: item.id) {
                                HStack(spacing: 14) {
                                    Image(systemName: "shippingbox").foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.name).font(.headline)
                                        Text(item.reading.map { String(localized: "剩余 \(amount($0.remaining))") } ?? String(localized: "尚未查询")).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }.padding(.vertical, 8)
                            }
                        }.onMove { from, to in store.move(from: from, to: to) }.moveDisabled(!search.isEmpty)
                        Button("添加订阅", systemImage: "plus") { adding = true }.disabled(store.demo)
                    }
                    .navigationTitle("订阅")
                    .toolbar { EditButton().disabled(!search.isEmpty) }
                    .searchable(text: $search, prompt: "搜索订阅名称")
                    .navigationDestination(for: UUID.self) { DetailView(id: $0) }
                }
            }
            Tab("设置", systemImage: "gearshape") { NavigationStack { SettingsView() } }
        }
        .sheet(isPresented: $showingSync) {
            NavigationStack { SyncSettingsView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showingSync = false } } } }
        }
        .sheet(isPresented: $showingTransfer) {
            NavigationStack { ManualTransferView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showingTransfer = false } } } }
        }
        .sheet(isPresented: $adding, onDismiss: {
            if let incomingLink { try? PendingSharedLink.remove(matching: incomingLink) }
            incomingLink = nil
        }) { AddSubscriptionView(initialLink: incomingLink ?? "") }
        .fullScreenCover(isPresented: $welcoming, onDismiss: {
            if addAfterWelcome { addAfterWelcome = false; adding = true }
            else { receiveSharedLink() }
        }) {
            WelcomeView(add: { finishWelcome(add: true) }, finish: { finishWelcome(add: false) })
        }
        .task {
            guard store.recordsAvailable else { return }
            welcoming = welcomePreference.shouldPresent(demo: store.demo, hasSubscriptions: !store.items.isEmpty)
            receiveSharedLink()
        }
        .onChange(of: scenePhase) { _, value in if value == .active { receiveSharedLink() } }
        .alert("无法读取记录", isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
            Button("好", role: .cancel) { store.storageError = nil }
        } message: { Text(store.storageError ?? "") }
        #if DEBUG
        .task {
            showingShareAcceptance = ProcessInfo.processInfo.arguments.contains("--qa-share-presentation")
        }
        .sheet(isPresented: $showingShareAcceptance) { ShareAcceptanceHost() }
        #endif
    }
    private func receiveSharedLink() {
        guard !store.demo, store.recordsAvailable, !welcoming, !adding,
              let value = try? PendingSharedLink.read() else { return }
        incomingLink = value
        adding = true
    }
    private func finishWelcome(add: Bool) {
        welcomePreference.complete()
        addAfterWelcome = add
        welcoming = false
    }
}

#if DEBUG
/// System extension presentation fixture; no real link, provider request or automatic save.
private struct ShareAcceptanceHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [URL(string: "https://example.invalid/bytekibble-share-acceptance")!], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif

struct WelcomePreference {
    var defaults: UserDefaults = .standard
    func shouldPresent(demo: Bool, hasSubscriptions: Bool) -> Bool {
        !demo && !hasSubscriptions && !defaults.bool(forKey: "welcome.completed")
    }
    func complete() { defaults.set(true, forKey: "welcome.completed") }
}

struct WelcomeView: View {
    var add: (() -> Void)?
    let finish: () -> Void
    @State private var showingSync = false
    @State private var showingTransfer = false
    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 12) {
                    if let path = Bundle.main.path(forResource: "QuotaBag", ofType: "png"), let icon = UIImage(contentsOfFile: path) {
                        Image(uiImage: icon).resizable().scaledToFit().frame(width: 88, height: 88).accessibilityHidden(true)
                    }
                    Text("欢迎使用 ByteKibble").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Text("订阅流量，一处查看").font(.title3).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 24) {
                    feature("先在 Mac 上同步", icon: "icloud", detail: "先在 Mac 版 ByteKibble 中开启同步并选择订阅，再通过 iCloud 接收数据。")
                    feature("流量与到期，一目了然", icon: "chart.pie", detail: "查看服务商提供的剩余流量和到期时间，回顾本机记录。未提供的数据不会显示为零。")
                    feature("订阅链接，安全保存", icon: "key", detail: "默认存于本机钥匙串。可选择通过 iCloud 同步，不上传至 MU LABS。查询需要连接订阅服务商。")
                    feature("查看流量，不连接 VPN", icon: "network.slash", detail: "不建立 VPN 连接，不读取其他 App 的配置。提醒和小组件可在设置中开启。")
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
            }
            .padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
            .frame(minHeight: geometry.size.height)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        .clipped()
        .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 12) {
                    if let add {
                        Button { showingSync = true } label: { Text("通过 iCloud 同步").frame(maxWidth: .infinity).padding(.vertical, 16) }
                            .buttonStyle(.glassProminent)
                            .accessibilityIdentifier("welcome.sync")
                        Button { showingTransfer = true } label: { Text("手动传输").frame(maxWidth: .infinity).padding(.vertical, 16) }
                            .buttonStyle(.glass)
                            .accessibilityIdentifier("welcome.transfer")
                        HStack {
                            Button("添加第一个订阅", action: add).frame(maxWidth: .infinity, minHeight: 44)
                            Button("暂不添加", action: finish).frame(maxWidth: .infinity, minHeight: 44)
                        }.font(.subheadline)
                    } else {
                        Button(action: finish) { Text("完成").frame(maxWidth: .infinity).padding(.vertical, 16) }
                            .buttonStyle(.glassProminent)
                    }
                }
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingSync) {
            NavigationStack { SyncSettingsView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showingSync = false } } } }
        }
        .sheet(isPresented: $showingTransfer) {
            NavigationStack { ManualTransferView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showingTransfer = false } } } }
        }
    }
    private func feature(_ title: LocalizedStringKey, icon: String, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}

struct QuotaCard: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let item: Subscription
    var error: String?
    var loading = false
    private var statusColor: Color {
        switch QuotaWarning(remainingRatio: item.reading?.remainingRatio) {
        case .critical: return .red
        case .low: return .orange
        default: return .primary
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(item.name).font(.headline).lineLimit(2)
                Spacer(minLength: 8)
                if loading { ProgressView().accessibilityLabel("正在查询") }
                else { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary) }
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("剩余流量").font(.subheadline).foregroundStyle(.secondary)
                Text(amount(item.reading?.remaining)).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(statusColor).contentTransition(.numericText())
                    .accessibilityLabel(String(localized: "剩余流量 \(amount(item.reading?.remaining))"))
            }
            if let ratio = item.reading?.remainingRatio {
                ProgressView(value: ratio).tint(statusColor == .primary ? .orange : statusColor)
                    .accessibilityLabel("剩余比例").accessibilityValue(ratio.formatted(.percent.precision(.fractionLength(0))))
                ViewThatFits(in: .horizontal) {
                    HStack { Text("已用 \(amount(item.reading?.used))"); Spacer(); Text("总量 \(amount(item.reading?.total))") }
                    VStack(alignment: .leading) { Text("已用 \(amount(item.reading?.used))"); Text("总量 \(amount(item.reading?.total))") }
                }.font(.caption).foregroundStyle(.secondary)
            } else { Text("服务商未提供完整流量数据").font(.subheadline).foregroundStyle(.secondary) }
            if let error { Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            else if let observed = item.reading?.observed {
                Text("读取于 \(observed.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            } else { Text("下拉刷新以查询流量").font(.caption).foregroundStyle(.secondary) }
            if let ratio = item.reading?.remainingRatio, ratio < 0.2 {
                Label(ratio < 0.1 ? String(localized: "剩余流量不足 10%") : String(localized: "剩余流量不足 20%"), systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.medium)).foregroundStyle(statusColor)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottomTrailing) {
            if let path = Bundle.main.path(forResource: "QuotaBag", ofType: "png"), let artwork = UIImage(contentsOfFile: path) {
                Image(uiImage: artwork).resizable().scaledToFit().frame(width: 160, height: 160)
                    .saturation(0).colorMultiply(.gray).opacity(0.16).padding(.trailing, 6).accessibilityHidden(true)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay { if contrast == .increased { RoundedRectangle(cornerRadius: 28).stroke(.primary.opacity(0.6), lineWidth: 1) } }
    }
}

struct AddSubscriptionView: View {
    init(initialLink: String = "") { _link = State(initialValue: initialLink) }
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var link = ""
    @State private var error: String?
    @State private var photo: PhotosPickerItem?
    @State private var importingFile = false
    @State private var readingImage = false
    @State private var scanning = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称（可选）", text: $name).textContentType(.none)
                    SecureField("HTTPS 订阅链接", text: $link).textContentType(.none)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    PasteButton(payloadType: String.self) { values in
                        if let first = values.first { link = first; error = nil }
                    }
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("从图片识别二维码", systemImage: "qrcode")
                    }.disabled(readingImage)
                    Button("从文本文件导入", systemImage: "doc") { importingFile = true }
                    Button("扫描二维码", systemImage: "camera") { scanning = true }.disabled(readingImage)
                    if readingImage { ProgressView("正在本机识别") }
                } header: { Text("订阅信息") } footer: {
                    Text("支持 HTTPS 订阅与部分客户端导入链接。链接默认存于本机钥匙串；选择同步后，也会存入 iCloud 钥匙串。查询直接连接服务商，不发送到 MU LABS。")
                }
                if let error { Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("importError") } }
                Section {
                    Label("不会建立 VPN 连接", systemImage: "network.slash")
                    Label("不会读取其他 App 的配置", systemImage: "lock.shield")
                }.font(.subheadline).foregroundStyle(.secondary)
            }
            .navigationTitle("添加订阅").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $scanning) {
                SubscriptionCameraView { value in
                    link = value; error = nil; scanning = false
                }
            }
            .fileImporter(isPresented: $importingFile, allowedContentTypes: [.plainText], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }
                    let data = try handle.read(upToCount: 16_385) ?? Data()
                    guard data.count <= 16_384, let text = String(data: data, encoding: .utf8) else {
                        error = String(localized: "请选择不超过 16 KiB、包含一条订阅链接的 UTF-8 文本文件。"); return
                    }
                    link = try SubscriptionLink.parse(text).absoluteString; error = nil
                } catch { self.error = String(localized: "未能导入文件。请选择包含一条有效订阅链接的文本文件。") }
            }
            .task(id: photo) {
                guard let photo else { return }
                readingImage = true
                defer { readingImage = false }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self), data.count <= 10 * 1024 * 1024 else {
                        error = String(localized: "请选择不超过 10 MiB 的二维码图片。"); return
                    }
                    let strings = try await Task.detached(priority: .userInitiated) {
                        try SubscriptionImageDecoder.payloads(in: data)
                    }.value
                    try Task.checkCancellation()
                    let links = Set(strings.compactMap { try? SubscriptionLink.parse($0).absoluteString })
                    guard links.count == 1, let found = links.first else {
                        error = links.isEmpty ? String(localized: "未找到有效的订阅二维码。请选择其他图片。") : String(localized: "图片包含多个订阅，请选择只包含一个二维码的图片。"); return
                    }
                    link = found; error = nil
                } catch is CancellationError { }
                catch { self.error = String(localized: "无法识别这张图片，请选择其他图片。") }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        do {
                            let id = try store.add(name: name, text: link)
                            link = ""; dismiss()
                            Task { await store.refresh(id) }
                        } catch { self.error = SubscriptionStore.message(error) }
                    }.disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

enum SubscriptionImageDecoder {
    /// Bound decoded dimensions as well as compressed bytes before Vision allocates the image.
    static func payloads(in data: Data) throws -> [String] {
        guard data.count <= 10 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue <= 16_384, height.doubleValue <= 16_384,
              width.doubleValue * height.doubleValue <= 40_000_000 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try VNImageRequestHandler(data: data).perform([request])
        return request.results?.compactMap(\.payloadStringValue) ?? []
    }
}

/// Camera input only fills the import form; it never saves or queries a subscription.
struct SubscriptionCameraView: View {
    let selected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @State private var ready = false
    @State private var message = String(localized: "正在检查相机")
    @State private var denied = false
    @State private var scanError: String?
    var body: some View {
        NavigationStack {
            Group {
                if ready && phase == .active {
                    LiveSubscriptionScanner(selected: selected, failed: { scanError = $0 })
                        .safeAreaInset(edge: .bottom) {
                            Text(scanError ?? String(localized: "对准二维码，轻点高亮的二维码填入链接。确认添加前不会保存或查询。"))
                                .font(.subheadline).padding().frame(maxWidth: .infinity).background(.regularMaterial)
                        }
                } else {
                    ContentUnavailableView {
                        Label("相机扫描", systemImage: "camera")
                    } description: { Text(message) } actions: {
                        if denied {
                            Button("前往系统设置") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                        }
                        Button("返回添加订阅") { dismiss() }
                    }
                }
            }
            .navigationTitle("扫描二维码").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .task(id: phase) { if phase == .active { await prepare() } }
        }
    }
    @MainActor private func prepare() async {
        ready = false; denied = false
        guard DataScannerViewController.isSupported else {
            message = String(localized: "此设备不支持相机扫描。请返回，使用图片识别或粘贴订阅链接。"); return
        }
        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            status = AVCaptureDevice.authorizationStatus(for: .video)
        }
        guard !Task.isCancelled else { return }
        guard status == .authorized else {
            denied = status == .denied
            message = denied ? String(localized: "相机访问已关闭。可前往系统设置开启，或返回使用图片识别与粘贴。") : String(localized: "相机访问受到系统限制。请返回，使用图片识别或粘贴订阅链接。")
            return
        }
        guard DataScannerViewController.isAvailable else {
            message = String(localized: "相机扫描暂不可用。请返回重试，或使用图片识别与粘贴。"); return
        }
        ready = true
    }
}

private struct LiveSubscriptionScanner: UIViewControllerRepresentable {
    let selected: (String) -> Void
    let failed: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(selected: selected, failed: failed) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced, recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }
    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !scanner.isScanning, !context.coordinator.finished else { return }
        do { try scanner.startScanning() }
        catch {
            context.coordinator.finished = true
            let report = failed
            Task { @MainActor in report(String(localized: "未能启动相机扫描。请取消后重试，或从图片识别二维码。")) }
        }
    }
    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        coordinator.finished = true
        scanner.stopScanning(); scanner.delegate = nil
    }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let selected: (String) -> Void
        let failed: (String) -> Void
        var finished = false
        init(selected: @escaping (String) -> Void, failed: @escaping (String) -> Void) {
            self.selected = selected; self.failed = failed
        }
        func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard !finished, case .barcode(let barcode) = item,
                  let value = barcode.payloadStringValue else { return }
            guard let link = try? SubscriptionLink.parse(value) else {
                failed(String(localized: "这个二维码不是有效订阅链接。请轻点其他二维码，或取消后更换导入方式。"))
                return
            }
            finished = true; scanner.stopScanning()
            selected(link.absoluteString)
        }
        func dataScanner(_ scanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            guard !finished else { return }
            finished = true; scanner.stopScanning()
            failed(String(localized: "相机扫描已中断。请取消后重试，或从图片识别二维码。"))
        }
    }
}

struct DetailView: View {
    @State private var clearingHistory = false
    @State private var exportingHistory = false
    @State private var exportRows: [QuotaReading] = []
    let id: UUID
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showReset = false
    @State private var deleting = false
    @State private var error: String?
    @State private var renaming = false
    @State private var editedName = ""
    var body: some View {
        if let item = store.items.first(where: { $0.id == id }) {
            List {
                Section {
                    QuotaCard(item: item, error: store.errors[id], loading: store.loading.contains(id))
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section("本次读数") {
                    Button("修改名称") { editedName = item.name; renaming = true }
                    LabeledContent("上传", value: amount(item.reading?.upload))
                    LabeledContent("下载", value: amount(item.reading?.download))
                    LabeledContent("套餐到期", value: item.reading?.expires?.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "未提供"))
                    Button { showReset = true } label: {
                        LabeledContent("流量重置", value: item.reset.map { $0.formatted(date: .abbreviated, time: .omitted) + String(localized: " · 手动") } ?? String(localized: "设置日期"))
                    }
                    if let reset = item.reset, reset < Calendar.current.startOfDay(for: .now) {
                        Text("手动日期已过，不会自动顺延或清零服务商流量。").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    NavigationLink("历史观测图") { HistoryChartView(id: id) }
                    Toggle("记录历史读数", isOn: Binding(get: { item.historyPaused != true }, set: { enabled in
                        do { try store.setHistoryRecording(enabled, id: id) } catch { self.error = SubscriptionStore.message(error) }
                    }))
                    ForEach(Array(HistoryRecords.retained(item.history).suffix(30).reversed().enumerated()), id: \.offset) { _, reading in
                        LabeledContent {
                            Text(amount(reading.remaining)).monospacedDigit()
                        } label: {
                            Text(reading.observed.formatted(date: .abbreviated, time: .shortened)).font(.subheadline)
                        }
                    }
                    if HistoryRecords.retained(item.history).isEmpty { Text(item.historyPaused == true ? String(localized: "已暂停记录，当前读数仍可刷新") : String(localized: "尚无历史读数，下次查询成功后开始记录")).foregroundStyle(.secondary) }
                    Button("预览并导出 CSV", systemImage: "square.and.arrow.up") {
                        exportRows = HistoryRecords.retained(item.history); exportingHistory = true
                    }.disabled(HistoryRecords.retained(item.history).isEmpty)
                    Button("清空此订阅历史", role: .destructive) { clearingHistory = true }.disabled(item.history.isEmpty)
                } header: { Text("近期读数") } footer: { Text("保留本机最近 90 天的观测记录，每个订阅最多 2,000 条；此处显示最近 30 条。不是连续计量，不推算每日实际用量。") }
                Section { Button("删除本机订阅", role: .destructive) { deleting = true } }
            }
            .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("刷新", systemImage: "arrow.clockwise") { Task { await store.refresh(id) } }.disabled(store.loading.contains(id) || store.demo) } }
            .refreshable { await store.refresh(id) }
            .sheet(isPresented: $showReset) { ResetView(id: id, initial: item.reset) }
            .sheet(isPresented: $exportingHistory) { HistoryExportView(rows: exportRows) }
            .alert("清空此订阅的本机历史？", isPresented: $clearingHistory) {
                Button("清空历史", role: .destructive) {
                    do { try store.clearHistory(id: id) } catch { self.error = SubscriptionStore.message(error) }
                }
                Button("取消", role: .cancel) { }
            } message: { Text("此操作无法撤销。若此订阅已开启同步，清空历史的更改也会同步。保留链接、当前读数和手动日期，不会清零服务商流量。") }
            .alert("修改名称", isPresented: $renaming) {
                TextField("订阅名称", text: $editedName)
                Button("保存") {
                    do { try store.rename(editedName, id: id) } catch { self.error = SubscriptionStore.message(error) }
                }.disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("取消", role: .cancel) { }
            }
            .confirmationDialog("删除本机订阅？", isPresented: $deleting, titleVisibility: .visible) {
                Button("删除订阅", role: .destructive) {
                    do { try store.remove(id); dismiss() } catch { self.error = SubscriptionStore.message(error) }
                }
                Button("取消", role: .cancel) { }
            } message: { Text("删除此设备的链接和历史记录，并停止接收此订阅的同步。iCloud 和其他设备的数据会保留，不会取消服务商套餐。") }
            .alert("未能完成操作", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        } else { ContentUnavailableView("订阅已删除", systemImage: "tray") }
    }
}

struct HistoryCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct HistoryChartView: View {
    let id: UUID
    @Environment(SubscriptionStore.self) private var store
    @State private var days = 7
    @State private var now = Date.now
    var body: some View {
        let rows = HistoryRecords.window(store.items.first(where: { $0.id == id })?.history ?? [], days: days, now: now)
        let points = rows.filter { $0.remaining != nil }
        List {
            Section {
                Picker("时间范围", selection: $days) {
                    Text("近 7 天").tag(7)
                    Text("近 30 天").tag(30)
                }.pickerStyle(.segmented)
                if points.isEmpty {
                    ContentUnavailableView("没有可绘制的读数", systemImage: "chart.xyaxis.line", description: Text(rows.isEmpty ? String(localized: "此时间范围内没有历史记录。可切换范围，或在查询成功后查看。") : String(localized: "此时间范围内的记录未提供剩余流量，不能绘制为零。")))
                } else {
                    Chart(Array(points.enumerated()), id: \.offset) { _, reading in
                        if let remaining = reading.remaining {
                            PointMark(x: .value("读取时间", reading.observed), y: .value("剩余流量（GiB）", Double(remaining) / 1_073_741_824))
                                .foregroundStyle(.orange)
                                .accessibilityLabel(Text(reading.observed.formatted(date: .abbreviated, time: .shortened)))
                                .accessibilityValue(Text("剩余 \(amount(reading.remaining))"))
                        }
                    }
                    .chartXScale(domain: (Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now)...now)
                    .chartXScale(range: .plotDimension(padding: 8))
                    .chartYScale(domain: 0...max(1, Double(points.compactMap(\.remaining).max() ?? 0) / 1_073_741_824 * 1.1))
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
                    .chartYAxisLabel("GiB")
                    // The full-size record list below provides the same values at accessibility sizes.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(height: 220)
                    .accessibilityIdentifier("history-observation-chart")
                }
                Text("每个点代表一次读取，不连线、不推算每日用量。额度或周期可能变化，请结合下方原始记录查看。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                ForEach(Array(rows.suffix(30).reversed().enumerated()), id: \.offset) { _, reading in
                    LabeledContent(reading.observed.formatted(date: .abbreviated, time: .shortened), value: reading.remaining.map { amount($0) } ?? String(localized: "未提供"))
                }
            } header: { Text("范围内记录") } footer: { Text("共 \(rows.count) 条，列表最多显示最近 30 条。未提供剩余流量的记录仅列出，不绘制。") }
        }
        .navigationTitle("历史观测图").navigationBarTitleDisplayMode(.inline)
        .onAppear { now = .now }
        .onChange(of: days) { now = .now }
    }
}

struct HistoryExportView: View {
    let rows: [QuotaReading]
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("包含读取时间和流量数字，不包含订阅名称、链接或凭据。时间使用 UTC，流量单位为字节；空白字段表示未提供。")
                    Text("导出 \(rows.count) 条记录，以下预览前 10 条。")
                }
                Section("CSV 预览") {
                    ScrollView(.horizontal) {
                        Text(HistoryRecords.csv(Array(rows.prefix(10)))).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                Section {
                    Button("存储 CSV 文件", systemImage: "doc.badge.arrow.up") { saving = true }
                    Text("请选择你信任的存储位置。导出文件不受 App 内的数据保护设置控制。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("导出历史").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } } }
                .fileExporter(isPresented: $saving, document: HistoryCSVDocument(text: HistoryRecords.csv(rows)), contentType: .commaSeparatedText, defaultFilename: "ByteKibble-history") { result in
                    switch result {
                    case .success: dismiss()
                    case .failure(let failure):
                        if (failure as NSError).code != NSUserCancelledError { error = String(localized: "未能存储文件，请选择其他位置后重试。") }
                    }
                }
        }
    }
}

struct ResetView: View {
    let id: UUID
    let initial: Date?
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("下一次重置", selection: $date, displayedComponents: .date)
                Text("这是你的手动记录，不是服务商确认的重置日。不会清零流量，也不会自动顺延。").font(.footnote).foregroundStyle(.secondary)
                if initial != nil { Button("清除手动日期", role: .destructive) { save(nil) } }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("手动重置日期").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") { save(date) } }
                }
                .onAppear { date = initial ?? .now }
        }.presentationDetents([.medium, .large])
    }
    private func save(_ date: Date?) {
        do { try store.setReset(date, id: id); dismiss() } catch { self.error = SubscriptionStore.message(error) }
    }
}

struct SettingsSymbol: View {
    let name: String
    var body: some View {
        Image(systemName: name).font(.system(size: 18, weight: .medium))
            .foregroundStyle(.orange).frame(width: 36, height: 36)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

struct SyncRouteIllustration: View {
    var body: some View {
        HStack(spacing: 12) {
            node("laptopcomputer", "Mac")
            Image(systemName: "arrow.right").foregroundStyle(.tertiary).accessibilityHidden(true)
            node("icloud", "iCloud")
            Image(systemName: "arrow.right").foregroundStyle(.tertiary).accessibilityHidden(true)
            node(UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone.gen3", "此设备")
        }.frame(maxWidth: .infinity).padding(.vertical, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("先在 Mac 选择订阅，再通过 iCloud 传到此设备"))
    }
    private func node(_ icon: String, _ title: LocalizedStringKey) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 30, weight: .light))
                .foregroundStyle(.orange).frame(width: 62, height: 56)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct SettingsView: View {
    @State private var showingWelcome = false
    @EnvironmentObject private var sync: SyncLibrary
    @Environment(WidgetSharing.self) private var widgets
    @Environment(ReminderSettings.self) private var reminders
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.openURL) private var openURL
    var body: some View {
        @Bindable var reminders = reminders
        @Bindable var widgets = widgets
        List {
            Section {
                SyncRouteIllustration().listRowSeparator(.hidden)
                NavigationLink { SyncSettingsView() } label: {
                    HStack(spacing: 12) {
                        SettingsSymbol(name: "icloud")
                        Text("iCloud 同步")
                        Spacer()
                        Image(systemName: sync.accountScope == nil ? "pause.circle" : "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text(sync.accountScope == nil ? "未开启" : "已开启"))
                    }
                }.accessibilityLabel(Text("iCloud 同步"))
                NavigationLink { ManualTransferView() } label: {
                    HStack(spacing: 12) { SettingsSymbol(name: "lock.doc"); Text("手动传输") }
                }
            }
            Section {
                Picker(selection: $widgets.selection) {
                    Text("不显示").tag("")
                    ForEach(store.items) { Text($0.name).tag($0.id.uuidString) }
                    if !widgets.selection.isEmpty && !store.items.contains(where: { $0.id.uuidString == widgets.selection }) {
                        Text("订阅已移除").tag(widgets.selection)
                    }
                } label: {
                    HStack(spacing: 12) { SettingsSymbol(name: "rectangle.grid.1x2"); Text("显示的订阅") }
                }.disabled(store.demo)
                DisclosureGroup {
                    Text("仅共享流量数字和读取时间，不包含订阅名称或链接。小组件不会自行联网查询，超过一小时的读数会标为旧读数。关闭后，系统可能延迟移除已显示的内容。")
                        .font(.footnote).foregroundStyle(.secondary)
                } label: { Label("小组件与隐私", systemImage: "info.circle").font(.subheadline).foregroundStyle(.secondary) }
                if let error = widgets.error { Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.secondary) }
            } header: { Text("小组件") }
            Section {
                if reminders.enabled {
                    Toggle(isOn: $reminders.enabled) {
                        HStack(spacing: 12) { SettingsSymbol(name: "bell.badge"); Text("订阅提醒") }
                    }.disabled(store.demo)
                } else {
                    Button { Task { await reminders.enable() } } label: {
                        HStack(spacing: 12) { SettingsSymbol(name: "bell.badge"); Text("开启订阅提醒") }
                    }.disabled(store.demo)
                }
                if reminders.permission == .denied {
                    Button("前往系统通知设置") { if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) } }
                }
                Toggle(isOn: $reminders.background) {
                    HStack(spacing: 12) { SettingsSymbol(name: "arrow.clockwise"); Text("尝试后台刷新") }
                }.disabled(store.demo)
                DisclosureGroup {
                    Text("提醒不包含订阅名称或链接。低流量提醒依据最近读数，每个订阅最多每天一次；日期提醒计划在当天 9:00 触发，最多安排最近 32 条。系统可能延迟提醒与后台运行，锁定设备时不会读取订阅凭据。")
                        .font(.footnote).foregroundStyle(.secondary)
                } label: { Label("提醒如何工作", systemImage: "info.circle").font(.subheadline).foregroundStyle(.secondary) }
                if let message = reminders.message { Label(message, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.secondary) }
            } header: { Text("提醒与刷新") }
            Section {
                Button { showingWelcome = true } label: {
                    HStack(spacing: 12) { SettingsSymbol(name: "hand.raised"); Text("使用说明与隐私") }
                }
                NavigationLink {
                    List {
                        Section {
                            Label("本机钥匙串保存订阅链接", systemImage: "key")
                            Label("本机解析服务商响应", systemImage: "iphone")
                            Text("查询直接连接订阅服务商。开启 iCloud 后，所选订阅的数据通过 iCloud 同步，链接通过 iCloud 钥匙串同步。不发送到 MU LABS。")
                        }
                        Section("数据说明") {
                            Text("流量由服务商返回，不统计设备全部网络流量。缺少的数据显示为“—”，而不是零。")
                            Text("1 GiB = 1,073,741,824 字节。不同客户端采用不同单位时，显示数字可能不同。")
                            Text("后台刷新可能延迟或不执行。低流量提醒不是实时监控，请结合读数时间判断。")
                        }
                    }.navigationTitle("数据说明")
                } label: {
                    HStack(spacing: 12) { SettingsSymbol(name: "chart.pie"); Text("数据说明") }
                }
            } header: { Text("隐私与数据") }
            Section {
                HStack(spacing: 12) {
                    SettingsSymbol(name: "shippingbox")
                    Text("ByteKibble").font(.headline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("MU LABS").font(.caption.weight(.medium))
                        Text("0.1 · 开发预览").font(.caption2).foregroundStyle(.secondary)
                    }
                }.accessibilityElement(children: .combine)
            }
        }.navigationTitle("设置").task { await reminders.checkPermission() }
            .sheet(isPresented: $showingWelcome) { WelcomeView(finish: { showingWelcome = false }) }
    }
}
