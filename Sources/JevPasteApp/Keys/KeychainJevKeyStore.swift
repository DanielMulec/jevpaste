import Foundation
import Security
import SmartPasteCore
import os

/// The API keys in the login Keychain: one generic password per Jev Provider, service
/// `com.jevpaste.JevPaste.jev-provider-key`, account = the provider's raw value. The item belongs to the app that
/// created it; builds signed with the same Signing Identity read it without a prompt (live-proven, see
/// docs/design/menu-and-settings.md). AppKit-free glue over `SecItem*`, live-proven only; logs carry statuses only.
struct KeychainJevKeyStore: JevKeyStore {
    static let service = "com.jevpaste.JevPaste.jev-provider-key"
    private static let log = Logger(subsystem: "jevpaste", category: "Keys")

    func apiKey(for provider: JevProvider) -> String? {
        var query = Self.itemQuery(for: provider)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound { Self.log.error("key read failed status=\(status, privacy: .public)") }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func setAPIKey(_ key: String, for provider: JevProvider) throws(JevKeyStoreFailure) {
        let status = key.isEmpty ? Self.removeKey(of: provider) : Self.store(key, for: provider)
        guard status == errSecSuccess else {
            Self.log.error("key write failed status=\(status, privacy: .public)")
            throw JevKeyStoreFailure(status: status)
        }
        Self.log.notice("key for \(provider.rawValue, privacy: .public) \(key.isEmpty ? "removed" : "stored")")
    }

    private static func store(_ key: String, for provider: JevProvider) -> OSStatus {
        let data = Data(key.utf8) as CFData
        let updated = SecItemUpdate(
            itemQuery(for: provider) as CFDictionary, [kSecValueData as String: data] as CFDictionary
        )
        guard updated == errSecItemNotFound else { return updated }
        var item = itemQuery(for: provider)
        item[kSecValueData as String] = data
        item[kSecAttrLabel as String] = "JevPaste — \(provider.displayName) API key" as CFString
        return SecItemAdd(item as CFDictionary, nil)
    }

    private static func removeKey(of provider: JevProvider) -> OSStatus {
        let status = SecItemDelete(itemQuery(for: provider) as CFDictionary)
        return status == errSecItemNotFound ? errSecSuccess : status
    }

    private static func itemQuery(for provider: JevProvider) -> [String: CFTypeRef] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as CFString,
            kSecAttrAccount as String: provider.rawValue as CFString,
        ]
    }
}
