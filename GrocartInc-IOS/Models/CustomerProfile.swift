// CustomerProfile.swift
// GrocartInc-IOS

import Foundation

struct CustomerProfile: Decodable {
    let id: Int?
    let firstName: String
    let lastName: String
    let email: String
    let phone: String?
    let active: Bool?

    var fullName: String { "\(firstName) \(lastName)" }
}

struct UpdateProfileRequest: Encodable {
    let firstName: String
    let lastName: String
    let phone: String
}
