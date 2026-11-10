//
//  SearchView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var searchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        searchField
                        resultCount

                        if viewModel.isLoading && viewModel.allItems.isEmpty {
                            loadingView
                        } else if viewModel.filteredItems.isEmpty {
                            emptyView
                        } else {
                            resultsGrid
                        }

                        Spacer().frame(height: 90)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .clearGlassBackground()
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Refresh automatically every time the tab opens, so the
                // products are current and in a new random order.
                Task { await viewModel.refresh() }
                // Open the keyboard right away so typing can start immediately.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    searchFocused = true
                }
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.grocartSecondary)

            TextField("Search all items...", text: $viewModel.query)
                .font(.system(size: 16))
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit {
                    // Performing a search refreshes the products and shows
                    // them in a new random order.
                    Task { await viewModel.refresh() }
                }

            if !viewModel.query.isEmpty {
                Button(action: { viewModel.query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.grocartSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 16, tint: .clear)
    }

    // MARK: - Result Count

    private var resultCount: some View {
        HStack {
            if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("\(viewModel.allItems.count) items · \(viewModel.storeCount) stores")
            } else {
                Text("\(viewModel.filteredItems.count) results for \"\(viewModel.query)\"")
            }
            Spacer()
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.grocartSecondary)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text("Loading all items...")
                .font(.system(size: 14))
                .foregroundColor(.grocartSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.grocartSecondary.opacity(0.5))

            if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("No items available")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.grocartSecondary)
                Text("Check back soon — new items arrive daily.")
                    .font(.system(size: 13))
                    .foregroundColor(.grocartSecondary)
            } else {
                Text("No results for \"\(viewModel.query)\"")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.grocartSecondary)
                Text("Try a different spelling or a more general word.")
                    .font(.system(size: 13))
                    .foregroundColor(.grocartSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Results

    private var resultsGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.filteredItems) { item in
                NavigationLink(destination: ProductDetailView(product: item.product, categoryName: item.categoryName, store: item.store)) {
                    SearchProductCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Product Card (search results)

struct SearchProductCard: View {
    let item: SearchItem
    @ObservedObject private var cartManager = CartManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Product Image
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(urlString: item.product.imageUrl) { phase in
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
                                    .foregroundColor(.black.opacity(0.2))
                            )
                    default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.grocartSecondaryBackground)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 130, maxHeight: 130)
                            .overlay(ProgressView())
                    }
                }

                if item.product.isOnSale {
                    Text("-\(item.product.discountPercentage)%")
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
                Text(item.product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)

                Text(item.product.quantity)
                    .font(.system(size: 11))
                    .foregroundColor(.black)

                Text(item.store.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.product.formattedOfferPrice)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)

                        Text(item.product.formattedOriginalPrice)
                            .font(.system(size: 11))
                            .foregroundColor(.black.opacity(0.55))
                            .strikethrough()
                            .opacity(item.product.isOnSale ? 1 : 0)
                    }

                    Spacer()

                    let qty = cartManager.count(for: item.product.id)
                    if qty > 0 {
                        HStack(spacing: 0) {
                            Button(action: { cartManager.decrement(productId: item.product.id) }) {
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
                                cartManager.add(product: item.product, categoryName: item.categoryName, store: item.store)
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
                            guard item.product.isInStock else { return }
                            cartManager.add(product: item.product, categoryName: item.categoryName, store: item.store)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 26, height: 26)
                                .background(item.product.isInStock ? Color.black : Color.gray)
                                .clipShape(Circle())
                        }
                        .disabled(!item.product.isInStock)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .glassCard(cornerRadius: 20, tint: .clear)
    }
}

#Preview {
    SearchView()
}
