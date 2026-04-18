//
//  APIConfig.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

//
//  APIConfig.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation

struct APIConfig {
    
    // MARK: - Base URL
    #if DEBUG
    static let baseURL = "http://147.93.114.66:9092/api"
    #else
    static let baseURL = "https://yourdomain.com/api"
    #endif
    
    // MARK: - Auth Endpoints
    struct Auth {
        static let login = "\(baseURL)/auth/login"
        static let register = "\(baseURL)/auth/register/customer"
        static let forgotPassword = "\(baseURL)/auth/forgot-password"
    }
    struct OTP {
        static let send = "\(baseURL)/otp/send"
        static let verify = "\(baseURL)/otp/verify"
    }

    struct Stores {
        static let active = "\(baseURL)/stores/active"
    }

    struct Cart {
        static let pricing = "\(baseURL)/cart/pricing"
    }

    struct Orders {
        static let place = "\(baseURL)/orders"
    }

    struct Products {
        static let categories = "\(baseURL)/categories"
    }

    struct Payment {
        static let cards = "\(baseURL)/payment/cards"
        static let setupIntent = "\(baseURL)/payment/cards/setup-intent"
        static let attachCard = "\(baseURL)/payment/cards/attach"
        static func deleteCard(_ id: String) -> String { "\(baseURL)/payment/cards/\(id)" }
        static let charge = "\(baseURL)/payment/charge"
        static let confirm = "\(baseURL)/payment/confirm"
        static let guestCheckout = "\(baseURL)/payment/guest/checkout"
        static let guestConfirm = "\(baseURL)/payment/guest/confirm"
    }

    // MARK: - Stripe
    // TODO: Replace with your actual Stripe publishable key from the Stripe Dashboard
    static let stripePublishableKey = "pk_test_51SLbM0R9HWZnywuRN3JXvhcuEivraWzl9zESdy8rLObHM4UXdFUgzEK8VI4vnj3OSPt9CFPobeRw7xCJ7S3ThiPp00ZyussQp3"

    // MARK: - Timeouts
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
    static let categoryCacheTTL: TimeInterval = 30 * 60
}
