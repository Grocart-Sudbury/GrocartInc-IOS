//
//  SignUpView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image("GrocartLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200)
                        .padding(.bottom, 8)

                    Text("Sign up to start ordering fresh groceries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                // Form Fields
                VStack(spacing: 16) {
                    // First & Last Name
                    HStack(spacing: 12) {
                        InputField(
                            icon: "person.fill",
                            placeholder: "First Name",
                            text: $viewModel.firstName
                        )
                        
                        InputField(
                            icon: "person.fill",
                            placeholder: "Last Name",
                            text: $viewModel.lastName
                        )
                    }
                    
                    InputField(
                        icon: "envelope.fill",
                        placeholder: "Email Address",
                        text: $viewModel.email,
                        keyboardType: .emailAddress
                    )
                    
                    InputField(
                        icon: "phone.fill",
                        placeholder: "Phone Number",
                        text: $viewModel.phone,
                        keyboardType: .phonePad
                    )
                    
                    SecureInputField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $viewModel.password,
                        isVisible: $isPasswordVisible
                    )
                    
                    SecureInputField(
                        icon: "lock.fill",
                        placeholder: "Confirm Password",
                        text: $viewModel.confirmPassword,
                        isVisible: $isConfirmPasswordVisible
                    )
                    
                    // Password Mismatch Warning
                    if viewModel.passwordMismatch {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Passwords do not match")
                                .font(.system(size: 13))
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
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
                
                // Terms
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        viewModel.agreedToTerms.toggle()
                    } label: {
                        Image(systemName: viewModel.agreedToTerms ? "checkmark.square.fill" : "square")
                            .foregroundStyle(viewModel.agreedToTerms ? Color.grocartGreen : Color.secondary)
                            .font(.title3)
                    }
                    
                    Text("I agree to the **[Terms of Service](terms)** and **[Privacy Policy](privacy)**")
                        .tint(Color.grocartGreen)
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Sign Up Button
                Button {
                    viewModel.register()
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Create Account")
                                .font(.headline)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(viewModel.isFormValid ? Color.grocartGreen : Color.grocartGreen.opacity(0.4))
                    )
                }
                .disabled(!viewModel.isFormValid || viewModel.isLoading)
                
                // Sign In Link
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(.secondary)
                    Button("Sign In") {
                        dismiss()
                    }
                    .foregroundStyle(Color.grocartGreen)
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
        .animation(.easeInOut(duration: 0.3), value: viewModel.passwordMismatch)
        .alert("Success", isPresented: $viewModel.isRegistrationSuccessful) {
            Button("Sign In") {
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "Registration successful. Please login.")
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
