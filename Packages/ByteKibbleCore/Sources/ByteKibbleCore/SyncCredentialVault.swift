import Foundation
import Security
import CryptoKit

/// Separate from each platform's device-only vault. No migration occurs merely
/// by constructing this object. Call only after explicit sync consent/account binding.
public struct SyncCredentialVault: Sendable {
    private let accessGroup: String
    private let accountScope: String
    public init(accessGroup: String, accountID: String) throws {
        guard !accessGroup.isEmpty, !accountID.isEmpty else { throw SyncValidationError.accountChanged }
        self.accessGroup = accessGroup
        self.accountScope = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func query(recordID: UUID, revision: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.mulabs.bytekibble.sync.\(accountScope)",
         kSecAttrAccount as String: "\(recordID.uuidString)/\(revision.uuidString)",
         kSecAttrAccessGroup as String: accessGroup,
         kSecAttrSynchronizable as String: true,
         kSecUseDataProtectionKeychain as String: true]
    }

    public func save(_ url: URL, recordID: UUID, revision: UUID) throws {
        guard url.absoluteString.utf8.count <= 16_384, SubscriptionLink.https(url.absoluteString) != nil else {
            throw QuotaError.invalidLink
        }
        var item = query(recordID: recordID, revision: revision)
        item[kSecValueData as String] = Data(url.absoluteString.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else { throw QuotaError.keychain(status) }
        // Credential revisions are immutable. Never overwrite a concurrent secret.
        guard try read(recordID: recordID, revision: revision) == url else { throw SyncValidationError.invalidRecord }
    }

    public func read(recordID: UUID, revision: UUID) throws -> URL {
        var item = query(recordID: recordID, revision: revision)
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(item as CFDictionary, &result)
        if status == errSecItemNotFound { throw SyncValidationError.missingCredential }
        guard status == errSecSuccess else { throw QuotaError.keychain(status) }
        guard let data = result as? Data, data.count <= 16_384,
              let text = String(data: data, encoding: .utf8), let url = SubscriptionLink.https(text) else {
            throw SyncValidationError.invalidRecord
        }
        return url
    }

    /// Use only after the corresponding deletion metadata is durably acknowledged.
    /// Disabling synchronization must never call this method.
    public func removeRevision(recordID: UUID, revision: UUID) throws {
        let status = SecItemDelete(query(recordID: recordID, revision: revision) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw QuotaError.keychain(status) }
    }
}
