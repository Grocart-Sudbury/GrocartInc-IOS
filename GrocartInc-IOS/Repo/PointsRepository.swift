//
//  PointsRepository.swift
//  GrocartInc-IOS
//
//  Loyalty points, served by the backend loyalty API
//  (Grocart_Loyalty_Points_API.pdf, v1.0).
//
//  TEST-ONLY: the API lives on staging (APIConfig.Points) until it
//  ships to production — see APIConfig.Points. This repository is the
//  only place that talks to the points endpoints; views read
//  PointsManager, never this repository directly.
//

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "PointsRepository")

final class PointsRepository: @unchecked Sendable {

    static let shared = PointsRepository()
    private static let decoder = JSONDecoder()
    private init() {}

    /// GET /customer/points — balance, rules and full history,
    /// newest first.
    func fetchPoints() async throws -> LoyaltyPointsSummary {
        logger.info("GET /customer/points (staging)")
        let response = await Session.authenticated
            .request(APIConfig.Points.summary, method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        switch response.result {
        case .success(let data):
            do {
                return try Self.decoder.decode(LoyaltyPointsSummary.self, from: data)
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.decodingError
            }
        case .failure(let afError):
            let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            logger.error("FAILED: \(body)")
            if response.response?.statusCode == 401 { throw NetworkError.unauthorized }
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
