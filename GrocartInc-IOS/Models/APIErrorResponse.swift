//
//  APIErrorResponse.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

//
//  APIErrorResponse.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation

struct APIErrorResponse: Decodable, Sendable {
    let message: String?
    let error: String?
    let status: Int?
    
    var displayMessage: String {
        return message ?? error ?? "Something went wrong. Please try again."
    }
}
