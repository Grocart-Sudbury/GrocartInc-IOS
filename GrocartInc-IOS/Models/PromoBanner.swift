//
//  PromoBanner.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-05-14.
//

import SwiftUI

struct PromoBanner: Codable, Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let colorHex: String
    let actionUrl: String?
    let displayOrder: Int
    let isActive: Bool

    var color: Color {
        Color(hex: colorHex) ?? .grocartGreen
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
