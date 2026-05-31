//
//  ProductRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-12.
//

//
//  ProductRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-12.
//

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "ProductRepository")



final class ProductRepository: @unchecked Sendable, ProductRepositoryProtocol {
    
    static let shared = ProductRepository()

    private let cache = CacheManager.shared
    private let cacheKey = "categories"

    // Public session for store-specific category fetch (no auth required)
    private let publicSession: Session = {
        let config = URLSessionConfiguration.af.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.timeoutIntervalForResource = APIConfig.resourceTimeout
        return Session(configuration: config)
    }()

    private init() {}
    
    // MARK: - Fetch Categories (Cache-first)
    func fetchCategories(forceRefresh: Bool = false) async throws -> [Category] {
        
        // 1. Return cache if valid and not forcing refresh
        if !forceRefresh,
           cache.isValid(forKey: cacheKey, ttl: APIConfig.categoryCacheTTL),
           let cached = cache.load([Category].self, forKey: cacheKey) {
            logger.info("Returning cached categories (\(cached.count) categories)")
            return cached
        }
        
        // 2. Fetch from API
        logger.info("Fetching categories from API")
        
        let categories: [Category] = try await performPublicRequest(
            url: APIConfig.Products.categories,
            method: .get
        )
        
        // 3. Cache the response
        cache.save(categories, forKey: cacheKey)
        logger.info("Fetched and cached \(categories.count) categories")
        
        return categories
    }
    
    // MARK: - Fetch Categories by Store ID (public endpoint, no cache)
    func fetchCategories(storeId: Int) async throws -> [Category] {
        logger.info("Fetching categories for storeId: \(storeId)")

        let task = publicSession.request(
            APIConfig.Products.categories,
            method: .get,
            parameters: ["storeId": storeId],
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
                return try JSONDecoder().decode([Category].self, from: data)
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.unknown(error)
            }
        case .failure(let afError):
            throw mapError(afError, data: response.data, statusCode: response.response?.statusCode)
        }
    }

    // MARK: - Invalidate Cache
    func invalidateCache() {
        cache.clear(forKey: cacheKey)
    }
    
    // MARK: - Public Request Helper (no auth token)
    private func performPublicRequest<T: Decodable>(
        url: String,
        method: HTTPMethod,
        parameters: [String: Any]? = nil
    ) async throws -> T {
        logger.info("REQUEST: \(method.rawValue) \(url)")

        let task = publicSession.request(
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
