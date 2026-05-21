//
//  AuthInterceptor.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

//
//  AuthInterceptor.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import Foundation
import Alamofire

final class AuthInterceptor: RequestInterceptor, @unchecked Sendable {

    nonisolated(unsafe) static let shared = AuthInterceptor()

    private init() {}

    // MARK: - Adapt (Add token to requests)
    nonisolated func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping @Sendable (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest

        if let token = KeychainManager.shared.get(key: KeychainManager.Keys.authToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        completion(.success(request))
    }

    // MARK: - Retry (Handle 401 by logging out)
    nonisolated func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping @Sendable (RetryResult) -> Void) {
        guard let statusCode = request.response?.statusCode, statusCode == 401 else {
            completion(.doNotRetry)
            return
        }

        // If the body contains a business error message (e.g. stock validation),
        // this is NOT a real auth failure — let the repository handle it.
        if let data = (request as? DataRequest)?.data,
           let json = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
           let message = json.message, !message.isEmpty {
            completion(.doNotRetry)
            return
        }

        // Only treat 401 as session expiry if the user was actually logged in.
        // Guest users hitting auth-required endpoints get 401 silently.
        if SessionManager.shared.isLoggedIn {
            SessionManager.shared.expireSession()
        }

        completion(.doNotRetry)
    }
}

// MARK: - Authenticated Session (Use this for all authenticated API calls)
extension Session {
    nonisolated(unsafe) static let authenticated: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = APIConfig.requestTimeout
        configuration.timeoutIntervalForResource = APIConfig.resourceTimeout
        return Session(configuration: configuration, interceptor: AuthInterceptor.shared)
    }()
}
