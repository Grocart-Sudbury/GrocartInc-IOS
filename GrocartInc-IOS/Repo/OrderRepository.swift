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

    // Public endpoint — no auth interceptor needed for top-products
    private let publicSession: Session = {
        let config = URLSessionConfiguration.af.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.timeoutIntervalForResource = APIConfig.resourceTimeout
        return Session(configuration: config)
    }()

    private init() {}

    func fetchActiveOrders() async throws -> [ActiveOrder] {
        logger.info("GET /customer/orders/active")

        let task = Session.authenticated.request(
            APIConfig.CustomerOrders.active,
            method: .get
        )
        .validate(statusCode: 200..<300)
        .serializingData()

        let response = await task.response
        logger.info("ACTIVE ORDERS STATUS: \(response.response?.statusCode ?? -1)")

        switch response.result {
        case .success(let data):
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            logger.debug("ACTIVE ORDERS RAW: \(raw.prefix(500))")
            do {
                let orders = try JSONDecoder().decode([ActiveOrder].self, from: data)
                logger.info("ACTIVE ORDERS SUCCESS: \(orders.count) order(s) returned")
                return orders
            } catch {
                logger.error("ACTIVE ORDERS DECODE ERROR: \(error)")
                throw NetworkError.unknown(error)
            }
        case .failure(let afError):
            let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            logger.error("ACTIVE ORDERS FAILED: \(body)")
            if response.response?.statusCode == 401 { throw NetworkError.unauthorized }
            throw NetworkError.unknown(afError)
        }
    }

    func fetchTopProducts(storeId: Int) async throws -> [TopOrderedProduct] {
        logger.info("TOP PRODUCTS REQUEST: GET \(APIConfig.Orders.topProducts, privacy: .public)?storeId=\(storeId)")

        let task = publicSession.request(
            APIConfig.Orders.topProducts,
            method: .get,
            parameters: ["storeId": storeId],
            encoding: URLEncoding.queryString
        )
        .validate(statusCode: 200..<300)
        .serializingData()

        let response = await task.response
        logger.info("TOP PRODUCTS STATUS: \(response.response?.statusCode ?? -1)")

        switch response.result {
        case .success(let data):
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            logger.info("TOP PRODUCTS RESPONSE BODY: \(raw, privacy: .public)")
            do {
                let products = try JSONDecoder().decode([TopOrderedProduct].self, from: data)
                logger.info("TOP PRODUCTS SUCCESS: \(products.count) product(s) returned")
                return products
            } catch {
                logger.error("TOP PRODUCTS DECODE ERROR: \(error, privacy: .public)")
                throw NetworkError.unknown(error)
            }
        case .failure(let afError):
            let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            logger.error("TOP PRODUCTS FAILED [\(response.response?.statusCode ?? -1)]: \(afError.localizedDescription, privacy: .public)")
            logger.error("TOP PRODUCTS ERROR BODY: \(body, privacy: .public)")
            if response.response?.statusCode == 401 { throw NetworkError.unauthorized }
            throw NetworkError.unknown(afError)
        }
    }

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
