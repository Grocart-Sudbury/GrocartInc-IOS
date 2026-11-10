//
//  SearchViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-19.
//

import Foundation
import Combine

/// One product as sold by one store. The same product can appear once per
/// store, because search shows every item regardless of which store sells it.
struct SearchItem: Identifiable, Sendable {
    let product: Product
    let store: Store
    let categoryName: String

    var id: String { "\(store.id)-\(product.id)" }
}

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var stores: [Store] = []
    @Published var allItems: [SearchItem] = []
    @Published var query = ""
    @Published var isLoading = false

    /// Normalizes text for searching: lowercased with every character that
    /// is not a letter or a digit removed, so punctuation never affects a
    /// match. "Lay's" and "lays" both become "lays".
    private func normalizedForSearch(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    /// Items matching the search text, or every item when nothing is typed.
    /// Punctuation is ignored on both sides, so "lays" matches "Lay's".
    var filteredItems: [SearchItem] {
        let text = normalizedForSearch(query)
        guard !text.isEmpty else { return allItems }
        return allItems.filter {
            normalizedForSearch($0.product.name).contains(text)
                || normalizedForSearch($0.categoryName).contains(text)
                || normalizedForSearch($0.store.name).contains(text)
        }
    }

    var storeCount: Int {
        Set(allItems.map(\.store.id)).count
    }

    private var cancellables = Set<AnyCancellable>()
    private let storeRepository = StoreRepository.shared
    private var loadedCity: String?

    init() {
        // Re-load everything when the city resolves or changes.
        LocationState.shared.$cityName
            .filter { !$0.isEmpty && $0 != "Locating..." && $0 != "Location Off" }
            .removeDuplicates()
            .sink { [weak self] city in
                Task { await self?.loadAll(city: city) }
            }
            .store(in: &cancellables)
    }

    /// Loads every product from every active store, in parallel.
    /// There is no single "all products" endpoint, so this reuses the same
    /// per-store catalogue call the store page already uses.
    /// The list is shuffled on every load, so the Search tab shows products
    /// in a new random order each time it refreshes.
    /// Pass `force: true` to re-fetch even when this city is already loaded.
    func loadAll(city: String, force: Bool = false) async {
        guard !city.isEmpty, city != "Locating...", city != "Location Off" else { return }
        if !force, loadedCity == city, !allItems.isEmpty { return }
        guard !isLoading else { return }
        loadedCity = city
        isLoading = true

        do {
            stores = try await storeRepository.fetchActiveStores(city: city)
        } catch {
            stores = []
        }

        let items = await withTaskGroup(of: [SearchItem].self) { group in
            for store in stores {
                group.addTask {
                    do {
                        let categories = try await ProductRepository.shared.fetchCategories(storeId: store.id)
                        return categories.flatMap { category in
                            category.products.map {
                                SearchItem(product: $0, store: store, categoryName: category.name)
                            }
                        }
                    } catch {
                        return []
                    }
                }
            }
            var collected: [SearchItem] = []
            for await batch in group {
                collected.append(contentsOf: batch)
            }
            return collected
        }

        if !items.isEmpty {
            // Fresh data: show it in a new random order.
            allItems = items.shuffled()
            // New products and price/discount changes show as notifications.
            NotificationManager.shared.checkProducts(items.map { (product: $0.product, store: $0.store, categoryName: $0.categoryName) })
        } else if allItems.isEmpty {
            allItems = []
        } else {
            // The refresh failed but we already have products: keep them and
            // just reshuffle, so the list never blanks out on a bad connection.
            allItems = allItems.shuffled()
        }
        isLoading = false
    }

    /// Forces a fresh fetch and a new random order. The Search tab calls this
    /// when it appears and whenever the user performs a search, so the
    /// products refresh automatically and show in a random order each time.
    func refresh() async {
        await loadAll(city: LocationState.shared.cityName, force: true)
    }
}
