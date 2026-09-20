#if BYTEKIBBLE_ACCEPTANCE
import SwiftUI
import ServiceManagement

/// Native QA-only host. Uses MenuView unchanged, synthetic data and an isolated store.
/// Compiled only with -DBYTEKIBBLE_ACCEPTANCE; absent from normal builds.
@MainActor
struct AcceptanceHarness: View {
    final class FixtureSource {
        let domain = "com.bytekibble.acceptance.\(UUID().uuidString)"
        let defaults: UserDefaults
        var clients: [SubTarget] = []

        init() {
            defaults = UserDefaults(suiteName: domain)!
            clients = Self.targets("Normal")
        }
        deinit { defaults.removePersistentDomain(forName: domain) }

        static func targets(_ scene: String) -> [SubTarget] {
            if scene == "Empty" { return [] }
            let names = scene == "Multiple" ? ["Alpha", "Beta"] : [scene]
            return names.map { name in
                let url = "https://\(name.lowercased().replacingOccurrences(of: " ", with: "-")).example/sub"
                let cached: QuotaSample? = scene == "Cache failure" ? sample(download: 55, live: false) : nil
                return SubTarget(id: url, name: scene == "Long name" ? "A deliberately long subscription name · International shared traffic plan" : name,
                                 origin: scene == "Cache failure" ? "sntp" : "verge", url: url, cached: cached)
            }
        }
        static func sample(download: Int64, live: Bool = true, expired: Bool = false) -> QuotaSample {
            QuotaSample(uploaded: 5 * 1_073_741_824, downloaded: download * 1_073_741_824,
                        total: 100 * 1_073_741_824,
                        expireAt: Date().addingTimeInterval(expired ? -86400 : 86400 * 12),
                        resetDay: 4,
                        fetchedAt: live ? Date() : nil, source: live ? .live : .cache)
        }
        func fetch(_ url: String) async throws -> QuotaSample {
            let host = URL(string: url)?.host ?? ""
            try await Task.sleep(nanoseconds: host == "loading.example" ? 30_000_000_000 : 400_000_000)
            if host.contains("failure") {
                throw Fetcher.Failure(message: L10n.t("无法连接。请检查网络和代理客户端后重试。"))
            }
            if host.contains("missing") {
                throw Fetcher.Failure(message: L10n.t("订阅流量信息不完整，无法计算剩余量。"))
            }
            if host.contains("sip008") {
                return try Fetcher.parseSIP008(data: Data("{\"version\":1,\"servers\":[],\"bytes_used\":26843545600,\"bytes_remaining\":80530636800}".utf8))
            }
            if host.contains("quantumult") {
                return try Fetcher.parse(header: "upload=2375927198; download=12983696043; total=1099511627776; expire=1862111613")
            }
            return Self.sample(download: host.contains("warning") ? 80 : host.contains("critical") ? 90 : host.contains("exhausted") ? 110 : 32,
                               expired: host.contains("expired"))
        }
    }

    private let source: FixtureSource
    @StateObject private var vm: ViewModel
    @State private var scene = "Normal"
    @State private var dark = false
    @State private var reduceMotion = false
    @State private var highContrast = false
    @State private var language = "en"
    @State private var largeText = false
    @State private var loginState = "Off"
    @State private var showWelcome = false
    @State private var menuPreview: MenuPopoverController?

