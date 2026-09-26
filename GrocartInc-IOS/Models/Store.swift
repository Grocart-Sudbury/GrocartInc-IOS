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

    /// Some stores don't have a hosted logo/banner yet, so their listing artwork ships as a bundled asset instead.
    var bundledIconAssetName: String? {
        let lower = name.lowercased()
        if lower.contains("grocart") {
            return "Grocart"
        }
        if lower.contains("salkara") {
            return "Salkara"
        }
        if lower.contains("aone") || lower.contains("a one") || lower.contains("a1") || lower.contains("al store") {
            return "Aone"
        }
        if lower.contains("shawarma") {
            return "Shawarma"
        }
        return nil
    }

    var bundledBannerAssetName: String? {
        let lower = name.lowercased()
        if lower.contains("grocart") {
            return "Grocart"
        }
        if lower.contains("salkara") {
            return "Salkara"
        }
        if lower.contains("aone") || lower.contains("a one") || lower.contains("a1") || lower.contains("al store") {
            return "Aone"
        }
        if lower.contains("shawarma") {
            return "Shawarma"
        }
        return nil
    }
}
