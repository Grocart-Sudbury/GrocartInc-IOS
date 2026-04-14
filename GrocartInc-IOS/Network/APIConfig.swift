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
    // MARK: - Timeouts
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
    static let categoryCacheTTL: TimeInterval = 30 * 60
}
