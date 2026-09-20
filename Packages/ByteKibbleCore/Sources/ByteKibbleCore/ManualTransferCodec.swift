import CryptoKit
import Foundation

/// A portable, user-mediated export. The archive never contains the transfer
/// key: callers must show the key separately and keep it out of the file.
public enum ManualTransferCodec {
    public static let maximumArchiveBytes = 16 * 1024 * 1024
    public static let maximumEntries = 256
    private static let format = "ByteKibbleManualTransfer"
    private static let version = 1

    public enum Error: Swift.Error, Equatable {
        case invalidKey
        case invalidFormat
        case unsupportedVersion
        case tooLarge
        case tooManyEntries
        case duplicateRecord
        case invalidSubscriptionURL
        case authenticationFailed
    }

    /// A 256-bit key displayed separately from the archive, in canonical text form.
    public struct TransferKey: Equatable, Sendable {
        private static let prefix = "BKMT1-"
        private let bytes: Data

        private init(bytes: Data) {
            self.bytes = bytes
        }

        public static func generate() -> Self {
            Self(bytes: SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) })
        }

        public init(text: String) throws {
            guard text.hasPrefix(Self.prefix) else { throw Error.invalidKey }
            let encoded = String(text.dropFirst(Self.prefix.count))
            guard encoded.count == 43,
                  encoded.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }),
                  let decoded = Data(base64Encoded: encoded.replacingOccurrences(of: "-", with: "+")
                    .replacingOccurrences(of: "_", with: "/") + "="),
                  decoded.count == 32 else { throw Error.invalidKey }
            self.bytes = decoded
            guard self.text == text else { throw Error.invalidKey }
        }

        public var text: String {
            let value = bytes.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            return Self.prefix + value
        }

        fileprivate var symmetricKey: SymmetricKey { SymmetricKey(data: bytes) }
    }

    public struct Entry: Codable, Equatable, Sendable {
        public let record: SyncRecord
        public let subscriptionURL: URL

        public init(record: SyncRecord, subscriptionURL: URL) {
            self.record = record
            self.subscriptionURL = subscriptionURL
        }
    }

    public struct Archive: Codable, Equatable, Sendable {
        public let entries: [Entry]

        public init(entries: [Entry]) {
            self.entries = entries
        }
    }

    private struct Payload: Codable {
        let format: String
        let version: Int
        let archive: Archive
    }

    private struct Envelope: Codable {
        let format: String
        let version: Int
        let ciphertext: Data
    }

    public static func encode(_ archive: Archive, key: TransferKey) throws -> Data {
        try validate(archive)
        let payload = Payload(format: format, version: version, archive: archive)
        let plaintext: Data
        do { plaintext = try JSONEncoder().encode(payload) }
        catch { throw Error.invalidFormat }
        guard plaintext.count <= maximumArchiveBytes else { throw Error.tooLarge }
        let box = try AES.GCM.seal(plaintext, using: key.symmetricKey)
        guard let ciphertext = box.combined else { throw Error.invalidFormat }
        let envelope = Envelope(format: format, version: version, ciphertext: ciphertext)
        let encoded: Data
        do { encoded = try JSONEncoder().encode(envelope) }
        catch { throw Error.invalidFormat }
        guard encoded.count <= maximumArchiveBytes else { throw Error.tooLarge }
        return encoded
    }

    public static func decode(_ data: Data, key: TransferKey) throws -> Archive {
        guard data.count <= maximumArchiveBytes else { throw Error.tooLarge }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw Error.invalidFormat }
        guard envelope.format == format else { throw Error.invalidFormat }
        guard envelope.version == version else { throw Error.unsupportedVersion }
        guard envelope.ciphertext.count <= maximumArchiveBytes else { throw Error.tooLarge }
        let plaintext: Data
        do {
            plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.ciphertext), using: key.symmetricKey)
        } catch {
            throw Error.authenticationFailed
        }
        guard plaintext.count <= maximumArchiveBytes else { throw Error.tooLarge }
        let payload: Payload
        do { payload = try JSONDecoder().decode(Payload.self, from: plaintext) }
        catch { throw Error.invalidFormat }
        guard payload.format == format else { throw Error.invalidFormat }
        guard payload.version == version else { throw Error.unsupportedVersion }
        try validate(payload.archive)
        return payload.archive
    }

    private static func validate(_ archive: Archive) throws {
        guard archive.entries.count <= maximumEntries else { throw Error.tooManyEntries }
        var identifiers = Set<UUID>()
        for entry in archive.entries {
            _ = try entry.record.validated()
            guard identifiers.insert(entry.record.id).inserted else { throw Error.duplicateRecord }
            guard entry.subscriptionURL.absoluteString.utf8.count <= 16_384,
                  SubscriptionLink.https(entry.subscriptionURL.absoluteString) != nil else {
                throw Error.invalidSubscriptionURL
            }
        }
    }
}
