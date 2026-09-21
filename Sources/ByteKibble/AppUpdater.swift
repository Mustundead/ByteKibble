import AppKit
import SwiftUI
#if !BYTEKIBBLE_APP_STORE
import Sparkle
#endif

/// Sparkle owns scheduling and preferences; no subscription data enters this path.
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()
    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = false
#if !BYTEKIBBLE_APP_STORE
    private var controller: SPUStandardUpdaterController?
#endif

    func start() {
#if BYTEKIBBLE_APP_STORE
        // Mac App Store builds receive updates from the store. Sparkle and its
        // feed are deliberately absent from this target.
        return
#else
#if BYTEKIBBLE_ACCEPTANCE
        guard CommandLine.arguments.contains("--updater-acceptance"),
              Bundle.main.bundleIdentifier == "com.mulabs.bytekibble.acceptance" else { return }
#else
        guard Bundle.main.bundleIdentifier == "com.mulabs.bytekibble" else { return }
#endif
        guard controller == nil,
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") is String else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticChecks)
        controller.startUpdater()
#endif
    }

    func check() {
#if BYTEKIBBLE_APP_STORE
        return
#else
        guard canCheck else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
#endif
    }

    func setAutomaticChecks(_ enabled: Bool) {
#if !BYTEKIBBLE_APP_STORE
        controller?.updater.automaticallyChecksForUpdates = enabled
#endif
    }
}

struct UpdateMenu: View {
    @ObservedObject private var updater = AppUpdater.shared
    var body: some View {
        Menu {
            Button(L10n.t("检查更新…")) { updater.check() }
                .disabled(!updater.canCheck)
            Toggle(L10n.t("自动检查更新"), isOn: Binding(
                get: { updater.automaticChecks }, set: { updater.setAutomaticChecks($0) }))
            Divider()
            Button("GitHub") { AppInfo.openRepo() }
        } label: {
            Text(AppInfo.versionLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(L10n.t("软件更新"))
    }
}
