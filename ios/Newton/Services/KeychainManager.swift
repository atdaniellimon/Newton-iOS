//
//  KeychainManager.swift
//  Newton
//
//  Generic Keychain helper. Provider-specific API removed — use AuthManager for nwtn keys.
//

import Foundation
import Security

public final class KeychainManager {
    public static let shared = KeychainManager()
    private let serviceName = "com.newton.ai.keychain"

    private init() {}

    // MARK: - Generic string-keyed API

    public func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(forKey: key)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let query: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    serviceName,
            kSecAttrAccount as String:    key,
            kSecValueData as String:      data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    public func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    public func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Legacy provider-keyed shims (kept for build compatibility — no-ops)
    @available(*, deprecated, message: "Use AuthManager for NWTN keys")
    public func saveApiKey(_ key: String, for account: String) {
        save(key, forKey: "apiKey_\(account)")
    }

    @available(*, deprecated, message: "Use AuthManager for NWTN keys")
    public func getApiKey(for account: String) -> String {
        get(forKey: "apiKey_\(account)") ?? ""
    }

    @available(*, deprecated, message: "Use AuthManager for NWTN keys")
    public func deleteApiKey(for account: String) {
        delete(forKey: "apiKey_\(account)")
    }
}
