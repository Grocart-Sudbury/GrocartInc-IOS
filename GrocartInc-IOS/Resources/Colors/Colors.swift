//
//  Colors.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

extension Color {
    // Primary Colors — baby blue (#89CFF0) is the app theme color.
    static let grocartGreen = Color(red: 137/255, green: 207/255, blue: 240/255)
    // Darker baby blue (#3EA3DC) for accents that need more contrast.
    static let grocartDarkGreen = Color(red: 62/255, green: 163/255, blue: 220/255)
    
    // Background Colors
    static let grocartBackground = Color(UIColor.systemBackground)
    static let grocartSecondaryBackground = Color(UIColor.secondarySystemBackground)
    
    // Text Colors
    static let grocartPrimary = Color(UIColor.label)
    static let grocartSecondary = Color(UIColor.secondaryLabel)
    static let grocartTertiary = Color(UIColor.tertiaryLabel)

    // Deep navy for text on baby-blue glass (readable where white is not).
    static let grocartNavy = Color(red: 31/255, green: 58/255, blue: 77/255)
}
