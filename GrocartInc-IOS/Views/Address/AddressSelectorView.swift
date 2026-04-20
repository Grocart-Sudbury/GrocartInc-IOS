// AddressSelectorView.swift
// GrocartInc-IOS
// Sheet presented from CheckoutView; lets the user pick, add, or edit addresses.

import SwiftUI

struct AddressSelectorView: View {
    @StateObject private var viewModel = AddressViewModel()
    @Binding var selectedAddress: CustomerAddress?
    @Environment(\.dismiss) private var dismiss

    @State private var showAddForm = false
    @State private var editingAddress: CustomerAddress?

    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.addresses.isEmpty {
                        ProgressView("Loading addresses…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                if let error = viewModel.errorMessage {
                                    errorBanner(error)
                                }

                                ForEach(viewModel.addresses) { address in
                                    addressRow(address)
                                }

                                if viewModel.canAddMore {
                                    addButton
                                } else {
                                    Text("Maximum of 10 addresses reached.")
                                        .font(.system(size: 13))
                                        .foregroundColor(.grocartSecondary)
                                        .padding()
                                }

                                Spacer(minLength: 40)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                    }
                }
            }
            .navigationTitle("Select Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.grocartGreen)
                }
            }
            .sheet(isPresented: $showAddForm) {
                AddressFormView { req in
                    try await viewModel.add(req)
                }
            }
            .sheet(item: $editingAddress) { addr in
                AddressFormView(editingAddress: addr) { req in
                    try await viewModel.update(id: addr.id, request: req)
                }
            }
            .onAppear { viewModel.load() }
        }
    }

    // MARK: - Address Row

    private func addressRow(_ address: CustomerAddress) -> some View {
        let isSelected = selectedAddress?.id == address.id
        return Button(action: {
            selectedAddress = address
            dismiss()
        }) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.grocartGreen : Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.grocartGreen)
                            .frame(width: 12, height: 12)
                    }
                }

                // Address info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(address.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                        if address.isDefault {
                            Text("DEFAULT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.grocartGreen)
                                .tracking(0.5)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.grocartGreen.opacity(0.1)))
                        }
                    }
                    Text(address.fullName)
                        .font(.system(size: 13))
                        .foregroundColor(.grocartSecondary)
                    Text(address.displayAddress)
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary.opacity(0.8))
                        .lineLimit(2)
                    Text(address.phone)
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary.opacity(0.8))
                }

                Spacer()

                // Actions menu
                Menu {
                    Button(action: { editingAddress = address }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    if !address.isDefault {
                        Button(action: { viewModel.setDefault(id: address.id) }) {
                            Label("Set as Default", systemImage: "checkmark.circle")
                        }
                    }
                    Button(role: .destructive, action: { viewModel.delete(id: address.id) }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.grocartSecondary)
                        .frame(width: 32, height: 32)
                }
                .simultaneousGesture(TapGesture())
            }
            .padding(14)
            .background(Color.grocartSecondaryBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.grocartGreen.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button(action: { showAddForm = true }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.grocartGreen, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                }
                Text("Add New Address")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.grocartGreen)
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.grocartGreen.opacity(0.3),
                            style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .background(Color.grocartGreen.opacity(0.03).cornerRadius(14))
            )
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.white)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(14)
        .background(Color.red.opacity(0.9))
        .cornerRadius(12)
    }
}
