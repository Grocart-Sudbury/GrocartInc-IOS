//
//  OTPLoginView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import SwiftUI

struct OTPLoginView: View {
    @StateObject private var viewModel = OTPViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.grocartGreen.opacity(0.1))
                                .frame(width: 100, height: 100)
                            Image(systemName: "message.badge.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.grocartGreen)
                        }

                        Text(viewModel.step == .enterEmail ? "Sign In with OTP" : "Enter OTP")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.grocartPrimary)

                        Text(viewModel.step == .enterEmail
                             ? "We'll send a 6-digit code to your email"
                             : "Code sent to \(viewModel.email)")
                            .font(.system(size: 15))
                            .foregroundColor(.grocartSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 50)

                    // Form
                    VStack(spacing: 20) {
                        if viewModel.step == .enterEmail {
                            emailSection
                        } else {
                            otpSection
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) {
            Button(action: {
                if viewModel.step == .enterOTP {
                    viewModel.goBackToEmail()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                    .padding(12)
                    .background(Color.grocartSecondaryBackground)
                    .clipShape(Circle())
            }
            .padding(.top, 56)
            .padding(.leading, 16)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.step)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
    }

    // MARK: - Email Section
    private var emailSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.grocartPrimary)

                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.grocartSecondary)
                        .frame(width: 20)
                    TextField("Enter your email", text: $viewModel.email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .onChange(of: viewModel.email) { _ in viewModel.clearError() }
                }
                .padding()
                .background(Color.grocartSecondaryBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }

            errorView

            Button(action: { viewModel.sendOTP() }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Send OTP")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(viewModel.isEmailValid ? Color.grocartGreen : Color.grocartGreen.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading || !viewModel.isEmailValid)
        }
    }

    // MARK: - OTP Section
    private var otpSection: some View {
        VStack(spacing: 20) {
            OTPFieldView(otp: $viewModel.otp)
                .onChange(of: viewModel.otp) { _ in viewModel.clearError() }

            errorView

            Button(action: { viewModel.verifyOTP() }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Verify OTP")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(viewModel.isOTPValid ? Color.grocartGreen : Color.grocartGreen.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading || !viewModel.isOTPValid)

            // Resend
            HStack(spacing: 4) {
                Text("Didn't receive the code?")
                    .font(.system(size: 14))
                    .foregroundColor(.grocartSecondary)

                if viewModel.resendCountdown > 0 {
                    Text("Resend in \(viewModel.resendCountdown)s")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.grocartSecondary)
                } else {
                    Button(action: { viewModel.resendOTP() }) {
                        Text("Resend OTP")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.grocartGreen)
                    }
                    .disabled(!viewModel.canResend)
                }
            }
        }
    }

    // MARK: - Error View
    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - OTP Field (6 individual boxes)
struct OTPFieldView: View {
    @Binding var otp: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Hidden text field captures input
            TextField("", text: $otp)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .opacity(0)
                .frame(width: 1, height: 1)
                .onChange(of: otp) { newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(6))
                    if filtered != newValue { otp = filtered }
                }

            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    let char: String = index < otp.count
                        ? String(otp[otp.index(otp.startIndex, offsetBy: index)])
                        : ""
                    let isCurrent = index == otp.count

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.grocartSecondaryBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isCurrent && isFocused ? Color.grocartGreen : Color.gray.opacity(0.3),
                                            lineWidth: isCurrent && isFocused ? 2 : 1)
                            )

                        Text(char)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                    }
                    .frame(width: 48, height: 56)
                }
            }
            .onTapGesture { isFocused = true }
        }
        .onAppear { isFocused = true }
    }
}
