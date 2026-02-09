//
//  CategoriesView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

//
//  CategoriesView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct CategoriesView: View {
    private let categories = [
        ("🥬", "Vegetables", "120+ items", Color.grocartGreen),
        ("🍎", "Fruits", "80+ items", Color.red),
        ("🥛", "Dairy & Eggs", "60+ items", Color(red: 0.2, green: 0.6, blue: 0.9)),
        ("🍞", "Bakery", "45+ items", Color(red: 0.95, green: 0.55, blue: 0.2)),
        ("🥩", "Meat & Poultry", "55+ items", Color(red: 0.8, green: 0.3, blue: 0.3)),
        ("🐟", "Seafood", "35+ items", Color(red: 0.2, green: 0.5, blue: 0.7)),
        ("🧃", "Beverages", "90+ items", Color.purple),
        ("🧊", "Frozen Foods", "70+ items", Color.cyan),
        ("🥫", "Pantry", "150+ items", Color.brown),
        ("🧹", "Household", "85+ items", Color.gray),
        ("🧴", "Personal Care", "65+ items", Color.pink),
        ("🍼", "Baby & Kids", "40+ items", Color(red: 0.4, green: 0.7, blue: 0.9))
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ], spacing: 14) {
                        ForEach(categories, id: \.1) { emoji, name, count, color in
                            VStack(spacing: 10) {
                                Text(emoji)
                                    .font(.system(size: 36))
                                    .frame(width: 64, height: 64)
                                    .background(color.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                
                                VStack(spacing: 2) {
                                    Text(name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.grocartPrimary)
                                    
                                    Text(count)
                                        .font(.system(size: 12))
                                        .foregroundColor(.grocartSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.grocartBackground)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    CategoriesView()
}
