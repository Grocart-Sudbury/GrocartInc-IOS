//
//  CartItem.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation

struct CartItem: Identifiable {
    var id: Int { product.id }
    let product: Product
    let categoryName: String
    let store: Store
    var count: Int  // number of units ordered (distinct from product.quantity which is a unit string)
}
