// CustomerRepository.swift
// GrocartInc-IOS

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "CustomerRepository")

final class CustomerRepository: @unchecked Sendable {

    static let shared = CustomerRepository()
    private init() {}

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("DECODE ERROR: \(error)")
            throw NetworkError.unknown(error)
        }
    }

    private func handleFailure(_ response: DataResponse<Data, AFError>) throws -> Never {
        let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        logger.error("FAILED: \(body)")
        if let data = response.data,
           let errResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            throw NetworkError.serverError(errResponse.displayMessage)
        }
        if response.response?.statusCode == 401 { throw NetworkError.unauthorized }
        throw NetworkError.serverError("Something went wrong. Please try again.")
    }

    // MARK: - Profile

    func getProfile() async throws -> CustomerProfile {
        logger.info("GET /customer/profile")
        let task = Session.authenticated
            .request(APIConfig.Customer.profile, method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data):
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            logger.debug("RAW: \(raw.prefix(500))")
            return try decode(CustomerProfile.self, from: data)
        case .failure:
            try handleFailure(response)
        }
    }

    func updateProfile(_ request: UpdateProfileRequest) async throws -> CustomerProfile {
        logger.info("PUT /customer/profile")
        let bodyData = try JSONEncoder().encode(request)
        guard let params = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            throw NetworkError.unknown(NSError(domain: "CustomerRepository", code: -1))
        }

        let task = Session.authenticated
            .request(APIConfig.Customer.profile, method: .put,
                     parameters: params, encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data):
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            logger.debug("RAW: \(raw.prefix(500))")
            return try decode(CustomerProfile.self, from: data)
        case .failure:
            try handleFailure(response)
        }
    }

    // MARK: - Orders

    func getOrders() async throws -> [CustomerOrderSummary] {
        logger.info("GET /customer/profile (orders)")
        let profile = try await getProfile()
        return profile.previousOrders ?? []
    }

    func getOrder(id: Int) async throws -> CustomerOrderDetail {
        logger.info("GET /orders/\(id)")
        let task = Session.authenticated
            .request(APIConfig.Orders.byId(id), method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data):
            return try decode(CustomerOrderDetail.self, from: data)
        case .failure:
            try handleFailure(response)
        }
    }
}
