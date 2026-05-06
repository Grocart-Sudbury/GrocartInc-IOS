//
//  City.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-05-03.
//

import Foundation

enum City: String, CaseIterable {
    case sudbury = "Sudbury"
    case timmins = "Timmins"
   // case winnipeg = "Manitoba"
    var displayName: String { rawValue }
}
