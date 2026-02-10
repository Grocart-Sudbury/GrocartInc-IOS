//
//  User.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

//
//  User.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation

struct User: Codable, Sendable {
    let id: Int
    let email: String
    let role: String
    let firstName: String
    let lastName: String
    let token: String
    
    var fullName: String {
        let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? email : name
    }
    
    var isAdmin: Bool {
        return role == "ADMIN"
    }
}
