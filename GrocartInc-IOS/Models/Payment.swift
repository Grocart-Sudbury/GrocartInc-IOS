//
//  Payment.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-16.
//

import Foundation

// MARK: - Saved Card
struct SavedCard: Identifiable, Codable {
    let id: String
    let brand: String
    let last4: String
    let expMonth: Int
    let expYear: Int
    let isDefault: Bool

    var displayBrand: String { brand.capitalized }
    var formattedExpiry: String { String(format: "%02d/%02d", expMonth, expYear % 100) }
}

// MARK: - Setup Intent Response
struct SetupIntentResponse: Decodable {
    let clientSecret: String
}

// MARK: - Attach Card
struct AttachCardRequest: Encodable {
    let paymentMethodId: String
    let setAsDefault: Bool
}

// MARK: - Charge
struct ChargeRequest: Encodable {
    let orderId: Int
    let paymentMethodId: String
}

struct ChargeResponse: Decodable {
    let paymentIntentId: String
    let status: String
    let success: Bool
    let message: String
    let requiresAction: Bool?
    let clientSecret: String?
}

// MARK: - Confirm Payment (after 3DS)
struct ConfirmPaymentRequest: Encodable {
    let paymentIntentId: String
    let orderId: Int
}

struct ConfirmPaymentResponse: Decodable {
    let status: String
    let success: Bool
}
