import Foundation
import CloudKit
import CryptoKit
import Combine

@MainActor public protocol SubscriptionSyncTransport {
    func enable() async throws -> String
    func disable()
    func prepareZone() async throws
    func upload(_ entry: SyncOutbox.Entry) async throws -> SyncRecord
    func download(into inbox: SyncInbox) async throws
}
extension CloudSyncTransport: SubscriptionSyncTransport {}

public protocol SyncCredentialAccess {
    func save(_ url: URL, recordID: UUID, revision: UUID) throws
    func read(recordID: UUID, revision: UUID) throws -> URL
}
extension SyncCredentialVault: SyncCredentialAccess {}

/// Shared application coordinator. Its durable replica contains metadata only;
/// subscription credentials remain in the account-scoped synchronizable vault.
@MainActor public final class SyncLibrary: ObservableObject {
    public struct Row: Codable, Equatable, Identifiable {
        public var id: UUID { record.id }
        public var record: SyncRecord
        public var base: SyncRecord?
        public var conflict: SyncRecord?
    }
    private struct Archive: Codable { var version = 1; var rows: [Row] }
    public enum Failure: Error { case disconnected, busy, invalidArchive, conflict, remoteDeletion }
    @Published public private(set) var rows: [Row] = []
    @Published public private(set) var busy = false
    @Published public private(set) var accountScope: String?
    @Published public private(set) var waiting: Set<UUID> = []
    @Published public private(set) var remoteDeleted: Set<UUID> = []
    @Published public private(set) var lastSuccess: Date?
    private let directory: URL
    private let accessGroup: String
    private let transport: any SubscriptionSyncTransport
    private let credentialFactory: (String, String) throws -> any SyncCredentialAccess
    private var vault: (any SyncCredentialAccess)?
    private var inbox: SyncInbox?
    private var file: URL?
    private var generation = UUID()
    private var observer: NSObjectProtocol?

    public init(directory: URL, accessGroup: String, transport: (any SubscriptionSyncTransport)? = nil,
                credentials: ((String, String) throws -> any SyncCredentialAccess)? = nil) {
        self.directory = directory; self.accessGroup = accessGroup
        self.transport = transport ?? CloudSyncTransport()
        credentialFactory = credentials ?? { try SyncCredentialVault(accessGroup: $0, accountID: $1) }
        observer = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.disconnect() }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    public func disconnect() {
        generation = UUID(); transport.disable(); accountScope = nil
        vault = nil; inbox = nil; file = nil; rows = []; waiting = []; remoteDeleted = []; lastSuccess = nil
    }

    public func connect(expectedScope: String? = nil) async throws {
        guard !busy else { throw Failure.busy }
        disconnect(); busy = true
        defer { busy = false }
        let token = generation
        let account = try await transport.enable()
        guard generation == token else { throw SyncValidationError.accountChanged }
        let scope = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
        if let expectedScope, scope != expectedScope {
            transport.disable()
            throw SyncValidationError.accountChanged
        }
        let candidate = directory.appendingPathComponent("replica-\(scope).json")
        var restored: [Row] = []
        if FileManager.default.fileExists(atPath: candidate.path) {
            guard try candidate.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max <= 32 * 1024 * 1024 else { throw Failure.invalidArchive }
            let data = try Data(contentsOf: candidate)
            guard data.count <= 32 * 1024 * 1024 else { throw Failure.invalidArchive }
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            guard archive.version == 1 else { throw Failure.invalidArchive }
            try Self.validate(archive.rows); restored = archive.rows
        }
        let incoming = try SyncInbox(directory: directory, accountID: account)
        vault = try credentialFactory(accessGroup, account)
        inbox = incoming; file = candidate; rows = restored; accountScope = scope
    }

    public func credential(for record: SyncRecord) throws -> URL {
        guard let vault, accountScope != nil else { throw Failure.disconnected }
        return try vault.read(recordID: record.id, revision: record.credentialRevision)
    }

