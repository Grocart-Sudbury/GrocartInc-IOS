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

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.grocartBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage

                    VStack(alignment: .leading, spacing: 16) {
                        badgesRow

                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.grocartPrimary)

                            Text(product.quantity)
                                .font(.system(size: 14))
                                .foregroundColor(.grocartSecondary)
                        }

                        priceRow

                        if !product.description.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.grocartPrimary)
                                Text(product.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.grocartSecondary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Color.clear.frame(height: 100)
                    }
                    .padding(20)
                }
            }

            // Back button
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addToCartBar
        }
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        ZStack {
            AsyncImage(url: URL(string: product.imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .scaledToFill()
                default:
                    Color.grocartSecondaryBackground
                        .overlay(
                            Image(systemName: "basket.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.grocartGreen.opacity(0.2))
                        )
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 300)
            .clipped()

            if !product.isInStock {
                Color.black.opacity(0.4)
                Text("Out of Stock")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 300)
        .clipped()
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
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color)
            .cornerRadius(20)
    }

    // MARK: - Price

    private var priceRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Text(product.formattedOfferPrice)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.grocartGreen)

            if product.isOnSale {
                Text(product.formattedOriginalPrice)
                    .font(.system(size: 16))
                    .foregroundColor(.grocartSecondary)
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
                            .foregroundColor(.grocartGreen)
                            .frame(width: 52, height: 52)
                    }

                    Text("\(qty)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                        .frame(minWidth: 40)

                    Button(action: {
                        cartManager.add(product: product, categoryName: categoryName, store: store)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.grocartGreen)
                            .clipShape(Circle())
                            .padding(.trailing, 6)
                    }
                }
                .background(Color.grocartSecondaryBackground)
                .cornerRadius(26)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.grocartBackground)
                .overlay(Rectangle().fill(Color.gray.opacity(0.12)).frame(height: 1), alignment: .top)
            } else {
                Button(action: {
                    guard product.isInStock else { return }
                    cartManager.add(product: product, categoryName: categoryName, store: store)
                }) {
                    Text(product.isInStock ? "Add to Cart" : "Out of Stock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(product.isInStock ? Color.grocartGreen : Color.gray)
                        .cornerRadius(14)
                }
                .disabled(!product.isInStock)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.grocartBackground)
                .overlay(Rectangle().fill(Color.gray.opacity(0.12)).frame(height: 1), alignment: .top)
            }
        }
    }
}
