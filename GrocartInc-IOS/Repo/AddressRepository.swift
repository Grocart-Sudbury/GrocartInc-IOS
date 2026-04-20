// AddressRepository.swift
// GrocartInc-IOS

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "AddressRepository")

final class AddressRepository: @unchecked Sendable {

    static let shared = AddressRepository()
    private init() {}

    // MARK: - Helpers

    private func encode(_ request: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.unknown(NSError(domain: "AddressRepository", code: -1))
        }
        return dict
    }

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

    // MARK: - API Methods

    func fetchAll() async throws -> [CustomerAddress] {
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
            if let list = try? JSONDecoder().decode([CustomerAddress].self, from: data) {
                return list
            }
            let wrapper = try decode(AddressListResponse.self, from: data)
            return wrapper.addresses
        case .failure:
            try handleFailure(response)
        }
    }

    func add(_ request: AddressRequest) async throws -> CustomerAddress {
        logger.info("POST /customer/addresses — label:\(request.label)")
        let params = try encode(request)
        let task = Session.authenticated
            .request(APIConfig.Addresses.base, method: .post,
                     parameters: params, encoding: JSONEncoding.default)
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

    func update(id: Int, request: AddressRequest) async throws -> CustomerAddress {
        logger.info("PUT /customer/addresses/\(id)")
        let params = try encode(request)
        let task = Session.authenticated
            .request(APIConfig.Addresses.byId(id), method: .put,
                     parameters: params, encoding: JSONEncoding.default)
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

    func setDefault(id: Int) async throws {
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

    func delete(id: Int) async throws {
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
