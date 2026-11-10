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
                // Order status changes (placed, processing, in transit,
                // delivered, cancelled) show as notifications.
                NotificationManager.shared.checkOrders(orders.map {
                    (id: $0.id, trackingId: $0.trackingId ?? "#\($0.id)", stage: $0.status.orderStage)
                })
            } catch let e as NetworkError {
                errorMessage = e.errorDescription
            } catch {
                errorMessage = "Failed to load orders."
            }
            isLoading = false
        }
    }
}
