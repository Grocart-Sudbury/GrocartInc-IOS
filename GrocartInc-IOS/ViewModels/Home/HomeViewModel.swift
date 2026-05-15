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
    @Published var categories: [Category] = []
    @Published var stores: [Store] = []
    @Published var banners: [PromoBanner] = []
    @Published var isLoadingStores: Bool = false
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed
    var featuredProducts: [Product] {
        categories
            .flatMap { $0.products }
            .filter { $0.isOnSale && $0.isInStock }
            .sorted { $0.discountPercentage > $1.discountPercentage }
            .prefix(10)
            .map { $0 }
    }
    
    var allProducts: [Product] {
        categories.flatMap { $0.products }
    }
    
    // MARK: - Dependencies
    private let productRepository: ProductRepositoryProtocol
    private let storeRepository: StoreRepository
    private let homeRepository: HomeRepository

    // MARK: - Init
    init(productRepository: ProductRepositoryProtocol? = nil) {
        self.productRepository = productRepository ?? ProductRepository.shared
        self.storeRepository = StoreRepository.shared
        self.homeRepository = HomeRepository.shared

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
    
    // MARK: - Load Data (cache-first)
    func loadData() {
        guard !isLoading else { return }
        
        isLoading = categories.isEmpty  // Only show loading spinner on first load
        errorMessage = nil
        
        Task {
            // Banners are always live — fetch independently and hide on error
            self.banners = (try? await homeRepository.fetchBanners()) ?? []

            do {
                // 1. Load categories from cache first (instant)
                let cached = try await productRepository.fetchCategories(forceRefresh: false)
                self.categories = cached
                self.isLoading = false

                // 2. Background refresh only if cache is expired
                if CacheManager.shared.isValid(forKey: "categories", ttl: APIConfig.categoryCacheTTL) {
                    return
                }

                // 3. Cache expired — silently refresh
                let fresh = try await productRepository.fetchCategories(forceRefresh: true)
                self.categories = fresh

            } catch let error as NetworkError {
                if categories.isEmpty && SessionManager.shared.isLoggedIn {
                    self.errorMessage = error.errorDescription
                }
                self.isLoading = false
            } catch {
                if categories.isEmpty && SessionManager.shared.isLoggedIn {
                    self.errorMessage = "Something went wrong. Please try again."
                }
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Pull to Refresh (always hits API)
    func refresh() async {
        isRefreshing = true
        errorMessage = nil

        self.banners = (try? await homeRepository.fetchBanners()) ?? []

        do {
            let fresh = try await productRepository.fetchCategories(forceRefresh: true)
            self.categories = fresh
        } catch let error as NetworkError {
            self.errorMessage = error.errorDescription
        } catch {
            self.errorMessage = "Something went wrong. Please try again."
        }

        let city = LocationState.shared.cityName
        if !city.isEmpty, city != "Locating...", city != "Location Off" {
            await loadStores(city: city, forceRefresh: true)
        }

        isRefreshing = false
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
    }

    // MARK: - Search
    func searchProducts(query: String) -> [Product] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return allProducts
        }
        
        let lowered = query.lowercased()
        return allProducts.filter {
            $0.product.lowercased().contains(lowered) ||
            $0.description.lowercased().contains(lowered)
        }
    }
    
    // MARK: - Filter by Category
    func products(forCategoryId id: Int) -> [Product] {
        categories.first(where: { $0.id == id })?.products ?? []
    }
}
