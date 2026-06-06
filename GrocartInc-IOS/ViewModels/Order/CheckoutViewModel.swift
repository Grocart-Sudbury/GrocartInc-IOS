//
//  CheckoutViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
import Combine

@MainActor
final class CheckoutViewModel: ObservableObject {

    // MARK: - Order Type
    @Published var orderType: OrderType = .delivery

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
    @Published var paymentMethod: String = "STRIPE"

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

    // MARK: - Uber Delivery Quote
    @Published var deliveryQuote: UberDeliveryQuoteResponse? = nil
    @Published var isLoadingDeliveryQuote = false

    // MARK: - Dependencies
    @Published var pricing: CartPricingResponse
    private let cartManager = CartManager.shared
    private let repository = OrderRepository.shared
    private let addressRepo = AddressRepository.shared
    private let uberRepo = UberRepository.shared

    // MARK: - Computed
    var effectiveShippingCost: Double {
        guard orderType == .delivery else { return 0 }
        if let quote = deliveryQuote, quote.deliveryPossible {
            return Double(quote.deliveryFeeCents) / 100.0
        }
        return pricing.shippingCost
    }

    var formattedEffectiveShipping: String {
        guard orderType == .delivery else { return "Free" }
        if isLoadingDeliveryQuote { return "Calculating..." }
        if let quote = deliveryQuote {
            return quote.deliveryPossible ? (quote.deliveryFeeFormatted ?? pricing.formattedShipping) : "Unavailable"
        }
        return pricing.formattedShipping
    }

    var totalWithTip: Double {
        if orderType == .pickup {
            return pricing.subtotal + pricing.tax - validatedDiscount
        }
        return pricing.subtotal + pricing.tax + effectiveShippingCost + pricing.serviceFee - validatedDiscount + tipAmount
    }
    var formattedTotal: String { String(format: "$%.2f", totalWithTip) }

    var availableDates: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    }

    var requiresUberCheck: Bool {
        cartManager.store?.id == 4 && !isSundayDelivery
    }

    private var isSundayDelivery: Bool {
        Calendar.current.component(.weekday, from: selectedDate) == 1
    }

    static let minimumOrderAmount: Double = 20.0

    var isBelowMinimum: Bool { pricing.subtotal < CheckoutViewModel.minimumOrderAmount }

    var isFormValid: Bool {
        guard !isBelowMinimum else { return false }
        switch orderType {
        case .delivery:
            let quoteOk = !requiresUberCheck || (deliveryQuote?.deliveryPossible == true)
            return selectedAddress != nil && selectedSlot != nil && !availableSlots.isEmpty && quoteOk
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
        Task { await fetchDeliveryQuote(for: a) }
    }

    func fetchDeliveryQuote(for addr: CustomerAddress? = nil) async {
        let target = addr ?? selectedAddress
        guard let a = target, orderType == .delivery else { return }

        // Only check for store 4; other stores are always deliverable
        guard cartManager.store?.id == 4 else {
            deliveryQuote = nil
            return
        }

        // Sundays: delivery available everywhere in Winnipeg — skip API call
        if isSundayDelivery {
            deliveryQuote = nil
            return
        }

        let dropoff = "\(a.address), \(a.city), \(a.province) \(a.postalCode), CA"
        isLoadingDeliveryQuote = true
        deliveryQuote = nil
        do {
            let quote = try await uberRepo.fetchDeliveryQuote(dropoffAddress: dropoff)
            deliveryQuote = quote
        } catch {
            deliveryQuote = nil
        }
        isLoadingDeliveryQuote = false
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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayOfWeek = formatter.string(from: selectedDate).uppercased()

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
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let deliveryDate = dateFormatter.string(from: selectedDate)
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
                discount: validatedDiscount,
                tipAmount: tipAmount,
                total: totalWithTip,
                couponCode: couponApplied ? couponCode.trimmingCharacters(in: .whitespaces) : nil,
                paymentMethod: paymentMethod,
                bundleIds: [],
                items: orderItems
            )
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let pickupDate = dateFormatter.string(from: selectedPickupDate)

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
                discount: validatedDiscount,
                tipAmount: 0,
                total: pricing.subtotal + pricing.tax - validatedDiscount,
                couponCode: couponApplied ? couponCode.trimmingCharacters(in: .whitespaces) : nil,
                paymentMethod: paymentMethod,
                bundleIds: [],
                items: orderItems
            )
        }

        Task {
            do {
                let result = try await repository.placeOrder(request)
                cartManager.clear()
                isPlacingOrder = false
                pendingPaymentOrder = result
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