    init() {
        let source = FixtureSource()
        self.source = source
        if CommandLine.arguments.contains("--compat-screenshot") {
            let quantumult = CommandLine.arguments.contains("--quantumult")
            let target = SubTarget(id: "compat-example", name: quantumult ? "Quantumult" : "Shadowsocks SIP008",
                                   origin: "custom", url: quantumult ? "https://quantumult.example/sub" : "https://sip008.example/sub", cached: nil)
            source.clients = [target]
            let vm = ViewModel(defaults: source.defaults, scan: { source.clients },
                               automaticRefresh: false, fetch: { try await source.fetch($0) })
            vm.targets = [target]
            vm.selectedID = target.id
            if CommandLine.arguments.contains("--manual-reset") {
                vm.setManualResetDate(Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
            }
            vm.samples[target.id] = quantumult
                ? try! Fetcher.parse(header: "upload=2375927198; download=12983696043; total=1099511627776; expire=1862111613")
                : try! Fetcher.parseSIP008(data: Data("{\"version\":1,\"servers\":[],\"bytes_used\":26843545600,\"bytes_remaining\":80530636800}".utf8))
            _vm = StateObject(wrappedValue: vm)
            _dark = State(initialValue: !CommandLine.arguments.contains("--light"))
            let language = CommandLine.arguments.contains("--zh") ? "zh-Hans" : "en"
            _language = State(initialValue: language)
            L10n.setAcceptanceLanguage(language)
            return
        }
        if CommandLine.arguments.contains("--readme-screenshot") {
            let vm = ViewModel(preview: true, defaults: source.defaults)
            let target = SubTarget(id: "readme-example", name: "Premium", origin: "sntp",
                                   url: "https://example.com/sub", cached: nil)
            vm.targets = [target]
            vm.selectedID = target.id
            vm.samples[target.id] = QuotaSample(uploaded: 0, downloaded: 0,
                total: 1000 * 1_073_741_824,
                expireAt: Date().addingTimeInterval(180 * 86400), resetDay: 30,
                fetchedAt: Date(), source: .live)
            _vm = StateObject(wrappedValue: vm)
            _dark = State(initialValue: true)
            return
        }
        _vm = StateObject(wrappedValue: ViewModel(defaults: source.defaults,
            scan: { source.clients + Providers.custom(defaults: source.defaults) },
            fetch: { try await source.fetch($0) }))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("QA · Synthetic data · Isolated preferences").font(.caption)
                Picker("Scenario", selection: $scene) {
                    ForEach(["Normal", "Quantumult", "SIP008", "Warning", "Critical", "Exhausted", "Expired", "Multiple", "Long name", "Empty", "Loading", "First failure", "Cache failure", "Missing"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                HStack {
                    Toggle("Dark", isOn: $dark)
                    Toggle("Reduce motion", isOn: $reduceMotion)
                    Toggle("Contrast", isOn: $highContrast)
                    Toggle("Large text", isOn: $largeText)
                }.font(.caption)
                HStack {
                    Button("Welcome preview") { showWelcome = true }
                    Button("Popover preview") { menuPreview?.showScreenshotPreview() }
                    Button("Sync preview") { SyncWindow.shared.show(vm: vm) }
                    Picker("Language", selection: $language) {
                        ForEach(["en", "zh-Hans", "zh-Hant", "ja", "ko"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Login", selection: $loginState) {
                        ForEach(["Off", "Enabled", "Pending", "Error"], id: \.self) { Text($0).tag($0) }
                    }
                }.font(.caption)
            }.padding(12)
            Divider()
            MenubarLabel(vm: vm).padding(6)
            MenuView(vm: vm, allowsSystemChanges: false,
                     reduceMotionOverride: reduceMotion, highContrastOverride: highContrast,
                     loginStatusOverride: loginState == "Enabled" ? .enabled : loginState == "Pending" ? .requiresApproval : .notRegistered,
                     loginErrorOverride: loginState == "Error" ? L10n.t("无法更改开机启动。请在系统设置中检查登录项。") : nil)
                .dynamicTypeSize(largeText ? .accessibility1 : .large)
                .environment(\.locale, Locale(identifier: language))
        }
        .frame(width: 400)
        .preferredColorScheme(dark ? .dark : .light)
        .sheet(isPresented: $showWelcome) {
            WelcomeView { showWelcome = false }
                .preferredColorScheme(dark ? .dark : .light)
        }
        .onAppear {
            if menuPreview == nil {
                menuPreview = MenuPopoverController(vm: vm, allowsSystemChanges: false)
                menuPreview?.setPreviewAppearance(dark: dark)
                if CommandLine.arguments.contains("--readme-screenshot") || CommandLine.arguments.contains("--compat-screenshot") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        menuPreview?.showScreenshotPreview()
                    }
                }
            }
        }
        .onChange(of: dark) { value in menuPreview?.setPreviewAppearance(dark: value) }
        .onChange(of: language) { value in
            L10n.setAcceptanceLanguage(value)
            vm.objectWillChange.send()
        }
        .onChange(of: scene) { value in
            source.defaults.removeObject(forKey: "customTargets")
            source.clients = FixtureSource.targets(value)
            vm.samples = [:]
            vm.rescan()
            if let first = source.clients.first { vm.selectedID = first.id }
            Task { await vm.refreshLive() }
        }
    }
}
#endif
