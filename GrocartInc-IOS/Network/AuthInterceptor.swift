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

final class AuthInterceptor: RequestInterceptor {
    
    static let shared = AuthInterceptor()
    
    private init() {}
    
    // MARK: - Adapt (Add token to requests)
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        
        if let token = SessionManager.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        completion(.success(request))
    }
    
    // MARK: - Retry (Handle 401 by logging out)
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let statusCode = request.response?.statusCode, statusCode == 401 else {
            completion(.doNotRetry)
            return
        }
        
        // Token expired — clear session and force re-login
        DispatchQueue.main.async {
            SessionManager.shared.clearSession()
        }
        
        completion(.doNotRetry)
    }
}

// MARK: - Authenticated Session (Use this for all authenticated API calls)
extension Session {
    static let authenticated: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = APIConfig.requestTimeout
        configuration.timeoutIntervalForResource = APIConfig.resourceTimeout
        return Session(configuration: configuration, interceptor: AuthInterceptor.shared)
    }()
}
