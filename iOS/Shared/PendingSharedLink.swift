import Foundation
import Security

/// One device-only handoff item. The widget has no entitlement to this group.
enum PendingSharedLink {
    static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.mulabs.bytekibble.pending-import",
         kSecAttrAccount as String: "pending",
         kSecAttrAccessGroup as String: "46P646AZCB.com.mulabs.bytekibble.import",
         kSecAttrSynchronizable as String: false]
    }
    static func save(_ text: String) throws {
        let url = try SubscriptionLink.parse(text)
        var item = query
        item[kSecValueData as String] = Data(url.absoluteString.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw QuotaError.keychain(status) }
    }
    static func read() throws -> String? {
        var item = query; item[kSecReturnData as String] = true; item[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(item as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw QuotaError.keychain(status) }
        guard let data = value as? Data, data.count <= 16_384, let text = String(data: data, encoding: .utf8) else { throw QuotaError.storage }
        return try SubscriptionLink.parse(text).absoluteString
    }
    static func remove(matching text: String) throws {
        guard try read() == text else { return }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw QuotaError.keychain(status) }
    }
}
