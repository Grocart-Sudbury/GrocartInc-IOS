//
//  HomeTabView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

//
//  HomeTabView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct HomeTabView: View {
    @State private var searchText = ""
    
    private let bannerDeals = [
        ("Fresh Produce Sale", "Up to 30% off fruits & vegetables", "leaf.fill", Color.grocartGreen),
        ("Weekend Special", "Free delivery on orders over $50", "shippingbox.fill", Color(red: 0.2, green: 0.6, blue: 0.9)),
        ("New User Offer", "Get $10 off your first order", "gift.fill", Color(red: 0.95, green: 0.55, blue: 0.2))
    ]
    
    private let quickCategories = [
        ("🥬", "Vegetables"),
        ("🍎", "Fruits"),
        ("🥛", "Dairy"),
        ("🍞", "Bakery"),
        ("🥩", "Meat"),
        ("🐟", "Seafood"),
        ("🧃", "Beverages"),
        ("🧊", "Frozen")
    ]
    
    private let popularItems = [
        ("Organic Bananas", "$2.49", "1 bunch", 4.8),
        ("Whole Milk 4L", "$5.99", "Neilson", 4.7),
        ("Sourdough Bread", "$4.49", "Fresh baked", 4.9),
        ("Chicken Breast", "$12.99", "Per kg", 4.6),
        ("Baby Spinach", "$3.99", "200g bag", 4.5),
        ("Free Range Eggs", "$6.49", "Dozen", 4.8)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Deliver to")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.grocartSecondary)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.grocartGreen)
                                            .font(.system(size: 14))
                                        Text("Timmins, ON")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.grocartPrimary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.grocartPrimary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {}) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "bell")
                                            .font(.system(size: 20))
                                            .foregroundColor(.grocartPrimary)
                                            .frame(width: 42, height: 42)
                                            .background(Color.grocartSecondaryBackground)
                                            .clipShape(Circle())
                                        
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                            .offset(x: -2, y: 2)
                                    }
                                }
                            }
                            
                            // Search bar
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.grocartSecondary)
                                
                                TextField("Search groceries...", text: $searchText)
                                    .font(.system(size: 15))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.grocartSecondaryBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Promo Banners
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(Array(bannerDeals.enumerated()), id: \.offset) { _, deal in
                                    PromoBannerCard(
                                        title: deal.0,
                                        subtitle: deal.1,
                                        icon: deal.2,
                                        color: deal.3
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Quick Categories
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Shop by Category")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.grocartPrimary)
                                Spacer()
                                Button("See All") {}
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.grocartGreen)
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(quickCategories, id: \.1) { emoji, name in
                                        VStack(spacing: 8) {
                                            Text(emoji)
                                                .font(.system(size: 28))
                                                .frame(width: 60, height: 60)
                                                .background(Color.grocartSecondaryBackground)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                            
                                            Text(name)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.grocartPrimary)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Today's Deals
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                    Text("Today's Deals")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.grocartPrimary)
                                }
                                Spacer()
                                Button("View All") {}
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.grocartGreen)
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(Array(popularItems.enumerated()), id: \.offset) { _, item in
                                        HomeDealCard(
                                            name: item.0,
                                            price: item.1,
                                            detail: item.2,
                                            rating: item.3
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Popular Items
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Popular Near You")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.grocartPrimary)
                                Spacer()
                                Button("View All") {}
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.grocartGreen)
                            }
                            .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 14),
                                GridItem(.flexible(), spacing: 14)
                            ], spacing: 14) {
                                ForEach(Array(popularItems.enumerated()), id: \.offset) { _, item in
                                    HomeGridCard(
                                        name: item.0,
                                        price: item.1,
                                        detail: item.2,
                                        rating: item.3
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer().frame(height: 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Promo Banner Card
struct PromoBannerCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("Shop Now →")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 4)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(18)
        .frame(width: 260)
        .background(
            LinearGradient(
                colors: [color, color.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
}

// MARK: - Home Deal Card (Horizontal Scroll)
struct HomeDealCard: View {
    let name: String
    let price: String
    let detail: String
    let rating: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.grocartSecondaryBackground)
                    .frame(width: 140, height: 110)
                
                Image(systemName: "basket.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.grocartGreen.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .lineLimit(1)
                
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
                
                HStack(spacing: 4) {
                    Text(price)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.grocartGreen)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.grocartSecondary)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.grocartGreen)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .frame(width: 160)
        .background(Color.grocartBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Home Grid Card
struct HomeGridCard: View {
    let name: String
    let price: String
    let detail: String
    let rating: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.grocartSecondaryBackground)
                    .aspectRatio(1.2, contentMode: .fit)
                
                Image(systemName: "basket.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.grocartGreen.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .lineLimit(1)
                
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
                
                HStack {
                    Text(price)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.grocartGreen)
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.grocartGreen)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .background(Color.grocartBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    HomeTabView()
}
