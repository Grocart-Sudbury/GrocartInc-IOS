// ProfileViewModel.swift
// GrocartInc-IOS

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var profile: CustomerProfile?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let repo = CustomerRepository.shared

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                profile = try await repo.getProfile()
            } catch let e as NetworkError {
                errorMessage = e.errorDescription
            } catch {
                errorMessage = "Failed to load profile."
            }
            isLoading = false
        }
    }

    func update(firstName: String, lastName: String, phone: String) async -> Bool {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { isSaving = false }
        do {
            let request = UpdateProfileRequest(firstName: firstName, lastName: lastName, phone: phone)
            profile = try await repo.updateProfile(request)
            // Keep SessionManager in sync
            if let user = SessionManager.shared.currentUser {
                let updated = User(id: user.id, email: user.email, role: user.role,
                                   firstName: firstName, lastName: lastName, token: user.token)
                if let data = try? JSONEncoder().encode(updated) {
                    UserDefaults.standard.set(data, forKey: "current_user")
                }
                SessionManager.shared.currentUser = updated
            }
            successMessage = "Profile updated successfully."
            return true
        } catch let e as NetworkError {
            errorMessage = e.errorDescription
        } catch {
            errorMessage = "Failed to update profile."
        }
        return false
    }
}
