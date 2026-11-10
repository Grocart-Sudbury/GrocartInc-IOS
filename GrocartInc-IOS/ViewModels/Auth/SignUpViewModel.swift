//
//  SignUpViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-11.
//

import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "SignUp")

@MainActor
final class SignUpViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""
    @Published var phone: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var agreedToTerms: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isRegistrationSuccessful: Bool = false
    @Published var successMessage: String?
    
    // MARK: - Dependencies
    private let authRepository: AuthRepositoryProtocol
    
    // MARK: - Init
    init(authRepository: AuthRepositoryProtocol? = nil) {
        self.authRepository = authRepository ?? AuthRepository.shared
        logger.info("SignUpViewModel initialized")
    }
    
    // MARK: - Validation
    var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.contains("@") &&
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        agreedToTerms
    }
    
    var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }
    
    // MARK: - Register
    func register() {
        logger.info("Register tapped")
        
        guard isFormValid else {
            logger.warning("Form validation failed - firstName: \(self.firstName.isEmpty), lastName: \(self.lastName.isEmpty), email: \(self.email.isEmpty), phone: \(self.phone.isEmpty), passwordLength: \(self.password.count), passwordsMatch: \(self.password == self.confirmPassword), agreedToTerms: \(self.agreedToTerms)")
            errorMessage = "Please fill in all fields correctly."
            return
        }
        
        logger.info("Form valid - proceeding with registration")
        
        errorMessage = nil
        isLoading = true
        
        let request = RegisterRequest(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        logger.debug("RegisterRequest created")
        
        let repo = authRepository
        
        Task {
            do {
                logger.info("Calling register API...")
                let response = try await repo.register(request: request)
                logger.info("Registration successful")
                logger.info("Server message: \(response.message ?? "none")")
                
                isLoading = false
                successMessage = response.message ?? "Registration successful. Please login."
                isRegistrationSuccessful = true
            } catch let error as NetworkError {
                logger.error("Registration failed with NetworkError: \(error.errorDescription ?? "unknown")")
                isLoading = false
                errorMessage = error.errorDescription
            } catch {
                logger.error("Registration failed with unexpected error: \(error.localizedDescription)")
                isLoading = false
                errorMessage = "An unexpected error occurred. Please try again."
            }
        }
    }
    
    // MARK: - Clear Error
    func clearError() {
        logger.debug("Error cleared")
        errorMessage = nil
    }
}
