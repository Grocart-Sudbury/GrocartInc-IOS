//
//  SubscriptionCreateView.swift
//  GrocartInc-IOS
//
//  Step 1 of a new subscription: pick the items from the chosen store.
//  Search + a category drop-down filter the list. Only the items scroll;
//  the search and category filter stay at the top, and a Continue bar
//  floats at the bottom. Continue goes to the review page, where the
//  user verifies everything before committing.
//

import SwiftUI

struct SubscriptionCreateView: View {
    let store: Store
    @ObservedObject var createVM: SubscriptionCreateViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            createForm
        }
        .navigationTitle(store.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await createVM.selectStore(store)
            await createVM.loadCards()
            await createVM.loadAddresses()
        }
        .alert("Something went wrong", isPresented: .constant(createVM.errorMessage != nil)) {
            Button("OK") { createVM.errorMessage = nil }
        } message: {
            Text(createVM.errorMessage ?? "")
        }
    }

    // MARK: - Step 1: pick items (search + category fixed, items scroll)
    private var createForm: some View {
        VStack(spacing: 0) {
            // Search + category filter — fixed at the top
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.black.opacity(0.5))
                    TextField("Search items", text: $createVM.searchText)
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                        .autocorrectionDisabled()
                    if !createVM.searchText.isEmpty {
                        Button { createVM.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.black.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 16, tint: .clear)

                // Category drop-down
                Menu {
                    Button("All categories") {
                        createVM.selectedCategory = nil
                    }
                    ForEach(createVM.categories, id: \.self) { category in
                        Button {
                            createVM.selectedCategory = category
                        } label: {
                            Label(category, systemImage: createVM.selectedCategory == category ? "checkmark" : "tag")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                        Text(createVM.selectedCategory ?? "All categories")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassPill(tint: .clear)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Items — the only scrolling part
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your items")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)

                    if createVM.isLoadingItems {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else if createVM.filteredItems.isEmpty {
                        Text(createVM.searchText.isEmpty && createVM.selectedCategory == nil
                             ? "No items available from this store yet."
                             : "No items match your filters.")
                            .font(.system(size: 14))
                            .foregroundColor(.black.opacity(0.6))
                            .padding(.vertical, 12)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(createVM.filteredItems, id: \.product.id) { item in
                                SubscriptionItemCard(
                                    product: item.product,
                                    quantity: createVM.quantity(for: item.product.id),
                                    onQuantityChange: { createVM.setQuantity($0, for: item.product.id) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            continueBar
        }
    }

    // MARK: - Floating Continue bar (always visible)
    private var continueBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(createVM.selectedItems.isEmpty
                 ? "Add items to continue"
                 : "\(createVM.selectedItems.count) item\(createVM.selectedItems.count == 1 ? "" : "s") selected · \(createVM.formattedTotalPerCycle) per delivery")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)

            NavigationLink {
                SubscriptionReviewView(store: store, createVM: createVM)
            } label: {
                Text("Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(18)
            }
            .disabled(createVM.selectedItems.isEmpty)
            .opacity(createVM.selectedItems.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.grocartBackground)
    }
}

// MARK: - Subscription item card
private struct SubscriptionItemCard: View {
    let product: Product
    let quantity: Int
    let onQuantityChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(urlString: product.imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 110, maxHeight: 110)
                            .clipped()
                            .cornerRadius(10)
                    case .failure:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.grocartSecondaryBackground)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 110, maxHeight: 110)
                            .overlay(
                                Image(systemName: "basket.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.black.opacity(0.2))
                            )
                    default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.grocartSecondaryBackground)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 110, maxHeight: 110)
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
            }

            Text(product.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
            Text(product.quantity)
                .font(.system(size: 11))
                .foregroundColor(.black)

            HStack(spacing: 6) {
                Text(product.formattedOfferPrice)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                if product.isOnSale {
                    Text(product.formattedOriginalPrice)
                        .font(.system(size: 11))
                        .strikethrough()
                        .foregroundColor(.black.opacity(0.55))
                }
                Spacer()
            }

            // Quantity stepper (subscription quantity, not the cart)
            HStack(spacing: 0) {
                Button {
                    onQuantityChange(quantity - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                }
                .disabled(quantity == 0)
                .opacity(quantity == 0 ? 0.3 : 1)

                Text("\(quantity)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(minWidth: 24)

                Button {
                    onQuantityChange(quantity + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.black)
                        .clipShape(Circle())
                }
            }
            .padding(4)
            .glassPill(tint: .clear)
        }
        .padding(10)
        .glassCard(cornerRadius: 16, tint: .clear)
    }
}
