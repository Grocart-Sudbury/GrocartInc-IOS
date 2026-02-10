//
//  LoginViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isLoginSuccessful: Bool = false
    
    // MARK: - Dependencies
    private let authRepository: AuthRepositoryProtocol
    private let sessionManager: SessionManager
    
    // MARK: - Init
    init(
        authRepository: AuthRepositoryProtocol? = nil,
        sessionManager: SessionManager? = nil
    ) {
        self.authRepository = authRepository ?? AuthRepository.shared
        self.sessionManager = sessionManager ?? SessionManager.shared
    }
    
    // MARK: - Validation
    var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        email.contains("@")
    }
    
    // MARK: - Login
    func login() {
        guard isFormValid else {
            errorMessage = "Please enter a valid email and password."
            return
        }
        
        errorMessage = nil
        isLoading = true
        
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let password = password
        let repo = authRepository
        
        Task {
            do {
                let response = try await repo.login(email: email, password: password)
                sessionManager.saveSession(from: response)
                isLoading = false
                isLoginSuccessful = true
            } catch let error as NetworkError {
                isLoading = false
                errorMessage = error.errorDescription
            } catch {
                isLoading = false
                errorMessage = "An unexpected error occurred. Please try again."
            }
        }
    }
    
    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }
}
