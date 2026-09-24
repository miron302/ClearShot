import Foundation
import Security

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            return "Keychain error (status \(status))."
        case .encodingFailed:
            return "Could not encode the API key for storage."
        }
    }
}

/// Thin wrapper around the Keychain Services C API for storing per-provider
/// API keys. Each provider gets its own generic-password item, keyed by
/// service name + account, so keys are never mixed up and can be individually
/// removed.
final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private func service(for provider: AIProviderID) -> String {
        "com.clearshot.mac.apikey.\(provider.rawValue)"
    }
    private let account = "default"

    func saveAPIKey(_ key: String, for provider: AIProviderID) throws {
        guard let data = key.data(using: .utf8) else { throw KeychainError.encodingFailed }
        let service = service(for: provider)

        // Remove any existing item first so this behaves as an upsert.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func readAPIKey(for provider: AIProviderID) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: provider),
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let key = String(data: data, encoding: .utf8) else { return nil }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status)
        }
    }

    func deleteAPIKey(for provider: AIProviderID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: provider),
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}
