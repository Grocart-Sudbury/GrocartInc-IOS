//
//  StripeCardField.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-16.
//

import SwiftUI
import StripePaymentsUI

/// SwiftUI wrapper around Stripe's STPPaymentCardTextField.
/// Reports validity and card params back via bindings/callbacks.
struct StripeCardField: UIViewRepresentable {
    @Binding var isValid: Bool
    var onCardParams: ((STPPaymentMethodCardParams?) -> Void)?

    func makeUIView(context: Context) -> STPPaymentCardTextField {
        let field = STPPaymentCardTextField()
        field.delegate = context.coordinator
        field.backgroundColor = UIColor.systemBackground
        field.borderColor = UIColor.clear
        field.borderWidth = 0
        return field
    }

    func updateUIView(_ uiView: STPPaymentCardTextField, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, STPPaymentCardTextFieldDelegate {
        var parent: StripeCardField
        init(_ parent: StripeCardField) { self.parent = parent }

        func paymentCardTextFieldDidChange(_ textField: STPPaymentCardTextField) {
            parent.isValid = textField.isValid
            parent.onCardParams?(textField.isValid ? textField.paymentMethodParams.card : nil)
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
