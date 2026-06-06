// UberDeliveryQuote.swift
// GrocartInc-IOS

import Foundation

struct UberDeliveryQuoteRequest: Encodable {
    let dropoffAddress: String
}

struct UberDeliveryQuoteResponse: Decodable {
    let deliveryPossible: Bool
    let deliveryFeeCents: Int
    let deliveryFeeFormatted: String?
    let currency: String?
    let expiresAt: String?
    let estimatedPickupMinutes: Int?
}
