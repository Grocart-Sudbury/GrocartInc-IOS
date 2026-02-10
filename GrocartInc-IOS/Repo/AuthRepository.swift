//
//  AuthRepository.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation
@preconcurrency import Alamofire

protocol AuthRepositoryProtocol: Sendable {
    func login(email: String, password: String) async throws -> LoginResponse
    func logout()
}

final class AuthRepository: @unchecked Sendable, AuthRepositoryProtocol {
    
    static let shared = AuthRepository()
    
    private let session: Session
    
    private init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = APIConfig.requestTimeout
        configuration.timeoutIntervalForResource = APIConfig.resourceTimeout
        self.session = Session(configuration: configuration)
    }
    
    func login(email: String, password: String) async throws -> LoginResponse {
        let parameters: [String: String] = [
            "email": email,
            "password": password
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                APIConfig.Auth.login,
                method: .post,
                parameters: parameters,
                encoding: JSONEncoding.default
            )
            .validate(statusCode: 200..<300)
            .responseData { [weak self] dataResponse in
                switch dataResponse.result {
                case .success(let data):
                    do {
                        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                        continuation.resume(returning: loginResponse)
                    } catch {
                        continuation.resume(throwing: NetworkError.unknown(error))
                    }
                case .failure(let afError):
                    let error = self?.mapError(
                        afError,
                        data: dataResponse.data,
                        statusCode: dataResponse.response?.statusCode
                    ) ?? .unknown(afError)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Logout
    func logout() {
        KeychainManager.shared.delete(key: KeychainManager.Keys.authToken)
        KeychainManager.shared.delete(key: KeychainManager.Keys.userId)
        UserDefaults.standard.removeObject(forKey: "current_user")
    }
    
    // MARK: - Error Mapping
    private func mapError(_ afError: AFError, data: Data?, statusCode: Int?) -> NetworkError {
        if let data = data,
           let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            if statusCode == 401 {
                return .unauthorized
            }
            return .serverError(errorResponse.displayMessage)
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
