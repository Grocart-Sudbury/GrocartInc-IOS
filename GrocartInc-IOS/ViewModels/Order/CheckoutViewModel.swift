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

    // MARK: - Rewards Points (server-driven)
    /// Points the customer wants to redeem on this order. 0 = none.
    @Published var pointsToRedeem: Int = 0
    /// The points amount typed in the rewards field.
    @Published var pointsInput: String = ""
    @Published var isApplyingPoints = false
    /// The server's own message about the points on this quote
    /// (e.g. why a redemption was rejected). Shown verbatim.
    @Published var pointsMessage: String? = nil
    /// Whether this order is placed through the staging points API
    /// (true when points are applied). Threaded to the payment step.
    @Published var placedOrderIsStaging = false

    /// Whether points are applied to this order.
    var pointsApplied: Bool { pointsToRedeem > 0 }

    /// The most points this order can take: the whole balance. Above the
    /// 100-point minimum a customer may redeem any amount up to what they
    /// have; the server only spends what the order needs and the rest
    /// stays banked.
    var maxRedeemablePoints: Int {
        PointsManager.shared.points
    }

    /// Points can be redeemed when the balance meets the server's
    /// minimum (100 points). There is no minimum order.
    var canRedeemPoints: Bool {
        maxRedeemablePoints >= PointsManager.shared.rules.minRedeemPoints
    }

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
    /// The dollar value of the points on this quote, as the server
    /// priced it. It is ALREADY included in pricing.discount and
    /// pricing.total — display only, never subtracted again.
    var pointsDiscount: Double { pricing.pointsDiscount }

    var totalWithTip: Double {
        // pricing.total / pricing.discount already hold the coupon and
        // points discounts the server applied (refreshPricing always
        // sends both), so they are never subtracted again here — only
        // the on-device scratch card discount is applied on top.
        if orderType == .pickup {
            return pricing.subtotal + pricing.tax - pricing.discount - scratchCardDiscount
        }
        return effectiveDeliveryTotal - scratchCardDiscount + tipAmount
    }
    var formattedTotal: String { String(format: "$%.2f", totalWithTip) }

    /// The discount from the scratch card applied to this order.
    /// Capped so the total never goes below $0.
    var scratchCardDiscount: Double {
        guard let card = selectedScratchCard, card.isUsable else { return 0 }
        let raw = ScratchCardManager.discount(for: card, subtotal: pricing.subtotal)
        // pricing.discount already nets the coupon + points discounts,
        // so the remaining payable base needs no further subtraction.
        let base: Double
        if orderType == .pickup {
            base = pricing.subtotal + pricing.tax - pricing.discount
        } else {
            base = effectiveDeliveryTotal + tipAmount
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

    // MARK: - Rewards Points

    /// Applies the points amount typed in the rewards field. Validates
    /// against the server rules first, then re-prices the cart on the
    /// staging points endpoint — the server is the source of truth
    /// for whether the redemption applies.
    func applyPoints() {
        let amount = Int(pointsInput.trimmingCharacters(in: .whitespaces)) ?? 0
        pointsMessage = nil
        let manager = PointsManager.shared
        let rules = manager.rules
        guard amount > 0 else {
            pointsMessage = "Enter how many points to use."
            return
        }
        guard amount <= manager.points else {
            pointsMessage = "You only have \(manager.points) points available."
            return
        }
        guard amount >= rules.minRedeemPoints else {
            pointsMessage = "The minimum redemption is \(rules.minRedeemPoints) points."
            return
        }
        pointsToRedeem = amount
        // Points stack with coupons and scratch cards: the coupon
        // discount applies first and points cover the remaining
        // subtotal (server-side). Nothing is cleared here.
        Task { await refreshPricing() }
    }

    /// Removes points from this order and re-prices the cart.
    /// Coupons and scratch cards stay applied.
    func clearPoints() {
        guard pointsApplied else {
            pointsToRedeem = 0
            pointsInput = ""
            pointsMessage = nil
            return
        }
        pointsToRedeem = 0
        pointsInput = ""
        pointsMessage = nil
        Task { await refreshPricing() }
    }

    /// Fills in the largest amount this order can take and applies it.
    func useMaxPoints() {
        pointsInput = "\(maxRedeemablePoints)"
        applyPoints()
    }

    /// Re-prices the cart. The request always carries both the coupon
    /// code and the points (when each is applied) — the coupon discount
    /// applies first and points cover the remaining subtotal, so the
    /// two stack. With points applied the staging points endpoint
    /// prices it; without points the production endpoint prices it.
    /// If the server rejects the redemption it answers 200 with
    /// pointsRedeemed = 0 and a reason in pointsMessage — shown
    /// verbatim, and the points are reset.
    private func refreshPricing() async {
        isApplyingPoints = true
        defer { isApplyingPoints = false }
        do {
            let request = cartManager.pricingRequest(
                couponCode: couponApplied ? couponCode.trimmingCharacters(in: .whitespaces) : nil,
                pointsToRedeem: pointsApplied ? pointsToRedeem : nil
            )
            let url = pointsApplied ? APIConfig.Points.pricing : APIConfig.Cart.pricing
            let response = try await CartRepository.shared.fetchPricing(request: request, url: url)
            pricing = response
            if pointsApplied {
                if let message = response.pointsMessage {
                    // Rejected: the response already carries the plain
                    // totals (pointsDiscount = 0), so nothing needs
                    // re-pricing — just show the reason verbatim.
                    pointsMessage = message
                    pointsToRedeem = 0
                    pointsInput = ""
                } else if response.pointsRedeemed > 0 {
                    pointsMessage = nil
                    // Trust the server's applied amount.
                    pointsToRedeem = response.pointsRedeemed
                    pointsInput = "\(response.pointsRedeemed)"
                } else {
                    pointsMessage = nil
                }
            } else {
                pointsMessage = nil
            }
        } catch {
            pointsMessage = (error as? NetworkError)?.errorDescription ?? "Could not apply points. Please try again."
            if pointsApplied {
                pointsToRedeem = 0
                pointsInput = ""
            }
        }
    }

    /// Toggles a scratch card. Scratch cards stack with points and
    /// coupons — selecting one leaves them applied.
    func selectScratchCard(_ card: ScratchCard) {
        if selectedScratchCard?.id == card.id {
            selectedScratchCard = nil
        } else {
            selectedScratchCard = card
        }
    }

    // MARK: - Promo Code
    func applyCoupon() {
        // Coupons stack with points and scratch cards — nothing is cleared.
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
                    // Price the coupon in on the server so the totals
                    // (and the points cap) include it.
                    await refreshPricing()
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

        // Points orders go through the staging points API; everything
        // else stays on production. Captured now — the points fields
        // stay editable while the order is placed.
        let stagingOrder = pointsApplied
        placedOrderIsStaging = stagingOrder

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
                // The discount sent here is the coupon + scratch-card
                // value only. The server adds the points discount itself
                // (and caps it at the remaining subtotal), so sending
                // pointsDiscount here too would count points twice.
                discount: validatedDiscount + scratchCardDiscount,
                tipAmount: tipAmount,
                total: totalWithTip,
                couponCode: couponApplied ? couponCode.trimmingCharacters(in: .whitespaces) : nil,
                pointsToRedeem: stagingOrder ? pointsToRedeem : nil,
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
                // The discount sent here is the coupon + scratch-card
                // value only. The server adds the points discount itself
                // (and caps it at the remaining subtotal), so sending
                // pointsDiscount here too would count points twice.
                discount: validatedDiscount + scratchCardDiscount,
                tipAmount: 0,
                total: totalWithTip,
                couponCode: couponApplied ? couponCode.trimmingCharacters(in: .whitespaces) : nil,
                pointsToRedeem: stagingOrder ? pointsToRedeem : nil,
                paymentMethod: paymentMethod.rawValue,
                bundleIds: [],
                items: orderItems
            )
        }

        Task {
            do {
                let result = try await repository.placeOrder(
                    request,
                    url: stagingOrder ? APIConfig.Points.placeOrder : APIConfig.Orders.place
                )
                cartManager.clear()
                isPlacingOrder = false
                // The balance changed (points were spent, or will be
                // earned on delivery) — refresh it from the server.
                Task { await PointsManager.shared.refresh() }
                if paymentMethod == .cash {
                    // Cash (pickup only): there is no card payment to take,
                    // so the order is placed — show the confirmation
                    // straight away instead of the card screen. Points
                    // are NOT settled here: they land on delivery, and
                    // the server deducts redeemed points at placement.
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
