// AddressFormView.swift
// GrocartInc-IOS

import SwiftUI
import MapKit
import Combine

// MARK: - Address search completer

private final class AddressSearchCompleter: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    var suggestions: [MKLocalSearchCompletion] = [] {
        willSet { objectWillChange.send() }
    }

    private let completer = MKLocalSearchCompleter()
    private let delegate = CompleterDelegate()

    init() {
        delegate.onUpdate = { [weak self] results in
            DispatchQueue.main.async { self?.suggestions = results }
        }
        completer.delegate = delegate
        completer.resultTypes = .address
        let canadaCenter = CLLocationCoordinate2D(latitude: 56.1304, longitude: -106.3468)
        let canadaSpan = MKCoordinateSpan(latitudeDelta: 28, longitudeDelta: 60)
        completer.region = MKCoordinateRegion(center: canadaCenter, span: canadaSpan)
    }

    func update(_ query: String) { completer.queryFragment = query }

    func clear() {
        completer.queryFragment = ""
        suggestions = []
    }

    // NSObject subclass kept separate so ObservableObject conformance compiles cleanly
    private class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
        var onUpdate: ([MKLocalSearchCompletion]) -> Void = { _ in }

        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            onUpdate(completer.results.filter {
                $0.subtitle.contains("Canada") || $0.subtitle.isEmpty
            })
        }

        func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
            onUpdate([])
        }
    }
}

// MARK: - Main form

struct AddressFormView: View {
    let editingAddress: CustomerAddress?
    let onSave: (AddressRequest) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = AddressSearchCompleter()

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
    @State private var showSuggestions = false
    @State private var isResolvingSuggestion = false

    private let labelOptions = ["Home", "Work", "Other"]

    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !phone.isEmpty &&
        !address.isEmpty && !city.isEmpty && !postalCode.isEmpty
    }

    /// The required fields still empty, so the form can say what's
    /// blocking Save instead of just greying the button out.
    private var missingFields: [String] {
        var missing: [String] = []
        if firstName.isEmpty { missing.append("First name") }
        if lastName.isEmpty { missing.append("Last name") }
        if phone.isEmpty { missing.append("Phone number") }
        if address.isEmpty { missing.append("Street address") }
        if city.isEmpty { missing.append("City") }
        if postalCode.isEmpty { missing.append("Postal code") }
        return missing
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
                        addressFieldWithSuggestions
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
                        if !isFormValid {
                            Text("Still needed: \(missingFields.joined(separator: ", "))")
                                .font(.system(size: 13))
                                .foregroundColor(.orange)
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

    // MARK: - Address field with autocomplete

    private var addressFieldWithSuggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Street address", text: $address)
                    .font(.system(size: 15))
                    .onChange(of: address) { newValue in
                        if !isResolvingSuggestion {
                            if newValue.count >= 3 {
                                completer.update(newValue)
                                showSuggestions = true
                            } else {
                                completer.clear()
                                showSuggestions = false
                            }
                        }
                    }

                if !address.isEmpty {
                    Button {
                        address = ""
                        completer.clear()
                        showSuggestions = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.6))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(12)
            .background(Color.grocartSecondaryBackground)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))

            if showSuggestions && !completer.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(completer.suggestions.prefix(5), id: \.self) { suggestion in
                        Button {
                            resolveSuggestion(suggestion)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.grocartGreen)
                                    .font(.system(size: 18))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.grocartPrimary)
                                        .lineLimit(1)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.system(size: 12))
                                            .foregroundColor(.grocartSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }

                        if suggestion !== completer.suggestions.prefix(5).last {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .background(Color.grocartSecondaryBackground)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
        }
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

    private func resolveSuggestion(_ completion: MKLocalSearchCompletion) {
        isResolvingSuggestion = true
        showSuggestions = false
        completer.clear()

        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { [self] response, _ in
            guard let placemark = response?.mapItems.first?.placemark else {
                DispatchQueue.main.async { self.isResolvingSuggestion = false }
                return
            }
            DispatchQueue.main.async {
                if let number = placemark.subThoroughfare, let street = placemark.thoroughfare {
                    self.address = "\(number) \(street)"
                } else if let street = placemark.thoroughfare {
                    self.address = street
                }
                self.city       = placemark.locality ?? self.city
                self.province   = placemark.administrativeArea ?? self.province
                self.postalCode = (placemark.postalCode ?? self.postalCode).uppercased()
                // Reset flag AFTER all fields are written so onChange doesn't re-trigger autocomplete
                self.isResolvingSuggestion = false
            }
        }
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
