import Foundation

/// Cloud metadata never contains a subscription URL. A revision identifies an
/// immutable synchronizable Keychain item; metadata and secrets may arrive apart.
public struct SyncRecord: Codable, Equatable, Sendable, Identifiable {
    public var schemaVersion: Int = 1
    public let id: UUID
    public var revision: UUID
    public var credentialRevision: UUID
    public var name: String
    public var reset: Date?
    public var historyPaused: Bool
    public var reading: QuotaReading?
    public var history: [QuotaReading]
    public var deleted: Bool

    public init(id: UUID = UUID(), revision: UUID = UUID(), credentialRevision: UUID = UUID(),
                name: String, reset: Date? = nil, historyPaused: Bool = false,
                reading: QuotaReading? = nil, history: [QuotaReading] = [], deleted: Bool = false) {
        self.id = id; self.revision = revision; self.credentialRevision = credentialRevision
        self.name = name; self.reset = reset; self.historyPaused = historyPaused
        self.reading = reading; self.history = history; self.deleted = deleted
    }

    public func validated() throws -> Self {
        guard schemaVersion == 1 else { throw SyncValidationError.unsupportedVersion }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 80, history.count <= 2000,
              reset.map(Self.validDate) ?? true else { throw SyncValidationError.invalidRecord }
        for row in history + (reading.map { [$0] } ?? []) {
            guard Self.validDate(row.observed), row.expires.map(Self.validDate) ?? true,
                  [row.upload, row.download, row.total, row.used].allSatisfy({ $0.map { $0 >= 0 } ?? true }) else {
                throw SyncValidationError.invalidRecord
            }
            if let up = row.upload, let down = row.download {
                let sum = up.addingReportingOverflow(down)
                guard !sum.overflow, row.used == nil || row.used == sum.partialValue else {
                    throw SyncValidationError.invalidRecord
                }
            }
        }
        return self
    }

    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 512 * 1024 else { throw SyncValidationError.tooLarge }
        return try JSONDecoder().decode(Self.self, from: data).validated()
    }
    public func encode() throws -> Data {
        let data = try JSONEncoder().encode(validated())
        guard data.count <= 512 * 1024 else { throw SyncValidationError.tooLarge }
        return data
    }
    private static func validDate(_ date: Date) -> Bool {
        date.timeIntervalSince1970.isFinite && date > .distantPast && date < .distantFuture
    }
}

public enum SyncValidationError: Error, Equatable {
    case unsupportedVersion, invalidRecord, tooLarge, accountChanged, missingCredential
}

/// Three-way reconciliation never uses device wall-clock time to pick a winner.
/// Keep both revisions on conflict, including delete-versus-edit conflicts.
public enum SyncMerge {
    public enum Result: Equatable, Sendable {
        case unchanged(SyncRecord)
        case upload(SyncRecord)
        case adopt(SyncRecord)
        case conflict(local: SyncRecord, remote: SyncRecord)
    }
    public static func reconcile(base: SyncRecord?, local: SyncRecord, remote: SyncRecord) throws -> Result {
        _ = try local.validated(); _ = try remote.validated()
        guard local.id == remote.id, base.map({ $0.id == local.id }) ?? true else {
            throw SyncValidationError.invalidRecord
        }
        if local == remote { return .unchanged(local) }
        if let base {
            _ = try base.validated()
            if local == base { return .adopt(remote) }
            if remote == base { return .upload(local) }
        }
        return .conflict(local: local, remote: remote)
    }
}

/// Bind a pending operation to the Apple account that was explicitly selected.
/// Signing out, switching accounts, or disabling sync invalidates every old task.
public struct SyncAccountGate: Sendable {
    public private(set) var account: String?
    public private(set) var generation = UUID()
    public init() {}
    public mutating func enable(account: String) throws -> UUID {
        guard !account.isEmpty else { throw SyncValidationError.accountChanged }
        self.account = account; generation = UUID()
        return generation
    }
    public mutating func disable() { account = nil; generation = UUID() }
    public func validate(account: String, generation: UUID) throws {
        guard self.account == account, self.generation == generation else { throw SyncValidationError.accountChanged }
    }
}
