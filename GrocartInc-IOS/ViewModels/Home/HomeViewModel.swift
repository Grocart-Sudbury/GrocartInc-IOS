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
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?
    
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
    
    // MARK: - Init
    init(productRepository: ProductRepositoryProtocol? = nil) {
        self.productRepository = productRepository ?? ProductRepository.shared
    }
    
    // MARK: - Load Data (cache-first)
    func loadData() {
        guard !isLoading else { return }
        
        isLoading = categories.isEmpty  // Only show loading spinner on first load
        errorMessage = nil
        
        Task {
            do {
                // 1. Load from cache first (instant)
                let cached = try await productRepository.fetchCategories(forceRefresh: false)
                self.categories = cached
                self.isLoading = false
                
                // 2. Background refresh if cache was used
                if CacheManager.shared.isValid(forKey: "categories", ttl: APIConfig.categoryCacheTTL) {
                    // Cache is still valid, no background refresh needed
                    return
                }
                
                // 3. If we got here, cache was expired but we still showed it
                // Now fetch fresh data silently
                let fresh = try await productRepository.fetchCategories(forceRefresh: true)
                self.categories = fresh
                
            } catch let error as NetworkError {
                // If we have cached data, keep showing it despite error
                if categories.isEmpty {
                    self.errorMessage = error.errorDescription
                }
                self.isLoading = false
            } catch {
                if categories.isEmpty {
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
        
        do {
            let fresh = try await productRepository.fetchCategories(forceRefresh: true)
            self.categories = fresh
        } catch let error as NetworkError {
            self.errorMessage = error.errorDescription
        } catch {
            self.errorMessage = "Something went wrong. Please try again."
        }
        
        isRefreshing = false
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
