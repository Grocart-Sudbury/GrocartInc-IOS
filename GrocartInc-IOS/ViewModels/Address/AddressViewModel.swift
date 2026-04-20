// AddressViewModel.swift
// GrocartInc-IOS

import Foundation
import Combine

@MainActor
final class AddressViewModel: ObservableObject {

    @Published var addresses: [CustomerAddress] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let repo = AddressRepository.shared

    // MARK: - Load

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                addresses = try await repo.fetchAll()
            } catch let e as NetworkError {
                errorMessage = e.errorDescription
            } catch {
                errorMessage = "Failed to load addresses."
            }
            isLoading = false
        }
    }

    // MARK: - Add

    func add(_ request: AddressRequest) async throws {
        let new = try await repo.add(request)
        if request.isDefault {
            addresses = addresses.map { var a = $0; a.isDefault = false; return a }
        }
        addresses.append(new)
    }

    // MARK: - Update

    func update(id: Int, request: AddressRequest) async throws {
        let updated = try await repo.update(id: id, request: request)
        if request.isDefault {
            addresses = addresses.map { var a = $0; a.isDefault = false; return a }
        }
        if let idx = addresses.firstIndex(where: { $0.id == id }) {
            addresses[idx] = updated
        }
    }

    // MARK: - Set Default

    func setDefault(id: Int) {
        Task {
            do {
                try await repo.setDefault(id: id)
                addresses = addresses.map { var a = $0; a.isDefault = (a.id == id); return a }
            } catch let e as NetworkError {
                errorMessage = e.errorDescription
            } catch {
                errorMessage = "Failed to set default address."
            }
        }
    }

    // MARK: - Delete

    func delete(id: Int) {
        Task {
            do {
                try await repo.delete(id: id)
                addresses.removeAll { $0.id == id }
            } catch let e as NetworkError {
                errorMessage = e.errorDescription
            } catch {
                errorMessage = "Failed to delete address."
            }
        }
    }

    var defaultAddress: CustomerAddress? {
        addresses.first(where: { $0.isDefault }) ?? addresses.first
    }

    var canAddMore: Bool { addresses.count < 10 }
}
