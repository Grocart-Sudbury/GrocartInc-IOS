//
//  HomeViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-12.
//

//
//  HomeViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-12.
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var stores: [Store] = []
    @Published var topProducts: [TopOrderedProduct] = []
    @Published var isLoadingStores: Bool = false
    @Published var isLoadingTopProducts: Bool = false
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies
    private let storeRepository: StoreRepository
    private let orderRepository: OrderRepository

    // MARK: - Init
    init(productRepository: ProductRepositoryProtocol? = nil) {
        self.storeRepository = StoreRepository.shared
        self.orderRepository = OrderRepository.shared

        // Re-fetch stores whenever the city resolves or changes.
        // Use `scan` to track whether we passed through "Locating..." so that
        // re-login always triggers a fresh fetch even when the city is the same.
        LocationState.shared.$cityName
            .scan((prev: "", current: "")) { state, city in (state.current, city) }
            .filter { _, city in !city.isEmpty && city != "Locating..." && city != "Location Off" }
            .filter { prev, city in prev != city || prev == "Locating..." || prev == "" }
            .map { _, city in city }
            .sink { [weak self] city in
                Task { await self?.loadStores(city: city) }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Pull to Refresh
    func refresh() async {
        isRefreshing = true
        errorMessage = nil

        let city = LocationState.shared.cityName
        if !city.isEmpty, city != "Locating...", city != "Location Off" {
            await loadStores(city: city, forceRefresh: true)
        }

        isRefreshing = false
    }

    // MARK: - Load Top Products (per-store, public)
    func loadTopProducts(storeId: Int) async {
        isLoadingTopProducts = true
        do {
            topProducts = try await orderRepository.fetchTopProducts(storeId: storeId)
        } catch {
            // Silently fail — section just stays hidden
            topProducts = []
        }
        isLoadingTopProducts = false
    }

    // MARK: - Load Stores
    func loadStores(city: String, forceRefresh: Bool = false) async {
        isLoadingStores = true
        do {
            stores = try await storeRepository.fetchActiveStores(city: city, forceRefresh: forceRefresh)
        } catch {
            // Silently fail — stores list just stays empty
        }
        isLoadingStores = false

        // Top products are per-store — use the first (nearest) store.
        if let firstStore = stores.first {
            await loadTopProducts(storeId: firstStore.id)
        } else {
            topProducts = []
        }
    }

}
