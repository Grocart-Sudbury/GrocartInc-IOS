// EditProfileView.swift
// GrocartInc-IOS

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    @State private var firstName: String
    @State private var lastName: String
    @State private var phone: String

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        let p = viewModel.profile
        _firstName = State(initialValue: p?.firstName ?? SessionManager.shared.currentUser?.firstName ?? "")
        _lastName  = State(initialValue: p?.lastName  ?? SessionManager.shared.currentUser?.lastName  ?? "")
        _phone     = State(initialValue: p?.phone ?? "")
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.grocartGreen.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.grocartGreen)
                        }
                        .padding(.top, 10)

                        // Fields
                        VStack(spacing: 0) {
                            ProfileField(label: "First Name", text: $firstName, placeholder: "First name")
                            Divider().padding(.horizontal, 16)
                            ProfileField(label: "Last Name", text: $lastName, placeholder: "Last name")
                            Divider().padding(.horizontal, 16)
                            ProfileField(label: "Phone", text: $phone, placeholder: "Phone number",
                                         keyboardType: .phonePad)
                            Divider().padding(.horizontal, 16)

                            // Email (read-only)
                            HStack(spacing: 12) {
                                Text("Email")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.grocartSecondary)
                                    .frame(width: 90, alignment: .leading)
                                Text(viewModel.profile?.email ?? SessionManager.shared.currentUser?.email ?? "")
                                    .font(.system(size: 15))
                                    .foregroundColor(.grocartSecondary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.grocartSecondary.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(Color.grocartSecondaryBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)

                        // Error / success
                        if let msg = viewModel.errorMessage {
                            Text(msg)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                        }

                        // Save Button
                        Button {
                            Task {
                                let saved = await viewModel.update(
                                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                                    phone: phone.trimmingCharacters(in: .whitespaces)
                                )
                                if saved { dismiss() }
                            }
                        } label: {
                            ZStack {
                                Text("Save Changes")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .opacity(viewModel.isSaving ? 0 : 1)

                                if viewModel.isSaving {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? Color.grocartGreen : Color.grocartGreen.opacity(0.4))
                            .cornerRadius(14)
                        }
                        .disabled(!isValid || viewModel.isSaving)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Profile Field

private struct ProfileField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.grocartSecondary)
                .frame(width: 90, alignment: .leading)
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(.grocartPrimary)
                .keyboardType(keyboardType)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
