//
//  LoginView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var showPassword = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header Section
                        VStack(spacing: 16) {
                            Spacer()
                                .frame(height: 60)
                            
                            // Logo
                            ZStack {
                                Circle()
                                    .fill(Color.grocartGreen.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "cart.fill")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.grocartGreen)
                            }
                            
                            Text("GroCart")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.grocartPrimary)
                            
                            Text("Fresh groceries delivered to Northern Ontario")
                                .font(.system(size: 15))
                                .foregroundColor(.grocartSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.bottom, 50)
                        
                        // Form Section
                        VStack(spacing: 20) {
                            // Email Field
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
                                        .onChange(of: viewModel.email) { _ in
                                            viewModel.clearError()
                                        }
                                }
                                .padding()
                                .background(Color.grocartSecondaryBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.grocartPrimary)
                                
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(.grocartSecondary)
                                        .frame(width: 20)
                                    
                                    if showPassword {
                                        TextField("Enter your password", text: $viewModel.password)
                                            .textContentType(.password)
                                    } else {
                                        SecureField("Enter your password", text: $viewModel.password)
                                            .textContentType(.password)
                                    }
                                    
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(.grocartSecondary)
                                    }
                                }
                                .padding()
                                .background(Color.grocartSecondaryBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            // Forgot Password
                            HStack {
                                Spacer()
                                Button(action: {
                                    // TODO: Forgot password
                                }) {
                                    Text("Forgot Password?")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.grocartGreen)
                                }
                            }
                            
                            // Error Message
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
                            
                            // Login Button
                            Button(action: {
                                viewModel.login()
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(viewModel.isFormValid ? Color.grocartGreen : Color.grocartGreen.opacity(0.5))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(viewModel.isLoading || !viewModel.isFormValid)
                            .padding(.top, 10)
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                                
                                Text("OR")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.grocartSecondary)
                                    .padding(.horizontal, 8)
                                
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 10)
                            
                            // OTP Login Button
                            Button(action: {
                                // TODO: Handle OTP login
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "message.badge.circle.fill")
                                        .font(.title3)
                                    Text("Sign In with OTP")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .foregroundColor(.grocartPrimary)
                                .background(Color.grocartSecondaryBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            // Sign Up Link
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .font(.system(size: 15))
                                    .foregroundColor(.grocartSecondary)
                                
                                NavigationLink(destination: SignUpView()) {
                                    Text("Sign Up")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.grocartGreen)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
            .fullScreenCover(isPresented: $viewModel.isLoginSuccessful) {
                OnboardingView()
            }
        }
    }
}
