//
//  ActiveOrder.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-05-19.
//

import Foundation
import SwiftUI

// MARK: - Active Order Status

enum ActiveOrderStatus: String, Decodable {
    case confirmed         = "CONFIRMED"
    case processing        = "PROCESSING"
    case readyForPickup    = "READY_FOR_PICKUP"
    case assigned          = "ASSIGNED"
    case enRouteToStore    = "EN_ROUTE_TO_STORE"
    case pickedUp          = "PICKED_UP"
    case enRouteToCustomer = "EN_ROUTE_TO_CUSTOMER"
    case cancelled         = "CANCELLED"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ActiveOrderStatus(rawValue: raw) ?? .processing
    }

    var color: Color {
        switch self {
        case .confirmed:         return .grocartGreen
        case .processing:        return .grocartGreen
        case .readyForPickup:    return .grocartGreen
        case .assigned:          return .grocartGreen
        case .enRouteToStore:    return .grocartGreen
        case .pickedUp:          return .grocartGreen
        case .enRouteToCustomer: return .grocartGreen
        case .cancelled:         return .red
        }
    }

    var icon: String {
        switch self {
        case .confirmed:         return "checkmark.seal.fill"
        case .processing:        return "gearshape.fill"
        case .readyForPickup:    return "storefront.fill"
        case .assigned:          return "person.badge.clock.fill"
        case .enRouteToStore:    return "bicycle"
        case .pickedUp:          return "bag.fill"
        case .enRouteToCustomer: return "location.fill"
        case .cancelled:         return "xmark.circle.fill"
        }
    }

    // 0-based step index; -1 for cancelled
    func progressStep(isPickup: Bool) -> Int {
        switch self {
        case .confirmed:         return 0
        case .processing:        return 1
        case .readyForPickup:    return isPickup ? 2 : 1
        case .assigned:          return 2
        case .enRouteToStore:    return 2
        case .pickedUp:          return 3
        case .enRouteToCustomer: return 3
        case .cancelled:         return -1
        }
    }
}

// MARK: - Active Order

struct ActiveOrder: Decodable, Identifiable {
    let id: Int
    let trackingId: String
    let orderType: String
    let status: ActiveOrderStatus
    let statusDisplay: String
    let preferredDeliveryDate: String?
    let preferredDeliveryTimeSlot: String?
    let preferredPickupDate: String?
    let preferredPickupTimeSlot: String?
    let subtotal: Double
    let tax: Double
    let discount: Double
    let total: Double
    let storeName: String
    let storeAddress: String
    let items: [ActiveOrderItem]
    let createdAt: String
    let updatedAt: String

    var isPickup: Bool { orderType == "PICKUP" }
    var formattedTotal: String { String(format: "$%.2f", total) }

    var scheduleDisplay: String? {
        if isPickup {
            guard let date = preferredPickupDate else { return nil }
            let slotText = preferredPickupTimeSlot.flatMap { PickupTimeSlot(rawValue: $0)?.display } ?? ""
            return slotText.isEmpty ? formatDate(date) : "\(formatDate(date)) · \(slotText)"
        } else {
            guard let date = preferredDeliveryDate else { return nil }
            let slotText = preferredDeliveryTimeSlot.flatMap { DeliveryTimeSlot(rawValue: $0)?.display } ?? ""
            return slotText.isEmpty ? formatDate(date) : "\(formatDate(date)) · \(slotText)"
        }
    }

    private func formatDate(_ iso: String) -> String {
        let input = DateFormatter(); input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter(); output.dateFormat = "MMM d"
        return input.date(from: iso).map { output.string(from: $0) } ?? iso
    }
}

// MARK: - Active Order Item

struct ActiveOrderItem: Decodable, Identifiable {
    let id: Int
    let productId: Int
    let productName: String
    let quantity: Int
    let priceAtPurchase: Double
    let imageUrl: String?
}
