//
//  NetworkError.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

//
//  NetworkError.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case unauthorized
    case serverError(String)
    case networkUnavailable
    case timeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL. Please try again."
        case .noData:
            return "No data received from server."
        case .decodingError:
            return "Unable to process server response."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .serverError(let message):
            return message
        case .networkUnavailable:
            return "No internet connection. Please check your network."
        case .timeout:
            return "Request timed out. Please try again."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
