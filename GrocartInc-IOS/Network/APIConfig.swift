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
  
    //static let baseURL = "http://147.93.114.66:9092/api"
    //static let baseURL = "http://localhost:9091/api"
   static let baseURL = "https://api.grocartinc.ca/api"
   
    
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
        static func byId(_ id: Int) -> String { "\(baseURL)/orders/\(id)" }
        static func track(_ trackingId: String) -> String { "\(baseURL)/orders/track/\(trackingId)" }
    }

    struct CustomerOrders {
        static let active = "\(baseURL)/customer/orders/active"
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
    // TODO: Replace with your actual Stripe publishable key from the Stripe Dashboard
    static let stripePublishableKey = "pk_live_51SLbLoBz4P6OLwsVYvrJhUb1KonoFVDivJjyIfLmiw3WgNZGYOqPXH8rFCpseI0hAjCEdEoIlOGC6XWrx0YdI51W00XTseX3jc"

    // MARK: - Timeouts
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
    static let categoryCacheTTL: TimeInterval = 30 * 60
    static let storeCacheTTL: TimeInterval = 60 * 60
}
