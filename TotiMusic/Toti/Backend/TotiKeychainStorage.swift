import Foundation
import Security
import Supabase

/// This app's session has a separate namespace and never enters library JSON or cloud backups.
struct TotiKeychainStorage: AuthLocalStorage {
    private let service = "com.toti.music.supabase.auth"

    /// Fail before creating an unrecoverable guest if the installed app cannot use Keychain.
    func verifyAvailable() throws {
        let key = "availability-" + UUID().uuidString
        let probe = Data(UUID().uuidString.utf8)
        defer { try? remove(key: key) }
        try store(key: key, value: probe)
        guard try retrieve(key: key) == probe else { throw TotiBackendError.secureSessionUnavailable }
    }

    func store(key: String, value: Data) throws {
        let query = baseQuery(key)
        let updates: [String: Any] = [kSecValueData as String: value]
        let result = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
        if result == errSecItemNotFound {
            var addition = query
            addition[kSecValueData as String] = value
            addition[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(addition as CFDictionary, nil) == errSecSuccess else {
                throw TotiBackendError.secureSessionUnavailable
            }
        } else if result != errSecSuccess {
            throw TotiBackendError.secureSessionUnavailable
        }
    }

    func retrieve(key: String) throws -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw TotiBackendError.secureSessionUnavailable
        }
        return data
    }

    func remove(key: String) throws {
        let result = SecItemDelete(baseQuery(key) as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else {
            throw TotiBackendError.secureSessionUnavailable
        }
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key,
         kSecAttrSynchronizable as String: false]
    }
}
