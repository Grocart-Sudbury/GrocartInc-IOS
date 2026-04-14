//
//  OrderRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "OrderRepository")

final class OrderRepository: @unchecked Sendable {

    static let shared = OrderRepository()
    private init() {}

    func placeOrder(_ request: OrderRequest) async throws -> OrderResponse {
        logger.info("POST /orders — store:\(request.storeId) items:\(request.items.count)")

        let bodyData = try JSONEncoder().encode(request)
        guard let params = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            throw NetworkError.unknown(NSError(domain: "OrderRepository", code: -1,
                                               userInfo: [NSLocalizedDescriptionKey: "Failed to encode order"]))
        }

        let task = Session.authenticated.request(
            APIConfig.Orders.place,
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
            logger.debug("RAW RESPONSE: \(raw.prefix(500))")
            do {
                return try JSONDecoder().decode(OrderResponse.self, from: data)
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.unknown(error)
            }
        case .failure(let afError):
            let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            logger.error("FAILED: \(body)")
            if let data = response.data,
               let errResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.serverError(errResponse.displayMessage)
            }
            if response.response?.statusCode == 401 { throw NetworkError.unauthorized }
            throw NetworkError.unknown(afError)
        }
    }
}
