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

struct AddressRequest: Sendable {
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

extension AddressRequest: Encodable {
    private enum CodingKeys: String, CodingKey {
        case label, firstName, lastName, phone, address, city, province, postalCode, isDefault
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label,      forKey: .label)
        try c.encode(firstName,  forKey: .firstName)
        try c.encode(lastName,   forKey: .lastName)
        try c.encode(phone,      forKey: .phone)
        try c.encode(address,    forKey: .address)
        try c.encode(city,       forKey: .city)
        try c.encode(province,   forKey: .province)
        try c.encode(postalCode, forKey: .postalCode)
        try c.encode(isDefault,  forKey: .isDefault)
    }
}

struct AddressListResponse: Decodable {
    let addresses: [CustomerAddress]
}