    /// Called only for subscriptions selected by the user. Later local changes
    /// reuse that record's immutable credential revision and keep the merge base.
    public func stage(_ record: SyncRecord, url: URL) throws {
        guard !busy else { throw Failure.busy }
        guard let vault, accountScope != nil else { throw Failure.disconnected }
        _ = try record.encode()
        var next = rows
        if let index = next.firstIndex(where: { $0.id == record.id }) {
            guard next[index].conflict == nil else { throw Failure.conflict }
            if next[index].record == record { return }
            guard next[index].record.revision != record.revision else { throw SyncValidationError.invalidRecord }
            try vault.save(url, recordID: record.id, revision: record.credentialRevision)
            next[index].record = record
        } else {
            try vault.save(url, recordID: record.id, revision: record.credentialRevision)
            next.append(Row(record: record))
        }
        try persist(next)
    }

    public func resolve(id: UUID, useRemote: Bool) throws {
        guard !busy else { throw Failure.busy }
        guard let index = rows.firstIndex(where: { $0.id == id }), let remote = rows[index].conflict else { return }
        var next = rows
        if useRemote { next[index].record = remote }
        else { next[index].record.revision = UUID() }
        next[index].base = remote; next[index].conflict = nil
        try persist(next)
    }

    /// User chooses to keep their local copy and stop syncing a server-deleted row.
    /// No provider data or credential is removed.
    public func keepLocalAfterRemoteDeletion(_ id: UUID) async throws {
        guard !busy else { throw Failure.busy }
        guard let inbox, remoteDeleted.contains(id) else { throw Failure.disconnected }
        busy = true; defer { busy = false }
        let token = generation
        try persist(rows.filter { $0.id != id })
        try await inbox.acknowledgeDeletion(id)
        try check(token)
        remoteDeleted.remove(id); waiting.remove(id)
    }

    public func synchronize() async throws {
        guard !busy else { throw Failure.busy }
        guard accountScope != nil, let inbox else { throw Failure.disconnected }
        busy = true; defer { busy = false }
        let token = generation
        try await transport.prepareZone()
        try check(token)
        // Fetch first so conflict decisions never silently discard remote edits.
        try await transport.download(into: inbox)
        try check(token)
        let incoming = await inbox.snapshot()
        waiting = incoming.failedIDs.union(incoming.deletedIDs)
        remoteDeleted = incoming.deletedIDs
        for remote in incoming.records.values where !incoming.failedIDs.contains(remote.id) {
            try check(token)
            var next = rows
            if let index = next.firstIndex(where: { $0.id == remote.id }) {
                let row = next[index]
                switch try SyncMerge.reconcile(base: row.base, local: row.record, remote: remote) {
                case .unchanged: next[index].base = remote; next[index].conflict = nil
                case .adopt: next[index] = Row(record: remote, base: remote)
                case .upload: break
                case .conflict: next[index].conflict = remote
                }
            } else { next.append(Row(record: remote, base: remote)) }
            try persist(next)
            try await inbox.acknowledge(remote)
            try check(token)
        }
        for row in rows where row.record != row.base && row.conflict == nil && !waiting.contains(row.id) {
            do {
                let accepted = try await transport.upload(.init(record: row.record, base: row.base))
                try check(token)
                var next = rows
                if let index = next.firstIndex(where: { $0.id == row.id }) { next[index].base = accepted }
                try persist(next)
            } catch CloudSyncTransport.Failure.conflict(let remote) {
                try check(token)
                var next = rows
                if let index = next.firstIndex(where: { $0.id == row.id }) { next[index].conflict = remote }
                try persist(next)
            }
        }
        for row in rows where !row.record.deleted {
            do { _ = try credential(for: row.record) }
            catch { waiting.insert(row.id) }
        }
        try check(token)
        if waiting.isEmpty && rows.allSatisfy({ $0.conflict == nil }) { lastSuccess = .now }
    }

    private func check(_ token: UUID) throws {
        guard token == generation, accountScope != nil else { throw SyncValidationError.accountChanged }
        try Task.checkCancellation()
    }
    private static func validate(_ rows: [Row]) throws {
        guard rows.count <= 256, Set(rows.map(\.id)).count == rows.count else { throw Failure.invalidArchive }
        for row in rows {
            _ = try row.record.encode()
            for item in [row.base, row.conflict].compactMap({ $0 }) {
                guard item.id == row.id else { throw Failure.invalidArchive }
                _ = try item.encode()
            }
        }
    }
    private func persist(_ next: [Row]) throws {
        guard let file else { throw Failure.disconnected }
        try Self.validate(next)
        let data = try JSONEncoder().encode(Archive(rows: next))
        guard data.count <= 32 * 1024 * 1024 else { throw Failure.invalidArchive }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        rows = next
    }
}
