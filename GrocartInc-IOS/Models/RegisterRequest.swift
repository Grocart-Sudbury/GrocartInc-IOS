//
//  RegisterRequest.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-11.
//

//
//  RegisterRequest.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation

struct RegisterRequest: Codable, Sendable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let phone: String
}
