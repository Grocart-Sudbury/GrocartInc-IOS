//
//  SubscriptionCreateViewModel.swift
//  GrocartInc-IOS
//
//  Drives the new-subscription flow (two steps):
//  1. Pick a store and its items (search + category filter).
//  2. Review everything — items, frequency, delivery or pickup,
//     address, billing card — then create it.
//

import Foundation
import Combine

@MainActor
final class SubscriptionCreateViewModel: ObservableObject {
    // MARK: - Store
    @Published private(set) var stores: [Store] = []
    @Published var selectedStore: Store?
    @Published var isLoadingStores = false

    // MARK: - Items
    @Published private(set) var allItems: [(product: Product, categoryName: String)] = []
    @Published var quantities: [Int: Int] = [:]
    @Published var searchText = ""
    @Published var selectedCategory: String?
    @Published var isLoadingItems = false

    // MARK: - Schedule + fulfilment
    @Published var frequency: SubscriptionFrequency = .weekly
    @Published var fulfilment: OrderType = .delivery

    // MARK: - Address + card
    @Published private(set) var addresses: [CustomerAddress] = []
    @Published var selectedAddressId: Int?
    @Published private(set) var savedCards: [SavedCard] = []
    @Published var selectedCardId: String?
    @Published var isLoadingCards = false
    @Published var isLoadingAddresses = false

    // MARK: - Create state
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var createdSubscription: Subscription?

    // Unique category names across the store's catalogue, sorted.
    var categories: [String] {
        Array(Set(allItems.map { $0.categoryName })).sorted()
    }

    var filteredItems: [(product: Product, categoryName: String)] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allItems.filter { item in
            let matchesCategory = selectedCategory == nil || item.categoryName == selectedCategory
            guard matchesCategory else { return false }
            guard !query.isEmpty else { return true }
            return item.product.name.lowercased().contains(query)
                || item.categoryName.lowercased().contains(query)
        }
    }

    var selectedItems: [SubscriptionItem] {
        allItems.compactMap { item in
            guard let qty = quantities[item.product.id], qty > 0 else { return nil }
            return SubscriptionItem(
                productId: item.product.id,
                productName: item.product.name,
                quantity: qty,
                unitPrice: item.product.displayPrice,
                imageUrl: item.product.imageUrl
            )
        }
    }

    var totalPerCycle: Double {
        selectedItems.reduce(0) { $0 + $1.lineTotal }
    }

    var formattedTotalPerCycle: String { String(format: "$%.2f", totalPerCycle) }

    var selectedCard: SavedCard? {
        savedCards.first { $0.id == selectedCardId }
    }

    var selectedAddress: CustomerAddress? {
        addresses.first { $0.id == selectedAddressId }
    }

    var firstDeliveryDate: Date {
        Subscription.firstDeliveryDate()
    }

    var formattedFirstDelivery: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateString = formatter.string(from: firstDeliveryDate)
        let calendar = Calendar.current
        if calendar.isDateInToday(firstDeliveryDate) {
            return "today, \(dateString)"
        }
        if calendar.isDateInTomorrow(firstDeliveryDate) {
            return "tomorrow, \(dateString)"
        }
        return dateString
    }

    var canCreate: Bool {
        selectedStore != nil
        && !selectedItems.isEmpty
        && selectedCardId != nil
        && (fulfilment == .pickup || selectedAddressId != nil)
        && !isCreating
    }

    var createBlockedReason: String? {
        if selectedStore == nil { return "Choose a store first." }
        if selectedItems.isEmpty { return "Add at least one item to the subscription." }
        if selectedCardId == nil { return "Choose a saved card for billing." }
        if fulfilment == .delivery && selectedAddressId == nil {
            return "Choose a delivery address."
        }
        return nil
    }

    // MARK: - Load
    func loadStores() async {
        isLoadingStores = true
        do {
            let city = LocationState.shared.cityName
            stores = try await StoreRepository.shared.fetchActiveStores(city: city)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingStores = false
    }

    func selectStore(_ store: Store) async {
        selectedStore = store
        quantities = [:]
        isLoadingItems = true
        errorMessage = nil
        do {
            let categories = try await ProductRepository.shared.fetchCategories(storeId: store.id)
            allItems = categories.flatMap { category in
                category.products.map { (product: $0, categoryName: category.name) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingItems = false
    }

    func loadCards() async {
        isLoadingCards = true
        do {
            savedCards = try await PaymentRepository.shared.getSavedCards()
            if selectedCardId == nil {
                selectedCardId = savedCards.first(where: { $0.isDefault })?.id ?? savedCards.first?.id
            }
        } catch {
            // No saved cards (or fetch failed) — the picker shows an
            // empty state and creation stays blocked until one is added.
            savedCards = []
        }
        isLoadingCards = false
    }

    func loadAddresses() async {
        isLoadingAddresses = true
        do {
            addresses = try await AddressRepository.shared.fetchAll()
            if selectedAddressId == nil {
                selectedAddressId = addresses.first(where: { $0.isDefault })?.id ?? addresses.first?.id
            }
        } catch {
            addresses = []
        }
        isLoadingAddresses = false
    }

    // MARK: - Quantity
    func setQuantity(_ qty: Int, for productId: Int) {
        if qty <= 0 {
            quantities.removeValue(forKey: productId)
        } else {
            quantities[productId] = qty
        }
    }

    func quantity(for productId: Int) -> Int {
        quantities[productId] ?? 0
    }

    // MARK: - Create
    func create() async {
        guard let store = selectedStore,
              let cardId = selectedCardId,
              canCreate else { return }
        isCreating = true
        errorMessage = nil
        do {
            let sub = try await SubscriptionRepository.shared.create(
                store: store,
                items: selectedItems,
                frequency: frequency,
                fulfilment: fulfilment,
                paymentMethodId: cardId,
                paymentCardLabel: selectedCard.map { "\($0.displayBrand) •• \($0.last4)" },
                addressId: fulfilment == .delivery ? selectedAddressId : nil,
                deliveryAddressLabel: fulfilment == .delivery ? selectedAddress?.displayAddress : nil
            )
            createdSubscription = sub
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }
}
