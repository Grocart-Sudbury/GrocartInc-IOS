//
//  HomeTabView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct HomeTabView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var searchText = ""
    
    private let bannerDeals = [
        ("Fresh Produce Sale", "Up to 30% off fruits & vegetables", "leaf.fill", Color.grocartGreen),
        ("Weekend Special", "Free delivery on orders over $50", "shippingbox.fill", Color(red: 0.2, green: 0.6, blue: 0.9)),
        ("New User Offer", "Get $10 off your first order", "gift.fill", Color(red: 0.95, green: 0.55, blue: 0.2))
    ]
    
    private let categoryIcons: [String: String] = [
        "Rice & Grains": "🌾",
        "Snacks & Chips": "🍿",
        "Pickles": "🫙",
        "Masalas & Powders": "🌶️",
        "Spices & Seeds": "🫘",
        "Seafood/Frozen": "🐟",
        "Households": "🏠"
    ]
    
    var filteredProducts: [Product] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return viewModel.searchProducts(query: searchText)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.categories.isEmpty {
                    // First load spinner
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading groceries...")
                            .font(.system(size: 14))
                            .foregroundColor(.grocartSecondary)
                    }
                } else if let error = viewModel.errorMessage, viewModel.categories.isEmpty {
                    // Error state (only if no cached data)
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.grocartSecondary)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.grocartSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Try Again") {
                            viewModel.loadData()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.grocartGreen)
                        .cornerRadius(10)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Header
                            headerSection
                            
                            // Search Results
                            if !searchText.isEmpty {
                                searchResultsSection
                            } else {
                                // Promo Banners
                                promoBannersSection
                                
                                // Categories from API
                                categoriesSection
                                
                                // Today's Deals (on-sale products)
                                if !viewModel.featuredProducts.isEmpty {
                                    dealsSection
                                }
                                
                                // Browse by Category sections
                                ForEach(viewModel.categories) { category in
                                    categoryProductsSection(category: category)
                                }
                                
                                Spacer().frame(height: 20)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.loadData()
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - Search Results
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(filteredProducts.isEmpty ? "No results for \"\(searchText)\"" : "\(filteredProducts.count) results")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.grocartPrimary)
                .padding(.horizontal, 20)
            
            if !filteredProducts.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ], spacing: 14) {
                    ForEach(filteredProducts) { product in
                        ProductGridCard(product: product)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Promo Banners
    private var promoBannersSection: some View {
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
    }
    
    // MARK: - Categories
    private var categoriesSection: some View {
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
                    ForEach(viewModel.categories) { category in
                        VStack(spacing: 8) {
                            Text(categoryIcons[category.name] ?? "🛒")
                                .font(.system(size: 28))
                                .frame(width: 60, height: 60)
                                .background(Color.grocartSecondaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            Text(category.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.grocartPrimary)
                                .lineLimit(1)
                                .frame(width: 70)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Today's Deals
    private var dealsSection: some View {
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
                    ForEach(viewModel.featuredProducts) { product in
                        ProductDealCard(product: product)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Category Products Section
    private func categoryProductsSection(category: Category) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Text(categoryIcons[category.name] ?? "🛒")
                        .font(.system(size: 16))
                    Text(category.name)
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
                    ForEach(category.products.filter { $0.isInStock }.prefix(6)) { product in
                        ProductDealCard(product: product)
                    }
                }
                .padding(.horizontal, 20)
            }
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

// MARK: - Product Deal Card (Horizontal Scroll)
struct ProductDealCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Product Image
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: product.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 110)
                            .clipped()
                            .cornerRadius(12)
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.grocartSecondaryBackground)
                            .frame(width: 140, height: 110)
                            .overlay(
                                Image(systemName: "basket.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.grocartGreen.opacity(0.3))
                            )
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.grocartSecondaryBackground)
                            .frame(width: 140, height: 110)
                            .overlay(ProgressView())
                    }
                }
                
                // Discount badge
                if product.isOnSale {
                    Text("-\(product.discountPercentage)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .cornerRadius(6)
                        .padding(6)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(product.quantity)
                    .font(.system(size: 11))
                    .foregroundColor(.grocartSecondary)
                
                HStack(spacing: 4) {
                    Text(product.formattedOfferPrice)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.grocartGreen)
                    
                    if product.isOnSale {
                        Text(product.formattedOriginalPrice)
                            .font(.system(size: 11))
                            .foregroundColor(.grocartSecondary)
                            .strikethrough()
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 4)
            
            // Add to cart button
            Button(action: {}) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(product.isInStock ? Color.grocartGreen : Color.gray)
                .cornerRadius(8)
            }
            .disabled(!product.isInStock)
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

// MARK: - Product Grid Card (Search results / Grid layout)
struct ProductGridCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: product.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1.2, contentMode: .fit)
                            .clipped()
                            .cornerRadius(10)
                    case .failure:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.grocartSecondaryBackground)
                            .aspectRatio(1.2, contentMode: .fit)
                            .overlay(
                                Image(systemName: "basket.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.grocartGreen.opacity(0.3))
                            )
                    default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.grocartSecondaryBackground)
                            .aspectRatio(1.2, contentMode: .fit)
                            .overlay(ProgressView())
                    }
                }
                
                if product.isOnSale {
                    Text("-\(product.discountPercentage)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red)
                        .cornerRadius(6)
                        .padding(6)
                }
                
                if !product.isInStock {
                    VStack {
                        Spacer()
                        Text("Out of Stock")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                    }
                    .cornerRadius(10)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .lineLimit(2)
                
                Text(product.quantity)
                    .font(.system(size: 11))
                    .foregroundColor(.grocartSecondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.formattedOfferPrice)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.grocartGreen)
                        
                        if product.isOnSale {
                            Text(product.formattedOriginalPrice)
                                .font(.system(size: 11))
                                .foregroundColor(.grocartSecondary)
                                .strikethrough()
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(product.isInStock ? Color.grocartGreen : Color.gray)
                            .clipShape(Circle())
                    }
                    .disabled(!product.isInStock)
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
