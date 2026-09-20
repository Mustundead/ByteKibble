import SwiftUI

@main struct ByteKibbleApp: App {
    @State private var store = SubscriptionStore(demo: ProcessInfo.processInfo.arguments.contains("--demo"))
    @State private var reminders = ReminderSettings()
    @State private var widgets = WidgetSharing()
    @StateObject private var sync = SyncLibrary(
        directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Sync"),
        accessGroup: "46P646AZCB.com.mulabs.bytekibble.sync")
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(reminders).environment(widgets).environmentObject(sync).tint(.orange)
                .task {
                    reconcileDerivedState()
                    await synchronizeApprovedAccount()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(300)) } catch { return }
                        if phase == .active { await synchronizeApprovedAccount() }
                    }
                }
                .onChange(of: store.items) { _, _ in reconcileDerivedState() }
                .onChange(of: widgets.selection) { _, _ in reconcileDerivedState() }
                .onChange(of: reminders.enabled) { _, _ in reconcileDerivedState() }
                .onChange(of: reminders.background) { _, _ in if !store.demo { reminders.scheduleBackground() } }
                .onChange(of: phase) { _, phase in
                    guard !store.demo else { return }
                    if phase == .active {
                        store.retryProtectedLoad(); reconcileDerivedState()
                        Task { await synchronizeApprovedAccount() }
                    }
                    if phase == .background { reminders.scheduleBackground() }
                }
        }
        .backgroundTask(.appRefresh(ReminderSettings.backgroundID)) {
            await refreshInBackground()
        }
    }
    @MainActor private func refreshInBackground() async {
        guard reminders.background, !store.demo else { return }
        reminders.scheduleBackground()
        guard UIApplication.shared.isProtectedDataAvailable, !Task.isCancelled else { return }
        store.retryProtectedLoad()
        guard store.recordsAvailable else { return }
        await store.refreshAll(while: { reminders.background && UIApplication.shared.isProtectedDataAvailable })
        if !Task.isCancelled { await synchronizeApprovedAccount() }
        reconcileDerivedState()
    }
    @MainActor private func synchronizeApprovedAccount() async {
        guard !store.demo, store.recordsAvailable, !sync.busy,
              UIApplication.shared.isProtectedDataAvailable,
              let scope = UserDefaults.standard.string(forKey: "sync.approvedAccount") else { return }
        do {
            if sync.accountScope == nil { try await sync.connect(expectedScope: scope) }
            guard sync.accountScope == scope else { return }
            try store.stageSyncChanges(in: sync)
            try await sync.synchronize()
            try store.applySync(sync)
            reconcileDerivedState()
        } catch SyncValidationError.accountChanged {
            UserDefaults.standard.removeObject(forKey: "sync.approvedAccount")
        } catch { /* Explicit sync exposes retry; local data is unchanged. */ }
    }
    @MainActor private func reconcileDerivedState() {
        DerivedStateCoordinator.reconcile(store: store, reminders: reminders, widgets: widgets)
    }
}

@MainActor enum DerivedStateCoordinator {
    static func reconcile(store: SubscriptionStore, reminders: ReminderSettings, widgets: WidgetSharing) {
        guard !store.demo else { return }
        // Unknown source state is not an empty subscription list. Explicit opt-out is still honored.
        if store.recordsAvailable || !reminders.enabled { reminders.reconcile(store.items) }
        if store.recordsAvailable || widgets.selection.isEmpty { widgets.update(store.items, demo: false) }
    }
}
