import Foundation
import Security
import CryptoKit

protocol CredentialStore {
    func read(for key: String) -> String?
    @discardableResult func write(_ value: String, for key: String) -> Bool
    @discardableResult func remove(for key: String) -> Bool
}
typealias SubscriptionCredentialStore = CredentialStore

final class InMemoryCredentialStore: CredentialStore {
    private(set) var values: [String: String] = [:]
    var failWrites = false
    var failRemoves = false
    func read(for key: String) -> String? { values[key] }
    @discardableResult func write(_ value: String, for key: String) -> Bool {
        guard !failWrites else { return false }; values[key] = value; return true
    }
    @discardableResult func remove(for key: String) -> Bool {
        guard !failRemoves else { return false }; values.removeValue(forKey: key); return true
    }
}

final class KeychainCredentialStore: CredentialStore {
    private let service: String
    init(service: String = "com.bytekibble.credentials") { self.service = service }
    func read(for key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    @discardableResult func write(_ value: String, for key: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: key]
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { return false }
        } else if status != errSecSuccess {
            return false
        }
        return read(for: key) == value
    }
    @discardableResult func remove(for key: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: key]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

extension Providers {
    static let productionCredentialStore: CredentialStore = KeychainCredentialStore()
    static func secureIdentifier(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func credentialKey(for url: String) -> String { "subscription." + secureIdentifier(url) }
    /// Stable, non-secret identifier suitable for UserDefaults selection/reset keys.
    static func persistenceID(_ raw: String) -> String {
        if raw.hasPrefix("id-v1:"), raw.dropFirst(6).count == 64,
           raw.dropFirst(6).allSatisfy({ $0.isHexDigit }) { return raw }
        return "id-v1:" + secureIdentifier(raw)
    }
}
