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

    // MARK: - Delivery Info
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
    @Published var paymentMethod: String = "CASH"

    // MARK: - State
    @Published var isPlacingOrder = false
    @Published var errorMessage: String? = nil
    @Published var placedOrder: OrderResponse? = nil

    // MARK: - Dependencies
    let pricing: CartPricingResponse
    private let cartManager = CartManager.shared
    private let repository = OrderRepository.shared

    // MARK: - Computed
    var totalWithTip: Double { pricing.total + tipAmount }
    var formattedTotal: String { String(format: "$%.2f", totalWithTip) }

    var availableDates: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    }

    var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty &&
        !phone.isEmpty && !address.isEmpty && !city.isEmpty &&
        !postalCode.isEmpty && selectedSlot != nil
    }

    // MARK: - Init
    init(pricing: CartPricingResponse) {
        self.pricing = pricing
        prefill()
    }

    private func prefill() {
        let user = SessionManager.shared.currentUser
        firstName  = user?.firstName ?? ""
        lastName   = user?.lastName  ?? ""
        email      = user?.email     ?? ""
        city       = LocationState.shared.cityName
            .replacingOccurrences(of: "Greater ", with: "")  // keep full name for display
    }

    // MARK: - Place Order
    func placeOrder() {
        guard isFormValid, let slot = selectedSlot else {
            errorMessage = "Please fill in all required fields and select a delivery time."
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
                placedOrder = result
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Something went wrong. Please try again."
            }
            isPlacingOrder = false
        }
    }
}
