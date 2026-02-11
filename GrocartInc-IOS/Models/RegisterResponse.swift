//
//  RegisterResponse.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-11.
//

import Foundation

struct RegisterResponse: Decodable, Sendable {
    let token: String?
    let userId: Int
    let email: String
    let role: String
    let firstName: String
    let lastName: String
    let message: String?
}
