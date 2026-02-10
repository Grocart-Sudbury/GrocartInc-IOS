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
    static let baseURL = "http://localhost:9091/api"
    #else
    static let baseURL = "https://yourdomain.com/api"
    #endif
    
    // MARK: - Auth Endpoints
    struct Auth {
        static let login = "\(baseURL)/auth/login"
        static let register = "\(baseURL)/auth/register"
        static let forgotPassword = "\(baseURL)/auth/forgot-password"
    }
    
    // MARK: - Timeouts
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
}
