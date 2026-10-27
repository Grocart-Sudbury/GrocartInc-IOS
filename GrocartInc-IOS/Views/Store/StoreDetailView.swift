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
            Color.grocartBackground.ignoresSafeArea()

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
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
            }
            .padding(.top, 56)
            .padding(.leading, 16)
        }
        .navigationBarHidden(true)
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

    // MARK: - Category Bar (horizontal chips, no scroll-position tracking)
    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.categories) { category in
                    let isActive = selectedCategoryId == category.id
                    Button(action: { selectedCategoryId = category.id }) {
                        Text(category.name)
                            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                            .foregroundColor(isActive ? .white : .grocartPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isActive ? Color.grocartGreen : Color.grocartSecondaryBackground)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.grocartBackground)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
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
                LazyVGrid(columns: gridColumns, spacing: 14) {
                    ForEach(category.products) { product in
                        StoreProductCard(
                            product: product,
                            categoryName: category.name,
                            store: viewModel.store
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
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
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(searchResults, id: \.product.id) { item in
                    StoreProductCard(
                        product: item.product,
                        categoryName: item.category.name,
                        store: viewModel.store
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
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
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 32, height: 32)
                        Text("\(cartManager.itemCount)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("View Cart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Text(cartManager.formattedSubtotal)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.grocartGreen)
                .cornerRadius(16)
                .shadow(color: Color.grocartGreen.opacity(0.4), radius: 10, y: 4)
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
                    AsyncImage(url: url) { phase in
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
                    colors: [Color.clear, Color.black.opacity(0.5)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .frame(height: 200)
            .clipped()

            // Store info row
            HStack(alignment: .top, spacing: 14) {
                if let assetName = viewModel.store.bundledIconAssetName {
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(10)
                        .frame(width: 64, height: 64)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white, lineWidth: 2))
                        .offset(y: -20)
                } else if let logoUrl = viewModel.store.logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.grocartGreen
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white, lineWidth: 2))
                    .offset(y: -20)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.store.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.grocartPrimary)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                        Text(viewModel.store.address)
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                    }

                    HStack(spacing: 12) {
                        Text(viewModel.store.formattedMinOrder)
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                    }
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .background(Color.grocartBackground)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.grocartSecondary)
                TextField("Search products...", text: $searchText)
                    .font(.system(size: 14))
                if isSearching {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.grocartSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.grocartSecondaryBackground)
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
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
                        AsyncImage(url: URL(string: product.imageUrl)) { phase in
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
                                            .foregroundColor(.grocartGreen.opacity(0.3))
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
                            .foregroundColor(.grocartSecondary)
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
                        .foregroundColor(.grocartGreen)

                    Text(product.formattedOriginalPrice)
                        .font(.system(size: 10))
                        .foregroundColor(.grocartSecondary)
                        .strikethrough()
                        .opacity(product.isOnSale ? 1 : 0)
                }

                Spacer()

                if qty > 0 {
                    HStack(spacing: 0) {
                        Button(action: { cartManager.decrement(productId: product.id) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.grocartGreen)
                                .frame(width: 26, height: 26)
                        }
                        Text("\(qty)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.grocartPrimary)
                            .frame(minWidth: 20)
                        Button(action: {
                            cartManager.add(product: product, categoryName: categoryName, store: store)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.grocartGreen)
                                .clipShape(Circle())
                        }
                    }
                    .background(Color.grocartSecondaryBackground)
                    .cornerRadius(13)
                } else {
                    Button(action: {
                        guard product.isInStock else { return }
                        cartManager.add(product: product, categoryName: categoryName, store: store)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(product.isInStock ? Color.grocartGreen : Color.gray)
                            .clipShape(Circle())
                    }
                    .disabled(!product.isInStock)
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
        .background(
            product.isSpecialOrder
                ? Color.orange.opacity(0.06)
                : Color.grocartBackground
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    product.isSpecialOrder ? Color.orange.opacity(0.3) : Color.gray.opacity(0.12),
                    lineWidth: 1
                )
        )
    }
}
