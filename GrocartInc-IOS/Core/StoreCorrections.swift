//
//  StoreCorrections.swift
//  GrocartInc-IOS
//
//  ONE place for the (temporary) corrections to stores whose backend data
//  is wrong. This is what makes adding a new store easy:
//
//  - A new store with CORRECT backend data needs NO code change at all.
//    It is added in the backend, the app fetches it from
//    GET /stores/active, and it just appears — with its own name,
//    address, coordinates, delivery fee and minimum order.
//  - A store whose backend data is WRONG needs exactly ONE entry here
//    (address and/or coordinates), and every part of the app that uses
//    that store's address or location reads it from this file.
//  - Once the backend data is fixed for a store, delete its entry here.
//
//  The two Sudbury stores are the only entries right now: the backend
//  stores the same placeholder coordinates (46.4862, -81.0113) for every
//  store, about 6 km from the real address, and GroCart-Sudbury is also
//  listed there at "305 Eyre St S" instead of 1460 Fairburn St.
//

import Foundation

/// The corrected address and/or coordinates for one store, used instead
/// of what the backend stores for it. Any field left nil means "use the
/// backend's value for that field".
struct StoreCorrection {
    let address: String?
    let latitude: Double?
    let longitude: Double?
}

enum StoreCorrections {
    /// Keyed by the store's backend id. Add one entry per store whose
    /// backend data is wrong; a store with correct data needs no entry.
    static let byStoreId: [Int: StoreCorrection] = [
        // GroCart-Sudbury (id 1): wrong address AND wrong coordinates.
        1: StoreCorrection(
            address: "1460 Fairburn St, Greater Sudbury, ON P3A 1N7",
            latitude: 46.5176904,
            longitude: -80.9428746
        ),
        // A1 India Bazaar (id 3): address is already right, only the
        // coordinates are the placeholder.
        3: StoreCorrection(
            address: nil,
            latitude: 46.5176904,
            longitude: -80.9428746
        ),
    ]

    static func correction(for storeId: Int) -> StoreCorrection? {
        byStoreId[storeId]
    }
}
