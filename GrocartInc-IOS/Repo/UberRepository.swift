// UberRepository.swift
// GrocartInc-IOS

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "UberRepository")

final class UberRepository: @unchecked Sendable {

    static let shared = UberRepository()
    private static let decoder = JSONDecoder()
    private init() {}

    func fetchDeliveryQuote(dropoffAddress: String) async throws -> UberDeliveryQuoteResponse {
        logger.info("POST /uber/delivery-quote — address: \(dropoffAddress)")

        let params: [String: Any] = ["dropoffAddress": dropoffAddress]

        let task = Session.authenticated.request(
            APIConfig.Uber.deliveryQuote,
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
            logger.debug("RAW: \(raw.prefix(500))")
            do {
                return try Self.decoder.decode(UberDeliveryQuoteResponse.self, from: data)
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.unknown(error)
            }
        case .failure(let afError):
            let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            logger.error("FAILED: \(body)")
            if response.response?.statusCode == 401 { throw NetworkError.unauthorized }
            throw NetworkError.unknown(afError)
        }
    }
}
