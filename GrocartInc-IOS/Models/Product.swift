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
struct Product: Codable, Identifiable, Sendable, Hashable {
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

// MARK: - Lenient decoding
//
// The backend occasionally sends a product with a missing or null field
// (or a whole malformed product). Decoding used to be strict, so one bad
// product failed the entire category — and the store page came up empty.
// These decoders default the soft fields and skip a product that is too
// broken to identify, so one bad record can no longer blank a store.
// The memberwise initializers are untouched (these decoders live in
// extensions), and `imageUrl` / `description` stay plain Strings with an
// empty-string default, so every existing use site is unchanged.

/// Decodes one array element leniently: a malformed element becomes `nil`
/// instead of failing the whole array.
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(T.self)
    }
}

extension Category {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        // One malformed product is skipped instead of failing the category.
        products = try container.decodeIfPresent([FailableDecodable<Product>].self, forKey: .products)?.compactMap(\.value) ?? []
    }
}

extension Product {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        product = try container.decode(String.self, forKey: .product)
        originalPrice = try container.decodeIfPresent(Double.self, forKey: .originalPrice) ?? 0
        offerPrice = try container.decodeIfPresent(Double.self, forKey: .offerPrice)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        stock = try container.decodeIfPresent(Int.self, forKey: .stock) ?? 0
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity) ?? ""
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl) ?? ""
        productType = try container.decodeIfPresent(String.self, forKey: .productType) ?? "REGULAR"
    }
}

extension TopOrderedProduct {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        product = try container.decode(String.self, forKey: .product)
        originalPrice = try container.decodeIfPresent(Double.self, forKey: .originalPrice) ?? 0
        offerPrice = try container.decodeIfPresent(Double.self, forKey: .offerPrice)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        stock = try container.decodeIfPresent(Int.self, forKey: .stock) ?? 0
        quantity = try container.decodeIfPresent(String.self, forKey: .quantity) ?? ""
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl) ?? ""
        totalOrderedQuantity = try container.decodeIfPresent(Int.self, forKey: .totalOrderedQuantity) ?? 0
    }
}
