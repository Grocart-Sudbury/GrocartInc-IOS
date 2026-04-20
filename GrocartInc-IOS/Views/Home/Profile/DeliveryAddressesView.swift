//
//  DeliveryAddressesView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct DeliveryAddressesView: View {
    @StateObject private var viewModel = AddressViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showAddForm = false
    @State private var editingAddress: CustomerAddress?
    @State private var addressToDelete: CustomerAddress?
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.addresses.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            mapHeader
                            if let error = viewModel.errorMessage {
                                errorBanner(error)
                            }
                            ForEach(viewModel.addresses) { address in
                                AddressCard(
                                    address: address,
                                    onSetDefault: { viewModel.setDefault(id: address.id) },
                                    onEdit: { editingAddress = address },
                                    onDelete: {
                                        addressToDelete = address
                                        showDeleteAlert = true
                                    }
                                )
                                .padding(.horizontal, 20)
                            }
                            if viewModel.canAddMore {
                                addButton
                            }
                            Spacer(minLength: 40)
                        }
                        .padding(.top, 10)
                    }
                }
            }
        }
        .navigationTitle("Delivery Addresses")
        .navigationBarTitleDisplayMode(.large)
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
        .alert("Delete Address", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let addr = addressToDelete {
                    viewModel.delete(id: addr.id)
                }
            }
        } message: {
            Text("Are you sure you want to remove this address?")
        }
        .onAppear { viewModel.load() }
    }

    // MARK: - Subviews

    private var mapHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.92, green: 0.95, blue: 0.98),
                                 Color(red: 0.86, green: 0.92, blue: 0.97)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: 120)

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.grocartGreen.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.grocartGreen)
                }
                Text("\(viewModel.addresses.count) saved address\(viewModel.addresses.count != 1 ? "es" : "")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.grocartSecondary)
            }
        }
        .padding(.horizontal, 20)
    }

    private var addButton: some View {
        Button(action: { showAddForm = true }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.grocartGreen, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .frame(width: 42, height: 42)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add New Address")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                    Text("Save a delivery location")
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.grocartGreen)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.grocartGreen.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
                    .background(Color.grocartGreen.opacity(0.03).cornerRadius(16))
            )
        }
        .padding(.horizontal, 20)
    }

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
        .padding(.horizontal, 20)
    }
}

// MARK: - Address Card
struct AddressCard: View {
    let address: CustomerAddress
    let onSetDefault: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private func labelIcon(for label: String) -> String {
        switch label.lowercased() {
        case "home": return "house.fill"
        case "work": return "briefcase.fill"
        default:     return "mappin.circle.fill"
        }
    }

    private var cardColor: Color {
        switch address.label.lowercased() {
        case "home": return Color(red: 0.18, green: 0.72, blue: 0.47)
        case "work": return Color(red: 0.25, green: 0.55, blue: 0.95)
        default:     return Color(red: 0.72, green: 0.35, blue: 0.85)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cardColor.opacity(0.1))
                        .frame(width: 42, height: 42)
                    Image(systemName: labelIcon(for: address.label))
                        .font(.system(size: 17))
                        .foregroundColor(cardColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(address.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                        if address.isDefault {
                            Text("DEFAULT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.grocartGreen)
                                .tracking(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.grocartGreen.opacity(0.1)))
                        }
                    }
                    Text(address.fullName)
                        .font(.system(size: 13))
                        .foregroundColor(.grocartSecondary)
                    Text(address.address)
                        .font(.system(size: 13))
                        .foregroundColor(.grocartSecondary)
                    Text("\(address.city), \(address.province) \(address.postalCode)")
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary.opacity(0.8))
                }

                Spacer()

                Menu {
                    if !address.isDefault {
                        Button(action: onSetDefault) {
                            Label("Set as Default", systemImage: "checkmark.circle")
                        }
                    }
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.grocartSecondary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(16)

            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.grocartSecondary)
                Text(address.phone)
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .padding(.top, -4)
        }
        .background(Color.grocartSecondaryBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(address.isDefault ? Color.grocartGreen.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}

#Preview {
    NavigationStack {
        DeliveryAddressesView()
    }
}
