//
//  PaymentViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-16.
//

import Foundation
import Combine

// Emitted when Stripe requires 3DS authentication
struct PaymentActionState: Identifiable, Equatable {
    let id = UUID()
    let clientSecret: String
    let paymentIntentId: String
    let orderId: Int
}

@MainActor
final class PaymentViewModel: ObservableObject {

    // MARK: - State
    @Published var savedCards: [SavedCard] = []
    @Published var selectedCard: SavedCard? = nil
    @Published var isLoadingCards = false
    @Published var isProcessing = false
    @Published var errorMessage: String? = nil
    @Published var requiresAction: PaymentActionState? = nil
    @Published var paymentComplete = false

    // MARK: - Dependencies
    let order: OrderResponse
    var onPaymentSuccess: ((OrderResponse) -> Void)?
    private let repository = PaymentRepository.shared

    init(order: OrderResponse) {
        self.order = order
    }

    // MARK: - Load Saved Cards
    func loadCards() {
        Task {
            isLoadingCards = true
            errorMessage = nil
            do {
                savedCards = try await repository.getSavedCards()
                selectedCard = savedCards.first(where: { $0.isDefault }) ?? savedCards.first
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Failed to load saved cards."
            }
            isLoadingCards = false
        }
    }

    // MARK: - Charge Selected Saved Card
    func chargeCard() {
        guard let card = selectedCard else { return }
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let response = try await repository.chargeCard(ChargeRequest(
                    orderId: order.id,
                    paymentMethodId: card.id
                ))
                handleChargeResponse(response)
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Payment failed. Please try again."
            }
            isProcessing = false
        }
    }

    // MARK: - Attach New Card Then Charge (called from AddCardView after Stripe SDK confirms setup intent)
    func attachAndCharge(paymentMethodId: String) {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                _ = try await repository.attachCard(AttachCardRequest(
                    paymentMethodId: paymentMethodId,
                    setAsDefault: savedCards.isEmpty
                ))
                let chargeResponse = try await repository.chargeCard(ChargeRequest(
                    orderId: order.id,
                    paymentMethodId: paymentMethodId
                ))
                handleChargeResponse(chargeResponse)
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Payment failed. Please try again."
            }
            isProcessing = false
        }
    }

    // MARK: - Confirm After 3DS (called after STPPaymentHandler.handleNextAction succeeds)
    func confirmAfterAction(paymentIntentId: String, orderId: Int) {
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let response = try await repository.confirmPayment(ConfirmPaymentRequest(
                    paymentIntentId: paymentIntentId,
                    orderId: orderId
                ))
                if response.success {
                    onPaymentSuccess?(order)
                    paymentComplete = true
                } else {
                    errorMessage = "Payment confirmation failed. Please contact support."
                }
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Failed to confirm payment."
            }
            isProcessing = false
        }
    }

    // MARK: - Delete Saved Card
    func deleteCard(_ card: SavedCard) {
        Task {
            do {
                try await repository.deleteCard(card.id)
                savedCards.removeAll { $0.id == card.id }
                if selectedCard?.id == card.id {
                    selectedCard = savedCards.first
                }
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "Failed to remove card."
            }
        }
    }

    // MARK: - Private
    private func handleChargeResponse(_ response: ChargeResponse) {
        if response.requiresAction, let secret = response.clientSecret {
            requiresAction = PaymentActionState(
                clientSecret: secret,
                paymentIntentId: response.paymentIntentId,
                orderId: order.id
            )
        } else if response.success {
            onPaymentSuccess?(order)
            paymentComplete = true
        } else {
            errorMessage = response.message
        }
    }
}
