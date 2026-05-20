//
//  PromoCode.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-05-13.
//

import Foundation

enum PromoRewardType: String, Codable {
    case percentage   = "PERCENTAGE"
    case flat         = "FLAT"
    case freeDelivery = "FREE_DELIVERY"
    case credits      = "CREDITS"
    case item         = "ITEM"
}

struct PromoCode: Codable, Identifiable {
    let id: Int
    let code: String
    let rewardType: PromoRewardType
    let rewardValue: Double
    let minOrderValue: Double?
    let maxUses: Int?
    let usedCount: Int
    let active: Bool
    let activeFrom: String?
    let expiresAt: String?
    let createdAt: String?
    let customer: PromoCodeCustomer?
    let store: PromoCodeStore?
    let thirdPartyPartner: String?
    let rewardItemName: String?
    let usesPerCustomer: Int?
}

struct PromoCodeCustomer: Codable {
    let id: Int
    let name: String?
}

struct PromoCodeStore: Codable {
    let id: Int
    let name: String?
}

struct PromoCodeRequest: Encodable {
    let code: String
    let rewardType: PromoRewardType
    let rewardValue: Double
    let minOrderValue: Double?
    let maxUses: Int?
    let active: Bool
    let expiresAt: String?
    let thirdPartyPartner: String?
    let rewardItemName: String?
    let usesPerCustomer: Int?
}

struct PromoCodeUpdateRequest: Encodable {
    var code: String?
    var rewardType: PromoRewardType?
    var rewardValue: Double?
    var minOrderValue: Double?
    var maxUses: Int?
    var active: Bool?
    var expiresAt: String?
    var thirdPartyPartner: String?
    var rewardItemName: String?
    var usesPerCustomer: Int?
}

struct DeletePromoCodeResponse: Decodable {
    let message: String
}

struct PromoCodeCheckRequest: Encodable {
    let code: String
    let subtotal: Double
    let storeId: Int
}

struct PromoCodeCheckResponse: Decodable {
    let valid: Bool
    let discount: Double?
    let rewardType: String?
    let rewardValue: Double?
    let rewardItemName: String?
    let message: String?
}
