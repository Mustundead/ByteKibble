import AppKit
import CloudKit
import ByteKibbleCore

/// Explicit development-only synthetic probe. Never selects or reads provider subscriptions.
@MainActor enum CloudAcceptance {
    static func run(id: UUID, cleanup: Bool) async -> Bool {
        guard Bundle.main.object(forInfoDictionaryKey: "ByteKibbleCloudEnabled") as? Bool == true else { return false }
        let transport = CloudSyncTransport()
        defer { transport.disable() }
        var phase = "account"
        do {
            let account = try await transport.enable()
            phase = "credential"
            let vault = try SyncCredentialVault(accessGroup: "46P646AZCB.com.mulabs.bytekibble.sync", accountID: account)
            let reading = QuotaReading(upload: 0, download: 0, total: 100, used: 0, expires: nil, observed: Date(timeIntervalSince1970: 1_700_000_000))
            let fixture = SyncRecord(id: id, revision: id, credentialRevision: id, name: "ByteKibble QA — synthetic", reading: reading, history: [reading])
            let url = URL(string: "https://example.invalid/bytekibble-acceptance/" + id.uuidString)!
            let database = CKContainer(identifier: "iCloud.com.mulabs.bytekibble").privateCloudDatabase
            let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: CloudSyncCodec.zoneID)
            if cleanup {
                do {
                    let found = try CloudSyncCodec.decode(await database.record(for: recordID))
                    guard found == fixture else { return false }
                    _ = try await database.deleteRecord(withID: recordID)
                } catch let error as CKError where error.code == .unknownItem { }
                try vault.removeRevision(recordID: id, revision: id)
                print("Synthetic cloud fixture removed.")
            } else {
                try vault.save(url, recordID: id, revision: id)
                phase = "zone"
                try await transport.prepareZone()
                phase = "upload"
                _ = try await transport.upload(.init(record: fixture, base: nil))
                phase = "read-back"
                let received = try CloudSyncCodec.decode(await database.record(for: recordID))
                guard received == fixture else { return false }
                print("Synthetic cloud metadata round-trip passed.")
            }
            return true
        } catch {
            // Only domain/code are diagnostic; error descriptions can contain account metadata.
            let error = error as NSError
            print("Cloud acceptance failed at \(phase): \(error.domain) / \(error.code)")
            let diagnostic = error.localizedDescription.replacingOccurrences(of: #"https?://\S+|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, with: "[redacted]", options: [.regularExpression, .caseInsensitive])
            print(diagnostic)
            return false
        }
    }
}
