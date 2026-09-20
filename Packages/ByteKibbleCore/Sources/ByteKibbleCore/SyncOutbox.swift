import Foundation
import CryptoKit

/// An account-bound, durable metadata outbox. It never stores subscription URLs.
/// A transport must bind every callback to an account generation independently.
public actor SyncOutbox {
    public struct Entry: Codable, Equatable, Sendable {
        public let record: SyncRecord
        public let base: SyncRecord?
        public init(record: SyncRecord, base: SyncRecord?) { self.record = record; self.base = base }
    }
    public struct Upload: Sendable {
        public let token: UUID
        public let entry: Entry
    }
    private struct Archive: Codable {
        var schema = 1
        let accountScope: String
        var entries: [Entry]
    }
    public enum Failure: Error { case invalidArchive, capacityExceeded, revisionReused }
    private let file: URL
    private let scope: String
    private var entries: [UUID: Entry]
    private var inFlight: [UUID: Upload] = [:]
    private static let maxBytes = 32 * 1024 * 1024

    public init(directory: URL, accountID: String) throws {
        guard !accountID.isEmpty else { throw SyncValidationError.accountChanged }
        scope = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
        file = directory.appendingPathComponent("outbox-\(scope).json")
        if FileManager.default.fileExists(atPath: file.path) {
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= Self.maxBytes else { throw Failure.capacityExceeded }
            let data = try Data(contentsOf: file)
            guard data.count <= Self.maxBytes else { throw Failure.capacityExceeded }
            let archive = try JSONDecoder().decode(Archive.self, from: data)
            guard archive.schema == 1, archive.accountScope == scope, archive.entries.count <= 256 else {
                throw Failure.invalidArchive
            }
            var restored: [UUID: Entry] = [:]
            for entry in archive.entries {
                _ = try entry.record.encode()
                if let base = entry.base {
                    _ = try base.encode()
                    guard base.id == entry.record.id else { throw Failure.invalidArchive }
                }
                guard restored.updateValue(entry, forKey: entry.record.id) == nil else { throw Failure.invalidArchive }
            }
            entries = restored
        } else { entries = [:] }
    }

    public func pending() -> [Entry] {
        entries.values.sorted { $0.record.id.uuidString < $1.record.id.uuidString }
    }

    /// Disabling or replacing a session invalidates callbacks but retains work.
    public func cancelUploads() { inFlight.removeAll() }

    /// Coalesce offline edits, retaining the last acknowledged server base.
    /// Persist before publishing in-memory state; a disk failure keeps old work.
    public func enqueue(_ record: SyncRecord, base: SyncRecord?) throws {
        _ = try record.encode()
        if let base {
            _ = try base.encode()
            guard base.id == record.id else { throw Failure.invalidArchive }
            guard base.revision != record.revision || base == record else { throw Failure.revisionReused }
        }
        let old = entries[record.id]
        if let old, old.record.revision == record.revision, old.record != record { throw Failure.revisionReused }
        var next = entries
        let originalBase: SyncRecord?
        if let old { originalBase = old.base } else { originalBase = base }
        next[record.id] = Entry(record: record, base: originalBase)
        try persist(next)
        entries = next
    }

    /// A late success must not erase an edit made while its upload was in flight.
    /// Instead the accepted revision becomes the remaining edit's new merge base.
    public func beginUpload(id: UUID) -> Upload? {
        guard inFlight[id] == nil, let entry = entries[id] else { return nil }
        let upload = Upload(token: UUID(), entry: entry)
        inFlight[id] = upload
        return upload
    }

    /// Network failure leaves durable work intact for a later retry.
    public func failed(_ upload: Upload) {
        guard inFlight[upload.entry.record.id]?.token == upload.token else { return }
        inFlight.removeValue(forKey: upload.entry.record.id)
    }

    public func acknowledge(_ upload: Upload) throws {
        let uploaded = upload.entry.record
        guard inFlight[uploaded.id]?.token == upload.token else { return }
        _ = try uploaded.encode()
        guard let current = entries[uploaded.id] else { return }
        var next = entries
        if current.record.revision == uploaded.revision {
            guard current.record == uploaded else { throw Failure.revisionReused }
            next.removeValue(forKey: uploaded.id)
        } else {
            next[uploaded.id] = Entry(record: current.record, base: uploaded)
        }
        try persist(next)
        entries = next
        inFlight.removeValue(forKey: uploaded.id)
    }

    private func persist(_ next: [UUID: Entry]) throws {
        guard next.count <= 256 else { throw Failure.capacityExceeded }
        let archive = Archive(accountScope: scope, entries: next.values.sorted { $0.record.id.uuidString < $1.record.id.uuidString })
        let data = try JSONEncoder().encode(archive)
        guard data.count <= Self.maxBytes else { throw Failure.capacityExceeded }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
