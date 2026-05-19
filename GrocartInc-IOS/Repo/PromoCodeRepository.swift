//
//  PromoCodeRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-05-13.
//

import Foundation
@preconcurrency import Alamofire
import os.log

nonisolated(unsafe) private let logger = Logger(subsystem: "com.grocartinc.ios", category: "PromoCodeRepository")

final class PromoCodeRepository: @unchecked Sendable {

    nonisolated(unsafe) static let shared = PromoCodeRepository()
    private init() {}

    // MARK: - Helpers

    nonisolated private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("DECODE ERROR: \(error)")
            throw NetworkError.unknown(error)
        }
    }

    nonisolated private func handleFailure(_ response: DataResponse<Data, AFError>) throws -> Never {
        let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        logger.error("FAILED: \(body)")
        if let data = response.data,
           let errResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            throw NetworkError.serverError(errResponse.displayMessage)
        }
        if response.response?.statusCode == 401 { throw NetworkError.unauthorized }
        if response.response?.statusCode == 404 { throw NetworkError.serverError("Promo code not found.") }
        if response.error?.isSessionTaskError == true {
            throw NetworkError.serverError("Network error. Please check your connection.")
        }
        throw NetworkError.serverError("Something went wrong. Please try again.")
    }

    nonisolated private func makeJSONRequest<T: Encodable>(url: String, method: String, body: T) throws -> URLRequest {
        guard let u = URL(string: url) else {
            throw NetworkError.unknown(NSError(domain: "PromoCodeRepository", code: -2))
        }
        var req = URLRequest(url: u)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        return req
    }

    // MARK: - GET /api/customer/promo-codes

    nonisolated func fetchCustomerCodes() async throws -> [PromoCode] {
        logger.info("GET /customer/promo-codes")
        let task = Session.authenticated
            .request(APIConfig.CustomerPromoCodes.base, method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data): return try decode([PromoCode].self, from: data)
        case .failure: try handleFailure(response)
        }
    }

    // MARK: - POST /api/customer/promo-codes/check

    nonisolated func checkCode(_ code: String, subtotal: Double, storeId: Int) async throws -> PromoCodeCheckResponse {
        logger.info("POST /customer/promo-codes/check — code:\(code) subtotal:\(subtotal) storeId:\(storeId)")
        let urlRequest = try makeJSONRequest(
            url: APIConfig.CustomerPromoCodes.check,
            method: "POST",
            body: PromoCodeCheckRequest(code: code, subtotal: subtotal, storeId: storeId)
        )
        let task = Session.authenticated
            .request(urlRequest)
            .validate(statusCode: 200..<500)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data):
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            logger.debug("RAW: \(raw.prefix(300))")
            return try decode(PromoCodeCheckResponse.self, from: data)
        case .failure:
            try handleFailure(response)
        }
    }

    // MARK: - GET /api/admin/promo-codes

    nonisolated func fetchAll() async throws -> [PromoCode] {
        logger.info("GET /admin/promo-codes")
        let task = Session.authenticated
            .request(APIConfig.PromoCodes.base, method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data): return try decode([PromoCode].self, from: data)
        case .failure: try handleFailure(response)
        }
    }

    // MARK: - GET /api/admin/promo-codes/global

    nonisolated func fetchGlobal() async throws -> [PromoCode] {
        logger.info("GET /admin/promo-codes/global")
        let task = Session.authenticated
            .request(APIConfig.PromoCodes.global, method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data): return try decode([PromoCode].self, from: data)
        case .failure: try handleFailure(response)
        }
    }

    // MARK: - GET /api/admin/promo-codes/customer/{customerId}

    nonisolated func fetchByCustomer(_ customerId: Int) async throws -> [PromoCode] {
        logger.info("GET /admin/promo-codes/customer/\(customerId)")
        let task = Session.authenticated
            .request(APIConfig.PromoCodes.byCustomer(customerId), method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data): return try decode([PromoCode].self, from: data)
        case .failure: try handleFailure(response)
        }
    }

    // MARK: - GET /api/admin/promo-codes/{id}

    nonisolated func fetchById(_ id: Int) async throws -> PromoCode {
        logger.info("GET /admin/promo-codes/\(id)")
        let task = Session.authenticated
            .request(APIConfig.PromoCodes.byId(id), method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data): return try decode(PromoCode.self, from: data)
        case .failure: try handleFailure(response)
        }
    }

    // MARK: - POST /api/admin/promo-codes

    nonisolated func create(_ request: PromoCodeRequest, customerId: Int? = nil) async throws -> PromoCode {
        var url = APIConfig.PromoCodes.base
        if let cid = customerId { url += "?customerId=\(cid)" }
        logger.info("POST /admin/promo-codes\(customerId.map { "?customerId=\($0)" } ?? "")")

        let urlRequest = try makeJSONRequest(url: url, method: "POST", body: request)
        let task = Session.authenticated
            .request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data): return try decode(PromoCode.self, from: data)
        case .failure: try handleFailure(response)
        }
    }

    // MARK: - PUT /api/admin/promo-codes/{id}

    nonisolated func update(id: Int, request: PromoCodeUpdateRequest, customerId: Int? = nil) async throws -> PromoCode {
        var url = APIConfig.PromoCodes.byId(id)
        if let cid = customerId { url += "?customerId=\(cid)" }
        logger.info("PUT /admin/promo-codes/\(id)\(customerId.map { "?customerId=\($0)" } ?? "")")

        let urlRequest = try makeJSONRequest(url: url, method: "PUT", body: request)
        let task = Session.authenticated
            .request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data): return try decode(PromoCode.self, from: data)
        case .failure: try handleFailure(response)
        }
    }

    // MARK: - PATCH /api/admin/promo-codes/{id}/toggle

    nonisolated func toggle(id: Int) async throws -> PromoCode {
        logger.info("PATCH /admin/promo-codes/\(id)/toggle")
        let task = Session.authenticated
            .request(APIConfig.PromoCodes.toggle(id), method: .patch)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data): return try decode(PromoCode.self, from: data)
        case .failure: try handleFailure(response)
        }
    }

    // MARK: - DELETE /api/admin/promo-codes/{id}

    nonisolated func delete(id: Int) async throws -> DeletePromoCodeResponse {
        logger.info("DELETE /admin/promo-codes/\(id)")
        let task = Session.authenticated
            .request(APIConfig.PromoCodes.byId(id), method: .delete)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data): return try decode(DeletePromoCodeResponse.self, from: data)
        case .failure: try handleFailure(response)
        }
    }
}
