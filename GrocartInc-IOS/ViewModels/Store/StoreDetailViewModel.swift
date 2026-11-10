//
//  StoreDetailViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
import Combine

@MainActor
final class StoreDetailViewModel: ObservableObject {

    @Published var categories: [Category] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    let store: Store
    private let repository = ProductRepository.shared

    init(store: Store) {
        self.store = store
    }

    func loadCategories() {
        guard categories.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                categories = try await repository.fetchCategories(storeId: store.id)
                // New products and price/discount changes show as notifications.
                NotificationManager.shared.checkProducts(
                    categories.flatMap { category in
                        category.products.map { (product: $0, store: store, categoryName: category.name) }
                    }
                )
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Something went wrong. Please try again."
            }
            isLoading = false
        }
    }

    func retry() {
        categories = []
        loadCategories()
    }
}
