// CustomerOrder.swift
// GrocartInc-IOS

import Foundation
import SwiftUI

// MARK: - Status

enum CustomerOrderStatus: String, Decodable {
    case pending    = "PENDING"
    case confirmed  = "CONFIRMED"
    case processing = "PROCESSING"
    case inTransit  = "IN_TRANSIT"
    case delivered  = "DELIVERED"
    case cancelled  = "CANCELLED"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CustomerOrderStatus(rawValue: raw) ?? .processing
    }

    var displayName: String {
        switch self {
        case .pending:    return "Pending"
        case .confirmed:  return "Confirmed"
        case .processing: return "Processing"
        case .inTransit:  return "In Transit"
        case .delivered:  return "Delivered"
        case .cancelled:  return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .pending:    return .orange
        case .confirmed:  return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .processing: return .orange
        case .inTransit:  return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .delivered:  return Color(red: 0.18, green: 0.72, blue: 0.47)
        case .cancelled:  return .red
        }
    }

    var icon: String {
        switch self {
        case .pending:    return "clock.fill"
        case .confirmed:  return "checkmark.seal.fill"
        case .processing: return "clock.fill"
        case .inTransit:  return "truck.box.fill"
        case .delivered:  return "checkmark.circle.fill"
        case .cancelled:  return "xmark.circle.fill"
        }
    }
}

// MARK: - Order Summary (list endpoint)

struct CustomerOrderSummary: Decodable, Identifiable {
    let id: Int
    let trackingId: String?
    let status: CustomerOrderStatus
    let total: Double
    let createdAt: String
    let preferredDeliveryDate: String?
    let preferredDeliveryTimeSlot: String?
    let items: [CustomerOrderItemSummary]?

    enum CodingKeys: String, CodingKey {
        case id = "orderId"
        case trackingId, status, total, createdAt
        case preferredDeliveryDate, preferredDeliveryTimeSlot, items
    }

    var formattedTotal: String { String(format: "$%.2f", total) }

    var formattedDate: String {
        // LocalDateTime format from backend: "2026-04-28T10:00:00"
        let local = DateFormatter()
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = local.date(from: createdAt) {
            let out = DateFormatter(); out.dateStyle = .medium
            return out.string(from: date)
        }
        // Fallback: ISO8601 with timezone
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: createdAt) {
            let out = DateFormatter(); out.dateStyle = .medium
            return out.string(from: date)
        }
        return createdAt
    }

    var itemCount: Int { items?.count ?? 0 }

    var deliveryDisplay: String? {
        guard let date = preferredDeliveryDate,
              let slot = preferredDeliveryTimeSlot else { return nil }
        let slotDisplay = DeliveryTimeSlot(rawValue: slot)?.display ?? slot
        return "\(date) · \(slotDisplay)"
    }
}

struct CustomerOrderItemSummary: Decodable, Identifiable {
    let id: Int?
    let productName: String
    let quantity: Int
    let priceAtPurchase: Double

    var formattedPrice: String { String(format: "$%.2f", priceAtPurchase * Double(quantity)) }
}

// MARK: - Full Order Detail

struct CustomerOrderDetail: Decodable, Identifiable {
    let id: Int
    let trackingId: String?
    let status: CustomerOrderStatus
    let total: Double
    let createdAt: String
    let firstName: String
    let lastName: String
    let email: String
    let address: String
    let city: String
    let paymentStatus: String?
    let paymentMethod: String?
    let preferredDeliveryDate: String?
    let preferredDeliveryTimeSlot: String?
    let items: [CustomerOrderItemSummary]?

    var formattedTotal: String { String(format: "$%.2f", total) }
}
