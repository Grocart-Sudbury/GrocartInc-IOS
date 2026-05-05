//
//  CartView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct CartView: View {
    @ObservedObject private var cartManager = CartManager.shared
    @StateObject private var viewModel = CartViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToCheckout = false
    @State private var showLoginSheet = false
    // Frozen at tap time — never cleared by cart/pricing resets while navigated
    @State private var checkoutPricing: CartPricingResponse? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()

                if cartManager.isEmpty {
                    emptyView
                } else {
                    cartContent
                }

                // Always in the hierarchy with a frozen destination so the nav stack
                // (CheckoutView → PaymentView) survives cart/pricing resets.
                NavigationLink(
                    destination: Group {
                        if let pricing = checkoutPricing {
                            CheckoutView(pricing: pricing)
                        }
                    },
                    isActive: $navigateToCheckout
                ) { EmptyView() }
                    .hidden()
            }
            .navigationTitle("My Cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                    }
                }
                if !cartManager.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") { cartManager.clear() }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    // MARK: - Cart Content
    private var cartContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Store info banner
                    if let store = cartManager.store {
                        storeBanner(store: store)
                    }

                    // Cart items
                    VStack(spacing: 1) {
                        ForEach(cartManager.items) { item in
                            cartRow(item: item)
                        }
                    }
                    .background(Color.grocartSecondaryBackground.opacity(0.5))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Pricing breakdown
                    pricingSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    Spacer().frame(height: 100)
                }
            }

            // Place order button
            placeOrderButton
        }
        .sheet(isPresented: $showLoginSheet, onDismiss: {
            guard SessionManager.shared.isLoggedIn, let pricing = viewModel.pricing else { return }
            checkoutPricing = pricing
            navigateToCheckout = true
        }) {
            LoginView()
        }
    }

    // MARK: - Store Banner
    private func storeBanner(store: Store) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "storefront.fill")
                .font(.system(size: 16))
                .foregroundColor(.grocartGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                Text(store.address)
                    .font(.system(size: 11))
                    .foregroundColor(.grocartSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.grocartGreen.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Cart Row
    private func cartRow(item: CartItem) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.product.imageUrl)) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.grocartSecondaryBackground
                }
            }
            .frame(width: 56, height: 56)
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.product.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .lineLimit(2)
                Text(item.product.quantity)
                    .font(.system(size: 11))
                    .foregroundColor(.grocartSecondary)
                Text(item.product.formattedOfferPrice)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.grocartGreen)
            }

            Spacer()

            // Stepper
            HStack(spacing: 0) {
                Button(action: { cartManager.decrement(productId: item.product.id) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.grocartGreen)
                        .frame(width: 30, height: 30)
                }
                Text("\(item.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.grocartPrimary)
                    .frame(minWidth: 24)
                Button(action: {
                    cartManager.add(product: item.product, categoryName: item.categoryName, store: item.store)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.grocartGreen)
                        .clipShape(Circle())
                }
            }
            .background(Color.grocartBackground)
            .cornerRadius(15)
        }
        .padding(14)
        .background(Color.grocartBackground)
    }

    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Order Summary")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.grocartPrimary)
                .padding(.bottom, 14)

            if viewModel.isLoadingPricing {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 80)
            } else if let pricing = viewModel.pricing {
                pricingRows(pricing: pricing)
            } else {
                // Fallback: show local subtotal only
                pricingRow(label: "Subtotal", value: cartManager.formattedSubtotal)
                if let error = viewModel.pricingError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.grocartSecondaryBackground.opacity(0.5))
        .cornerRadius(14)
    }

    private func pricingRows(pricing: CartPricingResponse) -> some View {
        VStack(spacing: 10) {
            pricingRow(label: "Subtotal", value: pricing.formattedSubtotal)
            pricingRow(label: "Tax (HST 13%)", value: pricing.formattedTax)
            pricingRow(label: "Shipping", value: pricing.formattedShipping)
            if pricing.serviceFee > 0 {
                pricingRow(label: "Service Fee", value: pricing.formattedServiceFee)
            }
            if pricing.discount > 0 {
                pricingRow(label: "Discount", value: pricing.formattedDiscount, valueColor: .green)
            }
            Divider().padding(.vertical, 4)
            HStack {
                Text("Total")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.grocartPrimary)
                Spacer()
                Text(pricing.formattedTotal)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.grocartGreen)
            }
        }
    }

    private func pricingRow(label: String, value: String, valueColor: Color = .grocartPrimary) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.grocartSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(valueColor)
        }
    }

    // MARK: - Place Order Button
    private var placeOrderButton: some View {
        VStack(spacing: 0) {
            Button(action: {
                guard SessionManager.shared.isLoggedIn else {
                    showLoginSheet = true
                    return
                }
                guard let pricing = viewModel.pricing else { return }
                checkoutPricing = pricing   // freeze before cart is cleared
                navigateToCheckout = true
            }) {
                HStack {
                    Text("Proceed to Checkout")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    if let total = viewModel.pricing?.formattedTotal {
                        Text(total)
                            .font(.system(size: 17, weight: .bold))
                    } else {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(viewModel.pricing != nil ? Color.grocartGreen : Color.grocartGreen.opacity(0.5))
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .disabled(viewModel.pricing == nil)
        }
        .background(Color.grocartBackground)
    }

    // MARK: - Empty
    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "cart")
                .font(.system(size: 56))
                .foregroundColor(.grocartSecondary.opacity(0.4))
            Text("Your cart is empty")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.grocartPrimary)
            Text("Browse stores and add items to get started")
                .font(.system(size: 15))
                .foregroundColor(.grocartSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
