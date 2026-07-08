//
//  Product.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-12.
//

//
//  ProductModels.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-12.
//

import Foundation

// MARK: - Category with Products
struct Category: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let products: [Product]
}

// MARK: - Product
struct Product: Codable, Identifiable, Sendable {
    let id: Int
    let product: String
    let originalPrice: Double
    let offerPrice: Double?
    let description: String
    let stock: Int
    let quantity: String
    let imageUrl: String
    let productType: String

    var name: String { product }

    var displayPrice: Double { offerPrice ?? originalPrice }

    var isOnSale: Bool {
        guard let offer = offerPrice else { return false }
        return offer < originalPrice
    }

    var discountPercentage: Int {
        guard originalPrice > 0, isOnSale, let offer = offerPrice else { return 0 }
        return Int(((originalPrice - offer) / originalPrice) * 100)
    }

    var isInStock: Bool { stock > 0 }

    var isSpecialOrder: Bool { productType == "SPECIAL_ORDER" }

    var formattedOriginalPrice: String {
        String(format: "$%.2f", originalPrice)
    }

    var formattedOfferPrice: String {
        String(format: "$%.2f", displayPrice)
    }
}

// MARK: - Top Ordered Product (GET /orders/top-products)
struct TopOrderedProduct: Codable, Identifiable, Sendable {
    let id: Int
    let product: String
    let originalPrice: Double
    let offerPrice: Double?
    let description: String
    let stock: Int
    let quantity: String
    let imageUrl: String
    let totalOrderedQuantity: Int

    // Bridge to the shared Product model for reuse in product cards.
    var asProduct: Product {
        Product(
            id: id,
            product: product,
            originalPrice: originalPrice,
            offerPrice: offerPrice,
            description: description,
            stock: stock,
            quantity: quantity,
            imageUrl: imageUrl,
            productType: "REGULAR"
        )
    }
}
