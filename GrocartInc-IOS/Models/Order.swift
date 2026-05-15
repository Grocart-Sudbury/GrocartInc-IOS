//
//  Order.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation

// MARK: - Delivery Time Slots
enum DeliveryTimeSlot: String, CaseIterable, Identifiable {
    case slot9_10   = "SLOT_9_10"
    case slot10_11  = "SLOT_10_11"
    case slot11_12  = "SLOT_11_12"
    case slot12_13  = "SLOT_12_13"
    case slot13_14  = "SLOT_13_14"
    case slot14_15  = "SLOT_14_15"
    case slot15_16  = "SLOT_15_16"
    case slot16_17  = "SLOT_16_17"
    case slot17_20  = "SLOT_17_20"

    var id: String { rawValue }

    var display: String {
        switch self {
        case .slot9_10:  return "9–10 AM"
        case .slot10_11: return "10–11 AM"
        case .slot11_12: return "11 AM–12 PM"
        case .slot12_13: return "12–1 PM"
        case .slot13_14: return "1–2 PM"
        case .slot14_15: return "2–3 PM"
        case .slot15_16: return "3–4 PM"
        case .slot16_17: return "4–5 PM"
        case .slot17_20: return "5–8 PM"
        }
    }
}

// MARK: - Delivery Schedule
struct DeliverySchedule: Decodable {
    let dayOfWeek: String
    let slots: [String]
}

// MARK: - Order Request
struct OrderRequest: Encodable {
    // Delivery info
    let storeId: Int
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let address: String
    let city: String
    let province: String
    let postalCode: String
    let deliveryNotes: String?
    // Pricing
    let subtotal: Double
    let tax: Double
    let shippingCost: Double
    let serviceFee: Double
    let discount: Double
    let tipAmount: Double
    let total: Double
    let couponCode: String?
    // Payment
    let paymentMethod: String
    // Schedule
    let preferredDeliveryDate: String   // "YYYY-MM-DD"
    let preferredDeliveryTimeSlot: String
    let bundleIds: [Int]
    // Items
    let items: [OrderItemRequest]

    struct OrderItemRequest: Encodable {
        let productId: Int
        let productName: String
        let productImage: String
        let quantity: Int
        let priceAtPurchase: Double
    }
}

// MARK: - Order Response
struct OrderResponse: Decodable {
    let id: Int
    let trackingId: String
    let firstName: String
    let lastName: String
    let email: String
    let address: String
    let city: String
    let total: Double
    let status: String
    let paymentStatus: String
    let paymentMethod: String
    let preferredDeliveryDate: String
    let preferredDeliveryTimeSlot: String
    let createdAt: String

    var formattedTotal: String { String(format: "$%.2f", total) }

    var slotDisplay: String {
        DeliveryTimeSlot(rawValue: preferredDeliveryTimeSlot)?.display ?? preferredDeliveryTimeSlot
    }
}
