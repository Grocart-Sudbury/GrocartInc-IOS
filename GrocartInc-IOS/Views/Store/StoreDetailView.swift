//
//  StoreDetailView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import SwiftUI

// MARK: - Preference key to track each category header's Y position
private struct CategoryPositionKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Main View
struct StoreDetailView: View {
    @StateObject private var viewModel: StoreDetailViewModel
    @ObservedObject private var cartManager = CartManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var activeCategoryId: Int? = nil
    @State private var isCategoryTap = false
    @State private var showCart = false

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
        .sheet(isPresented: $showCart) { CartView() }
    }

    // MARK: - Content
    private var contentView: some View {
        ScrollViewReader { productProxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    storeHeader

                    Section {
                        if viewModel.categories.isEmpty {
                            emptyProductsView
                        } else {
                            ForEach(viewModel.categories) { category in
                                categorySection(category)
                            }
                        }
                        // Bottom padding so floating button doesn't cover last items
                        Color.clear.frame(height: 90)
                    } header: {
                        categoryBar(proxy: productProxy)
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(CategoryPositionKey.self) { positions in
                guard !isCategoryTap else { return }
                updateActiveCategory(from: positions)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                floatingCartButton
            }
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
                if let bannerUrl = viewModel.store.bannerUrl, let url = URL(string: bannerUrl) {
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

                // Gradient overlay at bottom
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.5)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .frame(height: 200)
            .clipped()

            // Store info row
            HStack(alignment: .top, spacing: 14) {
                // Logo
                if let logoUrl = viewModel.store.logoUrl, let url = URL(string: logoUrl) {
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
                        Label(viewModel.store.formattedDeliveryFee, systemImage: "bicycle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.grocartGreen)

                        Text("·").foregroundColor(.grocartSecondary)

                        Text(viewModel.store.formattedMinOrder)
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                    }
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .background(Color.grocartBackground)
        }
    }

    // MARK: - Sticky Category Bar
    private func categoryBar(proxy: ScrollViewProxy) -> some View {
        ScrollViewReader { chipProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.categories) { category in
                        let isActive = activeCategoryId == category.id

                        Button(action: {
                            isCategoryTap = true
                            activeCategoryId = category.id
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(category.id, anchor: .top)
                            }
                            // Re-enable scroll-driven updates after animation settles
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isCategoryTap = false
                            }
                        }) {
                            Text(category.name)
                                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                                .foregroundColor(isActive ? .white : .grocartPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isActive ? Color.grocartGreen : Color.grocartSecondaryBackground)
                                .cornerRadius(20)
                        }
                        .id("chip_\(category.id)")
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
            .onChange(of: activeCategoryId) { id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    chipProxy.scrollTo("chip_\(id)", anchor: .center)
                }
            }
        }
    }

    // MARK: - Category + Products Section
    private func categorySection(_ category: Category) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Category title — used as anchor + position reporter
            Text(category.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.grocartPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .id(category.id)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: CategoryPositionKey.self,
                            value: [category.id: geo.frame(in: .named("scroll")).minY]
                        )
                    }
                )

            if category.products.isEmpty {
                Text("No products available")
                    .font(.system(size: 13))
                    .foregroundColor(.grocartSecondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
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
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Active Category Detection
    private func updateActiveCategory(from positions: [Int: CGFloat]) {
        // Sticky bar height ~55pt; category that has just scrolled past it is active
        let threshold: CGFloat = 60
        let passed = positions.filter { $0.value < threshold }
        if let current = passed.max(by: { $0.value < $1.value }) {
            if activeCategoryId != current.key {
                activeCategoryId = current.key
            }
        } else if activeCategoryId == nil, let first = viewModel.categories.first {
            activeCategoryId = first.id
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
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

            // Price row + Add/Qty button
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
                    // Stepper
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
