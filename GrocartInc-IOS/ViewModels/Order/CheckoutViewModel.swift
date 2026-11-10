//
//  CheckoutViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
import Combine

// MARK: - Checkout Payment Method
enum CheckoutPaymentMethod: String, CaseIterable {
    case card = "STRIPE"
    case cash = "CASH"

    var displayName: String {
        switch self {
        case .card: return "Credit / Debit Card"
        case .cash: return "Pay by Cash"
        }
    }

    var icon: String {
        switch self {
        case .card: return "creditcard.fill"
        case .cash: return "banknote.fill"
        }
    }
}

@MainActor
final class CheckoutViewModel: ObservableObject {

    // MARK: - Shared Date Formatters
    /// DateFormatter creation is expensive; these are created once and
    /// reused for every slot fetch and order placement. They are only
    /// touched from this @MainActor view model.
    private static let orderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    // MARK: - Order Type
    @Published var orderType: OrderType = .delivery {
        didSet { refreshDeliveryFee() }
    }

    // MARK: - Selected Address
    @Published var selectedAddress: CustomerAddress? = nil {
        didSet { applyAddress(selectedAddress) }
    }

    // MARK: - Delivery Info (populated from selectedAddress)
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var address = ""
    @Published var city = ""
    @Published var province = "ON"
    @Published var postalCode = ""
    @Published var deliveryNotes = ""

    // MARK: - Delivery Schedule
    @Published var selectedDate: Date = Date()
    @Published var selectedSlot: DeliveryTimeSlot? = nil
    @Published var availableSlots: [DeliveryTimeSlot] = []
    @Published var isLoadingSlots = false

    // MARK: - Pickup Schedule
    @Published var selectedPickupDate: Date = Date() {
        didSet {
            if let slot = selectedPickupSlot, !availablePickupSlots.contains(slot) {
                selectedPickupSlot = nil
            }
        }
    }
    @Published var selectedPickupSlot: PickupTimeSlot? = nil

    // MARK: - Tip & Payment
    @Published var tipAmount: Double = 0
    /// How this order is paid. Card is "STRIPE"; cash is "CASH" and is
    /// only offered for pickup orders (pay at the store).
    @Published var paymentMethod: CheckoutPaymentMethod = .card

    // MARK: - Saved Cards (Stripe)
    /// The customer's saved cards, loaded from the backend. Shown under
    /// the card payment option so the customer can see which card will
    /// be charged and add a new one (through Stripe) before placing
    /// the order.
    @Published var savedCards: [SavedCard] = []
    @Published var isLoadingCards = false

    func loadSavedCards() async {
        isLoadingCards = true
        do {
            savedCards = try await PaymentRepository.shared.getSavedCards()
        } catch {
            savedCards = []
        }
        isLoadingCards = false
    }

    // MARK: - Rewards Points
    @Published var usePointsReward = false
    /// Points this order will earn, from the items (each item's price
    /// rounded to the nearest $1, x quantity). Computed when the order is
    /// placed, before the cart is cleared; awarded only if the payment
    /// succeeds.
    var pendingEarnedPoints: Int = 0

    // MARK: - Sales Log
    /// The cart items and store for the order being placed, captured
    /// when the order is placed (like pendingEarnedPoints) because the
    /// cart is cleared right after. Used to record the sale in the
    /// on-device sales log once the order succeeds — in the cash branch
    /// here, and in CheckoutView's PaymentView onPaymentSuccess for card.
    var pendingLogItems: [CartItem] = []
    var pendingLogStore: Store? = nil

    // MARK: - Scratch Card
    /// The scratch card the customer chose to apply to this order.
    @Published var selectedScratchCard: ScratchCard? = nil
    /// The scratch card earned from this order, shown on the confirmation.
    @Published var earnedScratchCard: ScratchCard? = nil

    // MARK: - State
    @Published var isPlacingOrder = false
    @Published var errorMessage: String? = nil
    @Published var placedOrder: OrderResponse? = nil
    @Published var pendingPaymentOrder: OrderResponse? = nil

    // MARK: - Promo Code
    @Published var couponCode = ""
    @Published var isApplyingCoupon = false
    @Published var couponApplied = false
    @Published var couponError: String? = nil
    @Published var validatedDiscount: Double = 0

    // MARK: - Dependencies
    @Published var pricing: CartPricingResponse
    private let cartManager = CartManager.shared
    private let repository = OrderRepository.shared
    private let addressRepo = AddressRepository.shared

