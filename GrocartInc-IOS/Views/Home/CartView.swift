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
    @State private var minOrderError: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
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
            .clearGlassBackground()
            .navigationTitle(cartTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.loadSuggestions() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { goHome() }) {
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

    // MARK: - Title (with total item count)
    private var cartTitle: String {
        guard !cartManager.isEmpty else { return "My Cart" }
        return "My Cart · \(cartManager.itemCount) item\(cartManager.itemCount == 1 ? "" : "s")"
    }

    // MARK: - Go Home (X button)
    private func goHome() {
        // Close the cart itself (when it is open as a sheet over a store),
        // then tell the app to switch to the Home tab. The store page also
        // listens for this and pops itself, so the user lands on Home.
        dismiss()
        NotificationCenter.default.post(name: .navigateToHome, object: nil)
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

                    // Cart items — each product in its own glass card
                    VStack(spacing: 12) {
                        ForEach(cartManager.items) { item in
                            cartRow(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Pricing breakdown
                    pricingSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // Suggestions based on what's in the cart
                    suggestionsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    // Room for the raised checkout button + floating tab bar.
                    Spacer().frame(height: 170)
                }
            }

            // Place order button
            placeOrderButton
        }
        .sheet(isPresented: $showLoginSheet, onDismiss: {
            guard SessionManager.shared.isLoggedIn, let pricing = viewModel.pricing else { return }
            guard pricing.subtotal >= 20 else {
                minOrderError = "Minimum order is $20.00. Add more items to continue."
                return
            }
            minOrderError = nil
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
                Text(store.displayAddress)
                    .font(.system(size: 11))
                    .foregroundColor(.grocartSecondary)
            }
            Spacer()
        }
        .padding(14)
        .glassCard(cornerRadius: 14, tint: .clear)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Cart Row
    private func cartRow(item: CartItem) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(urlString: item.product.imageUrl) { phase in
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
                    .foregroundColor(.black)
                Text(item.product.formattedOfferPrice)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
            }

            Spacer()

            // Stepper
            HStack(spacing: 0) {
                Button(action: { cartManager.decrement(productId: item.product.id) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 20, height: 20)
                }
                Text("\(item.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(minWidth: 24)
                Button(action: {
                    cartManager.add(product: item.product, categoryName: item.categoryName, store: item.store)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.black)
                        .clipShape(Circle())
                }
            }
            .glassPill(tint: .clear)
        }
        .padding(14)
        .glassCard(cornerRadius: 16, tint: .clear)
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
        .glassCard(cornerRadius: 16, tint: .clear)
    }

    private func pricingRows(pricing: CartPricingResponse) -> some View {
        VStack(spacing: 10) {
            pricingRow(label: "Subtotal", value: pricing.formattedSubtotal)
            pricingRow(label: "Tax (HST 13%)", value: pricing.formattedTax)
            if pricing.serviceFee > 0 {
                pricingRow(label: "Service Fee", value: pricing.formattedServiceFee)
            }
            if pricing.discount > 0 {
                pricingRow(label: "Discount", value: pricing.formattedDiscount, valueColor: .grocartGreen)
            }
            Divider().padding(.vertical, 4)
            HStack {
                Text("Total")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.grocartPrimary)
                Spacer()
                Text(pricing.formattedTotal)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
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
            if let msg = minOrderError {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            Button(action: {
                guard SessionManager.shared.isLoggedIn else {
                    showLoginSheet = true
                    return
                }
                guard let pricing = viewModel.pricing else { return }
                guard pricing.subtotal >= 20 else {
                    minOrderError = "Minimum order is $20.00. Add more items to continue."
                    return
                }
                minOrderError = nil
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
                // Lifted above the floating tab bar (Home / Search / Cart),
                // which floats over the bottom ~76pt of the screen.
                .padding(.bottom, 88)
            }
            .disabled(viewModel.pricing == nil)
        }
        .onChange(of: cartManager.items.count) { _ in minOrderError = nil }
    }

    // MARK: - Suggestions
    // Empty cart: top selling items in a grid. Cart with products: items
    // from the same categories in a sideways-scrolling row. Tapping a card
    // opens the product; the + button adds it straight to the cart.
    private var suggestionsSection: some View {
        Group {
            if !viewModel.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text(viewModel.suggestionsTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.grocartPrimary)

                    if cartManager.isEmpty {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(viewModel.suggestions) { item in
                                NavigationLink(destination: ProductDetailView(product: item.product, categoryName: item.categoryName, store: item.store)) {
                                    SearchProductCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.suggestions) { item in
                                    NavigationLink(destination: ProductDetailView(product: item.product, categoryName: item.categoryName, store: item.store)) {
                                        SearchProductCard(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: 170)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty
    private var emptyView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 20) {
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
                    Button(action: { goHome() }) {
                        Text("Browse stores")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.glassPrimary)
                    .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

                suggestionsSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
