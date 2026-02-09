//
//  SearchView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

//
//  SearchView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    
    private let recentSearches = ["Organic Milk", "Avocados", "Chicken Wings", "Bread"]
    private let trendingSearches = ["Blueberries", "Greek Yogurt", "Pasta Sauce", "Rice", "Orange Juice", "Cheese"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.grocartSecondary)
                            
                            TextField("Search for groceries...", text: $searchText)
                                .font(.system(size: 15))
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.grocartSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.grocartSecondaryBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                        
                        // Recent Searches
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Searches")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.grocartPrimary)
                                Spacer()
                                Button("Clear") {}
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.grocartGreen)
                            }
                            
                            ForEach(recentSearches, id: \.self) { search in
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 14))
                                        .foregroundColor(.grocartSecondary)
                                    
                                    Text(search)
                                        .font(.system(size: 15))
                                        .foregroundColor(.grocartPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 12))
                                        .foregroundColor(.grocartSecondary)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        
                        // Trending
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.trend.up")
                                    .foregroundColor(.grocartGreen)
                                Text("Trending Now")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.grocartPrimary)
                            }
                            
                            FlowLayout(spacing: 10) {
                                ForEach(trendingSearches, id: \.self) { search in
                                    Text(search)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.grocartPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.grocartSecondaryBackground)
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        return (positions, CGSize(width: maxWidth, height: currentY + lineHeight))
    }
}

#Preview {
    SearchView()
}
