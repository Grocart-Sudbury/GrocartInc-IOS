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

    // Suggestions underneath the cart: top sellers when the cart is empty,
    // items from the same categories when it has products.
    @Published var suggestions: [SearchItem] = []
    @Published var suggestionsTitle = "Top selling items"
    @Published var isLoadingSuggestions = false

    private let repository = CartRepository.shared
    private let cartManager = CartManager.shared
    private let storeRepository = StoreRepository.shared
    private let productRepository = ProductRepository.shared
    private let orderRepository = OrderRepository.shared
    private var cancellables = Set<AnyCancellable>()
    private var pricingTask: Task<Void, Never>? = nil

    // Catalogue + top sellers for the store the suggestions come from.
    private var cachedStoreId: Int?
    private var cachedCategories: [Category] = []
    private var cachedTopProducts: [TopOrderedProduct] = []

    init() {
        // Re-fetch pricing whenever cart changes
        cartManager.$items
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.fetchPricing()
                Task { await self?.refreshSuggestions() }
            }
            .store(in: &cancellables)

        // Re-load suggestions when the city resolves or changes.
        LocationState.shared.$cityName
            .filter { !$0.isEmpty && $0 != "Locating..." && $0 != "Location Off" }
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { await self?.refreshSuggestions() }
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

    // MARK: - Suggestions

    func loadSuggestions() {
        Task { await refreshSuggestions() }
    }

    private func refreshSuggestions() async {
        // Suggestions come from one store: the cart's store, or the first
        // active store in the city when the cart is empty.
        var store = cartManager.store
        if store == nil {
            let city = LocationState.shared.cityName
            guard !city.isEmpty, city != "Locating...", city != "Location Off" else { return }
            do {
                let stores = try await storeRepository.fetchActiveStores(city: city)
                store = stores.first
            } catch {
                store = nil
            }
        }
        guard let store else { return }
        let resolvedStore = store

        // Fetch the catalogue + top sellers once per store; recompute from
        // the cache whenever the cart changes.
        if cachedStoreId != store.id {
            isLoadingSuggestions = true
            async let categories = productRepository.fetchCategories(storeId: store.id)
            async let top = orderRepository.fetchTopProducts(storeId: store.id)
            do {
                cachedCategories = try await categories
                cachedTopProducts = try await top
            } catch {
                cachedCategories = []
                cachedTopProducts = []
            }
            cachedStoreId = store.id
            isLoadingSuggestions = false
        }

        let categoryById: [Int: String] = Dictionary(
            cachedCategories.flatMap { category in
                category.products.map { ($0.id, category.name) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        func item(for product: Product) -> SearchItem {
            SearchItem(product: product, store: resolvedStore, categoryName: categoryById[product.id] ?? "")
        }

        if cartManager.isEmpty {
            suggestionsTitle = "Top selling items"
            suggestions = cachedTopProducts.map { item(for: $0.asProduct) }
        } else {
            suggestionsTitle = "Based on your cart"
            let cartIds = Set(cartManager.items.map(\.product.id))
            let cartCategories = Set(cartManager.items.map(\.categoryName))
            var related = cachedCategories
                .filter { cartCategories.contains($0.name) }
                .flatMap(\.products)
                .filter { !cartIds.contains($0.id) }
            // On-sale items first, then alphabetical.
            related.sort {
                if $0.isOnSale != $1.isOnSale { return $0.isOnSale }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            var picked = Array(related.prefix(8).map(item(for:)))
            if picked.count < 6 {
                let pickedIds = Set(picked.map(\.product.id))
                let fillers = cachedTopProducts
                    .map(\.asProduct)
                    .filter { !cartIds.contains($0.id) && !pickedIds.contains($0.id) }
                picked.append(contentsOf: fillers.prefix(8 - picked.count).map(item(for:)))
            }
            suggestions = picked
        }
    }
}
