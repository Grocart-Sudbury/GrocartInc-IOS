//
//  PaymentViewModel.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-16.
//

import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "PaymentViewModel")

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
    @Published var savedCards: [SavedCard] = [] {
        didSet { logger.debug("📋 savedCards changed → count=\(self.savedCards.count)") }
    }
    @Published var selectedCard: SavedCard? = nil {
        didSet { logger.debug("💳 selectedCard changed → \(self.selectedCard?.id ?? "nil")") }
    }
    @Published var isLoadingCards = false {
        didSet { logger.debug("⏳ isLoadingCards → \(self.isLoadingCards)") }
    }
    @Published var isProcessing = false {
        didSet { logger.debug("⚙️ isProcessing → \(self.isProcessing)") }
    }
    @Published var errorMessage: String? = nil {
        didSet { logger.debug("❌ errorMessage → \(self.errorMessage ?? "nil")") }
    }
    @Published var requiresAction: PaymentActionState? = nil {
        didSet { logger.debug("🔐 requiresAction → \(self.requiresAction == nil ? "nil" : "SET id=\(self.requiresAction!.paymentIntentId)")") }
    }
    @Published var paymentComplete = false {
        didSet { logger.debug("✅ paymentComplete → \(self.paymentComplete)") }
    }

    // MARK: - Dependencies
    let order: OrderResponse
    private let repository = PaymentRepository.shared

    init(order: OrderResponse) {
        self.order = order
        logger.info("🆕 PaymentViewModel init — orderId=\(order.id) total=\(order.formattedTotal)")
    }

    // MARK: - Load Saved Cards
    func loadCards() {
        logger.info("▶️ loadCards() called")
        Task {
            isLoadingCards = true
            errorMessage = nil
            do {
                let cards = try await repository.getSavedCards()
                logger.info("✅ loadCards() success — \(cards.count) card(s)")
                savedCards = cards
                selectedCard = savedCards.first(where: { $0.isDefault }) ?? savedCards.first
                logger.info("💳 auto-selected card → \(self.selectedCard?.id ?? "none")")
            } catch let error as NetworkError {
                logger.error("❌ loadCards() NetworkError: \(error.errorDescription ?? "unknown")")
                errorMessage = error.errorDescription
            } catch {
                logger.error("❌ loadCards() unknown error: \(error)")
                errorMessage = "Failed to load saved cards."
            }
            isLoadingCards = false
        }
    }

    // MARK: - Charge Selected Saved Card
    func chargeCard() {
        guard let card = selectedCard else {
            logger.warning("⚠️ chargeCard() called but no selectedCard")
            return
        }
        logger.info("▶️ chargeCard() — orderId=\(self.order.id) pmId=\(card.id)")
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let response = try await repository.chargeCard(ChargeRequest(
                    orderId: order.id,
                    paymentMethodId: card.id
                ))
                logger.info("✅ chargeCard() response — success=\(response.success) requiresAction=\(response.requiresAction.map(String.init) ?? "nil") status=\(response.status)")
                handleChargeResponse(response)
            } catch let error as NetworkError {
                logger.error("❌ chargeCard() NetworkError: \(error.errorDescription ?? "unknown")")
                errorMessage = error.errorDescription
            } catch {
                logger.error("❌ chargeCard() unknown error: \(error)")
                errorMessage = "Payment failed. Please try again."
            }
            isProcessing = false
        }
    }

    // MARK: - Attach New Card Then Charge
    func attachAndCharge(paymentMethodId: String) {
        logger.info("▶️ attachAndCharge() — orderId=\(self.order.id) pmId=\(paymentMethodId)")
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                logger.info("  → attaching card pmId=\(paymentMethodId)")
                _ = try await repository.attachCard(AttachCardRequest(
                    paymentMethodId: paymentMethodId,
                    setAsDefault: savedCards.isEmpty
                ))
                logger.info("  → attach success, charging order \(self.order.id)")
                let chargeResponse = try await repository.chargeCard(ChargeRequest(
                    orderId: order.id,
                    paymentMethodId: paymentMethodId
                ))
                logger.info("✅ attachAndCharge() charge response — success=\(chargeResponse.success) requiresAction=\(chargeResponse.requiresAction.map(String.init) ?? "nil")")
                handleChargeResponse(chargeResponse)
            } catch let error as NetworkError {
                logger.error("❌ attachAndCharge() NetworkError: \(error.errorDescription ?? "unknown")")
                errorMessage = error.errorDescription
            } catch {
                logger.error("❌ attachAndCharge() unknown error: \(error)")
                errorMessage = "Payment failed. Please try again."
            }
            isProcessing = false
        }
    }

    // MARK: - Confirm After 3DS
    func confirmAfterAction(paymentIntentId: String, orderId: Int) {
        logger.info("▶️ confirmAfterAction() — piId=\(paymentIntentId) orderId=\(orderId)")
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let response = try await repository.confirmPayment(ConfirmPaymentRequest(
                    paymentIntentId: paymentIntentId,
                    orderId: orderId
                ))
                logger.info("✅ confirmAfterAction() response — success=\(response.success) status=\(response.status)")
                if response.success {
                    logger.info("  → 3DS confirm success, setting paymentComplete")
                    paymentComplete = true
                } else {
                    logger.warning("  → server returned success=false")
                    errorMessage = "Payment confirmation failed. Please contact support."
                }
            } catch let error as NetworkError {
                logger.error("❌ confirmAfterAction() NetworkError: \(error.errorDescription ?? "unknown")")
                errorMessage = error.errorDescription
            } catch {
                logger.error("❌ confirmAfterAction() unknown error: \(error)")
                errorMessage = "Failed to confirm payment."
            }
            isProcessing = false
        }
    }

    // MARK: - Delete Saved Card
    func deleteCard(_ card: SavedCard) {
        logger.info("▶️ deleteCard() — pmId=\(card.id)")
        Task {
            do {
                try await repository.deleteCard(card.id)
                logger.info("✅ deleteCard() success")
                savedCards.removeAll { $0.id == card.id }
                if selectedCard?.id == card.id {
                    selectedCard = savedCards.first
                    logger.info("  → deselected deleted card, new selection: \(self.selectedCard?.id ?? "none")")
                }
            } catch let error as NetworkError {
                logger.error("❌ deleteCard() NetworkError: \(error.errorDescription ?? "unknown")")
                errorMessage = error.errorDescription
            } catch {
                logger.error("❌ deleteCard() unknown error: \(error)")
                errorMessage = "Failed to remove card."
            }
        }
    }

    // MARK: - Private
    private func handleChargeResponse(_ response: ChargeResponse) {
        logger.info("🔀 handleChargeResponse() — success=\(response.success) requiresAction=\(response.requiresAction.map(String.init) ?? "nil") message='\(response.message)'")
        if response.requiresAction == true, let secret = response.clientSecret {
            logger.info("  → 3DS required, setting requiresAction")
            requiresAction = PaymentActionState(
                clientSecret: secret,
                paymentIntentId: response.paymentIntentId,
                orderId: order.id
            )
        } else if response.success {
            logger.info("  → payment succeeded directly, setting paymentComplete")
            paymentComplete = true
        } else {
            logger.warning("  → charge not successful: \(response.message)")
            errorMessage = response.message
        }
    }

}
