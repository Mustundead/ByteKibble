import Foundation
import CryptoKit

/// Stores a fetched page and its opaque cursor in one transaction. Pending rows
/// remain available while synchronizable Keychain delivery is still in progress.
public actor SyncInbox {
    public struct Snapshot: Codable, Equatable, Sendable {
        public var records: [UUID: SyncRecord] = [:]
        public var deletedIDs: Set<UUID> = []
        public var failedIDs: Set<UUID> = []
        public var cursor: Data?
    }
    private struct Archive: Codable {
        var schema = 1
        let scope: String
        let snapshot: Snapshot
    }
    public enum Failure: Error { case invalidArchive, invalidPage, capacityExceeded }
    private let file: URL
    private let scope: String
    private var state: Snapshot
    private static let maxBytes = 32 * 1024 * 1024

    public init(directory: URL, accountID: String) throws {
        guard !accountID.isEmpty else { throw SyncValidationError.accountChanged }
        scope = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
        file = directory.appendingPathComponent("inbox-\(scope).json")
        if FileManager.default.fileExists(atPath: file.path) {
            guard try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max <= Self.maxBytes else {
                throw Failure.capacityExceeded
            }
            let data = try Data(contentsOf: file)
            guard data.count <= Self.maxBytes else { throw Failure.capacityExceeded }
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            guard archive.schema == 1, archive.scope == scope else { throw Failure.invalidArchive }
            try Self.validate(archive.snapshot)
            state = archive.snapshot
        } else { state = Snapshot() }
    }

    public func snapshot() -> Snapshot { state }

    public func validateAccount(_ accountID: String) throws {
        let candidate = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
        guard !accountID.isEmpty, candidate == scope else { throw SyncValidationError.accountChanged }
    }

    /// Caller must validate its account generation before submitting the page.
    /// A failed row is retained explicitly so advancing the cursor cannot hide it.
    public func receive(records: [SyncRecord], deletedIDs: Set<UUID>, failedIDs: Set<UUID>, cursor: Data?) throws {
        let ids = Set(records.map(\.id))
        guard ids.count == records.count, ids.isDisjoint(with: deletedIDs),
              ids.isDisjoint(with: failedIDs), deletedIDs.isDisjoint(with: failedIDs) else {
            throw Failure.invalidPage
        }
        var next = state
        for record in records {
            _ = try record.encode()
            next.records[record.id] = record
            next.deletedIDs.remove(record.id)
            next.failedIDs.remove(record.id)
        }
        for id in deletedIDs {
            next.records.removeValue(forKey: id)
            next.failedIDs.remove(id)
            next.deletedIDs.insert(id)
        }
        next.failedIDs.formUnion(failedIDs)
        next.cursor = cursor
        try commit(next)
    }

    /// Acknowledge only the exact revision durably applied to local storage.
    /// A later page may already have replaced the row while its credential loaded.
    public func acknowledge(_ record: SyncRecord) throws {
        guard state.records[record.id] == record else { return }
        var next = state
        next.records.removeValue(forKey: record.id)
        try commit(next)
    }

    /// Restart enumeration after token expiry without erasing pending imports.
    public func resetCursor() throws {
        var next = state
        next.cursor = nil
        try commit(next)
    }
    public func acknowledgeDeletion(_ id: UUID) throws {
        var next = state
        next.deletedIDs.remove(id)
        try commit(next)
    }

    private static func validate(_ value: Snapshot) throws {
        guard value.records.count + value.deletedIDs.count + value.failedIDs.count <= 4096,
              (value.cursor?.count ?? 0) <= 1024 * 1024 else { throw Failure.capacityExceeded }
        guard Set(value.records.keys).isDisjoint(with: value.deletedIDs),
              value.deletedIDs.isDisjoint(with: value.failedIDs) else { throw Failure.invalidArchive }
        for (id, record) in value.records {
            guard id == record.id else { throw Failure.invalidArchive }
            _ = try record.encode()
        }
    }

    private func commit(_ next: Snapshot) throws {
        try Self.validate(next)
        let data = try JSONEncoder().encode(Archive(scope: scope, snapshot: next))
        guard data.count <= Self.maxBytes else { throw Failure.capacityExceeded }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        state = next
    }
}
