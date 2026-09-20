import Foundation
import CloudKit

/// New encrypted fields only. The public database and subscription URLs are never used.
public enum CloudSyncCodec {
    public static let recordType = "ByteKibbleSubscriptionV1"
    public static let zoneID = CKRecordZone.ID(zoneName: "ByteKibbleSyncV1", ownerName: CKCurrentUserDefaultName)

    public static func encode(_ value: SyncRecord, into existing: CKRecord? = nil) throws -> CKRecord {
        let id = CKRecord.ID(recordName: value.id.uuidString, zoneID: zoneID)
        let record = existing ?? CKRecord(recordType: recordType, recordID: id)
        guard record.recordID == id, record.recordType == recordType else { throw SyncValidationError.invalidRecord }
        record.encryptedValues["payloadV1"] = try value.encode() as NSData
        return record
    }

    public static func decode(_ record: CKRecord) throws -> SyncRecord {
        guard record.recordType == recordType, record.recordID.zoneID == zoneID,
              let data = record.encryptedValues["payloadV1"] as? Data else { throw SyncValidationError.invalidRecord }
        let value = try SyncRecord.decode(data)
        guard record.recordID.recordName == value.id.uuidString else { throw SyncValidationError.invalidRecord }
        return value
    }
}

/// Construct only after sync opt-in. Call disable immediately on CKAccountChanged.
/// Every await revalidates the bound account/session before returning/applying data.
@MainActor public final class CloudSyncTransport {
    public enum Failure: Error { case unavailableAccount, missingResult, conflict(SyncRecord), remoteMissing, downloadInProgress }
    public struct Page {
        public let records: [SyncRecord]
        public let failedIDs: [UUID]
        public let deletedIDs: [UUID]
        public let token: CKServerChangeToken
        public let moreComing: Bool
    }
    private let containerIdentifier: String
    // CKContainer(identifier:) can trap in an ad-hoc build without iCloud
    // entitlements. Opening the local/manual-transfer UI must never touch it.
    private lazy var container = CKContainer(identifier: containerIdentifier)
    private var gate = SyncAccountGate()
    private var downloading = false
    public init(containerIdentifier: String = "iCloud.com.mulabs.bytekibble") {
        self.containerIdentifier = containerIdentifier
    }
    public func disable() { gate.disable() }

    public func enable() async throws -> String {
        gate.disable()
        let generation = gate.generation
        guard try await container.accountStatus() == .available else { throw Failure.unavailableAccount }
        let id = try await container.userRecordID().recordName
        guard gate.generation == generation else { throw SyncValidationError.accountChanged }
        _ = try gate.enable(account: id)
        return id
    }
    private func binding() throws -> (String, UUID) {
        guard let account = gate.account else { throw SyncValidationError.accountChanged }
        return (account, gate.generation)
    }
    private func validate(_ binding: (String, UUID)) async throws {
        try gate.validate(account: binding.0, generation: binding.1)
        guard try await container.accountStatus() == .available,
              try await container.userRecordID().recordName == binding.0 else {
            // An older operation must not disable a newer opt-in session.
            try gate.validate(account: binding.0, generation: binding.1)
            gate.disable(); throw SyncValidationError.accountChanged
        }
        try gate.validate(account: binding.0, generation: binding.1)
        try Task.checkCancellation()
    }

    public func prepareZone() async throws {
        let binding = try binding()
        try await validate(binding)
        _ = try await container.privateCloudDatabase.save(CKRecordZone(zoneID: CloudSyncCodec.zoneID))
        try await validate(binding)
    }

    /// On failure, callers retain the outbox entry. No blind overwrite on conflict.
    public func upload(_ entry: SyncOutbox.Entry) async throws -> SyncRecord {
        let binding = try binding()
        try await validate(binding)
        let database = container.privateCloudDatabase
        let id = CKRecord.ID(recordName: entry.record.id.uuidString, zoneID: CloudSyncCodec.zoneID)
        var existing: CKRecord?
        do { existing = try await database.record(for: id) }
        catch let error as CKError where error.code == .unknownItem { existing = nil }
        try await validate(binding)
        if let existing {
            let remote = try CloudSyncCodec.decode(existing)
            // Idempotent retry after an uncertain successful save.
            if remote == entry.record { return remote }
            guard let base = entry.base, remote == base else { throw Failure.conflict(remote) }
        } else if entry.base != nil {
            // A missing server record is not permission to recreate a deleted record.
            throw Failure.remoteMissing
        }
        let record = try CloudSyncCodec.encode(entry.record, into: existing)
        let results = try await database.modifyRecords(saving: [record], deleting: [],
                                                       savePolicy: .ifServerRecordUnchanged, atomically: true)
        try await validate(binding)
        guard let result = results.saveResults[id] else { throw Failure.missingResult }
        return try CloudSyncCodec.decode(result.get())
    }

