import Foundation
import ClearShotCore
import Security

/// Secrets go in the login Keychain (Apple's safe password store), never in the settings file.
enum KeychainStore {
    private static let service = "com.austinejose.clearshot"
    /// The Cloudflare R2 Secret Access Key.
    static let r2Secret = "r2-secret-access-key"

    static func read(_ account: String) -> String? {
        var query = base(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound { DiagnosticLog.write("keychain read \(account) failed: \(status)") }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Saves the value, or removes the item when the value is empty.
    static func write(_ value: String, account: String) {
        guard !value.isEmpty else {
            delete(account)
            return
        }
        let data = Data(value.utf8)
        var status = SecItemUpdate(base(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = base(account)
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "ClearShot Cloudflare R2"
            status = SecItemAdd(item as CFDictionary, nil)
        }
        if status != errSecSuccess { DiagnosticLog.write("keychain write \(account) failed: \(status)") }
    }

    static func delete(_ account: String) {
        let status = SecItemDelete(base(account) as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound { DiagnosticLog.write("keychain delete \(account) failed: \(status)") }
    }

    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
