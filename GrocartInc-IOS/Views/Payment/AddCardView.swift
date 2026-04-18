//
//  AddCardView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-16.
//

import SwiftUI
import StripePayments
import StripePaymentsUI

/// Presents a Stripe card input field, confirms the setup intent, and then triggers
/// attach + charge via PaymentViewModel.
struct AddCardView: View {
    @ObservedObject var viewModel: PaymentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var cardIsValid = false
    @State private var cardParams: STPPaymentMethodCardParams? = nil
    @State private var isConfirmingSetup = false
    @State private var localError: String? = nil

    var isWorking: Bool { isConfirmingSetup || viewModel.isProcessing }

    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Order total summary
                    VStack(spacing: 4) {
                        Text("Total to pay")
                            .font(.system(size: 13))
                            .foregroundColor(.grocartSecondary)
                        Text(viewModel.order.formattedTotal)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.grocartPrimary)
                    }
                    .padding(.top, 8)

                    // Card input card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Card Details")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.grocartSecondary)

                        StripeCardField(isValid: $cardIsValid) { params in
                            cardParams = params
                        }
                        .frame(height: 50)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.grocartBackground)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1))
                    }
                    .padding(16)
                    .background(Color.grocartSecondaryBackground.opacity(0.6))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)

                    // Secured badge
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.grocartSecondary)
                        Text("Secured by Stripe — card details never touch our servers")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                    }

                    // Error message
                    if let error = localError ?? viewModel.errorMessage {
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
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.grocartGreen)
                        .disabled(isWorking)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { payButton }
            .onChange(of: viewModel.paymentComplete) { complete in
                if complete { dismiss() }
            }
            .onChange(of: viewModel.requiresAction) { action in
                // If 3DS is needed, dismiss AddCardView so PaymentView can present ThreeDSHandlerView
                if action != nil { dismiss() }
            }
        }
    }

    // MARK: - Pay Button
    private var payButton: some View {
        Button(action: processNewCard) {
            HStack {
                if isWorking {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text(isConfirmingSetup ? "Verifying card…" : "Processing…")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Text("Pay \(viewModel.order.formattedTotal)")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(cardIsValid && !isWorking ? Color.grocartGreen : Color.grocartGreen.opacity(0.45))
            .cornerRadius(16)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .disabled(!cardIsValid || isWorking)
        .background(Color.grocartBackground)
    }

    // MARK: - New Card Flow
    // Step 1: Get setup intent clientSecret from backend
    // Step 2: Confirm setup intent using Stripe SDK (card tokenized client-side)
    // Step 3: ViewModel attaches the card then charges the order
    private func processNewCard() {
        guard let params = cardParams else { return }
        isConfirmingSetup = true
        localError = nil

        Task {
            do {
                let setupIntent = try await PaymentRepository.shared.createSetupIntent()

                let confirmParams = STPSetupIntentConfirmParams(clientSecret: setupIntent.clientSecret)
                confirmParams.paymentMethodParams = STPPaymentMethodParams(
                    card: params,
                    billingDetails: nil,
                    metadata: nil
                )

                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    STPPaymentHandler.shared().confirmSetupIntent(
                        confirmParams,
                        with: TopViewControllerAuthContext()
                    ) { status, setupIntentResult, error in
                        Task { @MainActor in
                            switch status {
                            case .succeeded:
                                if let paymentMethodId = setupIntentResult?.paymentMethodID {
                                    isConfirmingSetup = false
                                    viewModel.attachAndCharge(paymentMethodId: paymentMethodId)
                                } else {
                                    localError = "Card setup succeeded but no payment method was returned."
                                    isConfirmingSetup = false
                                }
                            case .failed:
                                localError = error?.localizedDescription ?? "Card setup failed. Please try again."
                                isConfirmingSetup = false
                            case .canceled:
                                isConfirmingSetup = false
                            @unknown default:
                                isConfirmingSetup = false
                            }
                            continuation.resume()
                        }
                    }
                }
            } catch let error as NetworkError {
                localError = error.errorDescription
                isConfirmingSetup = false
            } catch {
                localError = "Failed to initialize payment. Please try again."
                isConfirmingSetup = false
            }
        }
    }
}
