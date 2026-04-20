// OrdersViewModel.swift
// GrocartInc-IOS

import Foundation
import Combine

@MainActor
final class OrdersViewModel: ObservableObject {

    @Published var orders: [CustomerOrderSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repo = CustomerRepository.shared

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                orders = try await repo.getOrders()
            } catch let e as NetworkError {
                errorMessage = e.errorDescription
            } catch {
                errorMessage = "Failed to load orders."
            }
            isLoading = false
        }
    }
}