    // MARK: - Distance-Based Delivery Fee
    /// The distance from the store to the selected delivery address, and
    /// the fee for it, once the address has been geocoded. Nil until then
    /// (or when the address can't be geocoded), in which case the backend's
    /// flat shipping cost is used instead.
    @Published var deliveryDistanceKm: Double? = nil
    @Published var distanceBasedFee: Double? = nil

    /// The delivery fee actually charged for this order. For delivery it is
    /// the distance-based fee when the address has been geocoded, otherwise
    /// the backend's flat shipping cost. Pickup has no delivery fee.
    var effectiveShippingCost: Double {
        if orderType == .pickup { return 0 }
        return distanceBasedFee ?? pricing.shippingCost
    }

    var formattedEffectiveShipping: String {
        effectiveShippingCost == 0 ? "Free" : String(format: "$%.2f", effectiveShippingCost)
    }

    /// "Delivery (5.3 km)" once the distance is known, otherwise "Delivery".
    var deliveryFeeLabel: String {
        if let distance = deliveryDistanceKm {
            return "Delivery (\(DeliveryFeeCalculator.formattedDistance(distance)))"
        }
        return "Delivery"
    }

    /// The backend's order total with its flat shipping cost swapped for the
    /// distance-based fee, so the total, the discounts and the order itself
    /// all agree on the fee the customer actually pays.
    var effectiveDeliveryTotal: Double {
        pricing.total - pricing.shippingCost + effectiveShippingCost
    }

    /// Work out the distance-based delivery fee for the selected address.
    /// Runs whenever the address or the order type changes; until it
    /// resolves (or when the address can't be geocoded) the backend's
    /// flat shipping cost applies.
    func refreshDeliveryFee() {
        guard orderType == .delivery,
              let address = selectedAddress,
              let store = cartManager.store else {
            deliveryDistanceKm = nil
            distanceBasedFee = nil
            return
        }
        Task {
            if let result = await DeliveryFeeCalculator.fee(from: store, to: address) {
                deliveryDistanceKm = result.distanceKm
                distanceBasedFee = result.fee
            } else {
                deliveryDistanceKm = nil
                distanceBasedFee = nil
            }
        }
    }

    // MARK: - Computed
    /// $5 off when the customer redeems 500 points. Capped so the total
    /// never goes below $0.
    var pointsDiscount: Double {
        guard usePointsReward && PointsManager.shared.canRedeem else { return 0 }
        let base: Double
        if orderType == .pickup {
            base = pricing.subtotal + pricing.tax - validatedDiscount
        } else {
            base = effectiveDeliveryTotal - validatedDiscount + tipAmount
        }
        return min(PointsManager.redeemValue, max(0, base))
    }

    var totalWithTip: Double {
        if orderType == .pickup {
            return pricing.subtotal + pricing.tax - validatedDiscount - pointsDiscount - scratchCardDiscount
        }
        return effectiveDeliveryTotal - validatedDiscount - pointsDiscount - scratchCardDiscount + tipAmount
    }
    var formattedTotal: String { String(format: "$%.2f", totalWithTip) }

    /// The discount from the scratch card applied to this order.
    /// Capped so the total never goes below $0.
    var scratchCardDiscount: Double {
        guard let card = selectedScratchCard, card.isUsable else { return 0 }
        let raw = ScratchCardManager.discount(for: card, subtotal: pricing.subtotal)
        let base: Double
        if orderType == .pickup {
            base = pricing.subtotal + pricing.tax - validatedDiscount - pointsDiscount
        } else {
            base = effectiveDeliveryTotal - validatedDiscount - pointsDiscount + tipAmount
        }
        return min(raw, max(0, base))
    }

