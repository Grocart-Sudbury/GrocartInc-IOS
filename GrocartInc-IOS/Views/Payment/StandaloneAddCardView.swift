//
//  StandaloneAddCardView.swift
//  GrocartInc-IOS
//
//  Adds a card to the account without charging anything, using Stripe
//  PaymentSheet — Stripe's own hosted card form. The form shows separate
//  lines for full name, card number, expiry, CVC and postal code, and
//  the card details are tokenized by Stripe on the device: the app never
//  sees or stores raw card numbers. Flow: create a Stripe setup intent,
//  present PaymentSheet, then attach the resulting payment method to the
//  customer. No charge. Used from Payment Methods (and anywhere a saved
//  card is needed outside a checkout).
//

import SwiftUI
import UIKit
import StripePaymentSheet
import StripePayments

struct StandaloneAddCardView: View {
    /// True when this will be the account's first card (so it becomes the default).
    var setAsDefault: Bool = false
    /// Called after the card is attached, passing the attached card so the
    /// caller can reload its list and select the new card.
    var onAdded: ((SavedCard) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var isPreparing = true
    @State private var localError: String? = nil
    @State private var clientSecret: String? = nil
    @State private var paymentSheet: PaymentSheet? = nil
    @State private var didPresentSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()

                VStack(spacing: 16) {
                    if isPreparing {
                        ProgressView()
                        Text("Preparing secure card form…")
                            .font(.system(size: 14))
                            .foregroundColor(.grocartSecondary)
                    } else if let error = localError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.grocartPrimary)
                            .multilineTextAlignment(.center)
                        Button("Try again") {
                            Task { await prepare() }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.grocartSecondary)
                        Text("Secured by Stripe — card details never touch our servers")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.grocartGreen)
                }
            }
        }
        .task {
            await prepare()
        }
    }

    // MARK: - Prepare PaymentSheet
    // Step 1: Get a setup intent clientSecret from the backend.
    // Step 2: Build a PaymentSheet for that setup intent. Its form has
    // separate lines for full name, card number, expiry, CVC and postal
    // code, all hosted by Stripe.
    private func prepare() async {
        isPreparing = true
        localError = nil
        didPresentSheet = false
        do {
            let setupIntent = try await PaymentRepository.shared.createSetupIntent()
            clientSecret = setupIntent.clientSecret

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Grocart"
            // Always collect the cardholder's full name so the form shows
            // a separate name line. The postal code line is part of the
            // card form itself (Stripe collects it for card verification),
            // so the address mode stays automatic.
            configuration.billingDetailsCollectionConfiguration.name = .always
            configuration.billingDetailsCollectionConfiguration.address = .automatic

            paymentSheet = PaymentSheet(
                setupIntentClientSecret: setupIntent.clientSecret,
                configuration: configuration
            )
            isPreparing = false
            presentPaymentSheet()
        } catch {
            localError = (error as? NetworkError)?.errorDescription ?? "Failed to initialize payment. Please try again."
            isPreparing = false
        }
    }

    // MARK: - Present + handle the sheet
    private func presentPaymentSheet() {
        guard let sheet = paymentSheet, !didPresentSheet else { return }
        didPresentSheet = true
        guard let top = topViewController() else {
            localError = "Could not open the secure card form. Please try again."
            didPresentSheet = false
            return
        }
        sheet.present(from: top) { result in
            switch result {
            case .completed:
                Task { await finishSetup() }
            case .canceled:
                dismiss()
            case .failed(let error):
                localError = error.localizedDescription
            }
        }
    }

    // Step 3: The setup intent is confirmed. Retrieve it to get the
    // payment method id, then attach it to the customer. No charge.
    private func finishSetup() async {
        guard let secret = clientSecret else {
            localError = "Card setup succeeded but no payment method was returned."
            return
        }
        let intent: STPSetupIntent? = await withCheckedContinuation { continuation in
            STPAPIClient.shared.retrieveSetupIntent(withClientSecret: secret) { intent, _ in
                continuation.resume(returning: intent)
            }
        }
        guard let paymentMethodId = intent?.paymentMethodID else {
            localError = "Card setup succeeded but no payment method was returned."
            return
        }
        do {
            let savedCard = try await PaymentRepository.shared.attachCard(
                AttachCardRequest(paymentMethodId: paymentMethodId, setAsDefault: setAsDefault)
            )
            onAdded?(savedCard)
            dismiss()
        } catch {
            localError = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
