//
//  CartPricing.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation

struct CartPricingRequest: Encodable {
    let cart: [CartItemRequest]
    let couponCode: String?
    let cityCode: Int

    struct CartItemRequest: Encodable {
        let id: Int
        let product: String
        let originalPrice: Double
        let offerPrice: Double
        let description: String
        let stock: Int
        let imageUrl: String
        let category: String
        let quantity: Int
    }
}

struct CartPricingResponse: Decodable {
    let subtotal: Double
    let tax: Double
    let shippingCost: Double
    let serviceFee: Double
    let discount: Double
    let total: Double

    var formattedSubtotal:   String { format(subtotal) }
    var formattedTax:        String { format(tax) }
    var formattedShipping:   String { shippingCost == 0 ? "Free" : format(shippingCost) }
    var formattedServiceFee: String { serviceFee == 0 ? "Free" : format(serviceFee) }
    var formattedDiscount:   String { discount == 0 ? "-" : "-\(format(discount))" }
    var formattedTotal:      String { format(total) }

    private func format(_ value: Double) -> String { String(format: "$%.2f", value) }
}

extension CartPricingRequest {
    static func cityCode(for cityName: String) -> Int {
        cityName.lowercased().contains("timmins") ? 1 : 0
    }
}
