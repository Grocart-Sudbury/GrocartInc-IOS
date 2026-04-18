//
//  PaymentRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-16.
//

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "PaymentRepository")

final class PaymentRepository: @unchecked Sendable {

    static let shared = PaymentRepository()
    private init() {}

    // MARK: - Get Saved Cards
    func getSavedCards() async throws -> [SavedCard] {
        logger.info("GET /payment/cards")
        let response = await Session.authenticated
            .request(APIConfig.Payment.cards, method: .get)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        return try decode([SavedCard].self, from: response)
    }

    // MARK: - Create Setup Intent
    func createSetupIntent() async throws -> SetupIntentResponse {
        logger.info("POST /payment/cards/setup-intent")
        let response = await Session.authenticated
            .request(APIConfig.Payment.setupIntent, method: .post)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        return try decode(SetupIntentResponse.self, from: response)
    }

    // MARK: - Attach Card to Customer
    func attachCard(_ request: AttachCardRequest) async throws -> SavedCard {
        logger.info("POST /payment/cards/attach — pmId:\(request.paymentMethodId)")
        let response = await Session.authenticated
            .request(APIConfig.Payment.attachCard, method: .post,
                     parameters: try encodeToParams(request), encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        return try decode(SavedCard.self, from: response)
    }

    // MARK: - Delete Card
    func deleteCard(_ paymentMethodId: String) async throws {
        logger.info("DELETE /payment/cards/\(paymentMethodId)")
        let response = await Session.authenticated
            .request(APIConfig.Payment.deleteCard(paymentMethodId), method: .delete)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        if case .failure(let error) = response.result {
            throw mapError(response: response, afError: error)
        }
    }

    // MARK: - Charge Saved Card
    func chargeCard(_ request: ChargeRequest) async throws -> ChargeResponse {
        logger.info("POST /payment/charge — orderId:\(request.orderId) pmId:\(request.paymentMethodId)")
        let response = await Session.authenticated
            .request(APIConfig.Payment.charge, method: .post,
                     parameters: try encodeToParams(request), encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        return try decode(ChargeResponse.self, from: response)
    }

    // MARK: - Confirm Payment After 3DS
    func confirmPayment(_ request: ConfirmPaymentRequest) async throws -> ConfirmPaymentResponse {
        logger.info("POST /payment/confirm — piId:\(request.paymentIntentId)")
        // Note: /payment/confirm does not require auth per the API docs
        let response = await Session.default
            .request(APIConfig.Payment.confirm, method: .post,
                     parameters: try encodeToParams(request), encoding: JSONEncoding.default)
            .validate(statusCode: 200..<300)
            .serializingData()
            .response
        return try decode(ConfirmPaymentResponse.self, from: response)
    }

    // MARK: - Helpers
    private func encodeToParams<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let params = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetworkError.unknown(NSError(domain: "PaymentRepository", code: -1,
                                               userInfo: [NSLocalizedDescriptionKey: "Encoding failed"]))
        }
        return params
    }

    private func decode<T: Decodable>(_ type: T.Type, from response: DataResponse<Data, AFError>) throws -> T {
        switch response.result {
        case .success(let data):
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            logger.debug("RESPONSE: \(raw.prefix(300))")
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                logger.error("DECODE ERROR: \(error)")
                throw NetworkError.decodingError
            }
        case .failure(let error):
            throw mapError(response: response, afError: error)
        }
    }

    private func mapError(response: DataResponse<Data, AFError>, afError: AFError) -> NetworkError {
        let body = response.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
        logger.error("FAILED: \(body)")
        if let data = response.data,
           let errResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return NetworkError.serverError(errResponse.displayMessage)
        }
        if response.response?.statusCode == 401 { return NetworkError.unauthorized }
        return NetworkError.unknown(afError)
    }
}
