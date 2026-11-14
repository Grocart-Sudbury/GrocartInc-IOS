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
        didSet {
            if let action = requiresAction {
                logger.debug("🔐 requiresAction → SET id=\(action.paymentIntentId)")
            } else {
                logger.debug("🔐 requiresAction → nil")
            }
        }
    }
    @Published var paymentComplete = false {
        didSet { logger.debug("✅ paymentComplete → \(self.paymentComplete)") }
    }

    // MARK: - Dependencies
    let order: OrderResponse
    /// True when the order was placed through the staging points API —
    /// the charge and 3DS confirm then go to staging too.
    let isStagingOrder: Bool
    private let repository = PaymentRepository.shared

    init(order: OrderResponse, isStagingOrder: Bool = false) {
        self.order = order
        self.isStagingOrder = isStagingOrder
        logger.info("🆕 PaymentViewModel init — orderId=\(order.id) total=\(order.formattedTotal) staging=\(isStagingOrder)")
    }

    // MARK: - Load Saved Cards
    func loadCards() {
        loadCards(preserving: nil)
    }

    /// Reloads the saved cards. When `selection` is given and that card is in
    /// the fetched list, it stays selected (used after adding a card so the
    /// new card is selected even when it is not the default). Otherwise the
    /// default card, or the first card, is selected as before.
    func loadCards(preserving selection: SavedCard? = nil) {
        logger.info("▶️ loadCards() called")
        Task {
            isLoadingCards = true
            errorMessage = nil
            do {
                let cards = try await repository.getSavedCards()
                logger.info("✅ loadCards() success — \(cards.count) card(s)")
                savedCards = cards
                if let selection = selection, let kept = savedCards.first(where: { $0.id == selection.id }) {
                    selectedCard = kept
                    logger.info("💳 kept selected card → \(self.selectedCard?.id ?? "none")")
                } else {
                    selectedCard = savedCards.first(where: { $0.isDefault }) ?? savedCards.first
                    logger.info("💳 auto-selected card → \(self.selectedCard?.id ?? "none")")
                }
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
                ), url: isStagingOrder ? APIConfig.Points.charge : APIConfig.Payment.charge)
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
                ), url: isStagingOrder ? APIConfig.Points.confirm : APIConfig.Payment.confirm)
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
