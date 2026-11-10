//
//  QuantityPopupView.swift
//  GrocartInc-IOS
//
//  Quantity meter that pops up when a product is added to the cart.
//  The + and - buttons change the amount in the cart live: every tap on +
//  adds one more of the product, every tap on - takes one away. If the
//  amount reaches zero the product leaves the cart and the popup closes.
//

import SwiftUI

struct QuantityPopupView: View {
    let product: Product
    let categoryName: String
    let store: Store

    @ObservedObject private var cartManager = CartManager.shared
    @Environment(\.dismiss) private var dismiss

    private var qty: Int { cartManager.count(for: product.id) }

    private var totalPrice: String {
        String(format: "$%.2f", product.displayPrice * Double(qty))
    }

    var body: some View {
        VStack(spacing: 20) {
            // Product
            HStack(spacing: 14) {
                CachedAsyncImage(urlString: product.imageUrl) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.grocartSecondaryBackground
                    }
                }
                .frame(width: 72, height: 72)
                .cornerRadius(12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                        .lineLimit(2)
                    Text(product.quantity)
                        .font(.system(size: 13))
                        .foregroundColor(.black)
                    Text(product.formattedOfferPrice)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                }

                Spacer()
            }

            // Quantity meter
            HStack(spacing: 0) {
                Button(action: { cartManager.decrement(productId: product.id) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 56, height: 56)
                }

                Text("\(qty)")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.black)
                    .frame(minWidth: 56)

                Button(action: {
                    cartManager.add(product: product, categoryName: categoryName, store: store)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black)
                        .clipShape(Circle())
                        .padding(.trailing, 6)
                }
            }
            .glassPill(tint: .clear)

            // Total for this product
            HStack {
                Text("Total")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                Spacer()
                Text(totalPrice)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }

            // Actions
            VStack(spacing: 12) {
                Button(action: {
                    dismiss()
                    NotificationCenter.default.post(name: .navigateToCart, object: nil)
                }) {
                    Text("View Cart · \(cartManager.itemCount) item\(cartManager.itemCount == 1 ? "" : "s")")
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.blackPrimary)

                Button(action: {
                    dismiss()
                    // Close the product page too, landing back on the
                    // screen the product was opened from (the store page
                    // when browsing a store) instead of jumping home.
                    NotificationCenter.default.post(name: .dismissProductDetail, object: nil)
                }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.grocartPrimary)
                }
            }
        }
        .padding(20)
        .onChange(of: qty) { newQty in
            // Amount hit zero: nothing of this product is left in the cart.
            if newQty == 0 { dismiss() }
        }
    }
}
