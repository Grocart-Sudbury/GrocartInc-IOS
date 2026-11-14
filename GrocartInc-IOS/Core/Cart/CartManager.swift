//
//  CartManager.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
import Combine

@MainActor
final class CartManager: ObservableObject {

    static let shared = CartManager()

    @Published private(set) var items: [CartItem] = []
    @Published private(set) var store: Store? = nil

    private init() {}

    // MARK: - Computed

    var itemCount: Int { items.reduce(0) { $0 + $1.count } }

    var subtotal: Double {
        items.reduce(0) { $0 + $1.product.displayPrice * Double($1.count) }
    }

    var formattedSubtotal: String { String(format: "$%.2f", subtotal) }

    var isEmpty: Bool { items.isEmpty }

    // MARK: - Add / Increment

    func add(product: Product, categoryName: String, store: Store) {
        // If cart has items from a different store, clear first
        if let existing = self.store, existing.id != store.id {
            items.removeAll()
        }
        self.store = store

        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].count += 1
        } else {
            items.append(CartItem(product: product, categoryName: categoryName, store: store, count: 1))
        }
    }

    // MARK: - Decrement / Remove

    func decrement(productId: Int) {
        guard let index = items.firstIndex(where: { $0.product.id == productId }) else { return }
        if items[index].count > 1 {
            items[index].count -= 1
        } else {
            items.remove(at: index)
            if items.isEmpty { store = nil }
        }
    }

    func remove(productId: Int) {
        items.removeAll { $0.product.id == productId }
        if items.isEmpty { store = nil }
    }

    // MARK: - Count for product

    func count(for productId: Int) -> Int {
        items.first(where: { $0.product.id == productId })?.count ?? 0
    }

    // MARK: - Clear

    func clear() {
        items.removeAll()
        store = nil
    }

    // MARK: - Build pricing request

    func pricingRequest(couponCode: String? = nil, pointsToRedeem: Int? = nil) -> CartPricingRequest {
        let city = LocationState.shared.cityName
        let cityCode = CartPricingRequest.cityCode(for: city)

        let requestItems = items.map { item in
            CartPricingRequest.CartItemRequest(
                id: item.product.id,
                product: item.product.name,
                originalPrice: item.product.originalPrice,
                offerPrice: item.product.displayPrice,
                description: item.product.description,
                stock: item.product.stock,
                imageUrl: item.product.imageUrl,
                category: item.categoryName,
                quantity: item.count
            )
        }

        return CartPricingRequest(cart: requestItems, couponCode: couponCode, cityCode: cityCode, pointsToRedeem: pointsToRedeem)
    }
}
