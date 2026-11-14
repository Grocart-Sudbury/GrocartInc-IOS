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
            let cancelled = try await SubscriptionRepository.shared.cancel(subscription)
            if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                subscriptions[index] = cancelled
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
