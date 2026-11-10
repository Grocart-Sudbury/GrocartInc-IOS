//
//  StoreDetailView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import SwiftUI

// MARK: - Main View
struct StoreDetailView: View {
    @StateObject private var viewModel: StoreDetailViewModel
    @ObservedObject private var cartManager = CartManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategoryId: Int? = nil
    @State private var showCart = false
    @State private var searchText = ""

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var selectedCategory: Category? {
        viewModel.categories.first { $0.id == selectedCategoryId }
    }

    private var searchResults: [(product: Product, category: Category)] {
        guard isSearching else { return [] }
        let query = searchText.lowercased()
        return viewModel.categories.flatMap { cat in
            cat.products
                .filter { $0.name.lowercased().contains(query) }
                .map { (product: $0, category: cat) }
        }
    }

    private let gridColumns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    init(store: Store) {
        _viewModel = StateObject(wrappedValue: StoreDetailViewModel(store: store))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else {
                contentView
            }

            // Back button overlay
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .padding(10)
                    .glassPill()
            }
            .padding(.top, 56)
            .padding(.leading, 16)
        }
        .clearGlassBackground()
        .navigationBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
            // The cart's X means "go home": pop this store page too, so the
            // user lands on the home screen itself, not back on the store.
            dismiss()
        }
        .onAppear { viewModel.loadCategories() }
        .onChange(of: viewModel.categories.count) { _ in
            if selectedCategoryId == nil { selectedCategoryId = viewModel.categories.first?.id }
        }
        .sheet(isPresented: $showCart) { CartView() }
        .hideFloatingBottomBar()
    }

    // MARK: - Content
    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                storeHeader

                Section {
                    if isSearching {
                        searchResultsSection
                    } else if viewModel.categories.isEmpty {
                        emptyProductsView
                    } else {
                        categoryProductsSection
                    }
                    Color.clear.frame(height: 90)
                } header: {
                    if !isSearching {
                        categoryBar
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            floatingCartButton
        }
    }

    // MARK: - Category Bar (horizontal pills, no scroll-position tracking)
    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.categories) { category in
                    let isActive = selectedCategoryId == category.id
                    Button(action: { selectedCategoryId = category.id }) {
                        Text(category.name)
                            .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                            .foregroundColor(isActive ? .white : .grocartPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(isActive ? Color.black : Color.clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.black.opacity(0.12), lineWidth: isActive ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Selected Category Products
    @ViewBuilder
    private var categoryProductsSection: some View {
        if let category = selectedCategory {
            if category.products.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "basket")
                        .font(.system(size: 36))
                        .foregroundColor(.grocartSecondary.opacity(0.4))
                    Text("No products in this category")
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Section header: which category, and how many products.
                HStack(alignment: .firstTextBaseline) {
                    Text(category.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    Spacer()
                    Text("\(category.products.count) products")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.grocartSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 12)

                LazyVGrid(columns: gridColumns, spacing: 16) {
                    ForEach(category.products) { product in
                        StoreProductCard(
                            product: product,
                            categoryName: category.name,
                            store: viewModel.store
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Search Results
    @ViewBuilder
    private var searchResultsSection: some View {
        if searchResults.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(.grocartSecondary)
                Text("No results for \"\(searchText)\"")
                    .font(.system(size: 14))
                    .foregroundColor(.grocartSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text("Results for \"\(searchText)\"")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.grocartPrimary)
                    .lineLimit(1)
                Spacer()
                Text("\(searchResults.count) products")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.grocartSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)

            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(searchResults, id: \.product.id) { item in
                    StoreProductCard(
                        product: item.product,
                        categoryName: item.category.name,
                        store: viewModel.store
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Floating Cart Button
    @ViewBuilder
    private var floatingCartButton: some View {
        if !cartManager.isEmpty {
            Button(action: { showCart = true }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.grocartGreen.opacity(0.35))
                            .frame(width: 32, height: 32)
                        Text("\(cartManager.itemCount)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.grocartNavy)
                    }

                    Text("View Cart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.grocartNavy)

                    Spacer()

                    Text(cartManager.formattedSubtotal)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.grocartNavy)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .glassCard(cornerRadius: 20, tint: .clear)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: cartManager.isEmpty)
        }
    }

    // MARK: - Store Header
    private var storeHeader: some View {
        VStack(spacing: 0) {
            // Banner
            ZStack(alignment: .bottomLeading) {
                if let assetName = viewModel.store.bundledBannerAssetName {
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let bannerUrl = viewModel.store.bannerUrl, let url = URL(string: bannerUrl) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            LinearGradient(
                                colors: [Color.grocartGreen.opacity(0.8), Color.grocartGreen],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        }
                    }
                } else {
                    LinearGradient(
                        colors: [Color.grocartGreen.opacity(0.8), Color.grocartGreen],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.35)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .frame(height: 220)
            .clipped()

            // Store card — floats over the banner with the store identity
            // and the key facts, so the page reads as one organised card.
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    storeIcon

                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.store.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.grocartPrimary)

                        HStack(spacing: 5) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.grocartSecondary)
                            Text(viewModel.store.displayAddress)
                                .font(.system(size: 12))
                                .foregroundColor(.grocartSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }

                if !viewModel.store.description.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(viewModel.store.description)
                        .font(.system(size: 13))
                        .foregroundColor(.grocartPrimary.opacity(0.75))
                        .lineLimit(2)
                }

                // Key facts as small pills.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        storeFactPill(icon: "bag.fill", text: viewModel.store.formattedMinOrder)
                        storeFactPill(icon: "bicycle", text: viewModel.store.formattedDeliveryFee)
                        storeFactPill(icon: "square.grid.2x2.fill", text: "\(totalProductCount) products")
                        storeFactPill(icon: "list.bullet", text: "\(viewModel.categories.count) categories")
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 22, tint: .clear)
            .padding(.horizontal, 16)
            .offset(y: -28)
            .padding(.bottom, -28)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.grocartSecondary)
                TextField("Search in \(viewModel.store.name)...", text: $searchText)
                    .font(.system(size: 14))
                if isSearching {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.grocartSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 16, tint: .clear)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }

    private var totalProductCount: Int {
        viewModel.categories.reduce(0) { $0 + $1.products.count }
    }

    private func storeFactPill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.grocartNavy)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.grocartGreen.opacity(0.25))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var storeIcon: some View {
        if let assetName = viewModel.store.bundledIconAssetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(8)
                .frame(width: 56, height: 56)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        } else if let logoUrl = viewModel.store.logoUrl, let url = URL(string: logoUrl) {
            CachedAsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.grocartGreen
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.2)
            Text("Loading products...")
                .font(.system(size: 14))
                .foregroundColor(.grocartSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(.grocartSecondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.grocartSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try Again") { viewModel.retry() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.grocartGreen)
                .cornerRadius(10)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty
    private var emptyProductsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "basket")
                .font(.system(size: 40))
                .foregroundColor(.grocartSecondary)
            Text("No products available yet")
                .font(.system(size: 14))
                .foregroundColor(.grocartSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Product Card
struct StoreProductCard: View {
    let product: Product
    let categoryName: String
    let store: Store
    @ObservedObject private var cartManager = CartManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tappable image + info navigates to detail
            NavigationLink(destination: ProductDetailView(product: product, categoryName: categoryName, store: store)) {
                VStack(alignment: .leading, spacing: 8) {
                    // Image
                    ZStack(alignment: .topLeading) {
                        CachedAsyncImage(urlString: product.imageUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                                    .clipped()
                                    .cornerRadius(10)
                            default:
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.grocartSecondaryBackground)
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                                    .overlay(
                                        Image(systemName: "basket.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.black.opacity(0.2))
                                    )
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            if product.isOnSale {
                                Text("-\(product.discountPercentage)%")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .cornerRadius(5)
                            }
                            if product.isSpecialOrder {
                                Text("Special Order")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .cornerRadius(5)
                            }
                        }
                        .padding(5)

                        if !product.isInStock {
                            VStack {
                                Spacer()
                                Text("Out of Stock")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.6))
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                            .cornerRadius(10)
                        }
                    }

                    // Name + qty
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)

                        Text(product.quantity)
                            .font(.system(size: 10))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 2)
                }
            }
            .buttonStyle(.plain)

            // Price row + Add/Qty button (not part of navigation tap area)
            let qty = cartManager.count(for: product.id)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(product.formattedOfferPrice)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)

                    Text(product.formattedOriginalPrice)
                        .font(.system(size: 10))
                        .foregroundColor(.black.opacity(0.55))
                        .strikethrough()
                        .opacity(product.isOnSale ? 1 : 0)
                }

                Spacer()

                if qty > 0 {
                    HStack(spacing: 0) {
                        Button(action: { cartManager.decrement(productId: product.id) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 26, height: 26)
                        }
                        Text("\(qty)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(minWidth: 20)
                        Button(action: {
                            cartManager.add(product: product, categoryName: categoryName, store: store)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.black)
                                .clipShape(Circle())
                        }
                    }
                    .glassPill(tint: .clear)
                } else {
                    Button(action: {
                        guard product.isInStock else { return }
                        cartManager.add(product: product, categoryName: categoryName, store: store)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(product.isInStock ? Color.black : Color.gray)
                            .clipShape(Circle())
                    }
                    .disabled(!product.isInStock)
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
        .glassCard(cornerRadius: 20, tint: .clear)
    }
}
