//
//  CartRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "CartRepository")

final class CartRepository: @unchecked Sendable {

    static let shared = CartRepository()
    private static let decoder = JSONDecoder()
    private init() {}

    func fetchPricing(request: CartPricingRequest) async throws -> CartPricingResponse {
        logger.info("POST cart/pricing — \(request.cart.count) item(s), cityCode: \(request.cityCode)")

        // Encode struct → Data → [String: Any] to avoid JSONParameterEncoder's Sendable requirement
        let bodyData = try JSONEncoder().encode(request)
        guard let params = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            throw NetworkError.unknown(NSError(domain: "CartRepository", code: -1,
                                               userInfo: [NSLocalizedDescriptionKey: "Failed to encode request"]))
        }

        let task = Session.authenticated.request(
            APIConfig.Cart.pricing,
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default
        )
        .validate(statusCode: 200..<300)
        .serializingData()

        let response = await task.response
        logger.info("STATUS CODE: \(response.response?.statusCode ?? -1)")

        switch response.result {
        case .success(let data):
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            logger.debug("RAW RESPONSE: \(raw)")
            do {
                return try Self.decoder.decode(CartPricingResponse.self, from: data)
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.unknown(error)
            }
        case .failure(let afError):
            let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            logger.error("FAILED: \(afError.localizedDescription) — \(body)")
            if response.response?.statusCode == 401 {
                throw NetworkError.unauthorized
            }
            if let urlError = afError.underlyingError as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost: throw NetworkError.networkUnavailable
                case .timedOut: throw NetworkError.timeout
                default: throw NetworkError.unknown(urlError)
                }
            }
            throw NetworkError.unknown(afError)
        }
    }
}
