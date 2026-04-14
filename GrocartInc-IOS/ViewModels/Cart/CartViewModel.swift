//
//  CartViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
import Combine

@MainActor
final class CartViewModel: ObservableObject {

    @Published var pricing: CartPricingResponse? = nil
    @Published var isLoadingPricing = false
    @Published var pricingError: String? = nil

    private let repository = CartRepository.shared
    private let cartManager = CartManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var pricingTask: Task<Void, Never>? = nil

    init() {
        // Re-fetch pricing whenever cart changes
        cartManager.$items
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchPricing()
            }
            .store(in: &cancellables)
    }

    func fetchPricing() {
        guard !cartManager.isEmpty else {
            pricing = nil
            return
        }

        pricingTask?.cancel()
        isLoadingPricing = true
        pricingError = nil

        pricingTask = Task {
            do {
                let result = try await repository.fetchPricing(request: cartManager.pricingRequest())
                guard !Task.isCancelled else { return }
                pricing = result
            } catch let error as NetworkError {
                guard !Task.isCancelled else { return }
                pricingError = error.errorDescription
            } catch {
                guard !Task.isCancelled else { return }
                pricingError = "Could not calculate pricing."
            }
            isLoadingPricing = false
        }
    }
}
