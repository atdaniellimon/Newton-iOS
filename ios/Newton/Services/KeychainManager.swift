//
//  KeychainManager.swift
//  Newton
//
//  Created for Newton iOS.
//

import Foundation
import Security

public final class KeychainManager {
    public static let shared = KeychainManager()
    private let serviceName = "com.newton.ai.keychain"
    
    private init() {}
    
    public func saveApiKey(_ key: String, for provider: AIProvider) {
        let account = "apiKey_\(provider.rawValue)"
        guard let data = key.data(using: .utf8) else { return }
        
        // Delete existing item first
        deleteApiKey(for: provider)
        
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    public func getApiKey(for provider: AIProvider) -> String {
        let account = "apiKey_\(provider.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data, let key = String(data: data, encoding: .utf8) {
            return key
        }
        return ""
    }
    
    public func deleteApiKey(for provider: AIProvider) {
        let account = "apiKey_\(provider.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
