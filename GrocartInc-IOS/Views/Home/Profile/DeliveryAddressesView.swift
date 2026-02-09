//
//  DeliveryAddressesView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

//
//  DeliveryAddressesView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

// MARK: - Address Model
struct DeliveryAddress: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let fullAddress: String
    let city: String
    let postalCode: String
    let phone: String
    var isDefault: Bool
    let color: Color
}

// MARK: - Delivery Addresses View
struct DeliveryAddressesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var addresses: [DeliveryAddress] = [
        DeliveryAddress(
            label: "Home",
            icon: "house.fill",
            fullAddress: "142 Pine Street South",
            city: "Timmins, ON",
            postalCode: "P4N 2K1",
            phone: "+1 (705) 555-0123",
            isDefault: true,
            color: Color(red: 0.18, green: 0.72, blue: 0.47)
        ),
        DeliveryAddress(
            label: "Work",
            icon: "briefcase.fill",
            fullAddress: "85 Algonquin Blvd East",
            city: "Timmins, ON",
            postalCode: "P4N 1B3",
            phone: "+1 (705) 555-0456",
            isDefault: false,
            color: Color(red: 0.25, green: 0.55, blue: 0.95)
        ),
        DeliveryAddress(
            label: "Mom's Place",
            icon: "heart.fill",
            fullAddress: "310 Riverside Drive",
            city: "Timmins, ON",
            postalCode: "P4N 3V7",
            phone: "+1 (705) 555-0789",
            isDefault: false,
            color: Color(red: 0.72, green: 0.35, blue: 0.85)
        )
    ]
    @State private var showAddSheet = false
    @State private var addressToDelete: DeliveryAddress?
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    // Map Preview Header
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.92, green: 0.95, blue: 0.98),
                                        Color(red: 0.86, green: 0.92, blue: 0.97)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
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
                            
                            Text("\(addresses.count) saved address\(addresses.count != 1 ? "es" : "")")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.grocartSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Address Cards
                    ForEach(addresses) { address in
                        AddressCard(
                            address: address,
                            onSetDefault: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    for i in addresses.indices {
                                        addresses[i].isDefault = addresses[i].id == address.id
                                    }
                                }
                            },
                            onEdit: {},
                            onDelete: {
                                addressToDelete = address
                                showDeleteAlert = true
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Add New Address Button
                    Button(action: { showAddSheet = true }) {
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
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 10)
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
        .alert("Delete Address", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let address = addressToDelete {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        addresses.removeAll { $0.id == address.id }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to remove this address?")
        }
    }
}

// MARK: - Address Card
struct AddressCard: View {
    let address: DeliveryAddress
    let onSetDefault: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(address.color.opacity(0.1))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: address.icon)
                        .font(.system(size: 17))
                        .foregroundColor(address.color)
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
                                .background(
                                    Capsule().fill(Color.grocartGreen.opacity(0.1))
                                )
                        }
                    }
                    
                    Text(address.fullAddress)
                        .font(.system(size: 13))
                        .foregroundColor(.grocartSecondary)
                    
                    Text("\(address.city) \(address.postalCode)")
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
            
            // Phone Row
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
