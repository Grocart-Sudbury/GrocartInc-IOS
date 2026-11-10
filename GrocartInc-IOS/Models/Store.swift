//
//  Store.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation

struct Store: Codable, Identifiable, Sendable, Hashable {
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
        // Both stores charge the same $4.99 minimum delivery fee. The
        // backend still stores a different per-store fee (A1 India Bazaar
        // is $6.99 there), so the minimum is shown instead of the
        // backend's value. The fee at checkout is distance-based and
        // starts at this $4.99.
        String(format: "$%.2f delivery", DeliveryFeeCalculator.minimumFee)
    }

    var formattedMinOrder: String {
        String(format: "$%.0f min order", minOrderAmount)
    }

    /// The address shown to customers. If this store has a correction in
    /// StoreCorrections (its backend address is wrong), that address is
    /// shown; otherwise the backend's address is used as-is.
    var displayAddress: String {
        StoreCorrections.correction(for: id)?.address ?? address
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

// MARK: - Lenient decoding
//
// Same idea as Product: one store with a missing or mistyped field used to
// fail the whole active-stores list. Soft fields default here; a store
// without an id or name still throws, and the repository skips it
// per-item instead of failing the list.
extension Store {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        logoUrl = try container.decodeIfPresent(String.self, forKey: .logoUrl)
        bannerUrl = try container.decodeIfPresent(String.self, forKey: .bannerUrl)
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        city = try container.decodeIfPresent(String.self, forKey: .city) ?? ""
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? ""
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) ?? 0
        deliveryRadius = try container.decodeIfPresent(Double.self, forKey: .deliveryRadius) ?? 0
        deliveryFee = try container.decodeIfPresent(Double.self, forKey: .deliveryFee) ?? 0
        minOrderAmount = try container.decodeIfPresent(Double.self, forKey: .minOrderAmount) ?? 0
        // The endpoint only returns active stores, so a missing flag means active.
        active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? true
    }
}
