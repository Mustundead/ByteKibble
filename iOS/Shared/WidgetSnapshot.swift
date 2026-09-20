import Foundation

/// Deliberately excludes provider names, URLs and credentials.
struct WidgetSnapshot: Codable, Equatable {
    let remaining: Int64?
    let total: Int64?
    let observed: Date

    func isStale(at date: Date) -> Bool {
        observed > date || date.timeIntervalSince(observed) >= 3600
    }
    var valid: Bool {
        observed.timeIntervalSince1970.isFinite &&
        (remaining == nil || remaining! >= 0) &&
        (total == nil || total! >= 0) &&
        (remaining == nil || total == nil || remaining! <= total!)
    }
}

enum WidgetSnapshotFile {
    static let group = "group.com.mulabs.bytekibble"
    static let kind = "ByteKibbleQuota"
    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("quota-widget-v1.json")
    }
    static func read(from url: URL) -> WidgetSnapshot? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4097), data.count <= 4096,
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
              snapshot.valid else { return nil }
        return snapshot
    }
    static func write(_ snapshot: WidgetSnapshot?, to url: URL) throws {
        guard let snapshot else {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            return
        }
        guard snapshot.valid else { throw CocoaError(.coderInvalidValue) }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
