//
//  PaymentView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-16.
//

import SwiftUI
import StripePayments
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "PaymentView")

struct PaymentView: View {
    @StateObject private var viewModel: PaymentViewModel
    @State private var showAddCard = false
    private let onPaymentSuccess: (OrderResponse) -> Void

    init(order: OrderResponse, isStagingOrder: Bool = false, onPaymentSuccess: @escaping (OrderResponse) -> Void) {
        self.onPaymentSuccess = onPaymentSuccess
        _viewModel = StateObject(wrappedValue: PaymentViewModel(order: order, isStagingOrder: isStagingOrder))
    }

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    orderAmountHeader
                    savedCardsSection
                    Spacer().frame(height: 90)
                }
                .padding(.top, 8)
            }

            // Error banner
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
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { payButton }
        .onAppear {
            logger.info("👁️ PaymentView appeared — orderId=\(viewModel.order.id)")
            viewModel.loadCards()
        }
        .onDisappear {
            logger.info("👻 PaymentView disappeared — paymentComplete=\(viewModel.paymentComplete) isProcessing=\(viewModel.isProcessing)")
        }
        .onChange(of: showAddCard) { val in
            logger.info("📋 showAddCard → \(val)")
        }
        .onChange(of: viewModel.paymentComplete) { val in
            logger.info("✅ paymentComplete onChange → \(val)")
            if val { onPaymentSuccess(viewModel.order) }
        }
        .onChange(of: viewModel.requiresAction) { val in
            logger.info("🔐 requiresAction onChange → \(val == nil ? "nil" : "SET")")
        }
        .sheet(isPresented: $showAddCard, onDismiss: {
            logger.info("📋 PaymentSheet add-card sheet dismissed")
        }) {
            StandaloneAddCardView(setAsDefault: viewModel.savedCards.isEmpty) { newCard in
                viewModel.loadCards(preserving: newCard)
            }
        }
        .sheet(item: $viewModel.requiresAction, onDismiss: {
            logger.info("🔐 ThreeDSHandlerView sheet dismissed")
        }) { action in
            ThreeDSHandlerView(action: action, viewModel: viewModel)
        }
    }

    // MARK: - Order Amount Header
    private var orderAmountHeader: some View {
        VStack(spacing: 6) {
            Text("Order Total")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.grocartSecondary)
            Text(viewModel.order.formattedTotal)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.grocartPrimary)
            Text("Ref: \(viewModel.order.trackingId)")
                .font(.system(size: 12))
                .foregroundColor(.grocartSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.grocartSecondaryBackground.opacity(0.6))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Saved Cards Section
    private var savedCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.grocartGreen)
                    .frame(width: 24)
                Text("Saved Cards")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.grocartPrimary)
                Spacer()
                if viewModel.isLoadingCards {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 2)

            if !viewModel.isLoadingCards && viewModel.savedCards.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 32))
                        .foregroundColor(.grocartSecondary.opacity(0.4))
                    Text("No saved cards yet")
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .background(Color.grocartSecondaryBackground.opacity(0.6))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }

            ForEach(viewModel.savedCards) { card in
                cardRow(card)
            }

            addNewCardButton
        }
        .padding(.vertical, 4)
    }

    private func cardRow(_ card: SavedCard) -> some View {
        let isSelected = viewModel.selectedCard?.id == card.id
        return HStack(spacing: 14) {
            // Card brand icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.grocartGreen.opacity(0.12) : Color.grocartSecondaryBackground)
                    .frame(width: 46, height: 32)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? .grocartGreen : .grocartSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(card.displayBrand)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.grocartPrimary)
                    if card.isDefault {
                        Text("Default")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.grocartGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.grocartGreen.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                Text("•••• \(card.last4)")
                    .font(.system(size: 13))
                    .foregroundColor(.grocartSecondary)
            }

            Spacer()

            Text(card.formattedExpiry)
                .font(.system(size: 12))
                .foregroundColor(.grocartSecondary)

            // Selection indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.grocartGreen : Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(Color.grocartGreen)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(14)
        .background(isSelected ? Color.grocartGreen.opacity(0.05) : Color.grocartSecondaryBackground.opacity(0.6))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.grocartGreen.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectedCard = card }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteCard(card)
            } label: {
                Label("Remove Card", systemImage: "trash")
            }
        }
    }

    private var addNewCardButton: some View {
        Button(action: { showAddCard = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.grocartGreen.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                }
                Text("Add New Card")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.grocartGreen)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.grocartSecondary)
            }
            .padding(14)
            .background(Color.grocartSecondaryBackground.opacity(0.6))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(Color.grocartGreen.opacity(0.25), lineWidth: 1))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Pay Button
    private var payButton: some View {
        Button(action: { viewModel.chargeCard() }) {
            HStack {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else {
                    Text("Pay \(viewModel.order.formattedTotal)")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(viewModel.selectedCard != nil && !viewModel.isProcessing
                        ? Color.grocartGreen
                        : Color.grocartGreen.opacity(0.4))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .disabled(viewModel.selectedCard == nil || viewModel.isProcessing)
        .background(Color.grocartBackground)
    }
}

// MARK: - 3DS Handler View
/// Handles Stripe's next-action flow (3D Secure) in a full-screen cover.
struct ThreeDSHandlerView: View {
    let action: PaymentActionState
    @ObservedObject var viewModel: PaymentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isHandling = true
    @State private var handlingError: String? = nil

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                if isHandling {
                    ProgressView().scaleEffect(1.4)
                    Text("Completing authentication…")
                        .font(.system(size: 15))
                        .foregroundColor(.grocartSecondary)
                } else if let error = handlingError {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.red)
                    Text("Authentication Failed")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Try Again") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.grocartGreen)
                        .padding(.top, 8)
                }
            }
        }
        .onAppear { handle3DS() }
        .onChange(of: viewModel.paymentComplete) { complete in
            if complete { dismiss() }
        }
    }

    private func handle3DS() {
        STPPaymentHandler.shared().handleNextAction(
            paymentIntentClientSecret: action.clientSecret,
            authenticationContext: TopViewControllerAuthContext(),
            returnURL: nil
        ) { status, _, error in
            Task { @MainActor in
                isHandling = false
                switch status {
                case .succeeded:
                    viewModel.confirmAfterAction(
                        paymentIntentId: action.paymentIntentId,
                        orderId: action.orderId
                    )
                case .failed:
                    handlingError = error?.localizedDescription ?? "3D Secure authentication failed."
                case .canceled:
                    dismiss()
                @unknown default:
                    handlingError = "An unknown error occurred during authentication."
                }
            }
        }
    }
}

// MARK: - Auth Context for STPPaymentHandler (3DS & Setup Intent confirmation)

/// Provides the top-most UIViewController to Stripe for presenting authentication screens.
final class TopViewControllerAuthContext: NSObject, STPAuthenticationContext {
    func authenticationPresentingViewController() -> UIViewController {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return UIViewController() }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
