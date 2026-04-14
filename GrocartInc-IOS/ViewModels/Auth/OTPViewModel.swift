//
//  OTPViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
import Combine

@MainActor
final class OTPViewModel: ObservableObject {

    enum Step {
        case enterEmail
        case enterOTP
    }

    // MARK: - Published Properties
    @Published var email: String = ""
    @Published var otp: String = ""
    @Published var step: Step = .enterEmail
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isLoginSuccessful: Bool = false
    @Published var resendCountdown: Int = 0

    // MARK: - Dependencies
    private let authRepository: AuthRepositoryProtocol
    private let sessionManager: SessionManager
    private var countdownTimer: Timer?

    // MARK: - Init
    init(
        authRepository: AuthRepositoryProtocol? = nil,
        sessionManager: SessionManager? = nil
    ) {
        self.authRepository = authRepository ?? AuthRepository.shared
        self.sessionManager = sessionManager ?? SessionManager.shared
    }

    // MARK: - Validation
    var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.contains("@")
    }

    var isOTPValid: Bool {
        otp.count == 6 && otp.allSatisfy(\.isNumber)
    }

    var canResend: Bool {
        resendCountdown == 0 && !isLoading
    }

    // MARK: - Send OTP
    func sendOTP() {
        guard isEmailValid else {
            errorMessage = "Please enter a valid email address."
            return
        }

        errorMessage = nil
        isLoading = true
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        Task {
            do {
                let response = try await authRepository.sendOTP(email: trimmedEmail)
                isLoading = false
                if response.success {
                    email = trimmedEmail
                    step = .enterOTP
                    startResendCountdown()
                } else {
                    errorMessage = response.message
                }
            } catch let error as NetworkError {
                isLoading = false
                errorMessage = error.errorDescription
            } catch {
                isLoading = false
                errorMessage = "An unexpected error occurred. Please try again."
            }
        }
    }

    // MARK: - Resend OTP
    func resendOTP() {
        guard canResend else { return }
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let response = try await authRepository.sendOTP(email: email)
                isLoading = false
                if response.success {
                    otp = ""
                    startResendCountdown()
                } else {
                    errorMessage = response.message
                }
            } catch let error as NetworkError {
                isLoading = false
                errorMessage = error.errorDescription
            } catch {
                isLoading = false
                errorMessage = "An unexpected error occurred. Please try again."
            }
        }
    }

    // MARK: - Verify OTP
    func verifyOTP() {
        guard isOTPValid else {
            errorMessage = "Please enter the 6-digit OTP."
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                let response = try await authRepository.verifyOTP(email: email, otp: otp)
                isLoading = false
                if response.success {
                    sessionManager.saveSession(from: response)
                    isLoginSuccessful = true
                } else {
                    errorMessage = response.message
                }
            } catch let error as NetworkError {
                isLoading = false
                errorMessage = error.errorDescription
            } catch {
                isLoading = false
                errorMessage = "An unexpected error occurred. Please try again."
            }
        }
    }

    // MARK: - Go Back to Email Step
    func goBackToEmail() {
        step = .enterEmail
        otp = ""
        errorMessage = nil
        stopCountdown()
    }

    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Resend Countdown (60s)
    private func startResendCountdown() {
        resendCountdown = 60
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.resendCountdown > 0 {
                    self.resendCountdown -= 1
                } else {
                    self.stopCountdown()
                }
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        resendCountdown = 0
    }
}
