import XCTest
@testable import ByteKibble

final class CredentialStoreTests: XCTestCase {
    private var domains: [String] = []
    private func isolatedDefaults() -> UserDefaults {
        let domain = "CredentialStoreTests.\(UUID().uuidString)"
        domains.append(domain)
        return UserDefaults(suiteName: domain)!
    }
    override func tearDown() {
        for domain in domains { UserDefaults(suiteName: domain)?.removePersistentDomain(forName: domain) }
        super.tearDown()
    }
    func testAddAndRemoveKeepURLOutOfDefaults() {
        let d = isolatedDefaults()
        let store = InMemoryCredentialStore(); let url = "https://example.com/sub?token=secret"
        XCTAssertTrue(Providers.addCustom(url: url, defaults: d, store: store))
        XCTAssertFalse(String(describing: d.dictionaryRepresentation()).contains("secret"))
        XCTAssertEqual(Providers.custom(defaults: d, store: store).first?.url, url)
        XCTAssertTrue(Providers.removeCustom(url: url, defaults: d, store: store))
        XCTAssertTrue(Providers.custom(defaults: d, store: store).isEmpty)
    }

    func testMigrationIsTransactionalOnWriteFailure() {
        let d = isolatedDefaults()
        let url = "https://example.com/sub?token=secret"
        d.set([["url": url, "name": "Example"]], forKey: "customTargets")
        let store = InMemoryCredentialStore(); store.failWrites = true
        XCTAssertEqual(Providers.custom(defaults: d, store: store).first?.url, url)
        XCTAssertNotNil((d.array(forKey: "customTargets") as? [[String: String]])?.first?["url"])
    }

    func testAddAndRemoveReportStoreFailures() {
        let d = isolatedDefaults()
        let store = InMemoryCredentialStore(); store.failWrites = true
        XCTAssertFalse(Providers.addCustom(url: "https://example.com/sub", defaults: d, store: store))
        store.failWrites = false; XCTAssertTrue(Providers.addCustom(url: "https://example.com/sub", defaults: d, store: store))
        store.failRemoves = true
        XCTAssertFalse(Providers.removeCustom(url: "https://example.com/sub", defaults: d, store: store))
    }

    func testMixedRecordsRemainReadableAfterFailedMigration() {
        let d = isolatedDefaults()
        let store = InMemoryCredentialStore()
        let secureURL = "https://secure.example/sub"
        XCTAssertTrue(Providers.addCustom(url: secureURL, defaults: d, store: store))
        var records = d.array(forKey: "customTargets") as! [[String: String]]
        records.append(["url": "https://legacy.example/sub?token=secret", "name": "Legacy"])
        d.set(records, forKey: "customTargets")
        store.failWrites = true
        var failed = false
        XCTAssertEqual(Providers.custom(defaults: d, store: store, onStorageFailure: { failed = true }).count, 2)
        XCTAssertTrue(failed)
        XCTAssertEqual(d.array(forKey: "customTargets") as? [[String: String]], records)
        XCTAssertFalse(Providers.addCustom(url: "https://new.example/sub", defaults: d, store: store))
        store.failWrites = false
        XCTAssertEqual(Providers.custom(defaults: d, store: store).count, 2)
        XCTAssertFalse(String(describing: d.array(forKey: "customTargets")).contains("secret"))
    }

    func testUnavailableItemReportsFailureWithoutDeletingMetadata() {
        let d = isolatedDefaults()
        let records = [["id": "subscription.missing", "name": "Saved"]]
        d.set(records, forKey: "customTargets")
        var failed = false
        XCTAssertTrue(Providers.custom(defaults: d, store: InMemoryCredentialStore(), onStorageFailure: { failed = true }).isEmpty)
        XCTAssertTrue(failed)
        XCTAssertEqual(d.array(forKey: "customTargets") as? [[String: String]], records)
    }

    func testLegacyUnsupportedURLIsPreservedInSecureStorage() {
        let d = isolatedDefaults()
        let store = InMemoryCredentialStore()
        let legacy = "http://example.com/sub?token=old-secret"
        d.set([["url": legacy]], forKey: "customTargets")
        _ = Providers.custom(defaults: d, store: store)
        XCTAssertEqual(store.read(for: Providers.credentialKey(for: legacy)), legacy)
        XCTAssertFalse(String(describing: d.array(forKey: "customTargets")).contains("old-secret"))
    }
}
