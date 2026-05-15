//
//  HomeRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-05-14.
//

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "HomeRepository")

final class HomeRepository: @unchecked Sendable {

    static let shared = HomeRepository()

    private init() {}

    // MARK: - Fetch Banners (always live)
    func fetchBanners() async throws -> [PromoBanner] {
        logger.info("Fetching banners from API")

        let banners: [PromoBanner] = try await performAuthenticatedRequest(
            url: APIConfig.Home.banners,
            method: .get
        )

        return banners.filter(\.isActive).sorted { $0.displayOrder < $1.displayOrder }
    }

    // MARK: - Authenticated Request Helper
    private func performAuthenticatedRequest<T: Decodable>(
        url: String,
        method: HTTPMethod,
        parameters: [String: Any]? = nil
    ) async throws -> T {
        logger.info("REQUEST: \(method.rawValue) \(url)")

        let task = Session.authenticated.request(
            url,
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default
        )
        .validate(statusCode: 200..<300)
        .serializingData()

        let response = await task.response
        logger.info("STATUS CODE: \(response.response?.statusCode ?? -1)")

        switch response.result {
        case .success(let data):
            let rawJSON = String(data: data, encoding: .utf8) ?? "nil"
            logger.debug("RAW RESPONSE: \(rawJSON.prefix(500))")
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.unknown(error)
            }

        case .failure(let afError):
            let errorData = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            logger.error("REQUEST FAILED: \(afError.localizedDescription)")
            logger.error("ERROR RESPONSE BODY: \(errorData)")
            throw mapError(afError, data: response.data, statusCode: response.response?.statusCode)
        }
    }

    // MARK: - Error Mapping
    private func mapError(_ afError: AFError, data: Data?, statusCode: Int?) -> NetworkError {
        if let data = data,
           let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            if statusCode == 401 { return .unauthorized }
            return .serverError(errorResponse.displayMessage)
        }

        if let data = data,
           let plainText = String(data: data, encoding: .utf8),
           !plainText.isEmpty {
            if statusCode == 401 { return .unauthorized }
            return .serverError(plainText)
        }

        if let urlError = afError.underlyingError as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .timeout
            default:
                return .unknown(urlError)
            }
        }

        if statusCode == 401 { return .unauthorized }
        return .unknown(afError)
    }
}
