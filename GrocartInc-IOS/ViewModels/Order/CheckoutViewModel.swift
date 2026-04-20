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

    // MARK: - Schedule
    @Published var selectedDate: Date = Date()
    @Published var selectedSlot: DeliveryTimeSlot? = nil

    // MARK: - Tip & Payment
    @Published var tipAmount: Double = 0
    @Published var paymentMethod: String = "STRIPE"

    // MARK: - State
    @Published var isPlacingOrder = false
    @Published var errorMessage: String? = nil
    @Published var placedOrder: OrderResponse? = nil
    @Published var pendingPaymentOrder: OrderResponse? = nil

    // MARK: - Dependencies
    let pricing: CartPricingResponse
    private let cartManager = CartManager.shared
    private let repository = OrderRepository.shared
    private let addressRepo = AddressRepository.shared

    // MARK: - Computed
    var totalWithTip: Double { pricing.total + tipAmount }
    var formattedTotal: String { String(format: "$%.2f", totalWithTip) }

    var availableDates: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    }

    var isFormValid: Bool {
        selectedAddress != nil && selectedSlot != nil
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
        // Preserve user email from session
        if email.isEmpty {
            email = SessionManager.shared.currentUser?.email ?? ""
        }
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

    // MARK: - Place Order
    func placeOrder() {
        guard isFormValid, let slot = selectedSlot else {
            errorMessage = "Please select a delivery address and time slot."
            return
        }
        guard let store = cartManager.store else { return }

        errorMessage = nil
        isPlacingOrder = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let deliveryDate = dateFormatter.string(from: selectedDate)

        let orderItems = cartManager.items.map { item in
            OrderRequest.OrderItemRequest(
                productId: item.product.id,
                productName: item.product.name,
                productImage: item.product.imageUrl,
                quantity: item.count,
                priceAtPurchase: item.product.displayPrice
            )
        }

        let cityDisplay = city.isEmpty ? LocationState.shared.cityName : city

        let request = OrderRequest(
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
            subtotal: pricing.subtotal,
            tax: pricing.tax,
            shippingCost: pricing.shippingCost,
            serviceFee: pricing.serviceFee,
            discount: pricing.discount,
            tipAmount: tipAmount,
            total: totalWithTip,
            couponCode: nil,
            paymentMethod: paymentMethod,
            preferredDeliveryDate: deliveryDate,
            preferredDeliveryTimeSlot: slot.rawValue,
            bundleIds: [],
            items: orderItems
        )

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
