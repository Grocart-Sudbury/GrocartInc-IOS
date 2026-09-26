//
//  SearchViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-19.
//

import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {

    @Published var stores: [Store] = []
    @Published var isLoadingStores = false

    private var cancellables = Set<AnyCancellable>()
    private let storeRepository = StoreRepository.shared

    init() {
        // Re-load stores when city changes
        LocationState.shared.$cityName
            .filter { !$0.isEmpty && $0 != "Locating..." && $0 != "Location Off" }
            .removeDuplicates()
            .sink { [weak self] city in
                Task { await self?.loadStores(city: city) }
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
}