    var availableDates: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    }

    static let minimumOrderAmount: Double = 20.0

    var isBelowMinimum: Bool { pricing.subtotal < CheckoutViewModel.minimumOrderAmount }

    var isFormValid: Bool {
        guard !isBelowMinimum else { return false }
        switch orderType {
        case .delivery:
            return selectedAddress != nil && selectedSlot != nil && !availableSlots.isEmpty
        case .pickup:
            return !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !phone.isEmpty
                && selectedPickupSlot != nil
        }
    }

    // MARK: - Init
    init(pricing: CartPricingResponse) {
        self.pricing = pricing
        prefill()
        loadDefaultAddress()
    }

    private func prefill() {
        let user = SessionManager.shared.currentUser
        firstName = user?.firstName ?? ""
        lastName  = user?.lastName  ?? ""
        email     = user?.email     ?? ""
        city      = LocationState.shared.cityName
            .replacingOccurrences(of: "Greater ", with: "")
    }

    private func applyAddress(_ addr: CustomerAddress?) {
        guard let a = addr else { return }
        firstName  = a.firstName
        lastName   = a.lastName
        phone      = a.phone
        address    = a.address
        city       = a.city
        province   = a.province
        postalCode = a.postalCode
        if email.isEmpty {
            email = SessionManager.shared.currentUser?.email ?? ""
        }
        refreshDeliveryFee()
    }

    private func loadDefaultAddress() {
        Task {
            do {
                let all = try await addressRepo.fetchAll()
                if let def = all.first(where: { $0.isDefault }) ?? all.first {
                    selectedAddress = def
                }
            } catch {
                // Silently fall through — user can still pick manually
            }
        }
    }

    // MARK: - Pickup Slots (filtered for today)
    var availablePickupSlots: [PickupTimeSlot] {
        let calendar = Calendar.current
        guard calendar.isDateInToday(selectedPickupDate) else { return PickupTimeSlot.allCases }
        let thirtyMinsFromNow = Date().addingTimeInterval(30 * 60)
        return PickupTimeSlot.allCases.filter { slot in
            var comps = calendar.dateComponents([.year, .month, .day], from: Date())
            comps.hour = slot.startHour
            comps.minute = 0
            comps.second = 0
            guard let slotDate = calendar.date(from: comps) else { return false }
            return slotDate >= thirtyMinsFromNow
        }
    }

    // MARK: - Delivery Slots
    func fetchSlotsForSelectedDate() async {
        guard let storeId = cartManager.store?.id else { return }
        let dayOfWeek = Self.weekdayFormatter.string(from: selectedDate).uppercased()

        isLoadingSlots = true
        defer { isLoadingSlots = false }

        do {
            let schedule = try await StoreRepository.shared.fetchSchedule(storeId: storeId, dayOfWeek: dayOfWeek)
            var slots = schedule.slots.compactMap { DeliveryTimeSlot(rawValue: $0) }

            let calendar = Calendar.current
            if calendar.isDateInToday(selectedDate) {
                let threeHoursFromNow = Date().addingTimeInterval(2 * 3600)
                slots = slots.filter { slot in
                    var comps = calendar.dateComponents([.year, .month, .day], from: Date())
                    comps.hour = slot.startHour
                    comps.minute = 0
                    comps.second = 0
                    guard let slotDate = calendar.date(from: comps) else { return false }
                    return slotDate >= threeHoursFromNow
                }
            }

            availableSlots = slots
            if let current = selectedSlot, !slots.contains(current) {
                selectedSlot = nil
            }
        } catch {
            availableSlots = []
            selectedSlot = nil
        }
    }

    // MARK: - Promo Code
    func applyCoupon() {
        let code = couponCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        couponError = nil
        couponApplied = false
        validatedDiscount = 0
        isApplyingCoupon = true
        Task {
            do {
                guard let storeId = cartManager.store?.id else {
                    couponError = "Could not apply promo code. Try again."
                    isApplyingCoupon = false
                    return
                }
                let result = try await PromoCodeRepository.shared.checkCode(code, subtotal: pricing.subtotal, storeId: storeId)
                if result.valid, let discount = result.discount {
                    validatedDiscount = discount
                    couponApplied = true
                } else {
                    couponError = result.message ?? "Invalid or expired promo code."
                }
            } catch {
                couponError = "Could not apply promo code. Try again."
            }
            isApplyingCoupon = false
        }
    }

    // MARK: - Place Order
    func placeOrder() {
        guard isFormValid else {
            errorMessage = orderType == .delivery
                ? "Please select a delivery address and time slot."
                : "Please fill in your details and select a pickup time slot."
            return
        }
        guard let store = cartManager.store else { return }

        errorMessage = nil
        isPlacingOrder = true

        // Points for this order, from the items (price rounded to the
        // nearest $1, x quantity). Captured now — the cart is cleared
        // once the order is placed, so it can't be recomputed later.
        pendingEarnedPoints = cartManager.items.reduce(0) { total, item in
            total + PointsManager.points(forPrice: item.product.displayPrice, quantity: item.count)
        }

        // The items and store for the sales log. Captured now for the
        // same reason — the cart is cleared once the order is placed.
        pendingLogItems = cartManager.items
        pendingLogStore = store

        let orderItems = cartManager.items.map { item in
            OrderRequest.OrderItemRequest(
                productId: item.product.id,
                productName: item.product.name,
                productImage: item.product.imageUrl,
                quantity: item.count,
                priceAtPurchase: item.product.displayPrice
            )
        }

        let request: OrderRequest

        if orderType == .delivery {
            guard let slot = selectedSlot else {
                errorMessage = "Please select a delivery time slot."
                isPlacingOrder = false
                return
            }
            let deliveryDate = Self.orderDateFormatter.string(from: selectedDate)
            let cityDisplay = city.isEmpty ? LocationState.shared.cityName : city

            request = OrderRequest(
                orderType: OrderType.delivery.rawValue,
                storeId: store.id,
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                phone: phone.trimmingCharacters(in: .whitespaces),
                address: address.trimmingCharacters(in: .whitespaces),
                city: cityDisplay,
                province: province,
                postalCode: postalCode.trimmingCharacters(in: .whitespaces).uppercased(),
                deliveryNotes: deliveryNotes.isEmpty ? nil : deliveryNotes,
                preferredDeliveryDate: deliveryDate,
                preferredDeliveryTimeSlot: slot.rawValue,
                preferredPickupDate: nil,
                preferredPickupTimeSlot: nil,
                subtotal: pricing.subtotal,
                tax: pricing.tax,
                shippingCost: effectiveShippingCost,
                serviceFee: pricing.serviceFee,
                discount: validatedDiscount + pointsDiscount + scratchCardDiscount,
                tipAmount: tipAmount,
                total: totalWithTip,
                couponCode: couponApplied ? couponCode.trimmingCharacters(in: .whitespaces) : nil,
                paymentMethod: paymentMethod.rawValue,
                bundleIds: [],
                items: orderItems
            )
        } else {
            let pickupDate = Self.orderDateFormatter.string(from: selectedPickupDate)

            request = OrderRequest(
                orderType: OrderType.pickup.rawValue,
                storeId: store.id,
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                phone: phone.trimmingCharacters(in: .whitespaces),
                address: nil,
                city: nil,
                province: nil,
                postalCode: nil,
                deliveryNotes: nil,
                preferredDeliveryDate: nil,
                preferredDeliveryTimeSlot: nil,
                preferredPickupDate: pickupDate,
                preferredPickupTimeSlot: selectedPickupSlot?.rawValue,
                subtotal: pricing.subtotal,
                tax: pricing.tax,
                shippingCost: 0,
                serviceFee: 0,
                discount: validatedDiscount + pointsDiscount + scratchCardDiscount,
                tipAmount: 0,
                total: totalWithTip,
                couponCode: couponApplied ? couponCode.trimmingCharacters(in: .whitespaces) : nil,
                paymentMethod: paymentMethod.rawValue,
                bundleIds: [],
                items: orderItems
            )
        }

        Task {
            do {
                let result = try await repository.placeOrder(request)
                cartManager.clear()
                isPlacingOrder = false
                if paymentMethod == .cash {
                    // Cash (pickup only): there is no card payment to take,
                    // so the order is placed — settle rewards and show the
                    // confirmation straight away instead of the card screen.
                    // Record the sale FIRST, before settling points and
                    // marking the scratch card used: those change the
                    // points/scratch discounts to $0, and the log must
                    // capture the amounts actually charged.
                    if let logStore = pendingLogStore {
                        SalesLogManager.shared.recordOrder(
                            orderId: result.id,
                            trackingId: result.trackingId,
                            store: logStore,
                            items: pendingLogItems,
                            orderType: orderType.rawValue,
                            paymentMethod: paymentMethod.rawValue,
                            subtotal: pricing.subtotal,
                            tax: pricing.tax,
                            deliveryCharge: orderType == .delivery ? effectiveShippingCost : 0,
                            tip: orderType == .delivery ? tipAmount : 0,
                            discount: validatedDiscount + pointsDiscount + scratchCardDiscount,
                            total: totalWithTip
                        )
                    }
                    PointsManager.shared.settleOrder(earnedPoints: pendingEarnedPoints, redeemed: usePointsReward, orderLabel: "Order \(result.trackingId)")
                    if let usedCard = selectedScratchCard {
                        ScratchCardManager.shared.markUsed(usedCard)
                    }
                    earnedScratchCard = ScratchCardManager.shared.generateAfterOrder(orderLabel: "Order \(result.trackingId)")
                    placedOrder = result
                } else {
                    pendingPaymentOrder = result
                }
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
                isPlacingOrder = false
            } catch {
                errorMessage = "Something went wrong. Please try again."
                isPlacingOrder = false
            }
        }
    }
}
