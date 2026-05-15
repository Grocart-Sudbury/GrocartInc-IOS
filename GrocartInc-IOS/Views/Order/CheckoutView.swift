//
//  CheckoutView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "CheckoutView")

struct CheckoutView: View {
    @StateObject private var viewModel: CheckoutViewModel
    @ObservedObject private var cartManager = CartManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isPaymentActive = false
    @State private var showAddressSelector = false

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
                    promoCodeSection
                    paymentSection
                    orderSummarySection
                    Spacer().frame(height: 90)
                }
                .padding(.top, 8)
            }

            NavigationLink(
                destination: Group {
                    if let order = viewModel.pendingPaymentOrder {
                        PaymentView(order: order) { confirmedOrder in
                            logger.info("✅ PaymentView onPaymentSuccess — orderId=\(confirmedOrder.id)")
                            isPaymentActive = false
                            viewModel.pendingPaymentOrder = nil
                            viewModel.placedOrder = confirmedOrder
                        }
                    }
                },
                isActive: $isPaymentActive,
                label: { EmptyView() }
            )
            .hidden()

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
        .onAppear {
            Task { await viewModel.fetchSlotsForSelectedDate() }
        }
        .onChange(of: viewModel.selectedDate) { _ in
            Task { await viewModel.fetchSlotsForSelectedDate() }
        }
        .onChange(of: viewModel.pendingPaymentOrder?.id) { orderId in
            logger.info("🔄 pendingPaymentOrder changed → \(orderId?.description ?? "nil")")
            if orderId != nil { isPaymentActive = true }
        }
        .fullScreenCover(item: $viewModel.placedOrder, onDismiss: {
            dismiss()
        }) { order in
            OrderConfirmationView(order: order)
        }
        .sheet(isPresented: $showAddressSelector) {
            AddressSelectorView(selectedAddress: $viewModel.selectedAddress)
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

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .background(Color.grocartSecondaryBackground.opacity(0.6))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - 1. Delivery Address
    private var deliveryAddressSection: some View {
        card {
            HStack {
                sectionHeader("Delivery Address", icon: "mappin.circle.fill")
                Spacer()
                Button(action: { showAddressSelector = true }) {
                    Text(viewModel.selectedAddress == nil ? "Add" : "Change")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                }
            }

            if let addr = viewModel.selectedAddress {
                selectedAddressCard(addr)
            } else {
                emptyAddressPrompt
            }

            // Delivery notes always visible
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

    private func selectedAddressCard(_ addr: CustomerAddress) -> some View {
        Button(action: { showAddressSelector = true }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.grocartGreen.opacity(0.1))
                        .frame(width: 42, height: 42)
                    Image(systemName: labelIcon(for: addr.label))
                        .font(.system(size: 17))
                        .foregroundColor(.grocartGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(addr.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                        if addr.isDefault {
                            Text("DEFAULT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.grocartGreen)
                                .tracking(0.5)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.grocartGreen.opacity(0.1)))
                        }
                    }
                    Text(addr.fullName)
                        .font(.system(size: 13))
                        .foregroundColor(.grocartSecondary)
                    Text(addr.displayAddress)
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary.opacity(0.8))
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.grocartSecondary)
                        Text(addr.phone)
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary.opacity(0.8))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.grocartSecondary)
            }
            .padding(14)
            .background(Color.grocartBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.grocartGreen.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyAddressPrompt: some View {
        Button(action: { showAddressSelector = true }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.grocartGreen, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .frame(width: 42, height: 42)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select a delivery address")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                    Text("Tap to add or choose a saved address")
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.grocartGreen.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.grocartGreen.opacity(0.25), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func labelIcon(for label: String) -> String {
        switch label.lowercased() {
        case "home":  return "house.fill"
        case "work":  return "briefcase.fill"
        default:      return "mappin.circle.fill"
        }
    }

    // MARK: - 2. Schedule
    private var scheduleSection: some View {
        card {
            sectionHeader("Delivery Schedule", icon: "clock.fill")

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

            if viewModel.isLoadingSlots {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if viewModel.availableSlots.isEmpty {
                Text("No delivery available on this day")
                    .font(.system(size: 13))
                    .foregroundColor(.grocartSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 10) {
                    ForEach(viewModel.availableSlots) { slot in
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

    // MARK: - 4. Promo Code
    private var promoCodeSection: some View {
        card {
            sectionHeader("Promo Code", icon: "tag.fill")

            HStack(spacing: 10) {
                TextField("Enter promo code", text: $viewModel.couponCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.grocartBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1))

                Button(action: { viewModel.applyCoupon() }) {
                    Group {
                        if viewModel.isApplyingCoupon {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Apply")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 70, height: 42)
                    .background(Color.grocartGreen)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isApplyingCoupon || viewModel.couponCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if viewModel.couponApplied {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    Text("Promo applied! You save \(String(format: "$%.2f", viewModel.validatedDiscount))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green)
                }
            } else if let error = viewModel.couponError {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: - 5. Payment
    private var paymentSection: some View {
        card {
            sectionHeader("Payment Method", icon: "creditcard.fill")

            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.grocartGreen)
                Text("Credit Card")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(Color.grocartGreen.opacity(0.08))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color.grocartGreen.opacity(0.4), lineWidth: 1.5))
        }
    }

    // MARK: - 6. Order Summary
    private var orderSummarySection: some View {
        card {
            sectionHeader("Order Summary", icon: "list.bullet.rectangle")

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
            if viewModel.validatedDiscount > 0 {
                pricingRow("Discount", String(format: "-$%.2f", viewModel.validatedDiscount), color: .green)
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
