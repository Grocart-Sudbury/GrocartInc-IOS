//
//  StoreRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "StoreRepository")

final class StoreRepository: @unchecked Sendable {

    static let shared = StoreRepository()

    // Public endpoint — no auth interceptor needed
    private let session: Session = {
        let config = URLSessionConfiguration.af.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.timeoutIntervalForResource = APIConfig.resourceTimeout
        return Session(configuration: config)
    }()

    private init() {}

    func fetchActiveStores(city: String) async throws -> [Store] {
        logger.info("Fetching active stores for city: \(city)")

        let task = session.request(
            APIConfig.Stores.active,
            method: .get,
            parameters: ["city": city],
            encoding: URLEncoding.queryString
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
                return try JSONDecoder().decode([Store].self, from: data)
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.unknown(error)
            }
        case .failure(let afError):
            logger.error("REQUEST FAILED: \(afError.localizedDescription)")
            if let urlError = afError.underlyingError as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    throw NetworkError.networkUnavailable
                case .timedOut:
                    throw NetworkError.timeout
                default:
                    throw NetworkError.unknown(urlError)
                }
            }
            throw NetworkError.unknown(afError)
        }
    }
}
