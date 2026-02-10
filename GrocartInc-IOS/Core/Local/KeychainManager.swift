//
//  KeychainManager.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

//
//  KeychainManager.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation
import Security

final class KeychainManager {
    
    static let shared = KeychainManager()
    private let serviceName = "com.grocartinc.ios"
    
    private init() {}
    
    // MARK: - Save
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete existing item first
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Retrieve
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Delete
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Clear All
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Keychain Keys
extension KeychainManager {
    struct Keys {
        static let authToken = "auth_token"
        static let userId = "user_id"
    }
}
