//
//  OTPResponse.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation

struct OTPSendResponse: Decodable, Sendable {
    let success: Bool
    let message: String
}

struct OTPCustomer: Decodable, Sendable {
    let id: Int
    let email: String
    let firstName: String
    let lastName: String
}

struct OTPVerifyResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    let token: String?
    let customer: OTPCustomer?
}
