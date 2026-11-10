//
//  Order.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation

// MARK: - Order Type
enum OrderType: String, CaseIterable, Codable {
    case delivery = "DELIVERY"
    case pickup   = "PICKUP"

    var display: String {
        switch self {
        case .delivery: return "Delivery"
        case .pickup:   return "Pickup"
        }
    }
}

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

    var startHour: Int {
        switch self {
        case .slot9_10:  return 9
        case .slot10_11: return 10
        case .slot11_12: return 11
        case .slot12_13: return 12
        case .slot13_14: return 13
        case .slot14_15: return 14
        case .slot15_16: return 15
        case .slot16_17: return 16
        case .slot17_20: return 17
        }
    }

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

// MARK: - Pickup Time Slots
enum PickupTimeSlot: String, CaseIterable, Identifiable {
    case slot10_11 = "SLOT_10_11"
    case slot11_12 = "SLOT_11_12"
    case slot12_13 = "SLOT_12_13"
    case slot13_14 = "SLOT_13_14"
    case slot14_15 = "SLOT_14_15"
    case slot15_16 = "SLOT_15_16"
    case slot16_17 = "SLOT_16_17"
    case slot17_18 = "SLOT_17_18"
    case slot18_19 = "SLOT_18_19"
    case slot19_20 = "SLOT_19_20"
    case slot20_21 = "SLOT_20_21"
    case slot21_22 = "SLOT_21_22"

    var id: String { rawValue }

    var startHour: Int {
        switch self {
        case .slot10_11: return 10
        case .slot11_12: return 11
        case .slot12_13: return 12
        case .slot13_14: return 13
        case .slot14_15: return 14
        case .slot15_16: return 15
        case .slot16_17: return 16
        case .slot17_18: return 17
        case .slot18_19: return 18
        case .slot19_20: return 19
        case .slot20_21: return 20
        case .slot21_22: return 21
        }
    }

    var display: String {
        switch self {
        case .slot10_11: return "10:00 AM – 11:00 AM"
        case .slot11_12: return "11:00 AM – 12:00 PM"
        case .slot12_13: return "12:00 PM – 1:00 PM"
        case .slot13_14: return "1:00 PM – 2:00 PM"
        case .slot14_15: return "2:00 PM – 3:00 PM"
        case .slot15_16: return "3:00 PM – 4:00 PM"
        case .slot16_17: return "4:00 PM – 5:00 PM"
        case .slot17_18: return "5:00 PM – 6:00 PM"
        case .slot18_19: return "6:00 PM – 7:00 PM"
        case .slot19_20: return "7:00 PM – 8:00 PM"
        case .slot20_21: return "8:00 PM – 9:00 PM"
        case .slot21_22: return "9:00 PM – 10:00 PM"
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
    let orderType: String
    // Customer info
    let storeId: Int
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    // Delivery-only fields (nil for pickup)
    let address: String?
    let city: String?
    let province: String?
    let postalCode: String?
    let deliveryNotes: String?
    let preferredDeliveryDate: String?
    let preferredDeliveryTimeSlot: String?
    let preferredPickupDate: String?
    let preferredPickupTimeSlot: String?
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
    let orderType: String?
    let firstName: String
    let lastName: String
    let email: String
    let address: String?
    let city: String?
    let total: Double
    let status: String
    let paymentStatus: String
    let paymentMethod: String
    let preferredDeliveryDate: String?
    let preferredDeliveryTimeSlot: String?
    let preferredPickupDate: String?
    let preferredPickupTimeSlot: String?
    let createdAt: String

    var isPickup: Bool { orderType == OrderType.pickup.rawValue }

    var formattedTotal: String { String(format: "$%.2f", total) }

    /// Friendly payment label for the confirmation screen.
    var paymentMethodDisplay: String {
        switch paymentMethod.uppercased() {
        case "CASH": return "Cash on Pickup"
        case "STRIPE": return "Credit / Debit Card"
        default: return paymentMethod
        }
    }

    var deliverySlotDisplay: String {
        guard let slot = preferredDeliveryTimeSlot else { return "" }
        return DeliveryTimeSlot(rawValue: slot)?.display ?? slot
    }

    var pickupSlotDisplay: String {
        guard let slot = preferredPickupTimeSlot else { return "" }
        return PickupTimeSlot(rawValue: slot)?.display ?? slot
    }
}
