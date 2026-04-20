//
//  SearchViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-19.
//

import Foundation
import Combine

struct SearchResult: Identifiable {
    var id: Int { product.id }
    let product: Product
    let categoryName: String
}

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var stores: [Store] = []
    @Published var selectedStore: Store?
    @Published var searchText = ""
    @Published var searchResults: [SearchResult] = []
    @Published var recentSearches: [String] = []
    @Published var isLoadingStores = false
    @Published var isLoadingProducts = false

    private var categories: [Category] = []
    private var cancellables = Set<AnyCancellable>()
    private let storeRepository = StoreRepository.shared
    private let productRepository = ProductRepository.shared

    private static let recentSearchesKey = "search_recent_queries"
    private static let maxRecentSearches = 10

    init() {
        recentSearches = Self.loadRecentSearches()

        // Re-load stores when city changes
        LocationState.shared.$cityName
            .filter { !$0.isEmpty && $0 != "Locating..." && $0 != "Location Off" }
            .removeDuplicates()
            .sink { [weak self] city in
                Task { await self?.loadStores(city: city) }
            }
            .store(in: &cancellables)

        // Debounced search
        $searchText
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] query in self?.filterProducts(query: query) }
            .store(in: &cancellables)

        // Load products when store is selected
        $selectedStore
            .compactMap { $0 }
            .removeDuplicates { $0.id == $1.id }
            .sink { [weak self] store in
                Task { await self?.loadCategories(for: store) }
            }
            .store(in: &cancellables)
    }

    func loadStores(city: String) async {
        isLoadingStores = true
        do {
            stores = try await storeRepository.fetchActiveStores(city: city)
        } catch {
            // silent — stores list stays empty
        }
        isLoadingStores = false
    }

    func selectStore(_ store: Store) {
        selectedStore = store
        searchText = ""
        searchResults = []
        categories = []
    }

    func clearStore() {
        selectedStore = nil
        searchText = ""
        searchResults = []
        categories = []
    }

    private func loadCategories(for store: Store) async {
        isLoadingProducts = true
        do {
            categories = try await productRepository.fetchCategories(storeId: store.id)
        } catch {
            categories = []
        }
        isLoadingProducts = false
        filterProducts(query: searchText)
    }

    private func filterProducts(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        let lowered = trimmed.lowercased()
        searchResults = categories.flatMap { category in
            category.products
                .filter {
                    $0.product.lowercased().contains(lowered) ||
                    $0.description.lowercased().contains(lowered)
                }
                .map { SearchResult(product: $0, categoryName: category.name) }
        }
        if !searchResults.isEmpty {
            saveSearch(trimmed)
        }
    }

    // MARK: - Search History

    func applyRecent(_ query: String) {
        searchText = query
    }

    func removeRecent(_ query: String) {
        recentSearches.removeAll { $0 == query }
        Self.persist(recentSearches)
    }

    func clearAllRecent() {
        recentSearches = []
        Self.persist([])
    }

    private func saveSearch(_ query: String) {
        var updated = recentSearches.filter { $0.lowercased() != query.lowercased() }
        updated.insert(query, at: 0)
        if updated.count > Self.maxRecentSearches {
            updated = Array(updated.prefix(Self.maxRecentSearches))
        }
        recentSearches = updated
        Self.persist(updated)
    }

    private static func loadRecentSearches() -> [String] {
        UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }

    private static func persist(_ searches: [String]) {
        UserDefaults.standard.set(searches, forKey: recentSearchesKey)
    }
}
