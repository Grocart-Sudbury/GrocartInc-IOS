//
//  ProductDetailView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-05-21.
//

import SwiftUI

struct ProductDetailView: View {
    let product: Product
    let categoryName: String
    let store: Store

    @ObservedObject private var cartManager = CartManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showQuantityPopup = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage

                    VStack(alignment: .leading, spacing: 20) {
                        badgesRow

                        VStack(alignment: .leading, spacing: 6) {
                            Text(product.name)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.black)

                            Text(product.quantity)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        priceRow

                        if !product.description.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Description")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .tracking(1)
                                Text(product.description)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.black.opacity(0.75))
                                    .lineSpacing(7)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }

            // Back button
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .padding(10)
                    .glassPill(tint: .clear)
            }
            .padding(.top, 56)
            .padding(.leading, 16)
        }
        .clearGlassBackground()
        .navigationBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
            // Returning home (e.g. Done in the quantity popup after adding):
            // pop this product page too, so the user lands on the home
            // screen itself, not back here.
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCart)) { _ in
            // Same for jumping to the cart: no stale product page behind it.
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissProductDetail)) { _ in
            // Done in the quantity popup: close this page so the user
            // lands back where they were browsing (e.g. the store page).
            dismiss()
        }
        .sheet(isPresented: $showQuantityPopup) {
            QuantityPopupView(product: product, categoryName: categoryName, store: store)
                .presentationDetents([.medium])
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addToCartBar
        }
        .hideFloatingBottomBar()
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        ZStack {
            CachedAsyncImage(urlString: product.imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .scaledToFill()
                default:
                    Color.grocartSecondaryBackground
                        .overlay(
                            Image(systemName: "basket.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.black.opacity(0.2))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            if !product.isInStock {
                Color.black.opacity(0.4)
                Text("Out of Stock")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: 320)
        .cornerRadius(28)
        .clipped()
        .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Badges

    @ViewBuilder
    private var badgesRow: some View {
        let show = product.isOnSale || product.isSpecialOrder || !product.isInStock
        if show {
            HStack(spacing: 8) {
                if product.isOnSale {
                    badge("-\(product.discountPercentage)% Off", color: .red)
                }
                if product.isSpecialOrder {
                    badge("Special Order", color: .orange)
                }
                if !product.isInStock {
                    badge("Out of Stock", color: .gray)
                }
            }
        }
    }

    private func badge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .cornerRadius(20)
    }

    // MARK: - Price

    private var priceRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Text(product.formattedOfferPrice)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.black)

            if product.isOnSale {
                Text(product.formattedOriginalPrice)
                    .font(.system(size: 16))
                    .foregroundColor(.black.opacity(0.45))
                    .strikethrough()
                    .padding(.bottom, 3)
            }
        }
    }

    // MARK: - Add to Cart Bar

    private var addToCartBar: some View {
        let qty = cartManager.count(for: product.id)
        return Group {
            if qty > 0 {
                HStack(spacing: 0) {
                    Button(action: { cartManager.decrement(productId: product.id) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 52, height: 52)
                    }

                    Button(action: { showQuantityPopup = true }) {
                        Text("\(qty)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(minWidth: 40)
                    }

                    Button(action: {
                        cartManager.add(product: product, categoryName: categoryName, store: store)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black)
                            .clipShape(Circle())
                            .padding(.trailing, 6)
                    }
                }
                .glassPill(tint: .clear)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            } else {
                Button(action: {
                    guard product.isInStock else { return }
                    cartManager.add(product: product, categoryName: categoryName, store: store)
                    showQuantityPopup = true
                }) {
                    Text(product.isInStock ? "Add to Cart" : "Out of Stock")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.blackPrimary)
                .disabled(!product.isInStock)
                .opacity(product.isInStock ? 1 : 0.6)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
    }
}
