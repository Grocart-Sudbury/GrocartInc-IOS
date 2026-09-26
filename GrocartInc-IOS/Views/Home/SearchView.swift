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
                    storePicker
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
                NavigationLink(destination: StoreDetailView(store: store)) {
                    SearchStoreRow(store: store)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
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
                if let assetName = store.bundledIconAssetName {
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let logoUrl = store.logoUrl, let url = URL(string: logoUrl) {
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
