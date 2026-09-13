import Foundation

/// Explicit, offline acceptance mode executed inside the signed release app.
/// It creates only UUID-scoped dummy credentials and isolated preferences.
/// Production preferences, discovered clients and the updater are never opened.
@MainActor
enum CredentialAcceptance {
    static func run() -> Bool {
        let namespace = "com.bytekibble.credential-acceptance." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: namespace) else { return false }
        let store = KeychainCredentialStore(service: namespace)
        let legacyURL = "https://acceptance.invalid/sub?token=dummy-legacy"
        let addedURL = "https://acceptance.invalid/sub?token=dummy-added"
        let keys = [legacyURL, addedURL].map(Providers.credentialKey)
        var passed = true
        func check(_ condition: Bool, _ name: String) {
            print("\(condition ? "PASS" : "FAIL") \(name)")
            passed = passed && condition
        }
        let date = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400 * 7))
        defaults.set([["url": legacyURL, "name": "Acceptance"]], forKey: "customTargets")
        defaults.set(legacyURL, forKey: "selectedTargetID")
        defaults.set([Providers.dedupeKey(legacyURL): date.timeIntervalSince1970], forKey: "manualResetDates")
        let vm = ViewModel(defaults: defaults,
                           scan: { Providers.custom(defaults: defaults, store: store) },
                           credentialStore: store, automaticRefresh: false)
        check(store.read(for: keys[0]) == legacyURL, "legacy credential migrated to real Keychain")
        check(vm.selected?.url == legacyURL && vm.manualResetDate == date, "selection and reset date preserved")
        check(!String(describing: defaults.persistentDomain(forName: namespace)).contains("dummy-legacy"), "legacy token absent from preferences")
        check(vm.addCustom(url: addedURL), "new credential saved")
        check(store.read(for: keys[1]) == addedURL, "new credential read back")
        let reopened = ViewModel(defaults: defaults,
                                 scan: { Providers.custom(defaults: defaults, store: store) },
                                 credentialStore: store, automaticRefresh: false)
        check(reopened.selected?.url == addedURL, "selection restored from hashed identifier")
        if let target = reopened.selected {
            reopened.removeCustom(id: target.id)
            check(store.read(for: keys[1]) == nil, "removed credential absent from Keychain")
            reopened.undoRemoval()
            check(store.read(for: keys[1]) == addedURL, "undo restores credential")
        } else { check(false, "removal target available") }
        check(!String(describing: defaults.persistentDomain(forName: namespace)).contains("dummy-"), "all tokens absent from preferences")
        for key in keys {
            check(store.remove(for: key) && store.read(for: key) == nil, "dummy credential cleanup")
        }
        defaults.removePersistentDomain(forName: namespace)
        print("Credential acceptance: \(passed ? "PASS" : "FAIL"). No real subscriptions queried.")
        return passed
    }
}
