//
//  SignUpView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct SignUpView: View {
    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var agreedToTerms = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    
                    Text("Create Account")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("Sign up to start ordering fresh groceries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                // Form Fields
                VStack(spacing: 16) {
                    InputField(
                        icon: "person.fill",
                        placeholder: "Full Name",
                        text: $fullName
                    )
                    
                    InputField(
                        icon: "envelope.fill",
                        placeholder: "Email Address",
                        text: $email,
                        keyboardType: .emailAddress
                    )
                    
                    InputField(
                        icon: "phone.fill",
                        placeholder: "Phone Number",
                        text: $phone,
                        keyboardType: .phonePad
                    )
                    
                    SecureInputField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        isVisible: $isPasswordVisible
                    )
                    
                    SecureInputField(
                        icon: "lock.fill",
                        placeholder: "Confirm Password",
                        text: $confirmPassword,
                        isVisible: $isConfirmPasswordVisible
                    )
                }
                
                // Terms
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        agreedToTerms.toggle()
                    } label: {
                        Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                            .foregroundStyle(agreedToTerms ? .green : .secondary)
                            .font(.title3)
                    }
                    
                    Text("I agree to the **[Terms of Service](terms)** and **[Privacy Policy](privacy)**")
                        .tint(.green)
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Sign Up Button
                Button {
                    // Handle sign up
                } label: {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isFormValid ? .green : .green.opacity(0.4))
                        )
                }
                .disabled(!isFormValid)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.secondary.opacity(0.3))
                    Text("or")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.secondary.opacity(0.3))
                }
                
                // Social Sign Up
                SocialButton(
                    icon: "g.circle.fill",
                    title: "Continue with Google",
                    bgColor: Color(.secondarySystemBackground),
                    fgColor: .primary,
                    hasBorder: true
                )
                
                // Sign In Link
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(.secondary)
                    Button("Sign In") {
                        dismiss()
                    }
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var isFormValid: Bool {
        !fullName.isEmpty &&
        !email.isEmpty &&
        !phone.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        agreedToTerms
    }
}

// MARK: - Input Field Component
struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Secure Input Field Component
struct SecureInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            
            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Social Button Component
struct SocialButton: View {
    let icon: String
    let title: String
    let bgColor: Color
    let fgColor: Color
    var hasBorder: Bool = false
    
    var body: some View {
        Button {
            // Handle social sign up
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .fontWeight(.medium)
            }
            .foregroundStyle(fgColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(hasBorder ? Color.secondary.opacity(0.3) : .clear, lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
