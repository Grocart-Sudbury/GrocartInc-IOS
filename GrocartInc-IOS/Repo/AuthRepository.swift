//
//  AuthRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation
@preconcurrency import Alamofire
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "AuthRepository")

final class AuthRepository: @unchecked Sendable, AuthRepositoryProtocol {
    
    static let shared = AuthRepository()
    
    private let session: Session
    
    private init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = APIConfig.requestTimeout
        configuration.timeoutIntervalForResource = APIConfig.resourceTimeout
        self.session = Session(configuration: configuration)
    }
    
    // MARK: - Login
    func login(email: String, password: String) async throws -> LoginResponse {
        let parameters: [String: String] = [
            "email": email,
            "password": password
        ]
        
        return try await performRequest(
            url: APIConfig.Auth.login,
            method: .post,
            parameters: parameters
        )
    }
    
    // MARK: - Register
    func register(request: RegisterRequest) async throws -> RegisterResponse {
        let parameters: [String: Any] = [
            "firstName": request.firstName,
            "lastName": request.lastName,
            "email": request.email,
            "password": request.password,
            "phone": request.phone
        ]
        
        return try await performRequest(
            url: APIConfig.Auth.register,
            method: .post,
            parameters: parameters
        )
    }
    
    // MARK: - Send OTP
    func sendOTP(email: String) async throws -> OTPSendResponse {
        return try await performRequest(
            url: APIConfig.OTP.send,
            method: .post,
            parameters: ["email": email],
            encoding: URLEncoding.queryString
        )
    }

    // MARK: - Verify OTP
    func verifyOTP(email: String, otp: String) async throws -> OTPVerifyResponse {
        return try await performRequest(
            url: APIConfig.OTP.verify,
            method: .post,
            parameters: ["email": email, "otp": otp],
            encoding: URLEncoding.queryString
        )
    }

    // MARK: - Generic Request Helper
    private func performRequest<T: Decodable>(
        url: String,
        method: HTTPMethod,
        parameters: [String: Any],
        encoding: ParameterEncoding = JSONEncoding.default
    ) async throws -> T {
        logger.info("REQUEST: \(method.rawValue) \(url)")
        logger.debug("PARAMETERS: \(parameters.description)")
        
        let task = session.request(
            url,
            method: method,
            parameters: parameters,
            encoding: encoding
        )
        .validate(statusCode: 200..<300)
        .serializingData()
        
        let response = await task.response
        
        logger.info("STATUS CODE: \(response.response?.statusCode ?? -1)")
        
        switch response.result {
        case .success(let data):
            let rawJSON = String(data: data, encoding: .utf8) ?? "nil"
            logger.info("RAW RESPONSE: \(rawJSON)")
            
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
            
            throw mapError(
                afError,
                data: response.data,
                statusCode: response.response?.statusCode
            )
        }
    }
    
    // MARK: - Error Mapping
    private func mapError(_ afError: AFError, data: Data?, statusCode: Int?) -> NetworkError {
        // Try JSON error response first
        if let data = data,
           let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return .serverError(errorResponse.displayMessage)
        }

        // Fall back to plain text error response
        if let data = data,
           let plainText = String(data: data, encoding: .utf8),
           !plainText.isEmpty {
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
        
        if statusCode == 401 {
            return .unauthorized
        }
        
        return .unknown(afError)
    }
}
