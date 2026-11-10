//
//  SubscriptionViewModel.swift
//  GrocartInc-IOS
//

import Foundation
import Combine

@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published private(set) var subscriptions: [Subscription] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            subscriptions = try await SubscriptionRepository.shared.fetchMySubscriptions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func cancel(_ subscription: Subscription) async {
        errorMessage = nil
        do {
            try await SubscriptionRepository.shared.cancel(id: subscription.id)
            subscriptions.removeAll { $0.id == subscription.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
