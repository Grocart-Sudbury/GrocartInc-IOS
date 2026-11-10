// AddressRepository.swift
// GrocartInc-IOS

import Foundation
@preconcurrency import Alamofire
import os.log

nonisolated(unsafe) private let logger = Logger(subsystem: "com.grocartinc.ios", category: "AddressRepository")

final class AddressRepository: @unchecked Sendable {

    nonisolated(unsafe) static let shared = AddressRepository()
    private static let decoder = JSONDecoder()
    private init() {}

    // MARK: - Helpers

    nonisolated private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            logger.error("DECODE ERROR: \(error)")
            throw NetworkError.unknown(error)
        }
    }

    nonisolated private func handleFailure(_ response: DataResponse<Data, AFError>) throws -> Never {
        let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        logger.error("FAILED: \(body)")
        if let afError = response.error {
            logger.error("AF ERROR: \(afError)")
        }
        if let data = response.data,
           let errResponse = try? Self.decoder.decode(APIErrorResponse.self, from: data) {
            throw NetworkError.serverError(errResponse.displayMessage)
        }
        if response.response?.statusCode == 401 { throw NetworkError.unauthorized }
        if response.error?.isSessionTaskError == true {
            throw NetworkError.serverError("Network error. Please check your connection.")
        }
        throw NetworkError.serverError("Something went wrong. Please try again.")
    }

    // MARK: - API Methods

    nonisolated func fetchAll() async throws -> [CustomerAddress] {
        logger.info("GET /customer/addresses")
        let task = Session.authenticated
            .request(APIConfig.Addresses.base, method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data):
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            logger.debug("RAW: \(raw.prefix(500))")
            // The API returns either an array directly or a wrapper object
            if let list = try? Self.decoder.decode([CustomerAddress].self, from: data) {
                return list
            }
            let wrapper = try decode(AddressListResponse.self, from: data)
            return wrapper.addresses
        case .failure:
            try handleFailure(response)
        }
    }

    nonisolated private func makeJSONRequest(url: String, method: String, body: AddressRequest) throws -> URLRequest {
        guard let u = URL(string: url) else {
            throw NetworkError.unknown(NSError(domain: "AddressRepository", code: -2))
        }
        var req = URLRequest(url: u)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try JSONEncoder().encode(body)
        return req
    }

    nonisolated func add(_ request: AddressRequest) async throws -> CustomerAddress {
       
        let urlRequest = try makeJSONRequest(url: APIConfig.Addresses.base, method: "POST", body: request)
        let task = Session.authenticated
            .request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data):
            return try decode(CustomerAddress.self, from: data)
        case .failure:
            try handleFailure(response)
        }
    }

    nonisolated func update(id: Int, request: AddressRequest) async throws -> CustomerAddress {
        logger.info("PUT /customer/addresses/\(id)")
        let urlRequest = try makeJSONRequest(url: APIConfig.Addresses.byId(id), method: "PUT", body: request)
        let task = Session.authenticated
            .request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success(let data):
            return try decode(CustomerAddress.self, from: data)
        case .failure:
            try handleFailure(response)
        }
    }

    nonisolated func setDefault(id: Int) async throws {
        logger.info("PATCH /customer/addresses/\(id)/default")
        let task = Session.authenticated
            .request(APIConfig.Addresses.setDefault(id), method: .patch)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success: return
        case .failure: try handleFailure(response)
        }
    }

    nonisolated func delete(id: Int) async throws {
        logger.info("DELETE /customer/addresses/\(id)")
        let task = Session.authenticated
            .request(APIConfig.Addresses.byId(id), method: .delete)
            .validate(statusCode: 200..<300)
            .serializingData()

        let response = await task.response
        switch response.result {
        case .success: return
        case .failure: try handleFailure(response)
        }
    }
}
