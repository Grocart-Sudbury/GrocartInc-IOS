// AddressFormView.swift
// GrocartInc-IOS

import SwiftUI

struct AddressFormView: View {
    let editingAddress: CustomerAddress?
    let onSave: (AddressRequest) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label = "Home"
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var city = ""
    @State private var province = "ON"
    @State private var postalCode = ""
    @State private var isDefault = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let labelOptions = ["Home", "Work", "Other"]

    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !phone.isEmpty &&
        !address.isEmpty && !city.isEmpty && !postalCode.isEmpty
    }

    init(editingAddress: CustomerAddress? = nil, onSave: @escaping (AddressRequest) async throws -> Void) {
        self.editingAddress = editingAddress
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        labelPicker
                        nameRow
                        styledField("Phone number", text: $phone, keyboard: .phonePad)
                        styledField("Street address", text: $address)
                        cityProvinceRow
                        styledField("Postal code", text: $postalCode)
                            .textInputAutocapitalization(.characters)
                        defaultToggle
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        saveButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle(editingAddress == nil ? "Add Address" : "Edit Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.grocartGreen)
                }
            }
        }
        .onAppear(perform: prefill)
    }

    // MARK: - Subviews

    private var labelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Label")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.grocartSecondary)
            HStack(spacing: 10) {
                ForEach(labelOptions, id: \.self) { option in
                    let selected = label == option
                    Button(action: { label = option }) {
                        Text(option)
                            .font(.system(size: 14, weight: selected ? .semibold : .regular))
                            .foregroundColor(selected ? .white : .grocartPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selected ? Color.grocartGreen : Color.grocartSecondaryBackground)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private var nameRow: some View {
        HStack(spacing: 10) {
            styledField("First name", text: $firstName)
            styledField("Last name", text: $lastName)
        }
    }

    private var cityProvinceRow: some View {
        HStack(spacing: 10) {
            styledField("City", text: $city)
            styledField("Province", text: $province)
                .frame(maxWidth: 80)
        }
    }

    private var defaultToggle: some View {
        Toggle(isOn: $isDefault) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Set as default")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.grocartPrimary)
                Text("Use this address automatically at checkout")
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
            }
        }
        .tint(.grocartGreen)
        .padding(14)
        .background(Color.grocartSecondaryBackground)
        .cornerRadius(12)
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack {
                if isSaving {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(editingAddress == nil ? "Save Address" : "Update Address")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isFormValid ? Color.grocartGreen : Color.grocartGreen.opacity(0.5))
            .cornerRadius(14)
        }
        .disabled(!isFormValid || isSaving)
    }

    // MARK: - Helpers

    private func styledField(_ placeholder: String, text: Binding<String>,
                              keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(.system(size: 15))
            .padding(12)
            .background(Color.grocartSecondaryBackground)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    private func prefill() {
        guard let a = editingAddress else {
            let user = SessionManager.shared.currentUser
            firstName = user?.firstName ?? ""
            lastName  = user?.lastName  ?? ""
            return
        }
        label      = a.label
        firstName  = a.firstName
        lastName   = a.lastName
        phone      = a.phone
        address    = a.address
        city       = a.city
        province   = a.province
        postalCode = a.postalCode
        isDefault  = a.isDefault
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let req = AddressRequest(
            label: label,
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName:  lastName.trimmingCharacters(in: .whitespaces),
            phone:     phone.trimmingCharacters(in: .whitespaces),
            address:   address.trimmingCharacters(in: .whitespaces),
            city:      city.trimmingCharacters(in: .whitespaces),
            province:  province.trimmingCharacters(in: .whitespaces).uppercased(),
            postalCode: postalCode.trimmingCharacters(in: .whitespaces).uppercased(),
            isDefault: isDefault
        )
        Task {
            do {
                try await onSave(req)
                isSaving = false
                dismiss()
            } catch let e as NetworkError {
                errorMessage = e.errorDescription
                isSaving = false
            } catch {
                errorMessage = "Failed to save address."
                isSaving = false
            }
        }
    }
}
