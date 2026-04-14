//
//  AuthRepositoryProtocol.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-11.
//


    
    //
    //  AuthRepositoryProtocol.swift
    //  GrocartInc-IOS
    //
    //  Created by Athul Babu on 2026-02-09.
    //

    import Foundation

    protocol AuthRepositoryProtocol: Sendable {

        // MARK: - Authentication
        func login(email: String, password: String) async throws -> LoginResponse
        func register(request: RegisterRequest) async throws -> RegisterResponse

        // MARK: - OTP
        func sendOTP(email: String) async throws -> OTPSendResponse
        func verifyOTP(email: String, otp: String) async throws -> OTPVerifyResponse
    }
   


