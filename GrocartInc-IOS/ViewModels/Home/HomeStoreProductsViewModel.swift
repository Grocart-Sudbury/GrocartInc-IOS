//
//  HomeStoreProductsViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-07-08.
//

import Foundation
import Combine

// A product paired with the category it belongs to, so the home preview
// can navigate straight into ProductDetailView.
struct HomeStoreProduct: Identifiable {
    let product: Product
    let categoryName: String
    var id: Int { product.id }
}

@MainActor
final class HomeStoreProductsViewModel: ObservableObject {

    // Randomized subset shown in the home preview row.
    @Published var products: [HomeStoreProduct] = []
    @Published var isLoading = false

    // Full pool fetched once; reshuffled on each appearance.
    private var pool: [HomeStoreProduct] = []
    private let store: Store
    private let repository = ProductRepository.shared

    // Number of products to preview per store.
    private let previewCount = 8

    init(store: Store) {
        self.store = store
    }

    /// Fetches the store's products on first appearance, then reshuffles so
    /// each time the home screen opens a different random set is shown.
    func loadIfNeeded() async {
        if pool.isEmpty {
            isLoading = true
            do {
                let categories = try await repository.fetchCategories(storeId: store.id)
                pool = categories.flatMap { category in
                    category.products
                        .filter { $0.isInStock }
                        .map { HomeStoreProduct(product: $0, categoryName: category.name) }
                }
            } catch {
                pool = []
            }
            isLoading = false
        }
        reshuffle()
    }

    func reshuffle() {
        products = Array(pool.shuffled().prefix(previewCount))
    }
}
