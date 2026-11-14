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
    /// Points to redeem on this quote. Nil means no points. Only sent
    /// to the staging pricing endpoint; the production endpoint does
    /// not know this field yet. A nil value is omitted from the JSON.
    /// (No default here: a `let` with a default cannot be assigned
    /// again in init — the default lives on the init parameter.)
    let pointsToRedeem: Int?

    /// Explicit init: the memberwise init did not pick up the defaulted
    /// pointsToRedeem (the compiler rejected it as an extra argument),
    /// so the initializer is spelled out.
    init(cart: [CartItemRequest], couponCode: String?, cityCode: Int, pointsToRedeem: Int? = nil) {
        self.cart = cart
        self.couponCode = couponCode
        self.cityCode = cityCode
        self.pointsToRedeem = pointsToRedeem
    }

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
    /// The customer's points balance, as the server sees it. Null when
    /// no customer token was sent; absent on production responses.
    let pointsBalance: Int?
    /// Points applied to this quote (0 if none or rejected).
    let pointsRedeemed: Int
    /// Dollar value of the applied points. Already included in
    /// `discount` and `total` — never subtract it again.
    let pointsDiscount: Double
    /// Why the requested points were not applied, if they were not.
    /// Show it verbatim.
    let pointsMessage: String?

    private enum CodingKeys: String, CodingKey {
        case subtotal, tax, shippingCost, serviceFee, discount, total
        case pointsBalance, pointsRedeemed, pointsDiscount, pointsMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subtotal = try container.decode(Double.self, forKey: .subtotal)
        tax = try container.decode(Double.self, forKey: .tax)
        shippingCost = try container.decode(Double.self, forKey: .shippingCost)
        serviceFee = try container.decode(Double.self, forKey: .serviceFee)
        discount = try container.decode(Double.self, forKey: .discount)
        total = try container.decode(Double.self, forKey: .total)
        pointsBalance = try container.decodeIfPresent(Int.self, forKey: .pointsBalance)
        pointsRedeemed = try container.decodeIfPresent(Int.self, forKey: .pointsRedeemed) ?? 0
        pointsDiscount = try container.decodeIfPresent(Double.self, forKey: .pointsDiscount) ?? 0
        pointsMessage = try container.decodeIfPresent(String.self, forKey: .pointsMessage)
    }

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
        let name = cityName.lowercased()
        if name.contains("timmins") { return 1 }
        if name.contains("winnipeg") { return 2 }
        return 0
    }
}
