//
//  SearchView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if viewModel.selectedStore == nil {
                        storePicker
                    } else {
                        searchContent
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Store Picker (no store selected)

    private var storePicker: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Choose a store to search")
                    .font(.system(size: 15))
                    .foregroundColor(.grocartSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                if viewModel.isLoadingStores {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(height: 160)
                } else if viewModel.stores.isEmpty {
                    emptyStoresView
                } else {
                    storeList
                }
            }
            .padding(.vertical, 16)
        }
    }

    private var emptyStoresView: some View {
        VStack(spacing: 14) {
            Image(systemName: "storefront")
                .font(.system(size: 40))
                .foregroundColor(.grocartSecondary)
            Text("No stores available in your area")
                .font(.system(size: 14))
                .foregroundColor(.grocartSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var storeList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.stores) { store in
                Button(action: { viewModel.selectStore(store) }) {
                    SearchStoreRow(store: store)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Search Content (store selected)

    private var searchContent: some View {
        VStack(spacing: 0) {
            // Selected store header + change button
            selectedStoreHeader
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)

            // Search bar
            searchBar
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            Divider()

            // Results / empty state
            if viewModel.isLoadingProducts {
                Spacer()
                ProgressView()
                Spacer()
            } else if !viewModel.searchText.isEmpty {
                searchResultsList
            } else {
                idleSearchState
            }
        }
    }

    private var selectedStoreHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 14))
                .foregroundColor(.grocartGreen)

            Text(viewModel.selectedStore?.name ?? "")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.grocartPrimary)
                .lineLimit(1)

            Spacer()

            Button(action: { viewModel.clearStore() }) {
                Text("Change")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.grocartGreen)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.grocartGreen.opacity(0.08))
        .cornerRadius(12)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.grocartSecondary)

            TextField("Search for groceries...", text: $viewModel.searchText)
                .font(.system(size: 15))

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.grocartSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.grocartSecondaryBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Results

    private var searchResultsList: some View {
        Group {
            if viewModel.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.grocartSecondary)
                    Text("No results for \"\(viewModel.searchText)\"")
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(viewModel.searchResults) { result in
                            if let store = viewModel.selectedStore {
                                StoreProductCard(
                                    product: result.product,
                                    categoryName: result.categoryName,
                                    store: store
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Idle state (store selected, no query)

    private var idleSearchState: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if !viewModel.recentSearches.isEmpty {
                    recentSearchesSection
                } else {
                    Text("Start typing to search products in \(viewModel.selectedStore?.name ?? "this store")")
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                }
            }
            .padding(20)
        }
    }

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Searches")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.grocartPrimary)
                Spacer()
                Button("Clear All") { viewModel.clearAllRecent() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.grocartGreen)
            }

            ForEach(viewModel.recentSearches, id: \.self) { query in
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)

                    Button(action: { viewModel.applyRecent(query) }) {
                        Text(query)
                            .font(.system(size: 15))
                            .foregroundColor(.grocartPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: { viewModel.removeRecent(query) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.grocartSecondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - Store Row for picker

private struct SearchStoreRow: View {
    let store: Store

    var body: some View {
        HStack(spacing: 14) {
            // Logo / icon
            Group {
                if let logoUrl = store.logoUrl, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            storeIcon
                        }
                    }
                } else {
                    storeIcon
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(store.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.grocartPrimary)

                Text(store.address)
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Label(store.formattedDeliveryFee, systemImage: "bicycle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.grocartGreen)

                    Text("·")
                        .foregroundColor(.grocartSecondary)

                    Text(store.formattedMinOrder)
                        .font(.system(size: 11))
                        .foregroundColor(.grocartSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.grocartSecondary)
        }
        .padding(14)
        .background(Color.grocartSecondaryBackground)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.12), lineWidth: 1))
    }

    private var storeIcon: some View {
        LinearGradient(
            colors: [Color.grocartGreen.opacity(0.6), Color.grocartGreen],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "storefront.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
        )
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
