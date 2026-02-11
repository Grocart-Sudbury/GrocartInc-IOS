//
//  LoginResponse.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation

struct LoginResponse: Decodable, Sendable {
    let token: String
    let userId: Int
    let email: String
    let role: String
    let firstName: String
    let lastName: String
    let message: String?
}
