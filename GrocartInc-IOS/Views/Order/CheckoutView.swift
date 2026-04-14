//
//  CheckoutView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import SwiftUI

struct CheckoutView: View {
    @StateObject private var viewModel: CheckoutViewModel
    @ObservedObject private var cartManager = CartManager.shared
    @Environment(\.dismiss) private var dismiss

    init(pricing: CartPricingResponse) {
        _viewModel = StateObject(wrappedValue: CheckoutViewModel(pricing: pricing))
    }

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    deliveryAddressSection
                    scheduleSection
                    tipSection
                    paymentSection
                    orderSummarySection
                    Spacer().frame(height: 90)
                }
                .padding(.top, 8)
            }

            // Error banner
            if let error = viewModel.errorMessage {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    Spacer()
                }
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { placeOrderButton }
        .fullScreenCover(item: $viewModel.placedOrder) { order in
            OrderConfirmationView(order: order)
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.grocartGreen)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.grocartPrimary)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Card Container
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .background(Color.grocartSecondaryBackground.opacity(0.6))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Text Field Style
    private func styledField(_ placeholder: String, text: Binding<String>,
                              keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(.system(size: 15))
            .padding(12)
            .background(Color.grocartBackground)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    // MARK: - 1. Delivery Address
    private var deliveryAddressSection: some View {
        card {
            sectionHeader("Delivery Address", icon: "mappin.circle.fill")

            HStack(spacing: 10) {
                styledField("First name", text: $viewModel.firstName)
                styledField("Last name", text: $viewModel.lastName)
            }

            styledField("Phone number", text: $viewModel.phone, keyboard: .phonePad)
            styledField("Street address", text: $viewModel.address)

            HStack(spacing: 10) {
                styledField("City", text: $viewModel.city)
                styledField("Province", text: $viewModel.province)
                    .frame(maxWidth: 90)
            }

            styledField("Postal code", text: $viewModel.postalCode)
                .textInputAutocapitalization(.characters)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.deliveryNotes)
                    .font(.system(size: 15))
                    .frame(height: 70)
                    .padding(8)
                    .background(Color.grocartBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                if viewModel.deliveryNotes.isEmpty {
                    Text("Delivery instructions (optional)")
                        .font(.system(size: 15))
                        .foregroundColor(Color(UIColor.placeholderText))
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - 2. Schedule
    private var scheduleSection: some View {
        card {
            sectionHeader("Delivery Schedule", icon: "clock.fill")

            // Date pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.availableDates, id: \.self) { date in
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate)
                        Button(action: { viewModel.selectedDate = date }) {
                            VStack(spacing: 4) {
                                Text(dayAbbrev(date))
                                    .font(.system(size: 11, weight: .medium))
                                Text(dayNumber(date))
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .frame(width: 52, height: 62)
                            .foregroundColor(isSelected ? .white : .grocartPrimary)
                            .background(isSelected ? Color.grocartGreen : Color.grocartBackground)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1))
                        }
                    }
                }
            }

            Text("Select a time slot")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.grocartSecondary)
                .padding(.top, 4)

            // Time slot grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: 10) {
                ForEach(DeliveryTimeSlot.allCases) { slot in
                    let isSelected = viewModel.selectedSlot == slot
                    Button(action: { viewModel.selectedSlot = slot }) {
                        Text(slot.display)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : .grocartPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.grocartGreen : Color.grocartBackground)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - 3. Tip
    private var tipSection: some View {
        card {
            sectionHeader("Add a Tip", icon: "heart.fill")

            Text("100% goes to your delivery driver")
                .font(.system(size: 12))
                .foregroundColor(.grocartSecondary)

            HStack(spacing: 10) {
                ForEach([0.0, 1.0, 2.0, 3.0, 5.0], id: \.self) { amount in
                    let isSelected = viewModel.tipAmount == amount
                    Button(action: { viewModel.tipAmount = amount }) {
                        Text(amount == 0 ? "No Tip" : String(format: "$%.0f", amount))
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .white : .grocartPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.grocartGreen : Color.grocartBackground)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - 4. Payment
    private var paymentSection: some View {
        card {
            sectionHeader("Payment Method", icon: "creditcard.fill")

            HStack(spacing: 12) {
                paymentOption(label: "Cash", icon: "banknote", value: "CASH")
                paymentOption(label: "Credit Card", icon: "creditcard", value: "STRIPE")
            }
        }
    }

    private func paymentOption(label: String, icon: String, value: String) -> some View {
        let isSelected = viewModel.paymentMethod == value
        return Button(action: { viewModel.paymentMethod = value }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                Text(label)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .grocartPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color.grocartGreen : Color.grocartBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - 5. Order Summary
    private var orderSummarySection: some View {
        card {
            sectionHeader("Order Summary", icon: "list.bullet.rectangle")

            // Items
            ForEach(cartManager.items) { item in
                HStack(spacing: 10) {
                    Text("\(item.count)×")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                        .frame(width: 28)
                    Text(item.product.name)
                        .font(.system(size: 13))
                        .foregroundColor(.grocartPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "$%.2f", item.product.displayPrice * Double(item.count)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.grocartPrimary)
                }
            }

            Divider().padding(.vertical, 4)

            pricingRow("Subtotal", viewModel.pricing.formattedSubtotal)
            pricingRow("Tax (HST 13%)", viewModel.pricing.formattedTax)
            pricingRow("Shipping", viewModel.pricing.formattedShipping)
            if viewModel.pricing.serviceFee > 0 {
                pricingRow("Service Fee", viewModel.pricing.formattedServiceFee)
            }
            if viewModel.pricing.discount > 0 {
                pricingRow("Discount", viewModel.pricing.formattedDiscount, color: .green)
            }
            if viewModel.tipAmount > 0 {
                pricingRow("Tip", String(format: "$%.2f", viewModel.tipAmount), color: .grocartGreen)
            }

            Divider().padding(.vertical, 4)

            HStack {
                Text("Total")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.grocartPrimary)
                Spacer()
                Text(viewModel.formattedTotal)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.grocartGreen)
            }
        }
    }

    private func pricingRow(_ label: String, _ value: String, color: Color = .grocartPrimary) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(.grocartSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundColor(color)
        }
    }

    // MARK: - Place Order Button
    private var placeOrderButton: some View {
        Button(action: { viewModel.placeOrder() }) {
            HStack {
                if viewModel.isPlacingOrder {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Place Order")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text(viewModel.formattedTotal)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(viewModel.isFormValid ? Color.grocartGreen : Color.grocartGreen.opacity(0.5))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .disabled(viewModel.isPlacingOrder || !viewModel.isFormValid)
        .background(Color.grocartBackground)
    }

    // MARK: - Date Helpers
    private func dayAbbrev(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date).uppercased()
    }
    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
}
