//
//  HomeTabView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct HomeTabView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var locationState = LocationState.shared
    @State private var showCityPicker = false
    @State private var showNotifications = false
    @State private var showProfile = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Featured on Grocart (Stores Grid)
                        featuredStoresGridSection

                        // Stores with product previews
                        storesSection

                        // Top ordered products
                        topProductsSection

                        // Active Orders (shown when logged in and orders exist)
                        ActiveOrdersSection()

                        Spacer().frame(height: 90)
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            LocationManager.shared.requestLocationIfNeeded()
        }
        .onChange(of: locationState.cityName) { newValue in
            if newValue == "Location Off" {
                showCityPicker = true
            }
        }
        .confirmationDialog("Choose Your City", isPresented: $showCityPicker, titleVisibility: .visible) {
            ForEach(City.allCases, id: \.self) { city in
                Button(city.displayName) { locationState.cityName = city.displayName }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Location access is off. Select your delivery city.")
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
                    
                    Button(action: { showCityPicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.grocartGreen)
                                .font(.system(size: 14))
                            Text(locationState.cityName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.grocartPrimary)
                                .redacted(reason: locationState.cityName == "Locating..." ? .placeholder : [])
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.grocartPrimary)
                        }
                    }
                }
                
                Spacer()
                
                NavigationLink(destination: NotificationsView(), isActive: $showNotifications) {
                    EmptyView()
                }
                .hidden()

                NavigationLink(destination: ProfileView(), isActive: $showProfile) {
                    EmptyView()
                }
                .hidden()

                HStack(spacing: 10) {
                    Button(action: { showNotifications = true }) {
                        Image(systemName: "bell")
                            .font(.system(size: 18))
                            .foregroundColor(.grocartPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.grocartSecondaryBackground)
                            .clipShape(Circle())
                    }

                    Button(action: { showProfile = true }) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.grocartPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.grocartSecondaryBackground)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - Featured on Grocart (Store Grid)
    private var featuredStoresGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Featured on Grocart")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.grocartPrimary)
                .padding(.horizontal, 20)

            if viewModel.isLoadingStores {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 120)
            } else if !viewModel.stores.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 14
                ) {
                    ForEach(viewModel.stores) { store in
                        NavigationLink(destination: StoreDetailView(store: store)) {
                            FeaturedStoreCard(store: store)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Stores
    private var storesSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Stores Near You")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    Text("Design preview • Sample prices")
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            if viewModel.isLoadingStores {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 140)
            } else if viewModel.stores.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "storefront")
                            .font(.system(size: 32))
                            .foregroundColor(.grocartSecondary)
                        Text("No stores available in \(locationState.cityName)")
                            .font(.system(size: 13))
                            .foregroundColor(.grocartSecondary)
                            .multilineTextAlignment(.center)
                        Button(action: { showCityPicker = true }) {
                            Text("Change City")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.grocartGreen)
                                .cornerRadius(10)
                        }
                    }
                    Spacer()
                }
                .frame(height: 150)
                .padding(.horizontal, 20)
            } else {
                ForEach(viewModel.stores) { store in
                    HomeStoreSection(store: store)
                }
            }
        }
    }

    // MARK: - Top Products
    @ViewBuilder
    private var topProductsSection: some View {
        if !viewModel.topProducts.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Top Products")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    Spacer()
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.topProducts) { item in
                            HomeProductCard(product: item.asProduct)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
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
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                            .clipped()
                            .cornerRadius(10)
                    case .failure:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.grocartSecondaryBackground)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                            .overlay(
                                Image(systemName: "basket.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.grocartGreen.opacity(0.3))
                            )
                    default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.grocartSecondaryBackground)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 130, maxHeight: 130)
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
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)

                Text(product.quantity)
                    .font(.system(size: 11))
                    .foregroundColor(.grocartSecondary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.formattedOfferPrice)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.grocartGreen)

                        Text(product.formattedOriginalPrice)
                            .font(.system(size: 11))
                            .foregroundColor(.grocartSecondary)
                            .strikethrough()
                            .opacity(product.isOnSale ? 1 : 0)
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

// MARK: - Home Store Section (store header + randomized product preview)
struct HomeStoreSection: View {
    let store: Store
    @StateObject private var viewModel: HomeStoreProductsViewModel

    init(store: Store) {
        self.store = store
        _viewModel = StateObject(wrappedValue: HomeStoreProductsViewModel(store: store))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Store header + View All
            NavigationLink(destination: StoreDetailView(store: store)) {
                HStack(spacing: 12) {
                    storeLogo

                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.grocartPrimary)
                            .lineLimit(1)
                        Text(store.address)
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 2) {
                        Text("View All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.grocartGreen)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.grocartGreen)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            // Product preview row
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 180)
            } else if !viewModel.products.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.products) { item in
                            NavigationLink(destination: ProductDetailView(
                                product: item.product,
                                categoryName: item.categoryName,
                                store: store
                            )) {
                                HomeProductCard(product: item.product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var storeLogo: some View {
        if let assetName = store.bundledIconAssetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1))
        } else if let logoUrl = store.logoUrl, let url = URL(string: logoUrl) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.grocartSecondaryBackground
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.grocartGreen.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.grocartGreen)
                )
        }
    }
}

// MARK: - Home Product Card (compact preview, tappable)
struct HomeProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.grocartSecondaryBackground)
                            .frame(width: 140, height: 110)
                            .overlay(
                                Image(systemName: "basket.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.grocartGreen.opacity(0.3))
                            )
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
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .lineLimit(2)
                    .frame(width: 140, height: 34, alignment: .topLeading)

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

// MARK: - Featured Store Card (2-column Grid)
struct FeaturedStoreCard: View {
    let store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image header
            storeImage
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                .clipped()
                .cornerRadius(10)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(store.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.grocartPrimary)
                    .lineLimit(1)

                Text(store.formattedDeliveryFee)
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
        }
        .padding(10)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(Color.grocartBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var storeImage: some View {
        if let assetName = store.bundledBannerAssetName ?? store.bundledIconAssetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                .clipped()
        } else if let bannerUrl = store.bannerUrl ?? store.logoUrl, let url = URL(string: bannerUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 100)
                        .clipped()
                default:
                    placeholderImage
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 100)
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.grocartGreen.opacity(0.12))
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 100)
            .overlay(
                Image(systemName: "storefront.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.grocartGreen)
            )
    }
}

#Preview {
    HomeTabView()
}
