//
//  Store.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation

struct Store: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let slug: String
    let description: String
    let logoUrl: String?
    let bannerUrl: String?
    let address: String
    let city: String
    let phone: String
    let latitude: Double
    let longitude: Double
    let deliveryRadius: Double
    let deliveryFee: Double
    let minOrderAmount: Double
    let active: Bool

    var formattedDeliveryFee: String {
        deliveryFee == 0 ? "Free delivery" : String(format: "$%.2f delivery", deliveryFee)
    }

    var formattedMinOrder: String {
        String(format: "$%.0f min order", minOrderAmount)
    }
}
