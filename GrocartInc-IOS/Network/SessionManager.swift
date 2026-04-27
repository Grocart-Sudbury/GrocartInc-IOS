//
//  SessionManager.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

//
//  SessionManager.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation
import Combine

final class SessionManager: ObservableObject {
    
    static let shared = SessionManager()
    
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    
    private init() {
        loadSession()
    }
    
    // MARK: - Save Session
    func saveSession(from response: LoginResponse) {
        let user = User(
            id: response.userId,
            email: response.email,
            role: response.role,
            firstName: response.firstName,
            lastName: response.lastName,
            token: response.token
        )
        
        // Save token securely in Keychain
        KeychainManager.shared.save(key: KeychainManager.Keys.authToken, value: response.token)
        KeychainManager.shared.save(key: KeychainManager.Keys.userId, value: String(response.userId))
        
        // Save user info in UserDefaults
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "current_user")
        }
        
        resetLocationCache()
        DispatchQueue.main.async {
            self.currentUser = user
            self.isLoggedIn = true
        }
    }

    // MARK: - Save Session (OTP)
    func saveSession(from response: OTPVerifyResponse) {
        guard let token = response.token, let customer = response.customer else { return }

        let user = User(
            id: customer.id,
            email: customer.email,
            role: "CUSTOMER",
            firstName: customer.firstName,
            lastName: customer.lastName,
            token: token
        )

        KeychainManager.shared.save(key: KeychainManager.Keys.authToken, value: token)
        KeychainManager.shared.save(key: KeychainManager.Keys.userId, value: String(customer.id))

        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "current_user")
        }

        resetLocationCache()
        DispatchQueue.main.async {
            self.currentUser = user
            self.isLoggedIn = true
        }
    }

    // MARK: - Load Session
    func loadSession() {
        guard let token = KeychainManager.shared.get(key: KeychainManager.Keys.authToken),
              !token.isEmpty,
              let userData = UserDefaults.standard.data(forKey: "current_user"),
              let user = try? JSONDecoder().decode(User.self, from: userData)
        else {
            isLoggedIn = false
            currentUser = nil
            return
        }
        
        // Check if token is expired
        if isTokenExpired(token) {
            clearSession()
            return
        }
        
        currentUser = user
        isLoggedIn = true
    }
    
    // MARK: - Clear Session
    func clearSession() {
        KeychainManager.shared.clearAll()
        UserDefaults.standard.removeObject(forKey: "current_user")
        
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isLoggedIn = false
        }
    }
    
    // MARK: - Get Token
    var authToken: String? {
        return KeychainManager.shared.get(key: KeychainManager.Keys.authToken)
    }
    
    // MARK: - Location Cache Reset
    private func resetLocationCache() {
        UserDefaults.standard.removeObject(forKey: "grocart.selectedCity")
        CacheManager.shared.clearAll()
        DispatchQueue.main.async {
            LocationState.shared.cityName = "Locating..."
            LocationManager.shared.resetAndRequestLocation()
        }
    }

    // MARK: - Token Expiry Check
    private func isTokenExpired(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return true }
        
        var payload = String(parts[1])
        // Add padding if needed
        let remainder = payload.count % 4
        if remainder > 0 {
            payload += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval
        else { return true }
        
        return Date(timeIntervalSince1970: exp) < Date()
    }
}
