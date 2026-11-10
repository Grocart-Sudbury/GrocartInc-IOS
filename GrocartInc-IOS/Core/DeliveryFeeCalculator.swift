// DeliveryFeeCalculator.swift
// GrocartInc-IOS
//
// Distance-based delivery fees. The store's coordinates come from the
// backend; the delivery address is plain text, so it is geocoded with
// Apple's built-in CLGeocoder (no API key) into coordinates first.
// Distance is straight-line (Haversine) — "as the crow flies" — which is
// the standard simple basis for a delivery fee; road distance would need
// a routing service.

import CoreLocation
import Foundation

enum DeliveryFeeCalculator {

    // MARK: - The rate rule

    /// The lowest delivery fee, for both stores.
    static let minimumFee: Double = 4.99

    /// The first 2 km are included in the minimum fee.
    static let includedDistanceKm: Double = 2.0

    /// What each kilometre beyond the included 2 km costs.
    /// Change this one number to change the rate.
    static let perKmRate: Double = 1.00

    /// The fee for a delivery that is `distanceKm` from the store.
    /// Within the included distance it is the minimum; beyond that it
    /// is the minimum plus the rate for each extra kilometre, rounded
    /// to the nearest cent.
    static func fee(forDistanceKm distanceKm: Double) -> Double {
        guard distanceKm > includedDistanceKm else { return minimumFee }
        let extraKm = distanceKm - includedDistanceKm
        let fee = minimumFee + perKmRate * extraKm
        return (fee * 100).rounded() / 100
    }

    /// Straight-line distance in kilometres between two coordinates.
    static func distanceKm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (to.latitude - from.latitude) * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }

    // MARK: - Store location
    /// The coordinates to measure the delivery distance from. If this
    /// store has a correction in StoreCorrections (its backend coordinates
    /// are wrong), those are used; otherwise the coordinates the backend
    /// stores for it are used.
    static func coordinate(for store: Store) -> CLLocationCoordinate2D {
        if let correction = StoreCorrections.correction(for: store.id),
           let latitude = correction.latitude,
           let longitude = correction.longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return CLLocationCoordinate2D(latitude: store.latitude, longitude: store.longitude)
    }

    /// The fee for a delivery from `store` to `address`, or nil when the
    /// address cannot be geocoded (the caller falls back to the backend's
    /// flat shipping cost in that case).
    static func fee(from store: Store, to address: CustomerAddress) async -> (fee: Double, distanceKm: Double)? {
        guard let destination = await coordinates(for: address) else { return nil }
        let distance = distanceKm(from: coordinate(for: store), to: destination)
        return (fee(forDistanceKm: distance), distance)
    }

    /// Turn a saved delivery address into coordinates.
    static func coordinates(for address: CustomerAddress) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(address.displayAddress)
            return placemarks.first?.location?.coordinate
        } catch {
            return nil
        }
    }

    static func formattedFee(_ fee: Double) -> String {
        String(format: "$%.2f", fee)
    }

    static func formattedDistance(_ distanceKm: Double) -> String {
        String(format: "%.1f km", distanceKm)
    }
}
