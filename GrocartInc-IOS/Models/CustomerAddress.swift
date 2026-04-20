// CustomerAddress.swift
// GrocartInc-IOS

import Foundation

struct CustomerAddress: Codable, Identifiable {
    let id: Int
    let label: String
    let firstName: String
    let lastName: String
    let phone: String
    let address: String
    let city: String
    let province: String
    let postalCode: String
    var isDefault: Bool

    var fullName: String { "\(firstName) \(lastName)" }
    var displayAddress: String { "\(address), \(city), \(province) \(postalCode)" }

    enum CodingKeys: String, CodingKey {
        case id, label, firstName, lastName, phone, address, city, province, postalCode
        case isDefault = "default"
    }
}

struct AddressRequest: Encodable {
    let label: String
    let firstName: String
    let lastName: String
    let phone: String
    let address: String
    let city: String
    let province: String
    let postalCode: String
    let isDefault: Bool
}

struct AddressListResponse: Decodable {
    let addresses: [CustomerAddress]
}
