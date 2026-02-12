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
    let offerPrice: Double
    let description: String
    let stock: Int
    let quantity: String
    let imageUrl: String
    let productType: String
    
    var name: String { product }
    
    var isOnSale: Bool {
        offerPrice < originalPrice
    }
    
    var discountPercentage: Int {
        guard originalPrice > 0, isOnSale else { return 0 }
        return Int(((originalPrice - offerPrice) / originalPrice) * 100)
    }
    
    var isInStock: Bool {
        stock > 0
    }
    
    var isSpecialOrder: Bool {
        productType == "SPECIAL_ORDER"
    }
    
    var formattedOriginalPrice: String {
        String(format: "$%.2f", originalPrice)
    }
    
    var formattedOfferPrice: String {
        String(format: "$%.2f", offerPrice)
    }
}