    /// Persist valid rows and failures before committing this page's token.
    /// A token-expired error must cause a full fetch, never a local-data reset.
    public func fetchPage(since token: CKServerChangeToken?) async throws -> Page {
        let binding = try binding()
        try await validate(binding)
        let page = try await container.privateCloudDatabase.recordZoneChanges(
            inZoneWith: CloudSyncCodec.zoneID, since: token, resultsLimit: 100)
        try await validate(binding)
        var records: [SyncRecord] = [], failed: [UUID] = []
        for (id, result) in page.modificationResultsByID {
            guard let uuid = UUID(uuidString: id.recordName) else { throw SyncValidationError.invalidRecord }
            do { records.append(try CloudSyncCodec.decode(result.get().record)) }
            catch { failed.append(uuid) }
        }
        return Page(records: records, failedIDs: failed,
                    deletedIDs: page.deletions.compactMap { UUID(uuidString: $0.recordID.recordName) },
                    token: page.changeToken, moreComing: page.moreComing)
    }

    /// Drain remote changes into the durable inbox, not directly into UI state.
    /// The account-scoped inbox is retained by the caller for this session only.
    public func download(into inbox: SyncInbox) async throws {
        guard !downloading else { throw Failure.downloadInProgress }
        downloading = true
        defer { downloading = false }
        let session = try binding()
        try await inbox.validateAccount(session.0)
        try await retryFailedRecords(in: inbox)
        var didResetExpiredCursor = false
        while true {
            try await validate(session)
            let snapshot = await inbox.snapshot()
            let token: CKServerChangeToken?
            if let data = snapshot.cursor {
                token = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
                guard token != nil else { throw SyncValidationError.invalidRecord }
            } else { token = nil }
            let page: Page
            do { page = try await fetchPage(since: token) }
            catch let error as CKError where error.code == .changeTokenExpired && !didResetExpiredCursor {
                try await validate(session)
                try await inbox.resetCursor()
                didResetExpiredCursor = true
                continue
            }
            try await validate(session)
            let cursor = try NSKeyedArchiver.archivedData(withRootObject: page.token, requiringSecureCoding: true)
            try await inbox.receive(records: page.records, deletedIDs: Set(page.deletedIDs),
                                    failedIDs: Set(page.failedIDs), cursor: cursor)
            try await validate(session)
            if !page.moreComing { return }
        }
    }

    /// Retry malformed or individually failed rows even after the page cursor
    /// advanced. Valid siblings remain available; errors never erase a reading.
    private func retryFailedRecords(in inbox: SyncInbox) async throws {
        let session = try binding()
        try await inbox.validateAccount(session.0)
        let pending = await inbox.snapshot().failedIDs.sorted { $0.uuidString < $1.uuidString }
        for start in stride(from: 0, to: pending.count, by: 100) {
            try await validate(session)
            let batch = Array(pending[start..<min(start + 100, pending.count)])
            let ids = batch.map { CKRecord.ID(recordName: $0.uuidString, zoneID: CloudSyncCodec.zoneID) }
            let results = try await container.privateCloudDatabase.records(for: ids)
            try await validate(session)
            var records: [SyncRecord] = [], deleted: Set<UUID> = [], failed: Set<UUID> = []
            for (uuid, id) in zip(batch, ids) {
                do {
                    guard let result = results[id] else { throw Failure.missingResult }
                    records.append(try CloudSyncCodec.decode(result.get()))
                } catch let error as CKError where error.code == .unknownItem {
                    deleted.insert(uuid)
                } catch { failed.insert(uuid) }
            }
            let cursor = await inbox.snapshot().cursor
            try await inbox.receive(records: records, deletedIDs: deleted, failedIDs: failed, cursor: cursor)
            try await validate(session)
        }
    }
}
