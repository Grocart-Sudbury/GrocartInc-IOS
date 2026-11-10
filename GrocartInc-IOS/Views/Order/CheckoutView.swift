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
    @ObservedObject private var pointsManager = PointsManager.shared
    @ObservedObject private var scratchCardManager = ScratchCardManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isPaymentActive = false
    @State private var showAddressSelector = false
    @State private var showAddCard = false

    init(pricing: CartPricingResponse) {
        _viewModel = StateObject(wrappedValue: CheckoutViewModel(pricing: pricing))
    }

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    orderTypeSection
                    if viewModel.orderType == .delivery {
                        deliveryAddressSection
                        scheduleSection
                        tipSection
                    } else {
                        pickupInfoSection
                        pickupScheduleSection
                    }
                    if viewModel.orderType == .delivery {
                        promoCodeSection
                    }
                    rewardsSection
                    scratchCardSection
                    paymentSection
                    orderSummarySection
                    placeOrderButton
                    Spacer().frame(height: 90)
                }
                .padding(.top, 8)
            }

            NavigationLink(
                destination: Group {
                    if let order = viewModel.pendingPaymentOrder {
                        PaymentView(order: order) { confirmedOrder in
                            logger.info("✅ PaymentView onPaymentSuccess — orderId=\(confirmedOrder.id)")
                            // Record the sale in the on-device sales log.
                            // This runs first, before settling points and
                            // marking the scratch card used: those change
                            // the points/scratch discounts to $0, and the
                            // log must capture the amounts actually charged.
                            if let logStore = viewModel.pendingLogStore {
                                SalesLogManager.shared.recordOrder(
                                    orderId: confirmedOrder.id,
                                    trackingId: confirmedOrder.trackingId,
                                    store: logStore,
                                    items: viewModel.pendingLogItems,
                                    orderType: viewModel.orderType.rawValue,
                                    paymentMethod: viewModel.paymentMethod.rawValue,
                                    subtotal: viewModel.pricing.subtotal,
                                    tax: viewModel.pricing.tax,
                                    deliveryCharge: viewModel.orderType == .delivery ? viewModel.effectiveShippingCost : 0,
                                    tip: viewModel.orderType == .delivery ? viewModel.tipAmount : 0,
                                    discount: viewModel.validatedDiscount + viewModel.pointsDiscount + viewModel.scratchCardDiscount,
                                    total: viewModel.totalWithTip
                                )
                            }
                            // Settle rewards: take 500 points if redeemed,
                            // then award the points earned on this order's items.
                            PointsManager.shared.settleOrder(earnedPoints: viewModel.pendingEarnedPoints, redeemed: viewModel.usePointsReward, orderLabel: "Order \(confirmedOrder.trackingId)")
                            if let usedCard = viewModel.selectedScratchCard {
                                ScratchCardManager.shared.markUsed(usedCard)
                            }
                            viewModel.earnedScratchCard = ScratchCardManager.shared.generateAfterOrder(orderLabel: "Order \(confirmedOrder.trackingId)")
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
        .onAppear {
            if viewModel.orderType == .delivery {
                Task { await viewModel.fetchSlotsForSelectedDate() }
            }
            Task { await viewModel.loadSavedCards() }
        }
        .sheet(isPresented: $showAddCard) {
            StandaloneAddCardView(setAsDefault: viewModel.savedCards.isEmpty) {
                Task { await viewModel.loadSavedCards() }
            }
        }
        .onChange(of: viewModel.selectedDate) { _ in
            if viewModel.orderType == .delivery {
                Task { await viewModel.fetchSlotsForSelectedDate() }
            }
        }
        .onChange(of: viewModel.orderType) { type in
            if type == .delivery {
                // Cash is pickup-only, so switching to delivery goes back to card.
                viewModel.paymentMethod = .card
                Task { await viewModel.fetchSlotsForSelectedDate() }
            }
        }
        .onChange(of: viewModel.pendingPaymentOrder?.id) { orderId in
            logger.info("🔄 pendingPaymentOrder changed → \(orderId?.description ?? "nil")")
            if orderId != nil { isPaymentActive = true }
        }
        .fullScreenCover(item: $viewModel.placedOrder, onDismiss: {
            dismiss()
        }) { order in
            OrderConfirmationView(order: order, pointsEarned: viewModel.pendingEarnedPoints, scratchCard: viewModel.earnedScratchCard)
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

    // MARK: - 0. Order Type Picker
    private var orderTypeSection: some View {
        card {
            sectionHeader("Order Type", icon: "shippingbox.fill")

            HStack(spacing: 0) {
                ForEach(OrderType.allCases, id: \.rawValue) { type in
                    let isSelected = viewModel.orderType == type
                    Button(action: { viewModel.orderType = type }) {
                        HStack(spacing: 8) {
                            Image(systemName: type == .delivery ? "bicycle" : "storefront.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(type.display)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(isSelected ? .white : .grocartPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? Color.grocartGreen : Color.clear)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(4)
            .background(Color.grocartBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))

            if viewModel.orderType == .pickup {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.grocartGreen)
                    Text("Pick up your order at the store. No delivery fee or tip.")
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Pickup Contact Info
    private var pickupInfoSection: some View {
        card {
            sectionHeader("Your Details", icon: "person.fill")

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    checkoutField("First Name", text: $viewModel.firstName)
                    checkoutField("Last Name", text: $viewModel.lastName)
                }
                checkoutField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                checkoutField("Phone", text: $viewModel.phone)
                    .keyboardType(.phonePad)
            }

            HStack(spacing: 8) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.grocartGreen)
                Text("You'll receive a notification when your order is ready.")
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
            }
            .padding(.top, 2)
        }
    }

    private func checkoutField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 15))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.grocartBackground)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Pickup Schedule
    private var pickupScheduleSection: some View {
        card {
            sectionHeader("Pickup Schedule", icon: "clock.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.availableDates, id: \.self) { date in
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: viewModel.selectedPickupDate)
                        Button(action: { viewModel.selectedPickupDate = date }) {
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

            Text("Select a pickup time")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.grocartSecondary)
                .padding(.top, 4)

            if viewModel.availablePickupSlots.isEmpty {
                Text("No pickup available on this day")
                    .font(.system(size: 13))
                    .foregroundColor(.grocartSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(viewModel.availablePickupSlots) { slot in
                        let isSelected = viewModel.selectedPickupSlot == slot
                        Button(action: { viewModel.selectedPickupSlot = slot }) {
                            Text(slot.display)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : .grocartPrimary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
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

                // The distance from the store and the fee for it, once the
                // address has been geocoded.
                if let distance = viewModel.deliveryDistanceKm, let fee = viewModel.distanceBasedFee {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                        Text("\(DeliveryFeeCalculator.formattedDistance(distance)) from the store · Delivery fee \(DeliveryFeeCalculator.formattedFee(fee))")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.grocartSecondary)
                    .padding(.top, 2)
                }
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
                        .foregroundColor(.grocartGreen)
                        .font(.system(size: 14))
                    Text("Promo applied! You save \(String(format: "$%.2f", viewModel.validatedDiscount))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.grocartGreen)
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

    // MARK: - Rewards Points
    private var rewardsSection: some View {
        card {
            sectionHeader("Rewards", icon: "star.fill")

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.grocartGreen.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.grocartGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pointsManager.points) points")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    if pointsManager.canRedeem {
                        Text("You can redeem $5 off this order")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                    } else {
                        Text("Only redeemable at 500 points")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                    }
                }
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.grocartGreen.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.grocartGreen)
                        .frame(width: geo.size.width * pointsManager.progressToReward, height: 8)
                }
            }
            .frame(height: 8)

            if pointsManager.canRedeem {
                // 500+ points: choose to bank them or use them on this order.
                Picker("Redeem points", selection: $viewModel.usePointsReward) {
                    Text("Bank points").tag(false)
                    Text("Use 500 pts").tag(true)
                }
                .pickerStyle(.segmented)

                Text(viewModel.usePointsReward
                     ? "500 points will be used for $5 off this order."
                     : "Your points stay saved for a later order.")
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
            } else {
                Text("You have \(pointsManager.points) points — \(pointsManager.pointsToNextReward) more to unlock $5 off. Earn 1 point for every $1 you spend.")
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
            }
        }
    }

    // MARK: - Scratch Card
    private var scratchCardSection: some View {
        let usable = scratchCardManager.availableCards
        let unscratched = scratchCardManager.cards.filter { !$0.isScratched && !$0.isExpired }
        if usable.isEmpty && unscratched.isEmpty {
            return AnyView(EmptyView())
        }
        return AnyView(
            card {
                sectionHeader("Scratch Card", icon: "ticket.fill")

                if usable.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                        Text("You have \(unscratched.count) scratch card\(unscratched.count == 1 ? "" : "s") to reveal — find them in My Coupons.")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(usable) { scratchCard in
                            scratchCardOption(scratchCard)
                        }
                    }
                    if viewModel.selectedScratchCard != nil {
                        Text("This scratch card will be used on this order.")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                    }
                }
            }
        )
    }

    private func scratchCardOption(_ scratchCard: ScratchCard) -> some View {
        let isSelected = viewModel.selectedScratchCard?.id == scratchCard.id
        let discount = ScratchCardManager.discount(for: scratchCard, subtotal: viewModel.pricing.subtotal)
        return Button(action: {
            viewModel.selectedScratchCard = isSelected ? nil : scratchCard
        }) {
            HStack(spacing: 8) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scratchCard.displayDiscount)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.grocartPrimary)
                    Text("Save \(String(format: "$%.2f", discount)) on this order · Exp \(scratchCard.formattedExpiry)")
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.grocartGreen)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.grocartGreen.opacity(0.08) : Color.grocartBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.grocartGreen.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Payment
    private var paymentSection: some View {
        card {
            sectionHeader("Payment Method", icon: "creditcard.fill")

            VStack(spacing: 10) {
                paymentOption(.card)
                // Cash is only available for pickup orders.
                if viewModel.orderType == .pickup {
                    paymentOption(.cash)
                }
            }

            if viewModel.paymentMethod == .card {
                savedCardsBlock
            }

            if viewModel.paymentMethod == .cash {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.grocartGreen)
                    Text("Pay in cash when you pick up your order at the store.")
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Saved cards (Stripe) under the card option
    private var savedCardsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isLoadingCards {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if viewModel.savedCards.isEmpty {
                Text("No saved card yet. Add one below — your card is entered through Stripe and never touches our servers.")
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.6))
            } else {
                ForEach(viewModel.savedCards) { card in
                    HStack(spacing: 10) {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.black)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(card.displayBrand) •• \(card.last4)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            Text("Expires \(card.formattedExpiry)")
                                .font(.system(size: 12))
                                .foregroundColor(.black.opacity(0.6))
                        }
                        Spacer()
                        if card.isDefault {
                            Text("Default")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.grocartGreen)
                                .cornerRadius(10)
                        }
                    }
                    .padding(12)
                    .glassCard(cornerRadius: 14, tint: .clear)
                }
            }

            Button {
                showAddCard = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add a card")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black)
                .cornerRadius(14)
            }
        }
        .padding(.top, 4)
    }

    private func paymentOption(_ method: CheckoutPaymentMethod) -> some View {
        let isSelected = viewModel.paymentMethod == method
        return Button(action: { viewModel.paymentMethod = method }) {
            HStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(.system(size: 15))
                    .foregroundColor(.grocartGreen)
                Text(method.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.grocartGreen)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.grocartGreen.opacity(0.08) : Color.grocartBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.grocartGreen.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
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
            if viewModel.orderType == .delivery {
                pricingRow(viewModel.deliveryFeeLabel, viewModel.formattedEffectiveShipping)
                if viewModel.pricing.serviceFee > 0 {
                    pricingRow("Service Fee", viewModel.pricing.formattedServiceFee)
                }
            }
            if viewModel.validatedDiscount > 0 {
                pricingRow("Discount", String(format: "-$%.2f", viewModel.validatedDiscount), color: .grocartGreen)
            }
            if viewModel.pointsDiscount > 0 {
                pricingRow("Points Discount", String(format: "-$%.2f", viewModel.pointsDiscount), color: .grocartGreen)
            }
            if viewModel.scratchCardDiscount > 0 {
                pricingRow("Scratch Card", String(format: "-$%.2f", viewModel.scratchCardDiscount), color: .grocartGreen)
            }
            if viewModel.orderType == .delivery && viewModel.tipAmount > 0 {
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

            if viewModel.isBelowMinimum {
                HStack(spacing: 8) {
                    Image(systemName: "cart.badge.minus")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                    Text("Minimum order is $20.00. Add more items to proceed.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
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
    }

    // MARK: - Date Helpers
    private func dayAbbrev(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date).uppercased()
    }
    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
}
