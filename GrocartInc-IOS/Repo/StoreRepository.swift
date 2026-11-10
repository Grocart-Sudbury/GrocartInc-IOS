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
    private static let decoder = JSONDecoder()

    // Public endpoint — no auth interceptor needed
    private let session: Session = {
        let config = URLSessionConfiguration.af.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.timeoutIntervalForResource = APIConfig.resourceTimeout
        return Session(configuration: config)
    }()

    private init() {}

    private func cacheKey(for city: String) -> String {
        "stores_\(city.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }

    func fetchActiveStores(city: String, forceRefresh: Bool = false) async throws -> [Store] {
        let key = cacheKey(for: city)
        let cache = CacheManager.shared

        if !forceRefresh,
           cache.isValid(forKey: key, ttl: APIConfig.storeCacheTTL),
           let cached = cache.load([Store].self, forKey: key) {
            logger.info("Returning cached stores for city: \(city)")
            return cached
        }

        logger.info("Fetching active stores for city: \(city)")
        logger.info("REQUEST: GET \(APIConfig.Stores.active)?city=\(city)")

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
            logger.info("STATUS CODE: \(response.response?.statusCode ?? -1)")
            logger.info("RAW RESPONSE: \(raw.prefix(500))")
            do {
                // Decode stores one by one: a single malformed store is
                // skipped instead of failing the whole list.
                let stores = try Self.decoder.decode([FailableDecodable<Store>].self, from: data).compactMap(\.value)
                cache.save(stores, forKey: key)
                return stores
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

    func fetchSchedule(storeId: Int, dayOfWeek: String) async throws -> DeliverySchedule {
        let url = APIConfig.Stores.scheduleByDay(storeId: storeId, dayOfWeek: dayOfWeek)
        logger.info("REQUEST: GET \(url)")

        let task = session.request(url, method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        logger.info("STATUS CODE: \(response.response?.statusCode ?? -1)")

        switch response.result {
        case .success(let data):
            do {
                return try Self.decoder.decode(DeliverySchedule.self, from: data)
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.unknown(error)
            }
        case .failure(let afError):
            logger.error("SCHEDULE FETCH FAILED: \(afError.localizedDescription)")
            throw NetworkError.unknown(afError)
        }
    }
}
