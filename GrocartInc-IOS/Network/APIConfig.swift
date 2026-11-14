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

    // STAGING TESTING (2026-11-13, Probby: "make the app work in
    // staging"): the whole app — sign-up, stores, products, cart,
    // orders, cards — talks to the staging backend. Staging has its
    // own database, so accounts made here do NOT exist on production
    // and vice versa. To go back to production, swap the two lines
    // below and Run again. Do NOT ship a staging build.
    static let baseURL = "http://147.93.114.66:9092/api"
    //static let baseURL = "https://api.grocartinc.ca/api"

    // MARK: - Points (TEST-ONLY staging)
    //
    // The loyalty API (GET /customer/points, POST /cart/pricing with
    // pointsToRedeem, POST /orders with pointsToRedeem) lives on
    // STAGING only until it ships to production. While the whole app
    // is on staging these are the same server as `baseURL` above.
    // When the app goes back to production, point `pointsBaseURL` at
    // `baseURL` only once the loyalty API has shipped to production.
    static let pointsStagingBaseURL = "http://147.93.114.66:9092/api"
    static let pointsBaseURL = pointsStagingBaseURL

    struct Points {
        static let summary = "\(pointsBaseURL)/customer/points"
        static let pricing = "\(pointsBaseURL)/cart/pricing"
        static let placeOrder = "\(pointsBaseURL)/orders"
        static let charge = "\(pointsBaseURL)/payment/charge"
        static let confirm = "\(pointsBaseURL)/payment/confirm"
    }
   
    
    // MARK: - Auth Endpoints
    struct Auth {
        static let login = "\(baseURL)/auth/login"
        static let register = "\(baseURL)/auth/register/customer"
    }
    struct OTP {
        static let send = "\(baseURL)/otp/send"
        static let verify = "\(baseURL)/otp/verify"
    }

    struct Stores {
        static let active = "\(baseURL)/stores/active"
        static func scheduleByDay(storeId: Int, dayOfWeek: String) -> String {
            "\(baseURL)/stores/\(storeId)/schedules/\(dayOfWeek)"
        }
    }

    struct Cart {
        static let pricing = "\(baseURL)/cart/pricing"
    }

    struct Customer {
        static let profile  = "\(baseURL)/customer/profile"
        static let account  = "\(baseURL)/customer/account"
    }

    struct Orders {
        static let place = "\(baseURL)/orders"
        static let topProducts = "\(baseURL)/orders/top-products"
        static func byId(_ id: Int) -> String { "\(baseURL)/orders/\(id)" }
        static func track(_ trackingId: String) -> String { "\(baseURL)/orders/track/\(trackingId)" }
    }

    struct CustomerOrders {
        static let active = "\(baseURL)/customer/orders/active"
    }

    struct Subscriptions {
        static let base = "\(baseURL)/customer/subscriptions"
        static func byId(_ id: Int) -> String { "\(base)/\(id)" }
    }

    struct Products {
        static let categories = "\(baseURL)/categories"
    }

    struct Home {
        static let banners = "\(baseURL)/home/banners"
    }

    struct Addresses {
        static let base = "\(baseURL)/customer/addresses"
        static func byId(_ id: Int) -> String { "\(base)/\(id)" }
        static let defaultAddress = "\(base)/default"
        static func setDefault(_ id: Int) -> String { "\(base)/\(id)/default" }
    }

    struct CustomerPromoCodes {
        static let base  = "\(baseURL)/customer/promo-codes"
        static let check = "\(baseURL)/customer/promo-codes/check"
    }

    struct PromoCodes {
        static let base = "\(baseURL)/admin/promo-codes"
        static let global = "\(base)/global"
        static func byCustomer(_ customerId: Int) -> String { "\(base)/customer/\(customerId)" }
        static func byId(_ id: Int) -> String { "\(base)/\(id)" }
        static func toggle(_ id: Int) -> String { "\(base)/\(id)/toggle" }
    }

    struct Uber {
        static let deliveryQuote = "\(baseURL)/uber/delivery-quote"
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
    // STAGING GAP (2026-11-13): this is still the LIVE publishable key.
    // Staging's backend uses Stripe TEST keys, so adding a card or
    // paying by card on staging will fail (live key + test-mode setup
    // intent do not mix). Everything else on staging works. To fix
    // card payments on staging, replace this with staging's TEST
    // publishable key from the Stripe dashboard and flip it back to
    // this live key before any production build.
    static let stripePublishableKey = "pk_live_51SLbLoBz4P6OLwsVYvrJhUb1KonoFVDivJjyIfLmiw3WgNZGYOqPXH8rFCpseI0hAjCEdEoIlOGC6XWrx0YdI51W00XTseX3jc"

    // MARK: - Timeouts
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
    static let categoryCacheTTL: TimeInterval = 30 * 60
    static let storeCacheTTL: TimeInterval = 60 * 60
}
